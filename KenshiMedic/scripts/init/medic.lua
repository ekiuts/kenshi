-- medic.lua KenshiMedic
-- Press H to heal selected character(s)

local logDebug = KenshiLua.logDebug
local KC_H = 35

local function heal_selected()
    local player = getPlayerInterface()
    if not player then
        logDebug("[KenshiMedic] getPlayerInterface() returned nil")
        return
    end

    local selected = player.selectedCharacters
    if not selected then
        logDebug("[KenshiMedic] player.selectedCharacters is nil")
        return
    end

    logDebug("[KenshiMedic] healing selected characters")

    local healed, skipped, failed = 0, 0, 0
    -- selectedCharacters:toTable() returns handles as keys (set-style),
    -- so the loop variable is the hand, not the value.
    for h in pairs(selected:toTable()) do
        local c = h:getCharacter()
        if not c then
            skipped = skipped + 1
        else
            local ok, err = pcall(c.healCompletely, c)
            if ok then
                healed = healed + 1
            else
                failed = failed + 1
                logDebug("[KenshiMedic] healCompletely() failed for one character: " .. tostring(err))
            end
        end
    end

    logDebug(string.format(
        "[KenshiMedic] heal result: %d healed, %d skipped (no character), %d failed",
        healed, skipped, failed))
end

local function on_key_down(first, second)
    local key_code
    if type(first) == "number" then
        key_code = first -- legacy KenshiLua: first arg is the key code
    else
        key_code = second -- new KenshiLua: first arg is the InputHandler, second is the key code
    end
    if key_code == KC_H then
        logDebug("[KenshiMedic] H key pressed")
        heal_selected()
    end
end

local PREV_HANDLER_KEY = "_KenshiMedic_prev_onKeyDown"
local prev = _G[PREV_HANDLER_KEY]
if prev ~= nil then
    unregisterHandler("onKeyDown", prev)
end

logDebug("[KenshiMedic] registering H key handler")
registerHandler("onKeyDown", on_key_down)
_G[PREV_HANDLER_KEY] = on_key_down
