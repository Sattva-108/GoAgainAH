local addonName, ns = ...
local L = ns.L

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
if not ldb then return end

local plugin = ldb:NewDataObject(addonName, {
    type = "data source",
    text = "0",
    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
})

function plugin.OnClick(self, button)
    if button == "LeftButton" then
        if OFAuctionFrame:IsShown() then
            OFAuctionFrame:Hide()
        else
           ns.AuctionHouse:OpenAuctionHouse()
        end
    end
end

local function wrapColor(text, color)
    return "|cff"..color..text.."|r"
end

function plugin.OnTooltipShow(tt)
    tt:AddLine(L["GoAgain AH"])
    local grey = "808080"
    local me = UnitName("player")

    local pendingAuctions = ns.GetMyPendingAuctions({})
    local pendingReviewCount = ns.AuctionHouseAPI:GetPendingReviewCount()
    local ratingAvg, ratingCount = ns.AuctionHouseAPI:GetAverageRatingForUser(me)
    local ratingText = string.format(L["%.1f stars"], ratingAvg)
    if ratingCount == 0 then
        ratingText = L["N/A"]
    end

    tt:AddLine(wrapColor(L["Left-click: "], grey) .. L["Open Guild AH"])
    tt:AddLine(wrapColor(L["Pending Orders: "], grey) .. #pendingAuctions)
    tt:AddLine(wrapColor(L["Pending Reviews: "], grey) .. pendingReviewCount)
    tt:AddLine(wrapColor(L["Review Rating: "], grey) .. ratingText)
    tt:AddLine(wrapColor(L["Version: "], grey) .. GetAddOnMetadata(addonName, "Version"))
end

ns.GameEventHandler:On("PLAYER_LOGIN", function()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end
    icon:Register(addonName, plugin, {})
end)