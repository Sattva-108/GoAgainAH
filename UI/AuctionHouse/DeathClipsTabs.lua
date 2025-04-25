-- DeathClipsTabs.lua
local addonName, ns = ...
local L = ns.L

-- 1. Create the two sub-tab buttons when the frame loads:
hooksecurefunc("OFAuctionFrameDeathClips_OnShow", function()
    local frame = OFAuctionFrameDeathClips

    local liveBtn = CreateFrame("Button", "OFDeathClipsTabLive", frame, "UIPanelButtonTemplate")

    local compBtn = CreateFrame("Button", "OFDeathClipsTabCompleted", frame, "UIPanelButtonTemplate")


    -- Simple style toggle
    function updateTabStyles()
        if frame.currentSubTab == "live" then
            liveBtn:Disable(); compBtn:Enable()
        else
            compBtn:Disable(); liveBtn:Enable()
        end
    end
    if frame._hasSubtabs then return end
    frame._hasSubtabs = true

    -- Live tab
    liveBtn:SetSize(80, 22)
    liveBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -10)
    liveBtn:SetText(L["Live"])
    liveBtn:SetScript("OnClick", function()
        frame.currentSubTab = "live"
        updateTabStyles()
        OFAuctionFrameDeathClips_Update()
    end)

    -- Completed tab
    compBtn:SetSize(80, 22)
    compBtn:SetPoint("LEFT", liveBtn, "RIGHT", 10, 0)
    compBtn:SetText(L["Completed"])
    compBtn:SetScript("OnClick", function()
        frame.currentSubTab = "completed"
        updateTabStyles()
        OFAuctionFrameDeathClips_Update()
    end)

    -- Initialize
    frame.currentSubTab = frame.currentSubTab or "live"
    updateTabStyles()
end)

-- 2. Override the data‐fetch in the main update:
hooksecurefunc("OFAuctionFrameDeathClips_Update", function()
    local frame = OFAuctionFrameDeathClips
    local clips
    if frame.currentSubTab and frame.currentSubTab == "live" then
        clips = ns.GetLiveDeathClips()
    elseif frame.currentSubTab and frame.currentSubTab == "completed" then
    print("123")
        -- your new API to pull “completed” data
        --clips = ns.GetCompletedDeathClips()  -- you’ll implement this
    end

    -- stash it so UpdateClipEntry can see which mode we’re in
    frame._displayClips = clips
end)

-- 3. Tweak each row after it’s set up:
local orig_UpdateEntry = _G["UpdateClipEntry"]
_G["UpdateClipEntry"] = function(state, i, offset, button, clip, ratings, numBatchClips, totalClips)
    local frame = OFAuctionFrameDeathClips
    -- first, let the original do its work:
    orig_UpdateEntry(state, i, offset, button, clip, ratings, numBatchClips, totalClips)

    if frame.currentSubTab == "completed" then
        -- hide the “deathCause” and “where” frames:
        _G[button:GetName().."Clip"]:Hide()
        _G[button:GetName().."Where"]:Hide()
        -- show your new fields, e.g. “completedBy” and “completedAt”:
        _G[button:GetName().."YourNewField"]:SetText( clip.completedBy )
        _G[button:GetName().."YourNewField"]:Show()
    else
        -- live mode: ensure defaults are visible
        _G[button:GetName().."Clip"]:Show()
        _G[button:GetName().."Where"]:Show()
        _G[button:GetName().."YourNewField"]:Hide()
    end
end
