-- DeathClipsTabs.lua
local addonName, ns = ...
local L = ns.L

-- 1) Helper: what to do when the sub-tab changes
local function OnSubTabChanged(frame, newTab)
    if newTab == "completed" then
        -- pull or prepare your completed data
        -- e.g. ns.LoadCompletedDeathClips()
        --print("Switched to Completed — time to load/refresh your completed clips")
    else
        -- (optional) tear down or reset anything from completed mode
--        print("Back to Live — nothing special to do here")
    end
end

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
