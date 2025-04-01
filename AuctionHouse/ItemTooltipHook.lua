local _, ns = ...
local L = ns.L

local function boolSorter(l, r)
    local ln = l and 1 or 0
    local rn = r and 1 or 0
    return ln - rn
end

GameTooltip:HookScript("OnTooltipSetItem", function(tooltip, ...)
    local name, link = tooltip:GetItem()
    if not link then
        return

    end
    local itemID = tonumber(string.match(link, "item:(%d+)"), 10)
    local me = UnitName("player")
    local auctions = ns.AuctionHouseAPI:QueryAuctions(function (auction)
        return auction.auctionType == ns.AUCTION_TYPE_BUY and auction.itemID == itemID and auction.owner ~= me
    end)
    table.sort(auctions, ns.CreateCompositeSorter({
        function(a, b) return boolSorter(b.deathRoll, a.deathRoll) end,
        function(a, b) return boolSorter(b.duel, a.duel) end,
        function(a, b) return boolSorter(b.priceType == ns.PRICE_TYPE_CUSTOM, a.priceType == ns.PRICE_TYPE_CUSTOM) end,
        function(a, b) return boolSorter(b.priceType == ns.PRICE_TYPE_TWITCH_RAID, a.priceType == ns.PRICE_TYPE_TWITCH_RAID) end,
        function(a, b) return (b.price / b.quantity) - (a.price / a.quantity) end
    }))
    --Add the name and path of the item's texture
    local count = 0
    for k,v in pairs(auctions) do count = count + 1 end

    local function wrapColor(text, color)
        return "|cff"..color..text.."|r"
    end

    local goAgainAH = wrapColor(L["<GoAgain AH>"], "ff4040")


    local headerShown = false
    if OFAuctionFrame:IsShown() and OFAuctionFrameAuctions:IsShown() then
        tooltip:AddLine(goAgainAH)
        tooltip:AddLine(L["right-click: use item"])
        tooltip:AddLine(L["shift+right-click: auction item"])
        headerShown = true
    end
    if OFAuctionFrame:IsShown() and OFAuctionFrameBrowse:IsShown() then
        tooltip:AddLine(goAgainAH)
        tooltip:AddLine(L["shift+left-click: search for item"])
        headerShown = true
    end
    local isShiftPressed = IsShiftKeyDown()

    local max = 5
    if count >= 1 then
        local neededBy = wrapColor(L["Needed By:"],"ffff00")
        if headerShown then
            tooltip:AddLine(neededBy)
        else
            tooltip:AddLine(goAgainAH .. " " .. neededBy)
        end
        local i = 0
        for _, a in pairs(auctions) do
            i = i + 1
            if i < max or count == max or isShiftPressed then
                local moneyString
                if a.deathRoll then
                    moneyString = L["Death Roll"]
                elseif a.duel then
                    moneyString = L["Duel (Normal)"]
                elseif a.priceType == ns.PRICE_TYPE_TWITCH_RAID then
                    moneyString = string.format(L["Twitch Raid %d+"], a.raidAmount)
                elseif a.priceType == ns.PRICE_TYPE_CUSTOM then
                    moneyString = L["Custom"]
                elseif a.priceType == ns.PRICE_TYPE_GUILD_POINTS then
                    moneyString = string.format(L["%d Points"], a.points)
                else
                    moneyString = ns.GetMoneyString(a.price)
                end
                tooltip:AddLine("  " .. ns.GetDisplayName(a.owner) .. " x" .. a.quantity .. L[" for "] .. moneyString)
            else
                local extra = count - max + 1
                local line = wrapColor(string.format(L["+%d more (hold shift)"], extra), "bbbbbb")
                tooltip:AddLine("  " .. line)
                break
            end
        end
        --Repaint tooltip with newly added lines
        tooltip:Show()
    end

end)
