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
            { id = "WHEN_HAPPENED", headerText = "Когда", visible = true, baseWidth = 55, sortKey = "when", fontStringName = "WhenText", dataRowXOffset = -10 },
            { id = "REACTION", headerText = "Реакция", visible = true, baseWidth = 66, sortKey = "rating", fontStringName = "Rating", dataRowXOffset = 5 }
        }
    },
    ["COMPLETED_CLIPS"] = {
        tabId = "COMPLETED_CLIPS",
        tabName = "Выжившие",
        defaultSortKey = "CLIP_INFO",
        defaultSortAscending = false, -- Assuming higher playedTime is "better"
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
    WHEN_HAPPENED = "OFDeathClipsWhenSort", -- Assuming this is the correct global name
    REACTION = "OFDeathClipsRatingSort"   -- Assuming this is the correct global name
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

    -- Create two buttons using EncounterTierTabTemplate
    local liveBtn = CreateFrame("Button", "OFDeathClipsTabLive", frame, "EncounterTierTabTemplate")
    local compBtn = CreateFrame("Button", "OFDeathClipsTabCompleted", liveBtn, "EncounterTierTabTemplate")

    -- size & positioning
    liveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 90, -12)
    liveBtn:SetText("Погибшие")

    compBtn:SetPoint("LEFT", liveBtn, "RIGHT", 32, 0)
    compBtn:SetText("Выжившие")

    ---- size & positioning
    liveBtn:SetSize(100,40)
    compBtn:SetSize(100,40)

    liveBtn.selectedGlow:SetAlpha(0.60)
    compBtn.selectedGlow:SetAlpha(0.60)
    liveBtn.selectedGlow:SetVertexColor(0.78, 0.35, 0.33)  -- soft red
    compBtn.selectedGlow:SetVertexColor(0.5, 0.7, 0.5)     -- soft green
    liveBtn.selectedGlow:SetHeight(10)
    compBtn.selectedGlow:SetHeight(10)


    -- style toggle
    local function updateTabStyles()
        if frame.currentSubTab == "LIVE_CLIPS" then
            liveBtn.selectedGlow:Show()
            compBtn.selectedGlow:Hide()

            compBtn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            liveBtn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        else -- Assuming "COMPLETED_CLIPS"
            compBtn.selectedGlow:Show()
            liveBtn.selectedGlow:Hide()

            liveBtn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            compBtn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        end
    end


    -- 3) Hook Live button: only set state & run Update
    liveBtn:SetScript("OnClick", function()
        if frame.currentSubTab ~= "LIVE_CLIPS" then
            frame.currentSubTab = "LIVE_CLIPS"
            updateTabStyles()
            -- ns.isCompletedTabActive = false -- Remove this
            OnSubTabChanged(frame, "LIVE_CLIPS")
            OFAuctionFrameDeathClips_Update()
        end
    end)

    -- 4) Hook Completed button: set state, run your logic, then Update
    compBtn:SetScript("OnClick", function()
        if frame.currentSubTab ~= "COMPLETED_CLIPS" then
            frame.currentSubTab = "COMPLETED_CLIPS"
            updateTabStyles()
            -- ns.isCompletedTabActive = true -- Remove this
            OnSubTabChanged(frame, "COMPLETED_CLIPS")
            OFAuctionFrameDeathClips_Update()
        end
    end)

    -- initialize
    frame.currentSubTab = ns.currentActiveTabId -- Initialize with the default active tab ID
    updateTabStyles()
    OnSubTabChanged(frame, ns.currentActiveTabId) -- Call with the current active tab ID
end)