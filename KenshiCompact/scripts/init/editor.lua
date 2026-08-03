-- editor.lua - KenshiCompact
-- Press Shift + / to open the CharacterEditWindow for the primary selected character
-- Lua port of the KenshiCompact C++ plugin (RE_Kenshi)

local logDebug = KenshiLua.logDebug

local KC_SLASH = 53  -- OIS key code

local function open_character_editor()
    local player = getPlayerInterface()
    if not player then
        logDebug("[KenshiCompact] no PlayerInterface")
        return
    end

    local selected = player.selectedCharacter
    if not selected then
        logDebug("[KenshiCompact] no character selected")
        return
    end

    local c = selected:getCharacter()
    if not c then
        logDebug("[KenshiCompact] no Character Selected")
        return
    end

    if c:isInCombatMode(true, true) then
        logDebug("[KenshiCompact] Character in Combat")
        return
    end

    logDebug("[KenshiCompact] Opening Character Editor")
    player:activateCharacterEditMode(c)
end

local function on_key_down(key_code)
    local ih = getInputHandler()
    if key_code == KC_SLASH and ih and ih.shift then -- Shift + /
        open_character_editor()
    end
end
logDebug("[KenshiCompact] registering key callback (Shift + / = open character editor)")
registerHandler("onKeyDown", on_key_down)
