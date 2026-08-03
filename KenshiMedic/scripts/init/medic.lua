-- medic.lua - KenshiMedic
-- Press H to fully heal every currently selected character.
-- Uses Character:healCompletely(), the game's own full-heal routine
-- (see KenshiLua/docs/BindingsReference.md ## Character).

local logDebug = KenshiLua.logDebug
local KC_H = 35

local function heal_selected()
    logDebug("[KenshiMedic] healCompletely called")

    local world = getGameWorld()
    if not world then
        logDebug("[KenshiMedic] no world")
        return
    end

    local selected = getPlayerInterface().selectedCharacters
    if not selected then
        logDebug("[KenshiMedic] No selected characters set found")
        return
    end

    local count = 0
    for h, _ in pairs(selected:toTable()) do
        local c = h:getCharacter()
        if c then
            c:healCompletely()
            count = count + 1
        end
    end

    if count == 0 then
        logDebug("[KenshiMedic] nothing healed")
    else
        logDebug("[KenshiMedic] healed " .. tostring(count) .. " character(s)")
    end
end

local function on_key_down(key_code)
    logDebug("[KenshiMedic] Key pressed: " .. tostring(key_code))
    if key_code == KC_H then
        logDebug("[KenshiMedic] H pressed, healing selected characters")
        heal_selected()
    end
end

logDebug("[KenshiMedic] Registering key callback")
registerHandler("onKeyDown", on_key_down)
logDebug("[KenshiMedic] Callback registered")
