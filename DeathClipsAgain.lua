local addonName, ns = ...
local L = ns.L -- Assuming L is properly part of the ns table or loaded globally.

-- SAVED VARIABLES:
if type(AuctionHouseDBSaved) ~= "table" then _G.AuctionHouseDBSaved = {} end
AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
-- Structure: { [playerLowerName] = { clipLevel = number, hasBeenNotifiedForThisAdd = boolean } }

-- State for AddFriend Error Handling (Session Only)
local suppressPlayerNotFoundSystemMessageActive = false
local PLAYER_NOT_FOUND_RU = "Игрок не найден."
ns.expectingFriendAddSystemMessageFor = nil
ns.capturedFriendAddSystemMessage = nil
ns.lastActionStatus = nil -- Stores feedback from OnClick to be shown in HoverTooltip

local MAP_PING_SOUND_FILE = "Sound\\interface\\MapPing.wav"
ns.fallbackClassNames = {
    WARRIOR = "Воин", PALADIN = "Паладин", HUNTER = "Охотник", ROGUE = "Разбойник",
    PRIEST = "Жрец", DEATHKNIGHT = "Рыцарь смерти", SHAMAN = "Шаман", MAGE = "Маг",
    WARLOCK = "Чернокнижник", DRUID = "Друид", ["РЫЦАРЬ СМЕРТИ"] = "Рыцарь смерти"
}

-- Debounce/Cooldown variables
local FRIENDLIST_UPDATE_DEBOUNCE_TIME = 10
local NOTIFICATION_COOLDOWN = 3
local lastFriendListScanTime = 0
local lastNotificationTime = 0
local friendListDebounceTimer = nil
local initialLoginScanTimer = nil

local TOOLTIP_MIN_WIDTH = 150
local TOOLTIP_MAX_WIDTH = 350
local TOOLTIP_HORIZONTAL_PADDING = 20
local TOOLTIP_VERTICAL_PADDING = 16
local LINE_SPACING = 2

-- ShowStatusTooltip and HideStatusTooltip are removed.

function ns.IsPlayerOnFriendsList(characterName)
    if not characterName or characterName == "" then return false end
    local lowerCharacterName = string.lower(characterName)
    for i = 1, GetNumFriends() do
        local name, level, classToken, area, connected = GetFriendInfo(i)
        if name then
            local lowerName = string.lower(name)
            local friendBaseName = lowerName:match("([^%-]+)")
            if friendBaseName == lowerCharacterName or lowerName == lowerCharacterName then
                return true, connected, level, classToken, area
            end
        end
    end
    return false, false, nil, nil, nil
end

ns.russianClassNameToEnglishToken = {
    -- Male (and some neutral) forms from LOCALIZED_CLASS_NAMES_MALE
    ["Рыцарь смерти"] = "DEATHKNIGHT",
    ["Воин"] = "WARRIOR",
    ["Разбойник"] = "ROGUE",
    ["Маг"] = "MAGE",
    ["Жрец"] = "PRIEST",
    ["Чернокнижник"] = "WARLOCK",
    ["Охотник"] = "HUNTER",
    ["Друид"] = "DRUID", -- Druid is often neutral
    ["Шаман"] = "SHAMAN",
    ["Паладин"] = "PALADIN", -- Paladin is often neutral

    -- Female forms from LOCALIZED_CLASS_NAMES_FEMALE
    -- Note: DEATHKNIGHT, WARRIOR, MAGE, DRUID, PALADIN often use same localized string for male/female,
    -- so they might overwrite. This is fine as long as the English token is the same.
    ["Разбойница"] = "ROGUE",
    ["Жрица"] = "PRIEST",
    ["Чернокнижница"] = "WARLOCK",
    ["Охотница"] = "HUNTER",
    ["Шаманка"] = "SHAMAN",

    -- Also include uppercase versions if GetFriendInfo might return those
    ["РЫЦАРЬ СМЕРТИ"] = "DEATHKNIGHT",
    ["ВОИН"] = "WARRIOR",
    ["РАЗБОЙНИК"] = "ROGUE",
    ["МАГ"] = "MAGE",
    ["ЖРЕЦ"] = "PRIEST",
    ["ЧЕРНОКНИЖНИК"] = "WARLOCK",
    ["ОХОТНИК"] = "HUNTER",
    ["ДРУИД"] = "DRUID",
    ["ШАМАН"] = "SHAMAN",
    ["ПАЛАДИН"] = "PALADIN",
    ["ОХОТНИЦА"] = "HUNTER", -- Uppercase female
    ["РАЗБОЙНИЦА"] = "ROGUE",
    ["ЖРИЦА"] = "PRIEST",
    ["ЧЕРНОКНИЖНИЦА"] = "WARLOCK",
    ["ШАМАНКА"] = "SHAMAN"
}

local function NotifyPlayerLevelDrop(name, currentLevel, clipLevelWhenAdded, classTokenFromGetFriendInfo, area)
    local lowerName = string.lower(name)
    AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
    local watchedEntry = AuctionHouseDBSaved.watchedFriends[lowerName]

    if watchedEntry and not watchedEntry.hasBeenNotifiedForThisAdd and
            currentLevel and watchedEntry.clipLevel and currentLevel < watchedEntry.clipLevel then

        local currentTime = GetTime()
        if (currentTime - lastNotificationTime) < NOTIFICATION_COOLDOWN then
            return
        end
        lastNotificationTime = currentTime

        PlaySoundFile(MAP_PING_SOUND_FILE)

        local displayedClassName = "Неизвестный класс"
        local classColorHex = "ffffffff" -- Default to white for color if not found
        local englishTokenForColor = nil

        if classTokenFromGetFriendInfo and type(classTokenFromGetFriendInfo) == "string" and classTokenFromGetFriendInfo ~= "" then
            displayedClassName = classTokenFromGetFriendInfo

            if ns.russianClassNameToEnglishToken then
                englishTokenForColor = ns.russianClassNameToEnglishToken[displayedClassName]
                if not englishTokenForColor then
                    englishTokenForColor = ns.russianClassNameToEnglishToken[string.upper(displayedClassName)]
                end
            end

            if englishTokenForColor and RAID_CLASS_COLORS and RAID_CLASS_COLORS[englishTokenForColor] then
                local c = RAID_CLASS_COLORS[englishTokenForColor]
                classColorHex = string.format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            end
        end

        local zoneName = area and area ~= "" and area or "Неизвестная зона"

        -- Line 1: "GoAgainAH:" (grey) Name (class color) "начал новый путь." (default white)
        local prefix = string.format("|cff888888%s:|r", addonName)
        local clickableColoredName = string.format("|Hplayer:%s|h|cff%s[%s]|h|r", name, classColorHex, name)
        local line1 = string.format("%s %s начал новый путь.", prefix, clickableColoredName)

        -- Line 2: ClassName (class color) Level (yellow) • (light grey) Zone (gold) (прежний уровень: OriginalLevel (yellow))
        local coloredDisplayedClassName = string.format("|cff%s%s|r", classColorHex, displayedClassName)
        local currentLevelStr = string.format("|cffffff00%d ур.|r", currentLevel) -- Yellow #FFFF00
        local separator = "|cffaaaaaa•|r" -- Light grey #AAAAAA
        local zoneNameStr = string.format("|cffffd700%s|r", zoneName) -- Gold #FFD700
        local originalClipLevelStr = string.format("|cffffff00%d|r", watchedEntry.clipLevel) -- Yellow #FFFF00

        local line2 = string.format("%s %s %s %s %s прежний уровень: %s",
                coloredDisplayedClassName,
                currentLevelStr,
                separator,           -- First separator
                zoneNameStr,
                separator,           -- Second separator
                originalClipLevelStr)

        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(line1)
            DEFAULT_CHAT_FRAME:AddMessage(line2)
        else
            print(line1); print(line2)
        end

        watchedEntry.hasBeenNotifiedForThisAdd = true
    end
end

-- at addon load, create a dedicated hover-tooltip
local HoverTooltip = CreateFrame("GameTooltip", "GoAgainAH_HoverTooltip", UIParent, "GameTooltipTemplate")
HoverTooltip:SetFrameStrata("TOOLTIP")
-- you can tweak its default anchor offset here if you like:
-- HoverTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function ShowHoverTooltipForIcon(iconButton)
    HoverTooltip:ClearLines() -- Clear lines at the beginning

    -- hide the standard GameTooltip if it’s on this button
    if GameTooltip:IsShown() and GameTooltip:IsOwned(iconButton) then
        GameTooltip:Hide()
    end

    -- grab your clipData
    local row = iconButton:GetParent()
    if not row or not row.clipData or not row.clipData.characterName then
        return
    end
    local cd = row.clipData
    local name = cd.characterName

    -- populate *your* tooltip
    HoverTooltip:SetOwner(iconButton, "ANCHOR_RIGHT")
    -- HoverTooltip:ClearLines() -- Moved to top
    HoverTooltip:AddLine(name)

    local pf = UnitFactionGroup("player")
    if cd.faction ~= pf then
        HoverTooltip:AddLine("|cffff2020(Другая фракция)|r")
    else
        local isFriend, isConnected, lvl = ns.IsPlayerOnFriendsList(name) -- Corrected call
        HoverTooltip:AddLine("ЛКМ: |cffA0A0A0Шёпот|r")

        if isFriend then
            HoverTooltip:AddLine("ПКМ: |cff00cc00Уже друг|r")
            if isConnected then
                HoverTooltip:AddLine(string.format("|cff69ccf0(В сети - Ур: %d)|r", lvl or 0))
            else
                HoverTooltip:AddLine("|cff888888(Не в сети)|r")
            end
        else
            HoverTooltip:AddLine("ПКМ: |cffA0A0A0В друзья|r")
        end
    end

    -- Display last action status if available and relevant
    if ns.lastActionStatus and ns.lastActionStatus.characterName == name then
        HoverTooltip:AddLine(" ") -- Spacer line
        HoverTooltip:AddLine(ns.lastActionStatus.text)
        if ns.lastActionStatus.line2 then
            HoverTooltip:AddLine(ns.lastActionStatus.line2)
        end
        -- Clear the status after displaying it once to prevent staleness on immediate re-hover without OnLeave.
        -- ns.lastActionStatus = nil
        -- Decided against clearing here, OnLeave will handle it. This allows status to persist if user quickly re-hovers.
    end

    -- scale *only* your new tooltip
    HoverTooltip:SetScale(1.5)
    HoverTooltip:Show()
end


function GoAgainAH_ClipItem_OnClick(iconFrameElement, receivedMouseButton)
    -- Hide the GameTooltip if it’s showing for this icon
    if GameTooltip:IsShown() and GameTooltip:IsOwned(iconFrameElement) then
        GameTooltip:Hide()
    end

    -- Hide the custom hover tooltip (it will be re-shown by ShowHoverTooltipForIcon)
    if GoAgainAH_HoverTooltip then
        GoAgainAH_HoverTooltip:Hide()
    end
    ns.lastActionStatus = nil -- Clear previous status before new click action

    -- Grab the clip data from this row
    local mainRowButton = iconFrameElement:GetParent()
    if not mainRowButton or not mainRowButton.clipData then
        return
    end
    local clipData = mainRowButton.clipData
    if not clipData.characterName or not clipData.level then
        return
    end

    local characterName                      = clipData.characterName
    local characterNameLower                 = string.lower(characterName)
    local originalClipLevelFromThisInteraction = clipData.level
    local targetClipFaction                  = clipData.faction
    local playerFaction                      = UnitFactionGroup("player")
    local line1, line2, line3                = "", "", ""

    if receivedMouseButton == "LeftButton" then
        -- Left-click: whisper the character
        local editBox = _G["ChatFrame1EditBox"]
        if editBox then
            if editBox:IsShown() then
                editBox:ClearFocus()
                editBox:Hide()
            else
                ChatFrame_SendTell(characterName)
            end
        else
            ChatFrame_SendTell(characterName)
        end

    elseif receivedMouseButton == "RightButton" then
        -- Right-click: add to friends / notify

        -- 1) Client-side faction check removed. The game server will handle the result of a cross-faction AddFriend attempt.
        -- if targetClipFaction ~= playerFaction then
        --     ns.lastActionStatus = {
        --         characterName = characterName,
        --         text = "|cffff0000Нельзя добавить в друзья:|r " .. characterName,
        --         line2 = "(Разные фракции)"
        --     }
        --     ShowHoverTooltipForIcon(iconFrameElement)
        --     return
        -- end

        if AddFriend then
            -- Check existing friend status
            local wasAlreadyFriend, wasConnected, currentActualLevel, currentClass, currentArea =
            ns.IsPlayerOnFriendsList(characterName) -- Corrected call

            AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}

            if wasAlreadyFriend then
                ns.lastActionStatus = { characterName = characterName, text = string.format("%s |cff00ff00уже в друзьях.|r", characterName) }
                if wasConnected then
                    ns.lastActionStatus.line2 = string.format("|cff69ccf0В сети - Ур: %d|r", currentActualLevel or 0)
                else
                    ns.lastActionStatus.line2 = "|cff888888Не в сети|r"
                end
                ShowHoverTooltipForIcon(iconFrameElement)

                local watchedEntry = AuctionHouseDBSaved.watchedFriends[characterNameLower]
                if wasConnected and watchedEntry and watchedEntry.clipLevel then
                    NotifyPlayerLevelDrop(characterName, currentActualLevel, watchedEntry.clipLevel, currentClass, currentArea)
                end
                return
            end

            -- Not yet a friend: send request and capture system message
            ns.capturedFriendAddSystemMessage = nil
            ns.expectingFriendAddSystemMessageFor = characterNameLower
            suppressPlayerNotFoundSystemMessageActive = true
            AddFriend(characterName)

            -- Re-enable error messages after 0.2s
            C_Timer:After(0.2, function()
                suppressPlayerNotFoundSystemMessageActive = false
                if ns.expectingFriendAddSystemMessageFor == characterNameLower then
                    ns.expectingFriendAddSystemMessageFor = nil
                end
            end)

            -- After 0.3s, check whether the add succeeded
            C_Timer:After(0.3, function()
                local isNowFriend, isConnected, friendActualLevel, friendClass, friendArea =
                ns.IsPlayerOnFriendsList(characterName) -- Corrected call

                if isNowFriend then
                    ns.lastActionStatus = { characterName = characterName, text = string.format("|cff00ff00Добавлен в друзья:|r %s", characterName) }
                    if isConnected then
                        ns.lastActionStatus.line2 = "|cff69ccf0В сети|r"
                        AuctionHouseDBSaved.watchedFriends[characterNameLower] = {
                            characterName = characterName, -- Added original casing
                            clipLevel = originalClipLevelFromThisInteraction,
                            hasBeenNotifiedForThisAdd = false,
                        }
                        NotifyPlayerLevelDrop(characterName, friendActualLevel, originalClipLevelFromThisInteraction, friendClass, friendArea, "added")
                    else
                        ns.lastActionStatus.line2 = "|cff888888Не в сети|r"
                        AuctionHouseDBSaved.watchedFriends[characterNameLower] = {
                            characterName = characterName, -- Added original casing
                            clipLevel = originalClipLevelFromThisInteraction,
                            hasBeenNotifiedForThisAdd = false,
                        }
                    end
                else
                    ns.lastActionStatus = { characterName = characterName, text = string.format("|cffffcc00Не удалось добавить:|r %s", characterName) }
                    if ns.capturedFriendAddSystemMessage then
                        ns.lastActionStatus.line2 = "|cffffff80Причина: " .. ns.capturedFriendAddSystemMessage .. "|r"
                    else
                        ns.lastActionStatus.line2 = "(Проверьте ошибки игры в чате)"
                    end
                end
                ShowHoverTooltipForIcon(iconFrameElement) -- Refresh tooltip with status
                ns.expectingFriendAddSystemMessageFor = nil
                ns.capturedFriendAddSystemMessage = nil
            end)
        end
    end
end

-- When the mouse enters the icon, show your custom tooltip
function GoAgainAH_ClipItem_OnEnter(iconButton)
    ShowHoverTooltipForIcon(iconButton)
end

-- When the mouse leaves, hide *all* of your tooltips
function GoAgainAH_ClipItem_OnLeave(iconButton)
    -- Hide the custom hover tooltip
    if GoAgainAH_HoverTooltip then
        GoAgainAH_HoverTooltip:Hide()
    end

    ns.lastActionStatus = nil -- Clear status when mouse leaves

    -- In case the default GameTooltip was used, hide that too
    if GameTooltip:IsOwned(iconButton) then
        GameTooltip:Hide()
    end
end


local function FriendAddSystemMessageFilter(self, event, msg, ...)
    if not msg or type(msg) ~= "string" then return false end
    if event == "CHAT_MSG_SYSTEM" and suppressPlayerNotFoundSystemMessageActive and msg == PLAYER_NOT_FOUND_RU then
        if ns.expectingFriendAddSystemMessageFor then ns.capturedFriendAddSystemMessage = msg; ns.expectingFriendAddSystemMessageFor = nil end
        return true
    end
    if event == "CHAT_MSG_SYSTEM" and ns.expectingFriendAddSystemMessageFor and not ns.capturedFriendAddSystemMessage then
        local shortMsg = msg; if string.len(msg) > 60 then shortMsg = string.sub(msg, 1, 60) .. "..." end
        ns.capturedFriendAddSystemMessage = shortMsg; ns.expectingFriendAddSystemMessageFor = nil
    end
    return false
end

local function PerformFriendListScan()
    lastFriendListScanTime = GetTime()
    if type(AuctionHouseDBSaved) ~= "table" or type(AuctionHouseDBSaved.watchedFriends) ~= "table" then return end
    for i = 1, GetNumFriends() do
        local name, currentActualLevel, classToken, area, connected = GetFriendInfo(i)
        if name and connected then
            local lowerName = string.lower(name)
            local watchedEntry = AuctionHouseDBSaved.watchedFriends[lowerName]
            if watchedEntry and watchedEntry.clipLevel and not watchedEntry.hasBeenNotifiedForThisAdd then
                NotifyPlayerLevelDrop(name, currentActualLevel, watchedEntry.clipLevel, classToken, area, "friend_online_event")
            end
        end
    end
end

local function HandleFriendListUpdate()
    if friendListDebounceTimer then return end
    local currentTime = GetTime()
    if (currentTime - lastFriendListScanTime) < FRIENDLIST_UPDATE_DEBOUNCE_TIME then
        local remainingTime = FRIENDLIST_UPDATE_DEBOUNCE_TIME - (currentTime - lastFriendListScanTime)
        friendListDebounceTimer = C_Timer:After(remainingTime, function()
            friendListDebounceTimer = nil; PerformFriendListScan()
        end)
        return
    end
    PerformFriendListScan()
end

local function CleanupNotifiedFriendsDB()
    -- Intentionally left empty to preserve watchedFriends entries
    -- regardless of their hasBeenNotifiedForThisAdd status, allowing
    -- the "Восставшие" tab to be persistent across sessions.
    -- Original logic for cleaning up notified friends has been removed.

    -- If there's any other type of cleanup needed in the future (e.g., removing very old entries
    -- or entries for characters no longer on friends list for a long time),
    -- that logic could be added here. For now, no cleanup is performed.
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("FRIENDLIST_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if type(AuctionHouseDBSaved) ~= "table" then _G.AuctionHouseDBSaved = {} end
        AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FriendAddSystemMessageFilter)
    elseif event == "PLAYER_ENTERING_WORLD" then
        if type(AuctionHouseDBSaved) ~= "table" then _G.AuctionHouseDBSaved = {} end
        AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
        CleanupNotifiedFriendsDB()
        lastFriendListScanTime = 0
        if friendListDebounceTimer then friendListDebounceTimer:Cancel(); friendListDebounceTimer = nil end
        if initialLoginScanTimer then initialLoginScanTimer:Cancel(); initialLoginScanTimer = nil end
        initialLoginScanTimer = C_Timer:After(15, function()
            initialLoginScanTimer = nil; PerformFriendListScan()
        end)
    elseif event == "PLAYER_LOGOUT" then
        if friendListDebounceTimer then friendListDebounceTimer:Cancel(); friendListDebounceTimer = nil end
        if initialLoginScanTimer then initialLoginScanTimer:Cancel(); initialLoginScanTimer = nil end
        -- Watched friends data in AuctionHouseDBSaved persists. No session flags to clear here.
    elseif event == "FRIENDLIST_UPDATE" then
        HandleFriendListUpdate()
    end
end)
