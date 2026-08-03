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

1. Copy the whole `KenshiMedic` folder into Kenshi's `mods` directory (Steam: `<Steam>/steamapps/common/Kenshi/mods/`).
2. Make sure you have `RE_Kenshi` and `KenshiLua` installed and enabled (see the KenshiLua README).
3. Launch the game and enable **KenshiMedic** in the game launcher's mod list (it must be ticked - KenshiLua only loads `scripts/init/*.lua` from *active* mods).

## Usage

Select one or more of your characters in-game, then press **H**.

The script logs to the KenshiLua console/logger with the `[KenshiMedic]` prefix, so you can confirm it ran (open the KenshiLua GUI with `Ctrl` + `Shift` + `L`).

## Notes

- The hotkey is the `H` key (OIS key code `35`). To change it, edit `KC_H` at the top of `scripts/init/medic.lua`.
- OIS_KEY_CODES.md included for reference which lists available values.
- The bundled `KenshiMedic.mod` is an empty mod file (created by the FCS) - it exists only so the game's launcher recognizes the mod. All logic lives in Lua.
