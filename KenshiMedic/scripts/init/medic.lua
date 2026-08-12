local logDebug = KenshiLua.logDebug
local KC_H = 35

local function heal_selected()
    local player = getPlayerInterface()
    if not player then
        logDebug("[KenshiMedic] no PlayerInterface")
        return
    end

    local selected = player.selectedCharacters
    if not selected then
        logDebug("[KenshiMedic] no selected characters set")
        return
    end

    logDebug("[KenshiMedic] healing selected characters")

    local count = 0
    -- selectedCharacters:toTable() returns handles as keys (set-style),
    -- so the loop variable is the hand, not the value.
    for h in pairs(selected:toTable()) do
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
    if key_code == KC_H then
        logDebug("[KenshiMedic] H pressed, healing selected characters")
        heal_selected()
    end
end

logDebug("[KenshiMedic] Registering key callback")
registerHandler("onKeyDown", on_key_down)
logDebug("[KenshiMedic] Callback registered")
