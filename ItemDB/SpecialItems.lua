local addonName, ns = ...

local ICN_UNKNOWN = "Interface/icons/inv_misc_questionmark"
local ICN_GOLD = "Interface/icons/inv_misc_coin_02"

ns.ITEM_ID_GOLD = -1
ns.GOLD_ITEM_CLASS_ID = 51
ns.GOLD_ITEM_TOOLTIP = "Gold is the main currency used in World of Warcraft."
ns.ITEM_GOLD = {
    id = ns.ITEM_ID_GOLD,
    name = 'Gold',
    icon = ICN_GOLD,
    quality = 1,
    level = 0,
    equipSlot = 0,
    subclass = 0,
    class = ns.GOLD_ITEM_CLASS_ID,
    quantity = 0,
    price = 0,
    owner = "",
    expiresAt = 0,
    status = "",
    auctionType = 0,
    deliveryType = 0,
}

local ICN_FACTION_POINTS = "Interface\\Addons\\"..addonName.."\\Media\\icons\\Icn_FactionPoints.png"

ns.ITEM_ID_FACTION_POINTS = -2
ns.FACTION_POINTS_ITEM_TOOLTIP = "Each faction in OnlyFangs has points which can be spent on various rewards each week."

ns.GetGoldItemInfo = function(quantity)
    local itemName
    if quantity ~= nil and quantity > 0 then
        itemName = ns.GetMoneyString(quantity)
    else
        itemName = "Gold"
    end

    return itemName, itemName, 1, 0, 0, 0, 0, 99999999999, "", ICN_GOLD, 1, ns.GOLD_ITEM_CLASS_ID, 0, 0, 0, 0, false
end

ns.GetGoldItemInfoInstant = function()
    return ns.ITEM_ID_GOLD, "", "", "", ICN_GOLD, ns.GOLD_ITEM_CLASS_ID, 0
end

ns.IsFakeItem = function(itemID)
    return itemID and itemID <= ns.ITEM_ID_GOLD
end

local function _IsSupportedFakeItem(itemID)
    return itemID == ns.ITEM_ID_GOLD or ns.IsSpellItem(itemID)
end

ns.IsSupportedFakeItem = function(itemID)
    return itemID and ns.IsFakeItem(itemID) and _IsSupportedFakeItem(itemID)
end

ns.IsUnsupportedFakeItem = function(itemID)
    return itemID and ns.IsFakeItem(itemID) and not _IsSupportedFakeItem(itemID)
end

ns.GetFactionPointsItemInfo = function()
    return "Faction Points", nil, 1, 0, 0, 0, 0, 999999, "", ICN_FACTION_POINTS, 1, 0, 0, 0, 0, 0, false
end

ns.GetFactionPointsItemInfoInstant = function()
    return ns.ITEM_ID_FACTION_POINTS, "", "", "", ICN_FACTION_POINTS, 0, 0
end

ns.GetFakeItemInfo = function(itemID, quantity)
    if itemID == ns.ITEM_ID_GOLD then
        return ns.GetGoldItemInfo(quantity)
    end
    if itemID == ns.ITEM_ID_FACTION_POINTS then
        return ns.GetFactionPointsItemInfo()
    end
    return "Unknown Item", nil, 1, 0, 0, 0, 0, 1, "", ICN_UNKNOWN, 1, 0, 0, 0, 0, 0, false
end

ns.GetFakeItemInfoInstant = function(itemID)
    if itemID == ns.ITEM_ID_GOLD then
        return ns.GetGoldItemInfoInstant()
    end
    if itemID == ns.ITEM_ID_FACTION_POINTS then
        return ns.GetFactionPointsItemInfoInstant()
    end
    return itemID, "", "", "", ICN_UNKNOWN, 0, 0
end

ns.GetFakeItemTooltip = function(itemID)
    if itemID == ns.ITEM_ID_GOLD then
        return "Gold", ns.GOLD_ITEM_TOOLTIP
    end
    if itemID == ns.ITEM_ID_FACTION_POINTS then
        return "Faction Points", ns.FACTION_POINTS_ITEM_TOOLTIP
    end
    return "Unknown Item", "This item is not known to the addon. Update to the latest version to see this item."
end
