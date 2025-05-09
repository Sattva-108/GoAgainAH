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
        OFDeathClipsClipSort:SetText("Время прохождения")
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
        OFDeathClipsClipSort:SetText("Причина смерти")
        -- If live tab is active, show the level sort button again
        levelSort:Show()

        -- Reset StreamerSort width and re-anchor ClipSort to its original position
        streamerSort:SetWidth(90)  -- Reset to original width (adjust if needed)
        clipSort:ClearAllPoints()
        clipSort:SetPoint("LEFT", levelSort, "RIGHT", 2, 0)  -- Position it immediately to the right of LevelSort

        -- Show the WhereSort button again
        whereSort:Show()

        -- Reset the width of ClassSort and RaceSort
        classSort:SetWidth(55)  -- Reset to original width (adjust if needed)
        raceSort:SetWidth(60)   -- Reset to original width (adjust if needed)

        -- Re-anchor the ClassSort and RaceSort buttons back to the right of WhereSort
        classSort:ClearAllPoints()
        raceSort:ClearAllPoints()
        classSort:SetPoint("LEFT", whereSort, "RIGHT", 2, 0)  -- Position it immediately to the right of WhereSort
        raceSort:SetPoint("LEFT", classSort, "RIGHT", 2, 0)   -- Position it immediately to the right of ClassSort
    end
end


-- 1) Helper: what to do when the sub-tab changes
local function OnSubTabChanged(frame, newTab)

    ns.updatedButtons = {}
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
    liveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 78, -12)
    liveBtn:SetText("Погибшие")

    compBtn:SetPoint("LEFT", liveBtn, "RIGHT", 18, 0)
    compBtn:SetText("Выжившие")

    ---- size & positioning
    liveBtn:SetSize(120,40)
    compBtn:SetSize(120,40)

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