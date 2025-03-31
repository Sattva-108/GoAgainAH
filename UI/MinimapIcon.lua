local addonName, ns = ...

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
if not ldb then return end

local plugin = ldb:NewDataObject(addonName, {
    type = "data source",
    text = "0",
    icon = "Interface\\AddOns\\"..addonName.."\\Media\\icon_of_64px.png",
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
    tt:AddLine("OnlyFangs AH")
    local grey = "808080"
    local me = UnitName("player")

    local pendingAuctions = ns.GetMyPendingAuctions({})
    local pendingReviewCount = ns.AuctionHouseAPI:GetPendingReviewCount()
    local ratingAvg, ratingCount = ns.AuctionHouseAPI:GetAverageRatingForUser(me)
    local ratingText = string.format("%.1f stars", ratingAvg)
    if ratingCount == 0 then
        ratingText = "N/A"
    end

    tt:AddLine(wrapColor("Left-click: ", grey) .. "Open Guild AH")
    tt:AddLine(wrapColor("Pending Orders: ", grey) .. #pendingAuctions)
    tt:AddLine(wrapColor("Pending Reviews: ", grey) .. pendingReviewCount)
    tt:AddLine(wrapColor("Review Rating: ", grey) .. ratingText)
    tt:AddLine(wrapColor("Addon version: ", grey) .. GetAddOnMetadata(addonName, "Version"))
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then return end
    icon:Register(addonName, plugin, {})
end)
f:RegisterEvent("PLAYER_LOGIN")
