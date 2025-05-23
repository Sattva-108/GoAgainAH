-- DeathClipsTabs.lua
local addonName, ns = ...
local L = ns.L

-- Create the flag in the shared namespace
ns.isCompletedTabActive = false

local function UpdateDeathClipsLayout()
    local frame = OFAuctionFrameDeathClips
    local streamerSort = _G["OFDeathClipsStreamerSort"]
    local levelSort = _G["OFDeathClipsLevelSort"]
    local clipSort = _G["OFDeathClipsClipSort"]
    local whereSort = _G["OFDeathClipsWhereSort"]
    local classSort = _G["OFDeathClipsClassSort"]
    local raceSort = _G["OFDeathClipsRaceSort"]

    --if ns.isCompletedTabActive then
    --    OFAuctionFrame_SetSort("clips", "playedTime", true)
    --else
    --    OFAuctionFrame_SetSort("clips", "when", false)
    --end

    if ns.isCompletedTabActive then
        OFDeathClipsClipSort:SetText("      Время прохождения")
        -- When completed tab is active, hide the level sort button
        levelSort:Hide()

        -- Adjust the width of StreamerSort and move ClipSort to the right
        streamerSort:SetWidth(streamerSort:GetWidth() + levelSort:GetWidth())  -- Expand StreamerSort to fill the space
        clipSort:ClearAllPoints()  -- Clear any existing anchors
        clipSort:SetPoint("LEFT", streamerSort, "RIGHT", 2, 0)  -- Position it immediately to the right of StreamerSort

        -- Hide WhereSort button
        whereSort:Hide()

        -- Get half the width of WhereSort to distribute between ClassSort and RaceSort
        local whereWidth = whereSort:GetWidth()
        local halfWhereWidth = whereWidth / 2

        -- Increase the width of ClassSort and RaceSort by half of WhereSort's width
        classSort:SetWidth(classSort:GetWidth() + halfWhereWidth)
        raceSort:SetWidth(raceSort:GetWidth() + halfWhereWidth)

        -- Re-anchor the ClassSort and RaceSort buttons to slide them to the right of ClipSort
        classSort:ClearAllPoints()
        raceSort:ClearAllPoints()
        classSort:SetPoint("LEFT", clipSort, "RIGHT", 2, 0)  -- Position it immediately to the right of ClipSort
        raceSort:SetPoint("LEFT", classSort, "RIGHT", 2, 0)   -- Position it immediately to the right of ClassSort

    else
        OFDeathClipsClipSort:SetText("       Причина смерти")
        levelSort:Show()
        streamerSort:SetWidth(90)

        -- New header order: Level -> Where -> Clip -> Class -> Race
        whereSort:Show()

        whereSort:ClearAllPoints()
        whereSort:SetPoint("LEFT", levelSort, "RIGHT", 2, 0)

        clipSort:ClearAllPoints()
        clipSort:SetPoint("LEFT", whereSort, "RIGHT", 2, 0)

        classSort:SetWidth(71)
        raceSort:SetWidth(82)

        classSort:ClearAllPoints()
        classSort:SetPoint("LEFT", clipSort, "RIGHT", 2, 0)

        raceSort:ClearAllPoints()
        raceSort:SetPoint("LEFT", classSort, "RIGHT", 2, 0)
    end
end


-- 1) Helper: what to do when the sub-tab changes
local function OnSubTabChanged(frame, newTab)

    -- Reset the page number
    OFAuctionFrameDeathClips.page = 0
    -- Always reset the scroll frame offset (important for data loading)
    FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0)
    if OFDeathClipsScrollScrollBar then
        OFDeathClipsScrollScrollBar:SetValue(0)
    end


    if newTab == "completed" then
        ns.isCompletedTabActive = true
        OFAuctionFrame_SetSort("clips", "clip", false)

        UpdateDeathClipsLayout()  -- Re-update the layout whenever the tab switches

    else
        ns.isCompletedTabActive = false
        OFAuctionFrame_SetSort("clips", "when", false)

        UpdateDeathClipsLayout()  -- Re-update the layout whenever the tab switches
    end
    -- Применить макет к каждой из 9 видимых строк (NUM_CLIPS_TO_DISPLAY = 9)
    for i = 1, 9 do
        ns.ApplyClipLayout("OFDeathClipsButton" .. i)
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
        if frame.currentSubTab == "live" then
            liveBtn.selectedGlow:Show()
            compBtn.selectedGlow:Hide()

            compBtn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            liveBtn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        else
            compBtn.selectedGlow:Show()
            liveBtn.selectedGlow:Hide()

            liveBtn:GetFontString():SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
            compBtn:GetFontString():SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        end
    end


    -- 3) Hook Live button: only set state & run Update
    liveBtn:SetScript("OnClick", function()
        if frame.currentSubTab ~= "live" then
            frame.currentSubTab = "live"
            updateTabStyles()
            ns.isCompletedTabActive = false
            OnSubTabChanged(frame, "live")
            OFAuctionFrameDeathClips_Update()
        end
    end)

    -- 4) Hook Completed button: set state, run your logic, then Update
    compBtn:SetScript("OnClick", function()
        if frame.currentSubTab ~= "completed" then
            frame.currentSubTab = "completed"
            updateTabStyles()
            ns.isCompletedTabActive = true
            OnSubTabChanged(frame, "completed")
            OFAuctionFrameDeathClips_Update()
        end
    end)

    -- initialize
    frame.currentSubTab = frame.currentSubTab or "live"
    updateTabStyles()
    OnSubTabChanged(frame, frame.currentSubTab)
end)