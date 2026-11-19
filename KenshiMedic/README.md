# Kenshi Medic (KenshiLua Plugin)

A Kenshi mod that fully heals the currently selected player character(s) by pressing the **H** key.

Healing is done with `Character:healCompletely()`, the game's own full-heal routine (see `KenshiLua/docs/BindingsReference.md` ## Character). It is more reliable than manually poking `MedicalSystem` fields from Lua because it also handles internal state the Lua bindings can't reach, such as the wound list and damage-state recalculation.

## What It Heals

- **Blood** - restored to maximum
- **Flesh** - every body part (head, chest, stomach, arms, legs) restored to its maximum health
- **Stun damage** - cleared
- **Cut damage** - cleared, no medical kits needed
- **Splints** - cleared
- **Robot limb wear** - cleared
- **Wounds and derived health values** - recalculated by the game
- **Downed / bleeding-out state** - reset so the character stands back up instead of continuing to bleed out

A live character is fully healed. A truly dead character (dead flag) is not resurrected.

## Installation

1. For GoG, copy the whole `KenshiMedic` folder into Kenshi's `mods` directory (`GOG Games/Kenshi/mods/`). For Steam, simply subscribe.
2. Make sure you have `RE_Kenshi` and `KenshiLua` installed and enabled (see the KenshiLua README).
3. Launch the game and enable **KenshiMedic** in the game launcher's mod list (it must be ticked - KenshiLua only loads `scripts/init/*.lua` from _active_ mods).

## Usage

Select one or more of your characters in-game, then press **H**.

The script logs to the KenshiLua console/logger with the `[KenshiMedic]` prefix, so you can confirm it ran (open the KenshiLua GUI with `Ctrl` + `Shift` + `L`).

## Development

The script uses the KenshiLua API. For editor completion and hover documentation, use the [Lua Language Server](https://luals.github.io/) with the KenshiLua LuaLS addon:

1. Download `KenshiLua-LuaLS-Addon-v<version>-alpha.zip` from the [KenshiLua releases](https://github.com/Genpretz/KenshiLua/releases). Use the addon from the same release as the KenshiLua DLL you target.
2. Extract it outside your mods folder, for example `~/KenshiModding/LuaLS`.
3. The bundled `.luarc.json` already points at the addon in a sibling `KenshiLua` checkout (`../../KenshiLua/luals/addon/kenshilua/library`). If you extracted the addon somewhere else, add that path to `workspace.library`.

## Notes

- The hotkey is the `H` key (`OIS.KeyCode.KC_H`, numeric value `35`). To change it, edit `KC_H` at the top of `scripts/init/medic.lua`.
- The full list of key codes is in `KenshiLua/docs/EnumsReference.md` (table `OIS.KeyCode`), or at runtime via the global `OIS.KeyCode` table.
- The bundled `KenshiMedic.mod` is an empty mod file (created by the FCS) - it exists only so the game's launcher recognizes the mod. All logic lives in Lua.
