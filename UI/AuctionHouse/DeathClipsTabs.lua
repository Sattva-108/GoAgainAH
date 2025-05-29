-- DeathClipsTabs.lua
local addonName, ns = ...
local L = ns.L

ns.currentActiveTabId = "LIVE_CLIPS" -- Default active tab

ns.DeathClipsTabSettings = {
    ["LIVE_CLIPS"] = {
        tabId = "LIVE_CLIPS",
        tabName = "Погибшие",
        defaultSortKey = "WHEN_HAPPENED",
        defaultSortAscending = false,
        columns = {
            { id = "STREAMER", headerText = "Имя", visible = true, baseWidth = 90, sortKey = "streamer", fontStringName = "Name" },
            { id = "LEVEL", headerText = "Level", visible = true, baseWidth = 50, sortKey = "level", fontStringName = "Level" },
            { id = "WHERE_DIED", headerText = "Где умер", visible = true, baseWidth = 125, sortKey = "where", fontStringName = "WhereText" },
            { id = "CLIP_INFO", headerText = "Причина смерти", visible = true, baseWidth = 210, sortKey = "clip", fontStringName = "Clip" },
            { id = "CLASS_TYPE", headerText = "CLASS", visible = true, baseWidth = 71, sortKey = "class", fontStringName = "ClassText", fontObject = "GameFontHighlightSmall", justifyH = "RIGHT" },
            { id = "RACE_TYPE", headerText = "RACE", visible = true, baseWidth = 82, sortKey = "race", fontStringName = "RaceText", fontObject = "GameFontHighlightSmall", justifyH = "LEFT" },
            { id = "WHEN_HAPPENED", headerText = "Когда", visible = true, baseWidth = 55, sortKey = "when", fontStringName = "WhenText", dataRowXOffset = 2 },
            { id = "REACTION", headerText = "Реакция", visible = true, baseWidth = 66, sortKey = "rating", fontStringName = "Rating", dataRowXOffset = 5 }
        }
    },
    ["COMPLETED_CLIPS"] = {
        tabId = "COMPLETED_CLIPS",
        tabName = "Выжившие",
        defaultSortKey = "WHEN_HAPPENED",
        defaultSortAscending = false,
        columns = {
            { id = "STREAMER", headerText = "Имя", visible = true, baseWidth = 140, sortKey = "streamer", fontStringName = "Name" },
            { id = "LEVEL", headerText = "Level", visible = false, baseWidth = 50, sortKey = "level", fontStringName = "Level" },
            { id = "CLIP_INFO", headerText = "Время прохождения", visible = true, baseWidth = 210, sortKey = "clip", fontStringName = "Clip", dataRowXOffset = -8 },
            { id = "WHERE_DIED", headerText = "Где умер", visible = false, baseWidth = 125, sortKey = "where", fontStringName = "WhereText" },
            { id = "CLASS_TYPE", headerText = "CLASS", visible = true, baseWidth = 133, sortKey = "class", fontStringName = "ClassText", fontObject = "GameFontNormal", justifyH = "CENTER", dataRowXOffset = 15 },
            { id = "RACE_TYPE", headerText = "RACE", visible = true, baseWidth = 144, sortKey = "race", fontStringName = "RaceText", fontObject = "GameFontNormal", justifyH = "CENTER", dataRowXOffset = 2 },
            { id = "WHEN_HAPPENED", headerText = "Когда", visible = true, baseWidth = 55, sortKey = "when", fontStringName = "WhenText" },
            { id = "REACTION", headerText = "Реакция", visible = true, baseWidth = 66, sortKey = "rating", fontStringName = "Rating", dataRowXOffset = 5 }
        }
    },
    ["REINCARNATED_CLIPS"] = {
        tabId = "REINCARNATED_CLIPS",
        tabName = "Восставшие",
        defaultSortKey = "WHEN_HAPPENED", -- Original death time
        defaultSortAscending = false,      -- Most recent original deaths first
        columns = {
            { id = "STREAMER", headerText = "Имя", visible = true, baseWidth = 120, sortKey = "streamer", fontStringName = "Name" },
            { id = "LEVEL", headerText = "Уровень", visible = true, baseWidth = 70, sortKey = "level", fontStringName = "Level" }, -- New Level
            { id = "OLD_LEVEL", headerText = "Бывший ур.", visible = true, baseWidth = 85, sortKey = "oldlevel", fontStringName = "OldLevelText", dataRowXOffset = 5 },
            { id = "OLD_CLASS", headerText = "Бывший класс", visible = true, baseWidth = 100, sortKey = "oldclass", fontStringName = "OldClassText", dataRowXOffset = 5 },
            { id = "CLIP_INFO", headerText = "Причина смерти", visible = true, baseWidth = 220, sortKey = "clip", fontStringName = "Clip" },
            { id = "WHERE_DIED", headerText = "Где умер", visible = false, baseWidth = 125, sortKey = "where", fontStringName = "WhereText" },
            { id = "RACE_TYPE", headerText = "RACE", visible = false, baseWidth = 82, sortKey = "race", fontStringName = "RaceText" },
            { id = "CLASS_TYPE", headerText = "CLASS", visible = false, baseWidth = 71, sortKey = "class", fontStringName = "ClassText" },
            { id = "WHEN_HAPPENED", headerText = "Когда", visible = true, baseWidth = 70, sortKey = "when", fontStringName = "WhenText", dataRowXOffset = 2 },
            { id = "REACTION", headerText = "Реакция", visible = true, baseWidth = 70, sortKey = "rating", fontStringName = "Rating", dataRowXOffset = 5 }
        }
    },
    ["SPEED_CLIPS"] = { -- Speed ranking tab for living players
        tabId = "SPEED_CLIPS",
        tabName = "Скорость",
        defaultSortKey = "LEVEL",
        defaultSortAscending = false,
        columns = {
            { id = "STREAMER", headerText = "Имя", visible = true, baseWidth = 120, sortKey = "streamer", fontStringName = "Name" },
            { id = "LEVEL", headerText = "Ур.", visible = true, baseWidth = 40, sortKey = "level", fontStringName = "Level" },
            { id = "CLIP_INFO", headerText = "Время игры", visible = true, baseWidth = 160, sortKey = "clip", fontStringName = "Clip" },
            { id = "CLASS_TYPE", headerText = "Класс", visible = true, baseWidth = 100, sortKey = "class", fontStringName = "ClassText", fontObject = "GameFontHighlightSmall", justifyH = "CENTER" },
            { id = "RACE_TYPE", headerText = "Раса", visible = true, baseWidth = 100, sortKey = "race", fontStringName = "RaceText", fontObject = "GameFontHighlightSmall", justifyH = "CENTER" },
            { id = "WHERE_DIED", headerText = "Ранг", visible = true, baseWidth = 70, sortKey = "where", fontStringName = "WhereText", justifyH = "CENTER" },
            { id = "WHEN_HAPPENED", headerText = "Статус", visible = true, baseWidth = 70, sortKey = "when", fontStringName = "WhenText" },
            { id = "REACTION", headerText = "Реакция", visible = true, baseWidth = 66, sortKey = "rating", fontStringName = "Rating", dataRowXOffset = 5 }
        }
    }
}

-- ns.isCompletedTabActive = false -- This line will be removed

local columnIdToHeaderButtonName = {
    STREAMER = "OFDeathClipsStreamerSort",
    LEVEL = "OFDeathClipsLevelSort",
    WHERE_DIED = "OFDeathClipsWhereSort",
    CLIP_INFO = "OFDeathClipsClipSort",
    CLASS_TYPE = "OFDeathClipsClassSort",
    RACE_TYPE = "OFDeathClipsRaceSort",
    WHEN_HAPPENED = "OFDeathClipsWhenSort",
    REACTION = "OFDeathClipsRatingSort",
    OLD_LEVEL = "OFDeathClipsOldLevelSort",   -- New Entry
    OLD_CLASS = "OFDeathClipsOldClassSort"    -- New Entry
}

local function UpdateDeathClipsLayout()
    local frame = OFAuctionFrameDeathClips -- Main frame for anchoring
    if not frame then return end

    local activeTabKey = ns.currentActiveTabId -- Use the new state variable
    local activeTabConfig = ns.DeathClipsTabSettings[activeTabKey]

    if not activeTabConfig or not activeTabConfig.columns then
        if ns.debug then print("Error: No tab configuration or columns found for key: " .. activeTabKey) end
        return
    end

    local previousVisibleHeaderButton = nil
    local firstVisibleHeaderXOffset = 65 -- Default X offset for the very first sort button
    local firstVisibleHeaderYOffset = -52 -- Default Y offset for the very first sort button

    -- First pass: hide all buttons to handle cases where a button might not be in the config
    for _, headerButtonName in pairs(columnIdToHeaderButtonName) do
        local button = _G[headerButtonName]
        if button then
            button:Hide()
        end
    end

    for _, columnConfig in ipairs(activeTabConfig.columns) do
        local headerButtonName = columnIdToHeaderButtonName[columnConfig.id]
        if headerButtonName then
            local button = _G[headerButtonName]
            if button then
                if columnConfig.visible then
                    button:Show()
                    button:SetText(columnConfig.headerText)
                    button:SetWidth(columnConfig.baseWidth)
                    button:ClearAllPoints()

                    if previousVisibleHeaderButton then
                        button:SetPoint("LEFT", previousVisibleHeaderButton, "RIGHT", 2, 0) -- Standard 2px gap
                    else
                        -- This is the first visible header
                        -- The problem description implies OFAuctionFrameDeathClips is the parent for anchoring.
                        -- The original anchor for OFDeathClipsStreamerSort was ("TOPLEFT", frame, "TOPLEFT", 65, -52)
                        -- We use 'frame' which is OFAuctionFrameDeathClips here.
                        button:SetPoint("TOPLEFT", frame, "TOPLEFT", firstVisibleHeaderXOffset, firstVisibleHeaderYOffset)
                    end
                    previousVisibleHeaderButton = button
                else
                    button:Hide() -- Ensure button is hidden if not visible, even if it was shown by default
                end
            elseif ns.debug then
                print("Warning: Header button not found: " .. headerButtonName)
            end
        elseif ns.debug then
            print("Warning: No header button mapping for column ID: " .. columnConfig.id)
        end
    end
end


-- 1) Helper: what to do when the sub-tab changes
local function OnSubTabChanged(frame, newTabId)
    OFAuctionFrameDeathClips.page = 0
    FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0)
    if OFDeathClipsScrollScrollBar then
        OFDeathClipsScrollScrollBar:SetValue(0)
    end

    ns.currentActiveTabId = newTabId -- Set the new active tab ID

    local tabConfig = ns.DeathClipsTabSettings[newTabId]
    if not tabConfig then
        if ns.debug then print("Error: OnSubTabChanged - No tab configuration found for ID: " .. newTabId) end
        return
    end

    local sortKeyString = "" -- This will be the actual sort key like "when", "clip"
    local defaultSortColumnId = tabConfig.defaultSortKey -- This is an ID like "WHEN_HAPPENED"
    local actualSortColumn = nil

    for _, columnDef in ipairs(tabConfig.columns) do
        if columnDef.id == defaultSortColumnId then
            actualSortColumn = columnDef
            break
        end
    end

    if actualSortColumn and actualSortColumn.sortKey then
        sortKeyString = actualSortColumn.sortKey
        OFAuctionFrame_SetSort("clips", sortKeyString, tabConfig.defaultSortAscending)
    else
        if ns.debug then print("Error: Default sort key ID '" .. defaultSortColumnId .. "' not found or has no sortKey string in config for tab " .. newTabId) end
        OFAuctionFrame_SetSort("clips", "when", false) -- Fallback sort
    end

    UpdateDeathClipsLayout() -- This will now use ns.currentActiveTabId internally

    for i = 1, 9 do -- Assuming NUM_CLIPS_TO_DISPLAY is 9, or use a constant if available
        if ns.ApplyClipLayout then ns.ApplyClipLayout("OFDeathClipsButton" .. i) end -- This will also use ns.currentActiveTabId internally
    end
end


-- 2) Create the two sub-tab buttons once, on first show
hooksecurefunc("OFAuctionFrameDeathClips_OnShow", function()
    local frame = OFAuctionFrameDeathClips
    if frame._hasSubtabs then return end
    frame._hasSubtabs = true

    -- Create buttons using EncounterTierTabTemplate
    local liveBtn = CreateFrame("Button", "OFDeathClipsTabLive", frame, "EncounterTierTabTemplate")
    local compBtn = CreateFrame("Button", "OFDeathClipsTabCompleted", liveBtn, "EncounterTierTabTemplate")
    local newTab1Btn = CreateFrame("Button", "OFDeathClipsTabNew1", compBtn, "EncounterTierTabTemplate")
    local newTab2Btn = CreateFrame("Button", "OFDeathClipsTabNew2", newTab1Btn, "EncounterTierTabTemplate")

    local liveConfig = ns.DeathClipsTabSettings["LIVE_CLIPS"]
    local compConfig = ns.DeathClipsTabSettings["COMPLETED_CLIPS"]
    local newTab1Config = ns.DeathClipsTabSettings["REINCARNATED_CLIPS"] -- Updated key
    local newTab2Config = ns.DeathClipsTabSettings["SPEED_CLIPS"]

    -- Size & Positioning & Text
    liveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 90, -12)
    liveBtn:SetText(liveConfig.tabName)
    liveBtn:SetSize(100, 40) -- Ensure size

    compBtn:SetPoint("LEFT", liveBtn, "RIGHT", 32, 0) -- Adjusted gap to 32
    compBtn:SetText(compConfig.tabName)
    compBtn:SetSize(100, 40) -- Ensure size

    newTab1Btn:SetPoint("LEFT", compBtn, "RIGHT", 32, 0) -- Adjusted gap to 32
    newTab1Btn:SetText(newTab1Config.tabName)
    newTab1Btn:SetSize(100, 40) -- Ensure size

    newTab2Btn:SetPoint("LEFT", newTab1Btn, "RIGHT", 32, 0) -- Adjusted gap to 32
    newTab2Btn:SetText(newTab2Config.tabName)
    newTab2Btn:SetSize(100, 40) -- Ensure size

    -- Glow properties
    liveBtn.selectedGlow:SetAlpha(0.60); compBtn.selectedGlow:SetAlpha(0.60); newTab1Btn.selectedGlow:SetAlpha(0.60); newTab2Btn.selectedGlow:SetAlpha(0.60)
    liveBtn.selectedGlow:SetVertexColor(0.78, 0.35, 0.33); compBtn.selectedGlow:SetVertexColor(0.5, 0.7, 0.5)
    newTab1Btn.selectedGlow:SetVertexColor(0.5, 0.5, 0.7); newTab2Btn.selectedGlow:SetVertexColor(1.0, 0.84, 0.0)
    liveBtn.selectedGlow:SetHeight(10); compBtn.selectedGlow:SetHeight(10); newTab1Btn.selectedGlow:SetHeight(10); newTab2Btn.selectedGlow:SetHeight(10)

    -- Style toggle
    local function updateTabStyles()
        liveBtn.selectedGlow:Hide(); compBtn.selectedGlow:Hide(); newTab1Btn.selectedGlow:Hide(); newTab2Btn.selectedGlow:Hide()

        liveBtn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        compBtn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        newTab1Btn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        newTab2Btn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())

        if frame.currentSubTab == liveConfig.tabId then
            liveBtn.selectedGlow:Show()
            liveBtn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        elseif frame.currentSubTab == compConfig.tabId then
            compBtn.selectedGlow:Show()
            compBtn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        elseif frame.currentSubTab == newTab1Config.tabId then -- newTab1Config now refers to REINCARNATED_CLIPS
            newTab1Btn.selectedGlow:Show()
            newTab1Btn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        elseif frame.currentSubTab == newTab2Config.tabId then -- This is SPEED_CLIPS
            newTab2Btn.selectedGlow:Show()
            newTab2Btn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        end
    end

    -- OnClick Handlers
    liveBtn:SetScript("OnClick", function()
        if frame.currentSubTab ~= liveConfig.tabId then
            frame.currentSubTab = liveConfig.tabId; updateTabStyles()
            OnSubTabChanged(frame, liveConfig.tabId); OFAuctionFrameDeathClips_Update()
        end
    end)
    compBtn:SetScript("OnClick", function()
        if frame.currentSubTab ~= compConfig.tabId then
            frame.currentSubTab = compConfig.tabId; updateTabStyles()
            OnSubTabChanged(frame, compConfig.tabId); OFAuctionFrameDeathClips_Update()
        end
    end)
    newTab1Btn:SetScript("OnClick", function()
        if frame.currentSubTab ~= newTab1Config.tabId then
            frame.currentSubTab = newTab1Config.tabId; updateTabStyles()
            OnSubTabChanged(frame, newTab1Config.tabId); OFAuctionFrameDeathClips_Update()
        end
    end)
    newTab2Btn:SetScript("OnClick", function()
        if frame.currentSubTab ~= newTab2Config.tabId then
            frame.currentSubTab = newTab2Config.tabId; updateTabStyles()
            OnSubTabChanged(frame, newTab2Config.tabId); OFAuctionFrameDeathClips_Update()
        end
    end)

    -- Initialize
    frame.currentSubTab = ns.currentActiveTabId -- Initialize with the default active tab ID
    updateTabStyles()
    OnSubTabChanged(frame, ns.currentActiveTabId) -- Call with the current active tab ID
end)
