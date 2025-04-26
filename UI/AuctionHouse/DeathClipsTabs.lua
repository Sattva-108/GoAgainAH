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

    if ns.isCompletedTabActive then
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
        UpdateDeathClipsLayout()  -- Re-update the layout whenever the tab switches
    else
        ns.isCompletedTabActive = false
        UpdateDeathClipsLayout()  -- Re-update the layout whenever the tab switches
    end
end

-- Hook this function to the sub-tab change logic
hooksecurefunc("OFAuctionFrameDeathClips_OnShow", function()
    -- Call to update the layout when the frame shows
    UpdateDeathClipsLayout()
end)

-- Optionally, handle other logic when the sub-tab changes.


-- 2) Create the two sub-tab buttons once, on first show
hooksecurefunc("OFAuctionFrameDeathClips_OnShow", function()
    local frame = OFAuctionFrameDeathClips
    if frame._hasSubtabs then return end
    frame._hasSubtabs = true

    local liveBtn = CreateFrame("Button", "OFDeathClipsTabLive", frame, "UIPanelButtonTemplate")
    local compBtn = CreateFrame("Button", "OFDeathClipsTabCompleted", frame, "UIPanelButtonTemplate")

    -- size & positioning
    liveBtn:SetSize(80,22)
    liveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -10)
    liveBtn:SetText(L["Live"])
    compBtn:SetSize(80,22)
    compBtn:SetPoint("LEFT", liveBtn, "RIGHT", 10, 0)
    compBtn:SetText(L["Completed"])

    -- style toggle
    local function updateTabStyles()
        if frame.currentSubTab == "live" then
            liveBtn:Disable(); compBtn:Enable()
        else
            compBtn:Disable(); liveBtn:Enable()
        end
    end

    -- 3) Hook Live button: only set state & run Update
    liveBtn:SetScript("OnClick", function()
        frame.currentSubTab = "live"
        updateTabStyles()
        OnSubTabChanged(frame, "live")
        OFAuctionFrameDeathClips_Update()
    end)

    -- 4) Hook Completed button: set state, run your logic, then Update
    compBtn:SetScript("OnClick", function()
        frame.currentSubTab = "completed"
        updateTabStyles()
        OnSubTabChanged(frame, "completed")
        OFAuctionFrameDeathClips_Update()
    end)

    -- initialize
    frame.currentSubTab = frame.currentSubTab or "live"
    updateTabStyles()
    OnSubTabChanged(frame, frame.currentSubTab)
end)
