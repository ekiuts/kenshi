-- KenshiLinter.lua
-- In-game Lua linter for KenshiLua mod scripts.
--
-- Run this file once from the in-game Console / Script Editor (Ctrl+Shift+L),
-- then call any of the exported helpers. The helpers return formatted report
-- strings (which the Console prints), and also write a full report to
-- ./KenshiLinterReport.txt and echo findings through KenshiLua.logWarn.
--
--   lintMod("KenshiMedic")                       -- check one mod
--   lintMods({"KenshiMedic", "KenshiCompact"})   -- check several
--   lintFile("mods/KenshiMedic/scripts/init/medic.lua")
--   lintAll()                                    -- every mod with a scripts/ dir
--   fixMod("KenshiMedic", true)                  -- write .lint_fixed.lua copies
--   fixMod("KenshiMedic", false, true)           -- apply fixes in place (backs up first)
--
-- What it detects (static analysis; nothing is executed):
--   * syntax errors            (via loadstring/load)
--   * calls/references to globals that do not exist (e.g. getGameWorldd)
--   * method / property names that are not found on any bound class
--     (e.g. obj:healCompletly), with closest-match suggestions
--   * field access on the live global instances (ou, player, key, ...) and on
--     enum tables (ProneState.PS_NORMAL, ...) verified against the real members
--
-- The API index (globals, classes, enum tables) is built at runtime from the
-- live Lua state, so it is always in sync with the loaded KenshiLua bindings.
-- Nothing in this script mutates the game.

local LINT = {}
LINT.version = "0.1.0"

------------------------------------------------------------------------------
-- Configuration (override by assigning LINT.cfg.* before use)
------------------------------------------------------------------------------

LINT.cfg = {
    modsRoot    = "mods", -- relative to the game working directory
    reportFile  = "KenshiLinterReport.txt",
    maxSuggest  = 3,     -- suggestions shown per finding
    suggestDist = 3,     -- max edit distance for "did you mean" hints
    fixDist     = 2,     -- auto-fix only for very close matches
    -- Receive an identifier's line number from LuaJIT's load? not needed.
}

------------------------------------------------------------------------------
-- Small utilities
------------------------------------------------------------------------------

local function isWindows()
    local sep = package.config and package.config:sub(1, 1) or "/"
    return sep == "\\"
end

local function normalizePath(p)
    return (p:gsub("\\", "/"))
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function writeFile(path, data)
    local f = io.open(path, "wb")
    if not f then return false end
    f:write(data)
    f:close()
    return true
end

local function splitLines(s)
    local out = {}
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(out, line)
    end
    return out
end

-- Edit distance (Damerau-Levenshtein) bounded by `max`.
local function editDistance(a, b, max)
    max = max or 3
    local la, lb = #a, #b
    if math.abs(la - lb) > max then return max + 1 end
    local prev2, prev, cur = {}, {}, {}
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        cur[0] = i
        local ai = a:sub(i, i)
        local rowMin = cur[0]
        for j = 1, lb do
            local bj = b:sub(j, j)
            local cost = ai == bj and 0 or 1
            local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            if i > 1 and j > 1 and a:sub(i - 1, i - 1) == bj and b:sub(j - 1, j - 1) == ai then
                v = math.min(v, (prev2[j - 2] or 0) + 1)
            end
            cur[j] = v
            if v < rowMin then rowMin = v end
        end
        if rowMin > max then return max + 1 end
        prev2, prev, cur = prev, cur, {}
    end
    return prev[lb]
end

-- Best matches for `name` among candidates, sorted by (distance, alphabetical).
local function suggestMatches(name, candidates, maxDist, maxN)
    maxDist = maxDist or LINT.cfg.suggestDist
    maxN = maxN or LINT.cfg.maxSuggest
    local scored = {}
    for c in pairs(candidates) do
        if type(c) == "string" and c ~= name then
            local d = editDistance(name, c, maxDist)
            if d <= maxDist then
                table.insert(scored, { d = d, c = c })
            end
        end
    end
    table.sort(scored, function(x, y)
        if x.d ~= y.d then return x.d < y.d end
        return x.c < y.c
    end)
    local out = {}
    for i = 1, math.min(maxN, #scored) do
        table.insert(out, scored[i].c)
    end
    return out
end

------------------------------------------------------------------------------
-- API index: built from the live Lua state
------------------------------------------------------------------------------

LINT.api = { classes = {}, globals = {}, memberUnion = {}, knownInstances = {}, globalTables = {} }
LINT.apiBuilt = false

-- Global instances exposed by registerGlobals (name -> class metatable name).
LINT.api.knownInstances = {
    ou = "GameWorld",
    GameWorld = "GameWorld",
    player = "PlayerInterface",
    PlayerInterface = "PlayerInterface",
    key = "InputHandler",
    InputHandler = "InputHandler",
    con = "GlobalConstants",
    GlobalConstants = "GlobalConstants",
    options = "OptionsHolder",
    OptionsHolder = "OptionsHolder",
    gui = "ForgottenGUI",
    ForgottenGUI = "ForgottenGUI",
    root = "RootObjectFactory",
}

-- Tables whose members are ordinary Lua API and should not be member-checked.
LINT.api.stdTables = {
    math = true,
    string = true,
    table = true,
    io = true,
    os = true,
    debug = true,
    coroutine = true,
    bit = true,
    jit = true,
    package = true,
    arg = true,
    _G = true,
    utf8 = true,
}

local function collectMembersFromTable(t, out, skipMeta)
    if type(t) ~= "table" then return end
    for k in pairs(t) do
        if type(k) == "string" then
            if not (skipMeta and k:sub(1, 2) == "__") then
                out[k] = true
            end
        end
    end
end

-- Recursively gather every member of a class metatable including inherited ones.
local function walkClassMembers(mt, out, seen)
    seen = seen or {}
    if type(mt) ~= "table" or seen[mt] then return end
    seen[mt] = true
    collectMembersFromTable(mt, out, true)
    local idx = mt.__index
    if type(idx) == "table" then collectMembersFromTable(idx, out, true) end
    for _, field in ipairs({ "__getters", "__setters" }) do
        if type(mt[field]) == "table" then collectMembersFromTable(mt[field], out, true) end
    end
    local parent = getmetatable(mt)
    if type(parent) == "table" and type(parent.__index) == "table" then
        walkClassMembers(parent.__index, out, seen)
    end
end

function LINT.buildApi()
    if LINT.apiBuilt then return end

    -- Globals (everything in _G, plus common names).
    local g = _G
    for k, v in pairs(g) do
        if type(k) == "string" then
            LINT.api.globals[k] = true
            -- Enum / namespace tables exposed as plain global tables: validate
            -- their members strictly against the live object (ProneState.PS_NORMAL,
            -- KenshiLua.logDebug, ...). Stdlib tables are excluded from this so we
            -- don't second-guess dynamic stdlib usage.
            if type(v) == "table" and not LINT.api.stdTables[k] and k ~= "_G" and k ~= "arg" then
                local members = {}
                for mk in pairs(v) do
                    if type(mk) == "string" and mk:sub(1, 2) ~= "__" then members[mk] = true end
                end
                LINT.api.globalTables[k] = members
            end
        end
    end
    -- A few names that are always valid in LuaJIT regardless of environment.
    for _, n in ipairs({ "self", "arg", "_ENV" }) do LINT.api.globals[n] = true end

    -- Class metatables live in the registry under their registered names.
    local reg = debug and debug.getregistry()
    if type(reg) == "table" then
        for key, mt in pairs(reg) do
            if type(key) == "string" and type(mt) == "table" and type(mt.__name) == "string" then
                local members = {}
                walkClassMembers(mt, members)
                LINT.api.classes[mt.__name] = members
                for m in pairs(members) do LINT.api.memberUnion[m] = true end
            end
        end
    end

    -- Enum tables and the KenshiLua namespace are just global tables; their
    -- members are validated directly against the live object.
    LINT.apiBuilt = true
end

local function classMembers(name)
    return LINT.api.classes[name]
end

------------------------------------------------------------------------------
-- Lexer
------------------------------------------------------------------------------

local keywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}

local twoChar = {
    [".."] = true,
    ["..."] = true,
    ["=="] = true,
    ["~="] = true,
    ["<="] = true,
    [">="] = true,
    ["::"] = true,
    ["//"] = true,
}

local function isNameStart(c)
    return c:match("[%a_]") ~= nil
end

local function isNameChar(c)
    return c:match("[%w_]") ~= nil
end

local function isDigit(c)
    return c:match("[0-9]") ~= nil
end

local function isHexDigit(c)
    return c:match("[0-9a-fA-F]") ~= nil
end

-- Returns the length of a long bracket prefix "[[" "[=[" etc at pos, or 0.
local function longBracketOpen(src, pos)
    local i = pos
    if src:sub(i, i) ~= "[" then return 0 end
    i = i + 1
    while src:sub(i, i) == "=" do i = i + 1 end
    if src:sub(i, i) == "[" then return i - pos + 1 end
    return 0
end

local function lex(src)
    local toks = {}
    local n = #src
    local pos, line = 1, 1

    local function push(t, v)
        table.insert(toks, { t = t, v = v, line = line })
    end

    while pos <= n do
        local c = src:sub(pos, pos)

        if c == "\n" then
            line = line + 1
            pos = pos + 1
        elseif c:match("%s") then
            pos = pos + 1
        elseif c == "-" and src:sub(pos + 1, pos + 1) == "-" then
            -- comment
            local lb = longBracketOpen(src, pos + 2)
            if lb > 0 then
                local start = pos + 2
                local level = lb - 2
                local close = "]" .. string.rep("=", level) .. "]"
                local closeAt = src:find(close, start + lb, true)
                if closeAt then
                    -- account for newlines inside
                    local chunk = src:sub(start, closeAt - 1)
                    for _ in chunk:gmatch("\n") do line = line + 1 end
                    pos = closeAt + #close
                else
                    pos = n + 1
                end
            else
                local nl = src:find("\n", pos + 2, true)
                if nl then
                    line = line + 1
                    pos = nl + 1
                else
                    pos = n + 1
                end
            end
        elseif c == "[" then
            local lb = longBracketOpen(src, pos)
            if lb > 0 then
                local level = lb - 2
                local start = pos + lb
                local close = "]" .. string.rep("=", level) .. "]"
                local closeAt = src:find(close, start, true)
                if closeAt then
                    local chunk = src:sub(start, closeAt - 1)
                    for _ in chunk:gmatch("\n") do line = line + 1 end
                    push("str", chunk)
                    pos = closeAt + #close
                else
                    push("str", src:sub(start))
                    pos = n + 1
                end
            else
                push("sym", "[")
                pos = pos + 1
            end
        elseif c == "'" or c == '"' then
            local quote = c
            local i = pos + 1
            local buf = {}
            while i <= n do
                local ch = src:sub(i, i)
                if ch == "\\" then
                    table.insert(buf, ch .. (src:sub(i + 1, i + 1) or ""))
                    i = i + 2
                elseif ch == quote then
                    i = i + 1
                    push("str", table.concat(buf))
                    pos = i
                    break
                else
                    table.insert(buf, ch)
                    if ch == "\n" then line = line + 1 end
                    i = i + 1
                end
            end
            if i > n then pos = n + 1 end
        elseif isNameStart(c) then
            local i = pos
            while i <= n and isNameChar(src:sub(i, i)) do i = i + 1 end
            local word = src:sub(pos, i - 1)
            if keywords[word] then
                push("kw", word)
            else
                push("name", word)
            end
            pos = i
        elseif isDigit(c) or (c == "." and isDigit(src:sub(pos + 1, pos + 1))) then
            local i = pos
            if src:sub(i, i) == "0" and (src:sub(i + 1, i + 1) == "x" or src:sub(i + 1, i + 1) == "X") then
                i = i + 2
                while i <= n and isHexDigit(src:sub(i, i)) do i = i + 1 end
            else
                while i <= n and src:sub(i, i):match("[%d%.]") do i = i + 1 end
                if src:sub(i, i):match("[eE]") then
                    local j = i + 1
                    if src:sub(j, j):match("[%+%-]") then j = j + 1 end
                    if isDigit(src:sub(j, j)) then
                        while j <= n and isDigit(src:sub(j, j)) do j = j + 1 end
                        i = j
                    end
                end
            end
            push("num", src:sub(pos, i - 1))
            pos = i
        else
            local two = src:sub(pos, pos + 2)
            if two == "..." then
                push("sym", "...")
                pos = pos + 3
            else
                local two2 = src:sub(pos, pos + 1)
                if twoChar[two2] then
                    push("sym", two2)
                    pos = pos + 2
                else
                    push("sym", c)
                    pos = pos + 1
                end
            end
        end
    end
    push("eof", "")
    return toks
end

------------------------------------------------------------------------------
-- Scope-aware parser: records uses and declared locals
------------------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

local function newParser(toks)
    return setmetatable({
        toks = toks,
        i = 1,
        scopes = { { locals = {} } },
        uses = {},
        implicitGlobals = {},
    }, Parser)
end

function Parser:cur()
    return self.toks[self.i] or { t = "eof", v = "", line = 0 }
end

function Parser:peek(offset)
    offset = offset or 1
    return self.toks[self.i + offset] or { t = "eof", v = "", line = 0 }
end

function Parser:next()
    local t = self:cur()
    self.i = self.i + 1
    return t
end

function Parser:pushScope()
    table.insert(self.scopes, { locals = {} })
end

function Parser:popScope()
    table.remove(self.scopes)
end

function Parser:declare(name)
    local scope = self.scopes[#self.scopes]
    scope.locals[name] = true
end

function Parser:isLocal(name)
    for i = #self.scopes, 1, -1 do
        if self.scopes[i].locals[name] then return true end
    end
    return false
end

function Parser:recordUse(name, line, kind, call)
    table.insert(self.uses, {
        name = name,
        line = line,
        kind = kind or "var",
        call = call or false,
        ["local"] = (kind == "var") and self:isLocal(name) or false,
    })
    local u = self.uses[#self.uses]
    return u
end

function Parser:markImplicitGlobal(name)
    self.implicitGlobals[name] = true
end

------------------------------------------------------------------------------
-- Grammar (tolerant recursive descent)
------------------------------------------------------------------------------

function Parser:parseParams()
    self:expectSym("(")
    while self:cur().t ~= "eof" do
        local t = self:cur()
        if t.t == "sym" and t.v == ")" then
            self:next()
            break
        elseif t.t == "sym" and t.v == "..." then
            self:next()
        elseif t.t == "name" then
            self:declare(t.v)
            self:next()
            if self:cur().t == "sym" and self:cur().v == "," then self:next() end
        else
            self:next()
        end
    end
end

function Parser:expectSym(v)
    local t = self:cur()
    if t.t == "sym" and t.v == v then
        self:next()
        return true
    end
    return false
end

function Parser:parseBlock()
    while true do
        local t = self:cur()
        if t.t == "eof" then return end
        if t.t == "kw" then
            local v = t.v
            if v == "end" or v == "else" or v == "elseif" or v == "until" then
                return
            end
        end
        self:parseStatement()
    end
end

function Parser:parseStatement()
    local t = self:cur()

    if t.t == "kw" then
        local v = t.v
        if v == "local" then
            self:parseLocal()
            return
        elseif v == "function" then
            self:parseFunctionStmt()
            return
        elseif v == "for" then
            self:parseFor()
            return
        elseif v == "while" then
            self:next()
            self:parseExpr()
            if not self:expectSym("do") and self:cur().t == "kw" and self:cur().v == "do" then
                self:next()
            end
            self:pushScope()
            self:parseBlock()
            self:expectKw("end")
            self:popScope()
            return
        elseif v == "do" then
            self:next()
            self:pushScope()
            self:parseBlock()
            self:expectKw("end")
            self:popScope()
            return
        elseif v == "if" then
            self:parseIf()
            return
        elseif v == "repeat" then
            self:next()
            self:pushScope()
            self:parseBlock()
            self:expectKw("until")
            self:parseExpr()
            self:popScope()
            return
        elseif v == "return" then
            self:next()
            -- optional expression list
            while self:cur().t ~= "eof" do
                local c = self:cur()
                if c.t == "kw" and (c.v == "end" or c.v == "else" or c.v == "elseif" or c.v == "until") then
                    return
                end
                self:parseExpr()
                if not self:expectSym(",") then break end
            end
            return
        elseif v == "break" then
            self:next()
            return
        elseif v == "goto" then
            self:next()
            self:next()
            return
        else
            -- unexpected keyword; skip it to keep going
            self:next()
            return
        end
    end

    -- Assignment or call / expression statement.
    local e = self:parseExpr()
    -- handle assignment "a, b = ..."
    if self:cur().t == "sym" and (self:cur().v == "=" or self:cur().v == ",") then
        local seen = { e.name }
        while self:cur().t == "sym" and self:cur().v == "," do
            self:next()
            local n = self:parseExpr()
            if n.name and type(n.name) == "string" then table.insert(seen, n.name) end
        end
        self:expectSym("=")
        self:parseExprList()
        -- names assigned at any scope without a local declaration create globals
        for _, name in ipairs(seen) do
            if type(name) == "string" and not self:isLocal(name) then
                self:markImplicitGlobal(name)
            end
        end
    end
end

function Parser:expectKw(v)
    local t = self:cur()
    if t.t == "kw" and t.v == v then
        self:next()
        return true
    end
    return false
end

function Parser:parseLocal()
    self:next() -- 'local'
    local t = self:cur()
    if t.t == "kw" and t.v == "function" then
        -- local function name(...) body end
        self:next()
        local n = self:next()
        if n.t == "name" then self:declare(n.v) end
        self:pushScope()
        self:parseParams()
        self:parseBlock()
        self:expectKw("end")
        self:popScope()
        return
    end

    -- local a, b, c [= exprlist]
    local names = {}
    while true do
        local n = self:cur()
        if n.t == "name" then
            self:declare(n.v)
            table.insert(names, n.v)
            self:next()
        else
            self:next()
        end
        if self:cur().t == "sym" and self:cur().v == "," then
            self:next()
        else
            break
        end
    end
    if self:cur().t == "sym" and self:cur().v == "=" then
        self:next()
        self:parseExprList()
    end
end

function Parser:parseFunctionStmt()
    self:next() -- 'function'
    -- function name(...) or function a.b.c(...) or function t:m(...)
    local n = self:next()
    if n.t == "name" then
        if not self:isLocal(n.v) and self:peek().t ~= "sym" then
            -- global function definition; treat as implicit global
            self:markImplicitGlobal(n.v)
        end
    end
    while self:cur().t == "sym" and self:cur().v == "." do
        self:next()
        self:next() -- member name
    end
    local isMethod = false
    if self:cur().t == "sym" and self:cur().v == ":" then
        isMethod = true
        self:next()
        self:next() -- method name
    end
    self:pushScope()
    if isMethod then
        self:declare("self")
    end
    self:parseParams()
    self:parseBlock()
    self:expectKw("end")
    self:popScope()
end

function Parser:parseFor()
    self:next() -- 'for'
    self:pushScope()
    -- for i = e1, e2 [, e3] do | for a, b in explist do
    local names = {}
    while true do
        local n = self:cur()
        if n.t == "name" then
            table.insert(names, n.v)
            self:declare(n.v)
            self:next()
        end
        if self:cur().t == "sym" and self:cur().v == "," then
            self:next()
        else
            break
        end
    end
    if self:cur().t == "kw" and self:cur().v == "in" then
        self:next()
        self:parseExprList()
    else
        self:expectSym("=")
        self:parseExprList()
    end
    if self:cur().t == "kw" and self:cur().v == "do" then
        self:next()
    end
    self:parseBlock()
    self:expectKw("end")
    self:popScope()
end

function Parser:parseIf()
    self:next() -- 'if'
    self:parseExpr()
    if self:cur().t == "kw" and self:cur().v == "then" then self:next() end
    self:pushScope()
    self:parseBlock()
    self:popScope()

    while true do
        local t = self:cur()
        if t.t == "kw" and t.v == "elseif" then
            self:next()
            self:parseExpr()
            if self:cur().t == "kw" and self:cur().v == "then" then self:next() end
            self:pushScope()
            self:parseBlock()
            self:popScope()
        elseif t.t == "kw" and t.v == "else" then
            self:next()
            self:pushScope()
            self:parseBlock()
            self:popScope()
        else
            break
        end
    end
    self:expectKw("end")
end

function Parser:parseExprList()
    self:parseExpr()
    while self:cur().t == "sym" and self:cur().v == "," do
        self:next()
        self:parseExpr()
    end
end

------------------------------------------------------------------------------
-- Expressions
------------------------------------------------------------------------------

-- Returns { name = simpleBaseNameOrNil, callUse = useObjOrNil }
function Parser:parseExpr()
    return self:parseBinop(0)
end

local BINOP_PREC = {
    ["or"] = 1,
    ["and"] = 2,
    ["<"] = 3,
    [">"] = 3,
    ["<="] = 3,
    [">="] = 3,
    ["~="] = 3,
    ["=="] = 3,
    [".."] = 5,
    ["+"] = 6,
    ["-"] = 6,
    ["*"] = 7,
    ["/"] = 7,
    ["%"] = 7,
    ["^"] = 10,
}

local function isBinopTok(t)
    if t.t == "kw" then return t.v == "or" or t.v == "and" end
    if t.t == "sym" then return BINOP_PREC[t.v] ~= nil end
    return false
end

function Parser:parseBinop(level)
    if level > 10 then return self:parseUnary() end
    local lhs = self:parseBinop(level + 1)
    while true do
        local t = self:cur()
        local prec = isBinopTok(t) and BINOP_PREC[t.v] or nil
        if prec and prec >= level and not (t.v == "^" and prec == level) then
            self:next()
            self:parseBinop(level + 1)
        else
            break
        end
    end
    return lhs
end

function Parser:parseUnary()
    local t = self:cur()
    if t.t == "kw" and (t.v == "not") then
        self:next()
        return self:parseUnary()
    end
    if t.t == "sym" and (t.v == "#" or t.v == "-") then
        self:next()
        return self:parseUnary()
    end
    return self:parseSuffix()
end

function Parser:parseSuffix()
    local base = self:parsePrimary()
    -- simple base name (may be chained into member access later)
    local simpleName = base.name
    local callUse = base.callUse

    while true do
        local t = self:cur()
        if t.t == "sym" and t.v == "." then
            self:next()
            local m = self:next()
            if m.t == "name" then
                self:recordUse(nil, m.line, "member", false)
                -- attach receiver name for member validation
                local u = self.uses[#self.uses]
                u.recv = simpleName
                u.member = m.v
            end
            simpleName = nil
        elseif t.t == "sym" and t.v == ":" then
            self:next()
            local m = self:next()
            if m.t == "name" then
                self:recordUse(nil, m.line, "method", false)
                local u = self.uses[#self.uses]
                u.recv = simpleName
                u.member = m.v
                if self:cur().t == "sym" and self:cur().v == "(" then
                    u.call = true
                    self:parseCallArgs()
                end
            end
            simpleName = nil
        elseif t.t == "sym" and t.v == "[" then
            self:next()
            self:parseExpr()
            self:expectSym("]")
            simpleName = nil
        elseif t.t == "sym" and t.v == "(" then
            if callUse then callUse.call = true end
            self:parseCallArgs()
            simpleName = nil
        elseif t.t == "str" or (t.t == "sym" and t.v == "{") then
            -- call shorthand f"str" / f{...}
            if callUse then callUse.call = true end
            self:parseCallArgs()
            simpleName = nil
        else
            break
        end
    end
    return { name = simpleName, callUse = callUse }
end

function Parser:parseCallArgs()
    local t = self:cur()
    if t.t == "sym" and t.v == "(" then
        self:next()
        while true do
            local c = self:cur()
            if c.t == "eof" then return end
            if c.t == "sym" and c.v == ")" then
                self:next()
                return
            end
            self:parseExpr()
            if not self:expectSym(",") then
                if self:cur().t == "sym" and self:cur().v == ")" then
                    self:next()
                    return
                end
            end
        end
    elseif t.t == "str" then
        self:next()
    elseif t.t == "sym" and t.v == "{" then
        self:parseTableConstructor()
    end
end

function Parser:parseTableConstructor()
    self:next() -- '{'
    while true do
        local t = self:cur()
        if t.t == "eof" then return end
        if t.t == "sym" and t.v == "}" then
            self:next()
            return
        end
        -- [expr] = value
        if t.t == "sym" and t.v == "[" then
            self:next()
            self:parseExpr()
            self:expectSym("]")
            self:expectSym("=")
            self:parseTableValue()
        elseif t.t == "name" and self:peek().t == "sym" and self:peek().v == "=" then
            -- name = value
            self:next()
            self:next() -- '='
            self:parseTableValue()
        elseif t.t == "name" and self:peek().t == "sym" and self:peek().v == ":" then
            -- name:method(...) is invalid in table ctor, but be tolerant
            self:next()
            self:next()
            self:next()
            self:parseTableValue()
        elseif t.t == "kw" and t.v == "function" then
            -- anonymous function value
            self:next()
            self:pushScope()
            self:parseParams()
            self:parseBlock()
            self:expectKw("end")
            self:popScope()
        else
            self:parseExpr()
            local cur = self:cur()
            local noSep = not (cur.t == "sym" and (cur.v == "," or cur.v == ";"))
            if noSep then
                -- tolerate missing separators; advance one to avoid infinite loop
                if self:cur().t == "sym" and self:cur().v == "}" then
                    self:next()
                    return
                end
                self:next()
            else
                self:next()
            end
        end
    end
end

function Parser:parseTableValue()
    local t = self:cur()
    if t.t == "kw" and t.v == "function" then
        self:next()
        self:pushScope()
        self:parseParams()
        self:parseBlock()
        self:expectKw("end")
        self:popScope()
    else
        self:parseExpr()
    end
end

function Parser:parsePrimary()
    local t = self:cur()
    if t.t == "name" then
        self:next()
        local u = self:recordUse(t.v, t.line, "var", false)
        return { name = t.v, callUse = u }
    elseif t.t == "str" or t.t == "num" then
        self:next()
        return { name = nil, callUse = nil }
    elseif t.t == "kw" and t.v == "function" then
        self:next()
        self:pushScope()
        self:parseParams()
        self:parseBlock()
        self:expectKw("end")
        self:popScope()
        return { name = nil, callUse = nil }
    elseif t.t == "sym" and t.v == "(" then
        self:next()
        self:parseExpr()
        while self:cur().t == "sym" and self:cur().v == "," do
            self:next()
            self:parseExpr()
        end
        self:expectSym(")")
        return { name = nil, callUse = nil }
    elseif t.t == "sym" and t.v == "{" then
        self:parseTableConstructor()
        return { name = nil, callUse = nil }
    elseif t.t == "sym" and t.v == "..." then
        self:next()
        return { name = nil, callUse = nil }
    else
        self:next()
        return { name = nil, callUse = nil }
    end
end

------------------------------------------------------------------------------
-- Analysis
------------------------------------------------------------------------------

-- Returns { findings = {...}, syntaxOk = bool }
function LINT.analyzeSource(src, fileLabel)
    local findings = {}

    -- 1. Syntax check (compile only, never execute).
    local loadfn = loadstring or load
    local chunk, err = loadfn("return " .. src)
    if not chunk then
        chunk, err = loadfn(src)
    end
    if not chunk then
        table.insert(findings, {
            line = 0, kind = "error", message = "syntax error: " .. (err or "?"),
        })
        return { findings = findings, syntaxOk = false }
    end

    -- 2. Lex + parse to collect uses and locals.
    local toks = lex(src)
    local p = newParser(toks)
    local pcallOk, perr = pcall(function()
        p:parseBlock()
    end)
    if not pcallOk then
        table.insert(findings, {
            line = 0,
            kind = "warning",
            message = "parser fault (analysis degraded): " .. tostring(perr),
        })
    end

    -- 3. Validate variable uses against known globals.
    for _, u in ipairs(p.uses) do
        if u.kind == "var" then
            if not u["local"] and not LINT.api.globals[u.name] and not p.implicitGlobals[u.name] then
                local sugg = suggestMatches(u.name, LINT.api.globals)
                local msg = ("undefined global '%s'%s"):format(
                    u.name,
                    #sugg > 0 and (" (did you mean " .. table.concat(sugg, ", ") .. "?)") or "")
                table.insert(findings, {
                    line = u.line,
                    kind = "warning",
                    message = msg,
                    name = u.name,
                    suggestions = sugg,
                    fixable = #sugg == 1 and editDistance(u.name, sugg[1]) <= 1,
                })
            end
        elseif u.kind == "member" or u.kind == "method" then
            local recv = u.recv
            local strictClass = nil
            if recv then
                strictClass = LINT.api.knownInstances[recv]
                if not strictClass and LINT.api.classes[recv] then
                    strictClass = recv
                end
            end

            if strictClass then
                -- strict: member must exist on that class (or inherited)
                local exact = classMembers(strictClass)
                if exact and not exact[u.member] then
                    local sugg = suggestMatches(u.member, exact)
                    local msg = ("unknown %s '%s' on %s%s"):format(
                        u.kind == "method" and "method" or "property",
                        u.member, strictClass,
                        #sugg > 0 and (" (did you mean " .. table.concat(sugg, ", ") .. "?)") or "")
                    table.insert(findings, {
                        line = u.line,
                        kind = "error",
                        message = msg,
                        name = u.member,
                        suggestions = sugg,
                        fixable = #sugg == 1 and editDistance(u.member, sugg[1]) <= LINT.cfg.fixDist,
                    })
                end
            elseif LINT.api.globalTables[recv] then
                -- strict: enum / namespace table; member must exist on the live table
                local exact = LINT.api.globalTables[recv]
                if not exact[u.member] then
                    local sugg = suggestMatches(u.member, exact)
                    local msg = ("unknown member '%s' on %s%s"):format(
                        u.member, recv,
                        #sugg > 0 and (" (did you mean " .. table.concat(sugg, ", ") .. "?)") or "")
                    table.insert(findings, {
                        line = u.line,
                        kind = "error",
                        message = msg,
                        name = u.member,
                        suggestions = sugg,
                        fixable = #sugg == 1 and editDistance(u.member, sugg[1]) <= LINT.cfg.fixDist,
                    })
                end
            elseif not LINT.api.memberUnion[u.member] then
                -- unknown receiver: only flag when it looks like a typo of a real member
                local sugg = suggestMatches(u.member, LINT.api.memberUnion)
                if #sugg > 0 then
                    local msg = ("possible typo: '%s' is not a KenshiLua member (did you mean %s?)"):format(
                        u.member, table.concat(sugg, ", "))
                    table.insert(findings, {
                        line = u.line,
                        kind = "warning",
                        message = msg,
                        name = u.member,
                        suggestions = sugg,
                        fixable = #sugg == 1 and editDistance(u.member, sugg[1]) <= LINT.cfg.fixDist,
                    })
                end
            end
        end
    end

    return { findings = findings, syntaxOk = true }
end

------------------------------------------------------------------------------
-- File discovery (platform-aware, works in-game on Windows)
------------------------------------------------------------------------------

function LINT.listLuaFiles(rootDir)
    local files = {}
    local cmd
    if isWindows() then
        cmd = 'cmd /c dir /s /b "' .. rootDir .. '\\*.lua" 2>nul'
    else
        cmd = 'find "' .. rootDir .. '" -name "*.lua" 2>/dev/null'
    end
    local ok, p = pcall(io.popen, cmd)
    if not ok or not p then
        -- fallback: only direct children pattern
        local cmd2 = 'ls "' .. rootDir .. '"/*.lua 2>/dev/null'
        p = io.popen(cmd2)
    end
    if p then
        for raw in p:lines() do
            local line = normalizePath(raw:gsub("^%s+", ""):gsub("%s+$", ""))
            if line ~= "" then
                table.insert(files, line)
            end
        end
        p:close()
    end
    return files
end

function LINT.modScriptDir(modName)
    return LINT.cfg.modsRoot .. "/" .. modName .. "/scripts"
end

------------------------------------------------------------------------------
-- Reporting
------------------------------------------------------------------------------

LINT._report = {}

local function logLine(line)
    table.insert(LINT._report, line)
end

local function flushReport()
    if #LINT._report > 0 then
        -- ignore write failures (e.g. no permissions)
        pcall(function()
            writeFile(LINT.cfg.reportFile, table.concat(LINT._report, "\n") .. "\n")
        end)
        LINT._report = {}
    end
end

local function severityRank(s)
    if s == "error" then
        return 0
    elseif s == "warning" then
        return 1
    else
        return 2
    end
end

local function fmtFindings(fileLabel, findings)
    local lines = { "== " .. fileLabel .. " ==" }
    table.sort(findings, function(a, b)
        if a.line ~= b.line then return a.line < b.line end
        return severityRank(a.kind) < severityRank(b.kind)
    end)
    local nErr, nWarn = 0, 0
    for _, f in ipairs(findings) do
        if f.kind == "error" then
            nErr = nErr + 1
        elseif f.kind == "warning" then
            nWarn = nWarn + 1
        end
        local loc = f.line > 0 and ("  [line %d]"):format(f.line) or "  [top]"
        lines[#lines + 1] = loc .. " " .. f.kind .. ": " .. f.message
    end
    if #findings == 0 then
        lines[#lines + 1] = "  OK - no issues found"
    end
    lines[#lines + 1] = ("  -> %d error(s), %d warning(s)"):format(nErr, nWarn)
    return table.concat(lines, "\n"), nErr, nWarn
end

local function echo(message)
    -- Best-effort: log to KenshiLua logger if available.
    local kl = rawget(_G, "KenshiLua")
    if kl and type(kl) == "table" then
        local logWarn = kl.logWarn or kl.log
        if type(logWarn) == "function" then
            pcall(logWarn, message)
        end
    end
end

function LINT.lintFile(path, opts)
    opts = opts or {}
    LINT.buildApi()
    local src = readFile(path)
    if not src then
        local msg = "ERROR: cannot read file: " .. path
        echo(msg)
        return msg
    end
    local res = LINT.analyzeSource(src, path)
    local text, nErr, nWarn = fmtFindings(path, res.findings)
    logLine(text)
    if opts.report then flushReport() end
    if nErr > 0 or nWarn > 0 then echo(text) end
    return text
end

function LINT.lintMod(modName, opts)
    LINT.buildApi()
    local dir = LINT.modScriptDir(modName)
    local files = LINT.listLuaFiles(dir)
    if #files == 0 then
        local msg = "No .lua files found under " .. dir
        echo(msg)
        return msg
    end
    table.sort(files)
    local summary = {}
    local totalErr, totalWarn = 0, 0
    for _, f in ipairs(files) do
        local src = readFile(f)
        if src then
            local res = LINT.analyzeSource(src, f)
            local text, e, w = fmtFindings(f, res.findings)
            table.insert(summary, text)
            totalErr, totalWarn = totalErr + e, totalWarn + w
        end
    end
    table.insert(summary, ("== SUMMARY: %s =="):format(modName))
    table.insert(summary, ("  files=%d errors=%d warnings=%d"):format(#files, totalErr, totalWarn))
    local all = table.concat(summary, "\n")
    logLine(all)
    flushReport()
    echo("Lint of " ..
    modName .. ": " .. totalErr .. " error(s), " .. totalWarn .. " warning(s) -> " .. LINT.cfg.reportFile)
    return all
end

function LINT.lintMods(modNames, opts)
    local out = {}
    for _, m in ipairs(modNames) do
        out[#out + 1] = LINT.lintMod(m, opts)
    end
    return table.concat(out, "\n\n")
end

function LINT.lintAll(opts)
    LINT.buildApi()
    local modDirs = {}
    if isWindows() then
        local p = io.popen('cmd /c dir /b /ad "' .. LINT.cfg.modsRoot .. '" 2>nul')
        if p then
            for line in p:lines() do
                local n = line:gsub("%s", "")
                if n ~= "" then table.insert(modDirs, n) end
            end
            p:close()
        end
    else
        local p = io.popen('ls "' .. LINT.cfg.modsRoot .. '" 2>/dev/null')
        if p then
            for line in p:lines() do
                local n = line:gsub("%s", "")
                if n ~= "" then table.insert(modDirs, n) end
            end
            p:close()
        end
    end
    return LINT.lintMods(modDirs, opts)
end

------------------------------------------------------------------------------
-- Fixing (non-destructive by default)
------------------------------------------------------------------------------

-- Rewrites `name` -> replacement on the exact line where the finding occurred,
-- producing a new file. Original file is left untouched unless applyInPlace.
function LINT.applyFixes(filePath, applyInPlace)
    local src = readFile(filePath)
    if not src then return "ERROR: cannot read " .. filePath end
    LINT.buildApi()
    local res = LINT.analyzeSource(src, filePath)
    if not res.syntaxOk then
        return "NOT FIXED: syntax error in " .. filePath .. " - fix manually first"
    end

    -- build map line -> { old, new }
    local lines = splitLines(src)
    local fixes = {}
    local nFixes = 0
    for _, f in ipairs(res.findings) do
        if f.fixable and f.line > 0 and f.line <= #lines and f.suggestions and f.suggestions[1] then
            local oldTok, newTok = f.name, f.suggestions[1]
            local ln = lines[f.line]
            if ln:find(oldTok, 1, true) then
                if not fixes[f.line] then fixes[f.line] = {} end
                fixes[f.line][#fixes[f.line] + 1] = { oldTok = oldTok, newTok = newTok }
                nFixes = nFixes + 1
            end
        end
    end

    if nFixes == 0 then
        return "No auto-fixable findings in " .. filePath
    end

    for lineNo, fixList in pairs(fixes) do
        local ln = lines[lineNo]
        for _, fx in ipairs(fixList) do
            -- replace every occurrence of the exact identifier token on the line
            ln = ln:gsub("(%f[%a_])" .. fx.oldTok .. "(%f[%A_])", "%1" .. fx.newTok .. "%2")
        end
        lines[lineNo] = ln
    end

    local newContent = table.concat(lines, "\n")
    local outPath = applyInPlace and filePath or (filePath .. ".lint_fixed.lua")
    if applyInPlace then
        writeFile(filePath .. ".bak", src)
    end
    if writeFile(outPath, newContent) then
        local msg = ("Applied %d fix(es) to %s -> %s"):format(nFixes, filePath, outPath)
        if applyInPlace then msg = msg .. " (original backed up to .bak)" end
        return msg
    end
    return "ERROR: could not write " .. outPath
end

function LINT.fixMod(modName, applyInPlace)
    local dir = LINT.modScriptDir(modName)
    local files = LINT.listLuaFiles(dir)
    table.sort(files)
    local out = {}
    for _, f in ipairs(files) do
        out[#out + 1] = LINT.applyFixes(f, applyInPlace)
    end
    return table.concat(out, "\n")
end

------------------------------------------------------------------------------
-- Module export (plain global, compatible with the Console and Script Editor)
------------------------------------------------------------------------------

_G["KenshiLinter"] = LINT

-- Convenience: if loaded via `dofile`, provide the plain-global aliases too.
if not _G["lintMod"] then _G["lintMod"] = function(...) return LINT.lintMod(...) end end
if not _G["lintFile"] then _G["lintFile"] = function(...) return LINT.lintFile(...) end end
if not _G["lintAll"] then _G["lintAll"] = function(...) return LINT.lintAll(...) end end
if not _G["fixMod"] then _G["fixMod"] = function(...) return LINT.fixMod(...) end end

return LINT
