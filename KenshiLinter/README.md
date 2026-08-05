# Kenshi Linter — in-game Lua linter for KenshiLua mod scripts

A standalone, on-demand static analyzer that checks your KenshiLua mod scripts for
common mistakes without executing them. It is **not** a mod script and does not run
through the mod loader — you trigger it manually from the in-game Console / Script
Editor.

## What it detects

- Syntax errors (compile-only; nothing is executed)
- References to globals that don't exist (e.g. `getGameWorldd`)
- Method/property names not found on the bound classes (e.g. `obj:healCompletly`),
  with "did you mean" suggestions
- Fields on enum / namespace tables validated against the real members
  (`ProneState.PS_NORMAL`, `KenshiLua.logDebug`)
- Auto-fixable typos via `gsub` (edit distance ≤ 1; undefined-global fixes are
  limited to single-typo distance so a correct identifier is never clobbered)

The API index (globals, classes, enum tables) is built at runtime from the live Lua
state, so it is always in sync with the currently loaded bindings.

## Install / placement

Keep it **outside** `scripts/init/` — that folder auto-runs on game start/reload,
and you don't want the linter firing on load. Anywhere else works, e.g.
`mods/KenshiLinter/scripts/linter.lua`. You load it by path from the Console.

## Usage (Console / Script Editor)

Load it once when you need it:

```lua
dofile("mods/KenshiLinter/scripts/linter.lua")
```

Then call any exported helper. They return the formatted report string (the Console
prints it), write a full report to `KenshiLinterReport.txt` in the game working
directory, and echo findings through `KenshiLua.logWarn`.

| Function                                           | Purpose                                      |
| -------------------------------------------------- | -------------------------------------------- |
| `lintMod("KenshiMedic")`                           | Lint every `.lua` under one mod's `scripts/` |
| `lintMods({"KenshiMedic","KenshiCompact"})`        | Lint several mods                            |
| `lintAll()`                                        | Lint every mod with a `scripts/` directory   |
| `lintFile("mods/.../init/medic.lua")`              | Lint a single file                           |
| `fixMod("KenshiMedic", applyInPlace)`              | Apply auto-fixes; writes `.lint_fixed.lua`   |
| `fixFile("mods/.../init/medic.lua", applyInPlace)` | Apply auto-fixes to one file                 |

`fixMod`/`fixFile` are non-destructive by default: they write a new `<file>.lint_fixed.lua`
next to the original. Pass `true` as the second argument to rewrite in place (the
original is backed up to `<file>.lua.bak`).

## Configuration

Override defaults before use:

```lua
local L = dofile("mods/KenshiLinter/scripts/linter.lua")
L.cfg.modsRoot    = "mods"              -- root that contains each mod's scripts/
L.cfg.reportFile  = "KenshiLinterReport.txt"
L.cfg.maxSuggest  = 3                   -- suggestions shown per finding
L.cfg.suggestDist = 3                   -- max edit distance for hints
L.cfg.fixDist     = 2                   -- auto-fix distance for member typos
```

## Notes & limitations

- Tolerant but conservative on unknown receiver types: a member with no close
  match on an untyped receiver is passed silently to avoid false positives, while
  known instances (`ou`, `player`, `key`, `con`, ...) and enum/namespace tables are
  checked strictly.
- Argument **arity is not checked**, so `player:activateCharacterEditMode(c)` and the
  docs' zero-arg form both pass — the bindings are authoritative.
- File discovery uses `cmd /c dir` on Windows and `find` on other platforms; edit
  discovery calls if your `mods` path differs.
- LuaJIT is required to be the game's Lua runtime as normal; local validation used
  a stock Lua 5.5 interpreter with a simulated KenshiLua API.
