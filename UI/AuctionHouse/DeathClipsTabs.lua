-- DeathClipsTabs.lua
local addonName, ns = ...
local L = ns.L

-- 1) Helper: what to do when the sub-tab changes
local function OnSubTabChanged(frame, newTab)
    if newTab == "completed" then
        -- pull or prepare your completed data
        -- e.g. ns.LoadCompletedDeathClips()
        print("Switched to Completed — time to load/refresh your completed clips")
    else
        -- (optional) tear down or reset anything from completed mode
        print("Back to Live — nothing special to do here")
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

-- 5) Drive which clips get displayed; leave the “live” path as-is
hooksecurefunc("OFAuctionFrameDeathClips_Update", function()
    local frame = OFAuctionFrameDeathClips
    if frame.currentSubTab == "live" then
        frame._displayClips = ns.GetLiveDeathClips()
    else
        -- your new API to pull “completed” data; e.g.
        --frame._displayClips = ns.GetCompletedDeathClips()
    end
end)

-- after your existing hooksecurefuncs in DeathClipsTabs.lua:

hooksecurefunc("OFAuctionFrameDeathClips_Update", function()
    local frame = OFAuctionFrameDeathClips
    -- How many buttons you show per page:
    local maxButtons = 1000

    for i = 1, maxButtons do
        local btn = _G["OFDeathClipsButton"..i]
        if not (btn and btn.clip) then break end

        local name  = btn:GetName()
        local clipF = _G[name.."Clip"]
        local where = _G[name.."Where"]

        if frame.currentSubTab == "completed" then
            -- hide the two columns you don't want on the completed view:
            if clipF then clipF:Hide() end
            if where then where:Hide() end
        else
            -- on live, make sure they’re visible again:
            if clipF then clipF:Show() end
            if where then where:Show() end
        end
    end
end)


