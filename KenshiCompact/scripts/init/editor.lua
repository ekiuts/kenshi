-- editor.lua - KenshiCompact
-- Press Shift + / to open the CharacterEditWindow for the primary selected character
-- Lua port of the KenshiCompact C++ plugin (RE_Kenshi)

local logDebug = KenshiLua.logDebug

local KC_SLASH = 53 -- OIS key code

local function open_character_editor()
    local player = getPlayerInterface()
    if not player then
        logDebug("[KenshiCompact] getPlayerInterface() returned nil")
        return
    end

    local selected = player.selectedCharacter
    if not selected then
        logDebug("[KenshiCompact] player.selectedCharacter is nil (nothing selected)")
        return
    end

    local c = selected:getCharacter()
    if not c then
        logDebug("[KenshiCompact] selectedCharacter:getCharacter() returned nil (stale handle?)")
        return
    end

    if c:isInCombatMode(true, true) then -- args: (melee, ranged)
        logDebug("[KenshiCompact] character is in combat mode (melee or ranged)")
        return
    end

    logDebug("[KenshiCompact] opening character editor for selected character")
    player:activateCharacterEditMode(c)
end

local function on_key_down(first, second)
    local key_code, ih
    if type(first) == "number" then
        key_code = first -- legacy KenshiLua: first arg is the key code
        ih = getInputHandler()
    else
        ih = first -- new KenshiLua: first arg is the InputHandler
        key_code = second -- second arg is the key code
    end
    if key_code == KC_SLASH and ih and ih.shift then -- Shift + /
        open_character_editor()
    end
end

local PREV_HANDLER_KEY = "_KenshiCompact_prev_onKeyDown"
local prev = _G[PREV_HANDLER_KEY]
if prev ~= nil then
    unregisterHandler("onKeyDown", prev)
end

logDebug("[KenshiCompact] registering Shift+/ key handler")
registerHandler("onKeyDown", on_key_down)
_G[PREV_HANDLER_KEY] = on_key_down
