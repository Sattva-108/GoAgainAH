local addonName, ns = ...
local L = ns.L -- Assuming L is properly part of the ns table or loaded globally.

-- SAVED VARIABLES:
if type(AuctionHouseDBSaved) ~= "table" then _G.AuctionHouseDBSaved = {} end
AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}
-- Structure: { [playerLowerName] = { clipLevel = number, hasBeenNotifiedForThisAdd = boolean } }

ns.isFriendCleanupRunning = false -- Mutex for cleanup process

-- State for AddFriend Error Handling (Session Only)
local suppressPlayerNotFoundSystemMessageActive = false
local PLAYER_NOT_FOUND_RU = "Игрок не найден."
local FRIENDS_MUST_BE_ALLIES_RU = "Друзья должны быть вашими союзниками."
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
    if not characterName or characterName == "" then
        return false, false, nil, nil, nil, nil
    end
    local lowerCharacterName = string.lower(characterName)
    local isFriend = false
    local connected = false
    local displayLevel = nil
    local classToken = nil
    local area = nil
    local clipLevelFromDB = nil

    for i = 1, GetNumFriends() do
        local name, levelFromGetFriendInfo, classTokenFromGetFriendInfo, areaFromGetFriendInfo, connectedFromGetFriendInfo = GetFriendInfo(i)
        if name then
            local lowerName = string.lower(name)
            local friendBaseName = lowerName:match("([^%-]+)")
            if friendBaseName == lowerCharacterName or lowerName == lowerCharacterName then
                isFriend = true
                connected = connectedFromGetFriendInfo
                classToken = classTokenFromGetFriendInfo
                area = areaFromGetFriendInfo

                if connected then
                    displayLevel = levelFromGetFriendInfo
                else
                    -- Friend is offline, try to get level from DB
                    local watchedEntry = AuctionHouseDBSaved.watchedFriends and AuctionHouseDBSaved.watchedFriends[lowerCharacterName]
                    if watchedEntry then
                        if watchedEntry.lastKnownActualLevel and watchedEntry.lastKnownActualLevel > 0 then
                            displayLevel = watchedEntry.lastKnownActualLevel
                        else
                            -- lastKnownActualLevel is nil or 0, meaning never truly observed or invalid
                            displayLevel = 0
                        end
                    else
                        -- Not a watched friend, or no entry (should ideally not happen if they are on friends list and being processed)
                        displayLevel = 0
                    end
                end

                -- Get clipLevelFromDB regardless of online status
                local watchedEntryForClipLevel = AuctionHouseDBSaved.watchedFriends and AuctionHouseDBSaved.watchedFriends[lowerCharacterName]
                if watchedEntryForClipLevel then
                    clipLevelFromDB = watchedEntryForClipLevel.clipLevel
                end
                return isFriend, connected, displayLevel, classToken, area, clipLevelFromDB
            end
        end
    end
    return false, false, nil, nil, nil, nil -- Not found on friends list
end

function ns.GetEnglishClassToken(localizedClassName)
    if not localizedClassName or localizedClassName == "" then return nil end

    if ns.russianClassNameToEnglishToken then
        local token = ns.russianClassNameToEnglishToken[localizedClassName]
        if token then return token end
        token = ns.russianClassNameToEnglishToken[string.upper(localizedClassName)]
        if token then return token end
    end

    -- Fallback: Check if the localizedClassName (uppercased) is itself a valid English global constant key
    -- This handles cases where the game client might already provide the English token.
    local upperLocalizedClassName = string.upper(localizedClassName)
    if _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[upperLocalizedClassName] then
        -- Check if upperLocalizedClassName is a key in LOCALIZED_CLASS_NAMES_MALE, implying it IS an English token
        local isKey = false
        for k, _ in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
            if k == upperLocalizedClassName then
                isKey = true
                break
            end
        end
        if isKey then return upperLocalizedClassName end
    end

    -- Further fallback: Check against ns.fallbackClassNames values (which are localized) to get key (English token)
    -- This assumes ns.fallbackClassNames maps English Token (key) -> Localized Name (value)
    if ns.fallbackClassNames then
        for engToken, locName in pairs(ns.fallbackClassNames) do
            if locName == localizedClassName or locName == upperLocalizedClassName then
                return engToken -- Return the English key
            end
        end
    end

    return nil -- No token found
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
    -- Guard clause: Exit if button is invalid or mouse is not over it.
    if not iconButton or not iconButton:IsMouseOver() then
        if GoAgainAH_HoverTooltip then -- Check if tooltip exists
            GoAgainAH_HoverTooltip:Hide()
        end
        return -- Exit the function if the mouse is not over the iconButton
    end

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
        local characterNameLower = string.lower(name)
        local isWatched = AuctionHouseDBSaved.watchedFriends[characterNameLower] ~= nil
        -- Call IsPlayerOnFriendsList to get their current WoW friend status and live level if online.
        -- displayLevelFromFunc will be their live level if online, or 0 if offline and unknown lastKnownActualLevel.
        -- clipLvlDB_from_func is the clipLevel from watchedFriends IF they are on WoW friends list.
        local isFriendOnWoWList, isConnected, displayLevelFromFunc, classToken, area, clipLvlDB_from_func = ns.IsPlayerOnFriendsList(name)

        HoverTooltip:AddLine("ЛКМ: |cffA0A0A0Шёпот|r")

        -- "Add/Remove Friend" line (PKМ):
        if isWatched then
            if isFriendOnWoWList then
                HoverTooltip:AddLine("ПКМ: |cff00cc00Уже друг|r")
            else
                HoverTooltip:AddLine("ПКМ: |cff888888Добавить в друзья|r") -- Grayed out as per request
            end
        else -- Not watched (this case might be less relevant if UI is purely from watchedFriends, but as fallback)
            if isFriendOnWoWList then
                HoverTooltip:AddLine("ПКМ: |cff00cc00Уже друг|r")
            else
                HoverTooltip:AddLine("ПКМ: |cffA0A0A0В друзья|r")
            end
        end

        -- Online/Offline Status & Level Line:
        if isConnected then -- Player is on WoW friends list AND online
            HoverTooltip:AddLine(string.format("|cff69ccf0(В сети - Ур: %d)|r", displayLevelFromFunc or 0))
        else -- Player is OFFLINE or NOT on WoW friends list (or both)
            if isWatched then
                local watchedEntry = AuctionHouseDBSaved.watchedFriends[characterNameLower]
                -- Prioritize lastKnownActualLevel from the DB if it's valid (>0).
                -- displayLevelFromFunc is 0 if offline friend's level unknown to IsPlayerOnFriendsList.
                local levelToDisplay = (watchedEntry and watchedEntry.lastKnownActualLevel and watchedEntry.lastKnownActualLevel > 0) and watchedEntry.lastKnownActualLevel or displayLevelFromFunc
                HoverTooltip:AddLine(string.format("|cffaaaaaa(Последний известный уровень: %d)|r", levelToDisplay or 0))
            else -- Not watched AND not connected (e.g. a player from a standard AH scan not yet watched/friended)
                HoverTooltip:AddLine("|cffaaaaaa(Не в сети)|r") -- Generic "Не в сети"
            end
        end

        -- Original Level Line:
        if isWatched then
            -- We need the clipLevel directly from the watchedFriends entry,
            -- as clipLvlDB_from_func is only populated if they are also on WoW friends list.
            local watchedEntry = AuctionHouseDBSaved.watchedFriends[characterNameLower]
            if watchedEntry and watchedEntry.clipLevel then
                HoverTooltip:AddLine(string.format("|cffaaaaaa(Исходный уровень: %d)|r", watchedEntry.clipLevel))
            end
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
            local isWatched = AuctionHouseDBSaved.watchedFriends[characterNameLower] ~= nil
            local isFriendOnWoWListInitially, isConnectedInitially, currentDisplayLevelInitially, currentClassInitially, currentAreaInitially, _ =
            ns.IsPlayerOnFriendsList(characterName)

            AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}

            if isWatched then
                if isFriendOnWoWListInitially then
                    -- Watched and already on WoW friends list
                    ns.lastActionStatus = {
                        characterName = characterName,
                        text = string.format("%s |cff00ff00уже в друзьях.|r", characterName),
                        line2 = nil
                    }
                    ShowHoverTooltipForIcon(iconFrameElement)

                    local watchedEntry = AuctionHouseDBSaved.watchedFriends[characterNameLower]
                    if isConnectedInitially and watchedEntry and watchedEntry.clipLevel and currentDisplayLevelInitially and currentDisplayLevelInitially > 0 then
                        NotifyPlayerLevelDrop(characterName, currentDisplayLevelInitially, watchedEntry.clipLevel, currentClassInitially, currentAreaInitially)
                    end
                    return
                else
                    -- Watched, but NOT on WoW friends list; try to re-add to WoW list
                    ns.capturedFriendAddSystemMessage = nil
                    ns.expectingFriendAddSystemMessageFor = characterNameLower
                    suppressPlayerNotFoundSystemMessageActive = true
                    AddFriend(characterName)

                    C_Timer:After(0.2, function()
                        suppressPlayerNotFoundSystemMessageActive = false
                        if ns.expectingFriendAddSystemMessageFor == characterNameLower then ns.expectingFriendAddSystemMessageFor = nil end
                    end)

                    C_Timer:After(0.3, function()
                        local isNowFriendOnWoWList, isNowConnected = ns.IsPlayerOnFriendsList(characterName)
                        if isNowFriendOnWoWList then
                            ns.lastActionStatus = {
                                characterName = characterName,
                                text = string.format("|cff00ff00Добавлен в друзья:|r %s", characterName),
                                line2 = isNowConnected and "|cff69ccf0В сети|r" or "|cff888888Не в сети|r"
                            }
                        else
                            ns.lastActionStatus = {
                                characterName = characterName,
                                text = string.format("|cffffcc00Не удалось добавить в друзья:|r %s", characterName),
                                line2 = ns.capturedFriendAddSystemMessage and "|cffffff80Причина: " .. ns.capturedFriendAddSystemMessage .. "|r" or "(Проверьте ошибки игры в чате)"
                            }
                        end
                        ShowHoverTooltipForIcon(iconFrameElement)
                        ns.capturedFriendAddSystemMessage = nil
                    end)
                    return -- Important: Do not proceed to add/modify watchedFriends, they are already watched.
                end
            else
                -- Character is NOT watched. This is the flow to add a new character to WoW Friends and to our watched list.
                if isFriendOnWoWListInitially then
                    -- Not watched, but already on WoW friends list. User right-clicked an "Add to friends (WoW)" that was green in tooltip.
                    -- This implies user wants to start watching them.
                    -- Add to watchedFriends, then update status.
                    local friendData = {
                        characterName = characterName,
                        clipLevel = originalClipLevelFromThisInteraction, -- Use clip level as original
                        lastKnownActualLevel = (isConnectedInitially and currentDisplayLevelInitially and currentDisplayLevelInitially > 0) and currentDisplayLevelInitially or originalClipLevelFromThisInteraction,
                        lastKnownActualLevelTimestamp = GetTime(),
                        hasBeenNotifiedForThisAdd = false,
                        localizedClassNameAtLastSighting = isConnectedInitially and currentClassInitially or nil,
                        currentEnglishClassTokenAtLastSighting = isConnectedInitially and ns.GetEnglishClassToken(currentClassInitially) or nil,
                        addedToWatchTimestamp = GetTime()
                    }
                    AuctionHouseDBSaved.watchedFriends[characterNameLower] = friendData
                    ns.lastActionStatus = {
                        characterName = characterName,
                        text = string.format("%s |cff00cc00теперь отслеживается.|r", characterName),
                        line2 = nil
                    }
                    ShowHoverTooltipForIcon(iconFrameElement)
                    if isConnectedInitially and friendData.clipLevel and currentDisplayLevelInitially and currentDisplayLevelInitially > 0 then
                        NotifyPlayerLevelDrop(characterName, currentDisplayLevelInitially, friendData.clipLevel, currentClassInitially, currentAreaInitially)
                    end
                    return
                end

                -- Not watched, and not on WoW friends list. Standard add flow.
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
                    local isNowFriend, isConnected, newFriendDisplayLevel, newFriendClass, newFriendArea, _ =
                    ns.IsPlayerOnFriendsList(characterName)

                    if isNowFriend then -- This is isNowFriendOnWoWList after attempting AddFriend for an unwatched player
                        ns.lastActionStatus = {
                            characterName = characterName,
                            text = string.format("|cff00ff00Добавлен в друзья и отслеживается:|r %s", characterName)
                            -- line2 will be set below
                        }
                        if isConnected then -- isNowConnected
                            ns.lastActionStatus.line2 = "|cff69ccf0В сети|r"
                            local determinedLastKnownLevel
                            local determinedLocalizedClass
                            local determinedEnglishClassToken

                            if isConnected and newFriendDisplayLevel and newFriendDisplayLevel > 0 then
                                determinedLastKnownLevel = newFriendDisplayLevel
                                determinedLocalizedClass = newFriendClass -- newFriendClass is the localized one from GetFriendInfo
                                determinedEnglishClassToken = ns.GetEnglishClassToken(newFriendClass)
                            else
                                -- Offline or newFriendDisplayLevel is 0 or nil
                                determinedLastKnownLevel = originalClipLevelFromThisInteraction -- Fallback to original clip's level
                                determinedLocalizedClass = nil -- No live localized class
                                determinedEnglishClassToken = clipData.class -- Fallback to English class token from original clipData
                            end

                            local friendData = {
                                characterName = characterName,
                                clipLevel = originalClipLevelFromThisInteraction,
                                lastKnownActualLevel = determinedLastKnownLevel,
                                lastKnownActualLevelTimestamp = GetTime(),
                                hasBeenNotifiedForThisAdd = false,
                                localizedClassNameAtLastSighting = determinedLocalizedClass,
                                currentEnglishClassTokenAtLastSighting = determinedEnglishClassToken,
                                addedToWatchTimestamp = GetTime()
                            }
                            AuctionHouseDBSaved.watchedFriends[characterNameLower] = friendData

                            -- Notify only if live data was available and level > 0
                            if isConnected and newFriendDisplayLevel and newFriendDisplayLevel > 0 then
                                NotifyPlayerLevelDrop(characterName, newFriendDisplayLevel, originalClipLevelFromThisInteraction, newFriendClass, newFriendArea, "added")
                            end
                        else
                            -- This 'else' corresponds to 'if isConnected then'
                            -- This means the player was added to WoW friends but is immediately offline or data is missing.
                            ns.lastActionStatus.line2 = "|cff888888Не в сети|r"
                            local friendData = {
                                characterName = characterName,
                                clipLevel = originalClipLevelFromThisInteraction,
                                lastKnownActualLevel = originalClipLevelFromThisInteraction, -- Fallback to original clip's level
                                lastKnownActualLevelTimestamp = GetTime(),
                                hasBeenNotifiedForThisAdd = false,
                                localizedClassNameAtLastSighting = nil, -- Offline, no live localized class
                                currentEnglishClassTokenAtLastSighting = clipData.class, -- Fallback to English class token from original clipData
                                addedToWatchTimestamp = GetTime()
                            }
                            AuctionHouseDBSaved.watchedFriends[characterNameLower] = friendData
                        end
                    else
                        ns.lastActionStatus = {
                            characterName = characterName,
                            text = string.format("|cffffcc00Не удалось добавить в друзья:|r %s", characterName), -- Updated text
                            line2 = ns.capturedFriendAddSystemMessage and "|cffffff80Причина: " .. ns.capturedFriendAddSystemMessage .. "|r" or "(Проверьте ошибки игры в чате)"
                        }
                    end
                    ShowHoverTooltipForIcon(iconFrameElement) -- Refresh tooltip with status
                    ns.expectingFriendAddSystemMessageFor = nil
                    ns.capturedFriendAddSystemMessage = nil
                end)
            end -- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< THIS IS THE MISSING END
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
    -- Suppress faction message when adding friends
    if event == "CHAT_MSG_SYSTEM" and suppressPlayerNotFoundSystemMessageActive and msg == FRIENDS_MUST_BE_ALLIES_RU then
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
        local name, currentActualLevel, classToken, area, connected = GetFriendInfo(i) -- Renamed liveLevel to currentActualLevel for clarity
        if name and connected then -- Only process online friends
            local lowerName = string.lower(name)
            local watchedEntry = AuctionHouseDBSaved.watchedFriends[lowerName]

            if watchedEntry then
                -- Check for level change to update lastKnownActualLevel
                if currentActualLevel ~= watchedEntry.lastKnownActualLevel then
                    local oldLevel = watchedEntry.lastKnownActualLevel or "неизвестен"
                    local prefix = string.format("|cff888888[%s]|r", addonName)
                    local playerName = string.format("|cff69ccf0%s|r", name)
                    local levelChange = string.format("|cffffff00%s на %s|r", tostring(oldLevel), tostring(currentActualLevel))

                    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s %s уровень изменился с %s.",
                            prefix, playerName, levelChange))

                    watchedEntry.lastKnownActualLevel = currentActualLevel
                    watchedEntry.lastKnownActualLevelTimestamp = GetTime()
                end

                -- Update class info at last sighting
                if classToken then
                    watchedEntry.localizedClassNameAtLastSighting = classToken
                    watchedEntry.currentEnglishClassTokenAtLastSighting = ns.GetEnglishClassToken(classToken)
                end

                -- Logic for level drop notification (original functionality)
                if watchedEntry.clipLevel and not watchedEntry.hasBeenNotifiedForThisAdd then
                    NotifyPlayerLevelDrop(name, currentActualLevel, watchedEntry.clipLevel, classToken, area, "friend_online_event")
                end
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

function ns.GetReincarnatedFriendsDisplayList()
    local displayList = {}
    if type(AuctionHouseDBSaved) ~= "table" or type(AuctionHouseDBSaved.watchedFriends) ~= "table" then
        return displayList
    end

    local rawOriginalClips = ns.GetLiveDeathClips and ns.GetLiveDeathClips() or {}
    local realmFilteredOriginalClips = ns.FilterClipsThisRealm and ns.FilterClipsThisRealm(rawOriginalClips) or rawOriginalClips

    local nonCompletedOriginalClips = {}
    for _, clip in ipairs(realmFilteredOriginalClips) do
        if not clip.completed then
            table.insert(nonCompletedOriginalClips, clip)
        end
    end

    for playerLowerName, watchedEntry in pairs(AuctionHouseDBSaved.watchedFriends) do
        if watchedEntry and watchedEntry.characterName and watchedEntry.hasBeenNotifiedForThisAdd then
            local characterName = watchedEntry.characterName

            local liveIsFriendOnWoWList, liveIsConnected, liveDisplayLevel, liveLocalizedClass, liveArea, _ = ns.IsPlayerOnFriendsList(characterName)

            local actualLevelToStore
            local finalLocalizedClassName
            local finalCurrentEnglishClassToken

            if liveIsConnected then
                actualLevelToStore = liveDisplayLevel
                finalLocalizedClassName = liveLocalizedClass
                finalCurrentEnglishClassToken = ns.GetEnglishClassToken(liveLocalizedClass)
            else
                -- Player is offline or not on WoW friends list
                actualLevelToStore = (watchedEntry.lastKnownActualLevel and watchedEntry.lastKnownActualLevel > 0) and watchedEntry.lastKnownActualLevel or 0
                finalLocalizedClassName = watchedEntry.localizedClassNameAtLastSighting
                finalCurrentEnglishClassToken = watchedEntry.currentEnglishClassTokenAtLastSighting
            end

            -- Ensure actualLevelToStore is not nil, default to 0 if it ended up nil (e.g. from liveDisplayLevel being nil for some reason)
            actualLevelToStore = actualLevelToStore or 0

            -- Find the corresponding original death clip
            local bestOriginalClip = nil
            for _, originalClip in ipairs(nonCompletedOriginalClips) do
                if string.lower(originalClip.characterName or "") == playerLowerName then
                    if not bestOriginalClip or (originalClip.ts and bestOriginalClip.ts and originalClip.ts > bestOriginalClip.ts) then
                        bestOriginalClip = originalClip
                    end
                end
            end

            local friendDisplayData = {
                characterName = characterName,
                clipLevel = watchedEntry.clipLevel,
                actualLevel = actualLevelToStore,
                isOnline = liveIsConnected, -- Reflects current live online status
                isOnWoWFriends = liveIsFriendOnWoWList, -- Reflects current live WoW friend status
                localizedClassName = finalLocalizedClassName,
                currentEnglishClassToken = finalCurrentEnglishClassToken,
                zone = liveArea, -- Will be nil if not connected/not on friends list, which is appropriate
                lastKnownActualLevelTimestamp = watchedEntry.lastKnownActualLevelTimestamp,
                hasBeenNotifiedForThisAdd = watchedEntry.hasBeenNotifiedForThisAdd,

                originalTimestamp = bestOriginalClip and bestOriginalClip.ts or nil,
                originalDeathCause = bestOriginalClip and bestOriginalClip.deathCause or nil,
                originalCauseCode = bestOriginalClip and bestOriginalClip.causeCode or nil,
                originalMobLevel = bestOriginalClip and bestOriginalClip.mobLevel or nil,
                originalEnglishClassToken = bestOriginalClip and bestOriginalClip.class or nil, -- Assuming originalClip.class is English token
                originalFaction = bestOriginalClip and bestOriginalClip.faction or nil,
                originalMapId = bestOriginalClip and bestOriginalClip.mapId or nil
            }
            table.insert(displayList, friendDisplayData)
        end
    end
    return displayList
end

function ns.InitiateFriendCleanup()
    local prefix = addonName .. ": "
    if ns.isFriendCleanupRunning then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Friend cleanup process is already running.")
        return
    end
    ns.isFriendCleanupRunning = true

    if type(AuctionHouseDBSaved) ~= "table" or type(AuctionHouseDBSaved.watchedFriends) ~= "table" or not next(AuctionHouseDBSaved.watchedFriends) then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "No watched friends to process for cleanup.")
        ns.isFriendCleanupRunning = false
        return
    end

    local candidatesForRemoval = {}
    for playerLowerName, entry in pairs(AuctionHouseDBSaved.watchedFriends) do
        if entry and entry.characterName and not entry.hasBeenNotifiedForThisAdd then
            table.insert(candidatesForRemoval, {
                characterName = entry.characterName,
                addedToWatchTimestamp = entry.addedToWatchTimestamp or 0
            })
        end
    end

    if #candidatesForRemoval == 0 then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. "No unnotified watched friends to process for cleanup.")
        ns.isFriendCleanupRunning = false
        return
    end

    table.sort(candidatesForRemoval, function(a, b)
        return a.addedToWatchTimestamp < b.addedToWatchTimestamp
    end)

    DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Starting cleanup of " .. #candidatesForRemoval .. " unnotified watched friend(s)...")

    local removedFromWoWListCount = 0
    local removedFromDBCount = 0

    local function ProcessNextRemoval(index)
        if index > #candidatesForRemoval then
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Friend cleanup process complete.")
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Removed " .. removedFromWoWListCount .. " players from WoW friends list.")
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. "Removed " .. removedFromDBCount .. " unnotified entries (not on WoW list) from the watch list database.")
            ns.isFriendCleanupRunning = false -- Release lock
            return
        end

        local candidate = candidatesForRemoval[index]
        local characterNameLower = string.lower(candidate.characterName)

        local isActuallyOnWoWFriends = GetFriendInfo(candidate.characterName) ~= nil

        if isActuallyOnWoWFriends then -- Player IS on WoW friends list
            RemoveFriend(candidate.characterName)
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. candidate.characterName .. " removed from WoW friends list.")
            removedFromWoWListCount = removedFromWoWListCount + 1
        else -- Player is NOT on WoW friends list
            AuctionHouseDBSaved.watchedFriends[characterNameLower] = nil
            DEFAULT_CHAT_FRAME:AddMessage(prefix .. candidate.characterName .. " (unnotified, not on WoW list) removed from watch list database.")
            removedFromDBCount = removedFromDBCount + 1
        end

        C_Timer:After(3, function()
            ProcessNextRemoval(index + 1)
        end)
    end

    ProcessNextRemoval(1)
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
