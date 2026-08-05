# Kenshi Compact (KenshiLua Plugin Conversion)

A Lua port of the KenshiCompact C++ plugin. Press **SHIFT + /** to open the CharacterEditWindow for the currently selected character, allowing cosmetic changes to be made.

## Difference From The Original

|                  | KenshiCompact (C++)                                     | KenshiCompactLua (Lua)                                                                                    |
| ---------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Size             | 99 lines (plus build files)                             | ~45 lines, one file                                                                                       |
| Hotkey polling   | Background `PollThread` + `GetAsyncKeyState` every 50ms | `registerHandler("onKeyDown", ...)` - the game notifies the script                                        |
| Game thread hop  | `SetTimer` + `WM_TIMER` `TimerProc`                     | Not needed - callbacks already run on the game thread                                                     |
| Foreground check | `GetForegroundWindow()` + PID compare                   | Not needed - input events only fire while the game has focus                                              |
| Mod content      | DLL + `RE_Kenshi.json` + `.mod` referencing them        | One `.lua` file in `scripts/init/` + an empty `.mod`                                                      |
| Hotkey           | `ALT + V` (polls modifier state)                        | `SHIFT + /` - `onKeyDown` only reports the raw `OIS::KeyCode`, `InputHandler` captures the modifier state |

The logic itself is a one-to-one port:

```lua
player:activateCharacterEditMode(c)
```

## Bindings Used

All from `KenshiLua/docs/BindingsReference.md`:

- `getPlayerInterface()` - global (## PlayerInterface)
- `player.selectedCharacter` - a `hand` (## PlayerInterface)
- `hand:getCharacter()` - (## hand)
- `character:isInCombatMode(melee, ranged)` - (## Character)
- `player:activateCharacterEditMode(character)` - (## PlayerInterface)
- `registerHandler("onKeyDown", function(keyCode))` - (## CallbacksReference.md)

## Installation

1. For GoG, copy the whole `KenshiCompact` folder into Kenshi's `mods` directory (`GOG Games/Kenshi/mods/`). For Steam, simply subscribe.
2. Make sure you have `RE_Kenshi` and `KenshiLua` installed and enabled (see the KenshiLua README).
3. Launch the game and enable **KenshiCompact** in the game launcher's mod list (it must be ticked - KenshiLua only loads `scripts/init/*.lua` from _active_ mods).

## Usage

Select a character in-game, then press **SHIFT + /**. The editor will not open while the character is in combat mode. The script logs with the `[KenshiCompact]` prefix (KenshiLua GUI: `Ctrl` + `Shift` + `L`).

To change the hotkey, edit `KC_SLASH` at the top of `scripts/init/editor.lua`.

## Notes

- Only the primary selected character (`selectedCharacter`, matching the original plugin) is affected, not the whole selection.
- OIS_KEY_CODES.md included for reference which lists available values.
- The bundled `.mod` file is an empty mod file (created by the FCS) - it exists only so the game's launcher recognizes the mod. All logic lives in Lua.
