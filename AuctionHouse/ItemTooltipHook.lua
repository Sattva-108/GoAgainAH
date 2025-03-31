local _, ns = ...

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

    local headerShown = false
    if OFAuctionFrame:IsShown() and OFAuctionFrameAuctions:IsShown() then
        tooltip:AddLine("|cffff4040<OnlyFangs AH>|r")
        tooltip:AddLine("right-click: use item")
        tooltip:AddLine("shift+right-click: auction item")
        headerShown = true
    end
    local isShiftPressed = IsShiftKeyDown()

    local max = 5
    if count >= 1 then
        if headerShown then
            tooltip:AddLine("|cffffff00Needed By:|r")
        else
            tooltip:AddLine("|cffff4040<OnlyFangs AH>|r |cffffff00Needed By:|r")
        end
        local i = 0
        for _, a in pairs(auctions) do
            i = i + 1
            if i < max or count == max or isShiftPressed then
                local moneyString
                if a.deathRoll then
                    moneyString = "Death Roll"
                elseif a.duel then
                    moneyString = "Duel (Normal)"
                elseif a.priceType == ns.PRICE_TYPE_TWITCH_RAID then
                    moneyString = string.format("Twitch Raid %d+", a.raidAmount)
                elseif a.priceType == ns.PRICE_TYPE_CUSTOM then
                    moneyString = "Custom"
                else
                    moneyString = ns.GetMoneyString(a.price)
                end
                tooltip:AddLine("  " .. ns.GetDisplayName(a.owner) .. " x" .. a.quantity .. " for " .. moneyString)
            else
                local extra = count - max + 1
                tooltip:AddLine("  |cffbbbbbb+ " .. tostring(extra) .. " more (hold shift)|r")
                break
            end
        end
        --Repaint tooltip with newly added lines
        tooltip:Show()
    end

end)
