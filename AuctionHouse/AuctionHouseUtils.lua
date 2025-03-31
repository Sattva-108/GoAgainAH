local _, ns = ...

local _SCANNER = "Athene_ScannerTooltip"
local Scanner = _G[_SCANNER] or CreateFrame("GameTooltip", _SCANNER, UIParent, "GameTooltipTemplate")

local GetContainerNumSlots = C_Container and _G.C_Container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetContainerItemLink = C_Container and _G.C_Container.GetContainerItemLink or _G.GetContainerItemLink
local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo

local function IsItemTradeable(bag, slot)
    Scanner:ClearLines()
    Scanner:SetOwner(UIParent, "ANCHOR_NONE")
    Scanner:SetBagItem(bag, slot)

    for i = 1, Scanner:NumLines() do
        local line = _G[_SCANNER.."TextLeft"..i]
        local text = line and line:GetText()
        if text then
            -- Check various binding types
            if string.find(text, ITEM_SOULBOUND) or 
               string.find(text, ITEM_BIND_ON_PICKUP) then
                return false
            end
            if string.find(text, ITEM_BIND_QUEST) then
                return false
            end
            if string.find(text, ITEM_BIND_TO_ACCOUNT) or
               string.find(text, ITEM_BIND_TO_BNETACCOUNT) then
                return false
            end
        end
    end

    return true
end

local REALM_NAME = GetRealmName()
local REALM_NAME_SUFFIX = "-" .. REALM_NAME:gsub("%s+", "")

-- Helper function to get race icon texture
local function GetRaceIcon(raceName)
    local iconMap = {
        ["Tauren"] = "0:16:16:32",
        ["Undead"] = "16:32:16:32",
        ["Troll"] = "32:48:16:32",
        ["Orc"] = "48:64:16:32"
    }

    if iconMap[raceName] then
        return string.format("|TInterface\\Glues\\CHARACTERCREATE\\UI-CHARACTERCREATE-RACES:16:16:0:0:64:64:%s|t", iconMap[raceName])
    end
    return nil
end


ns.IsGuildMember = function(name)
    if not _G.OnlyFangsStreamerMap then
        -- fallback to checking for online members, shouldn't happen on prod
        local data = ns.GuildRegister:GetMemberData(name)
        if data then
            return true
        end
        return false
    end

    local fullCharName = name .. REALM_NAME_SUFFIX
    local ofTwitchName = _G.OnlyFangsStreamerMap[fullCharName]
    if ofTwitchName then
        return true
    end
    return false
end

ns.GetTwitchName = function(owner)
    if not owner then
        return ""
    end

    -- for testing
    if owner == "Onefingerjoe" then
        return "jannysice"
    elseif owner == "Smorcstronk" then
        return "kratosstronk"
    elseif owner == "Pencilbow" then
        return "pencilbow9"
    elseif owner == "Flawlezzgg" then
        return "Flawlezz"
    end

    if _G.OnlyFangsStreamerMap then
        local fullCharName = owner .. REALM_NAME_SUFFIX
        local ofTwitchName = _G.OnlyFangsStreamerMap[fullCharName]
        if ofTwitchName then
            return ofTwitchName
        end
    end
    return nil
end

ns.GetDisplayName = function (name, racePosition, maxCharacters)
    local displayName
    local twitchName = ns.GetTwitchName(name)
    local race = ns.GetUserRace(name)
    local guildData = ns.GuildRegister:GetMemberData(name)

    if not twitchName then
        displayName = name
    else
        displayName = string.format("%s (%s)", name, twitchName)
    end

    if maxCharacters and maxCharacters > 3 and string.len(displayName) > maxCharacters then
        displayName = string.sub(displayName, 1, 37) .. "..."
    end
    if guildData and guildData.class then
        displayName = ns.AddClassColor(displayName, guildData.class)
    end

    local raceIcon = GetRaceIcon(race)
    if raceIcon then
        if racePosition == 'right' then
            displayName = string.format("%s %s", displayName, raceIcon)
        else
            displayName = string.format("%s %s", raceIcon, displayName)
        end
    end
    return displayName
end

ns.GetUserRace = function(owner)
    return _G.OnlyFangsRaceMap and _G.OnlyFangsRaceMap[owner .. REALM_NAME_SUFFIX]
end

-- Converts a price in copper to gold, silver, and copper components
local function GetGoldSilverCopper(price)
    local gold = math.floor(price / 10000)
    local silver = math.floor((price % 10000) / 100)
    local copper = price % 100
    return gold, silver, copper
end

-- Returns a list of {bag, slot, count} entries that sum up to the required quantity
local function FindItemsInBags(itemID, requiredCount)
    local locations = {}

    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local info = GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID then
                    if info.stackCount == requiredCount then
                        -- Found exact match, return just this location
                        return {{bag = bag, slot = slot, count = info.stackCount}}
                    end
                    table.insert(locations, {bag = bag, slot = slot, count = info.stackCount})
                end
            end
        end
    end

    return locations
end

-- Finds the first empty slot in bags and returns bag and slot number
local function FindFirstEmptySlot()
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            if not C_Container.GetContainerItemID(bag, slot) then
                return bag, slot
            end
        end
    end
    return nil
end

-- Update PrefillAuctionMail to use the new function
function PrefillAuctionMail(totalCopper, quantity, itemID, recipient, note)
    if not recipient then
        return false, "Missing recipient."
    end
    if not itemID then
        return false, "Missing itemID."
    end

    if ns.IsFakeItem(itemID) then
        -- NOTE: totalCopper is equal to quantity at this point (comes from ns.GetExpectedCopperForMail)
        --
        -- no item pickup for fake items
    else
        local locations = FindItemsInBags(itemID, quantity)

        local totalAvailable = 0
        for _, loc in ipairs(locations) do
            totalAvailable = totalAvailable + loc.count
        end
        if totalAvailable == 0 and quantity == 1 then
            return false, "Item not found in bags."
        end
        if totalAvailable < quantity then
            return false, "Not enough items found in bags."
        end

        -- Look for a single stack with exact quantity
        local exactMatch = nil
        for _, loc in ipairs(locations) do
            if loc.count == quantity then
                exactMatch = loc
                break
            end
        end

        if not exactMatch then
            return false, string.format("Please manually split stacks to get exactly %d items.", quantity)
        end

        -- Now proceed with adding items to mail
        C_Container.PickupContainerItem(exactMatch.bag, exactMatch.slot)
    end
    ClickSendMailItemButton()


    local itemName = ns.GetItemInfo(itemID)
    if not itemName then
        itemName = "Order fulfilled"
    end

    local quantityStr = quantity > 1 and string.format("x%d", quantity) or ""
    if ns.IsFakeItem(itemID) then
        quantityStr = ""
    end
    local subject = string.format("Guild Order - %s%s", itemName, quantityStr)

    MailFrameTab_OnClick(nil, 2)
    SendMailNameEditBox:SetText(recipient)
    SendMailSubjectEditBox:SetText(subject)
    MailEditBox:SetText(note)
	MailEditBox:SetFocus()

    if ns.IsFakeItem(itemID) then
        -- don't click COD, the mailbox UI will automatically handle it
    else
        SendMailCODButton:Click()
    end

    local gold, silver, copper = GetGoldSilverCopper(totalCopper)
    SendMailMoneyGold:SetText(gold)
    SendMailMoneySilver:SetText(silver)
    SendMailMoneyCopper:SetText(copper)

    SendMailMailButton_OnClick(MailFrameTab2)

    return true
end

function ClearMailFields()
    ClickSendMailItemButton()

    SendMailNameEditBox:SetText("")
    SendMailSubjectEditBox:SetText("")
    MailEditBox:SetText("")

    SendMailMoneyGold:SetText(0)
    SendMailMoneySilver:SetText(0)
    SendMailMoneyCopper:SetText(0)

    -- unclear how to clear attachments, skip implementation
end


ns.CreateCompositeFilter = function(filters)
    return function(item)
        for _, filter in ipairs(filters) do
            if not filter(item) then
                return false
            end
        end
        return true
    end
end

ns.IsDefaultBrowseParams = function(browseParams)
    local text, minLevel, maxLevel, categoryIndex = unpack(browseParams)
    return (not text or text == '') and not minLevel and not maxLevel and not categoryIndex
end

ns.BrowseParamsToItemDBArgs = function(browseParams)
    local text, minLevel, maxLevel, categoryIndex, page, faction, exactMatch = unpack(browseParams)
    return text, ns.CategoryIndexToID[categoryIndex], nil, nil, nil, minLevel, maxLevel
end

local function CreateBrowseAuctionFilters(browseParams)
    local playerName = UnitName("player")
    local filters = {
        function(item) return item.owner ~= playerName end,
        function(item) return item.status == ns.AUCTION_STATUS_ACTIVE end,
        -- remove auctions from people that I blacklisted
        function(item) return not ns.BlacklistAPI:IsBlacklisted(playerName, ns.BLACKLIST_TYPE_ORDERS, item.owner) end,
        -- remove auctions from people that blacklisted me
        function(item) return not ns.BlacklistAPI:IsBlacklisted(item.owner, ns.BLACKLIST_TYPE_ORDERS, playerName) end,
    }

    local text, minLevel, maxLevel, categoryIndex, page, faction, exactMatch, onlineOnly, auctionsOnly = unpack(browseParams)
    if text and text ~= "" then
        if exactMatch then
            table.insert(filters, function(item)
                local name = select(1, ns.GetItemInfo(item.itemID))
                return name and name:lower() == text:lower()
            end)
        else
            table.insert(filters, function(item)
                local name = select(1, ns.GetItemInfo(item.itemID))
                return name and string.find(name:lower(), text:lower(), 0, true) ~= nil
            end)
        end
    end
    if minLevel and minLevel > 0 then
        table.insert(filters, function(item)
            local table = ns.GetItemInfoTable(item.itemID)
            return table and table.level >= minLevel
        end)
    end
    if maxLevel and maxLevel > 0 then
        table.insert(filters, function(item)
            local table = ns.GetItemInfoTable(item.itemID)
            return table and table.level <= maxLevel
        end)
    end
    if categoryIndex and categoryIndex > 0 then
        table.insert(filters, function(item)
            local classID = select(6,ns.GetItemInfoInstant(item.itemID))
            return classID == ns.CategoryIndexToID[categoryIndex]
        end)
    end
    if onlineOnly then
        table.insert(filters, function(item)
            return ns.GuildRegister:IsMemberOnline(item.owner)
        end)
    end
    if auctionsOnly then
        table.insert(filters, function(item)
            return item.auctionType == ns.AUCTION_TYPE_SELL
        end)
    end
    return ns.CreateCompositeFilter(filters)
end


ns.CreateCompositeSorter = function(sorters)
    return function(l, r)
        for _, sorter in ipairs(sorters) do
            local result = sorter(l, r)
            if result ~= 0 then
                return result < 0
            end
        end
        return false
    end
end

local function CreateRatingSorter(auctions)
    local me = UnitName("player")
    local ratings = {}

    for _, auction in ipairs(auctions) do
        if not ratings[auction.owner] then
            local rating = ns.AuctionHouseAPI:GetAverageRatingForUser(auction.owner)
            ratings[auction.owner] = rating
        end
        if auction.buyer and not ratings[auction.buyer] then
            local rating = ns.AuctionHouseAPI:GetAverageRatingForUser(auction.buyer)
            ratings[auction.buyer] = rating
        end
    end

    return function(l, r)
        local lOther = l.owner ~= me and l.owner or l.buyer or ""
        local rOther = r.owner ~= me and r.owner or r.buyer or ""
        return (ratings[lOther] or 0) - (ratings[rOther] or 0)
    end
end

local function CreateAuctionSorter(auctions, sortParams)
    local statusToSortValue = {
        [ns.AUCTION_STATUS_ACTIVE] = 1,
        [ns.AUCTION_STATUS_PENDING_TRADE] = 2,
        [ns.AUCTION_STATUS_PENDING_LOAN] = 3,
        [ns.AUCTION_STATUS_SENT_COD] = 4,
        [ns.AUCTION_STATUS_SENT_LOAN] = 5
    }
    local sorters = { }
    local addSorter = function(desc, sorter)
        local sign = desc and -1 or 1
        table.insert(sorters, function(l, r) return sign * sorter(l, r) end)
    end

    for i = #sortParams, 1, -1 do
        local k = sortParams[i].column
        local desc = sortParams[i].reverse
        if k == "quantity" then
            addSorter(desc, function(l, r) return l.quantity - r.quantity end)
        elseif k == "bid" then
            addSorter(desc, function(l, r) return l.price - r.price end)
        elseif k == "name" then
            addSorter(desc, function(l, r)
                local lName, rName = (l.name or select(1, ns.GetItemInfo(l.itemID)) or ""), (r.name or select(1, ns.GetItemInfo(r.itemID)) or "")
                return lName < rName and -1 or lName > rName and 1 or 0
            end)
        elseif k == "buyer" then
            addSorter(desc, function(l, r) return (l.buyer or "") < (r.buyer or "") and -1 or (l.buyer or "") > (r.buyer or "") and 1 or 0 end)
        elseif k == "seller" then
            addSorter(desc, function(l, r) return l.owner < r.owner and -1 or l.owner > r.owner and 1 or 0 end)
        elseif k == "level" then
            addSorter(desc, function(l, r)
                return (l.level or select(4, ns.GetItemInfo(l.itemID)) or 0) - (r.level or select(4, ns.GetItemInfo(r.itemID)) or 0) end)
        elseif k == "quality" then
            addSorter(desc, function(l, r) return (l.quality or select(3, ns.GetItemInfo(l.itemID)) or 0) - (r.quality or select(3, ns.GetItemInfo(r.itemID)) or 0) end)
        elseif k == "duration" then
            addSorter(desc, function(l, r) return l.expiresAt - r.expiresAt end)
        elseif k == "status" then
            addSorter(desc, function(l, r) return (statusToSortValue[l.status] or -1) - (statusToSortValue[r.status] or -1) end)
        elseif k == "type" then
            addSorter(desc, function(l, r) return l.auctionType - r.auctionType end)
        elseif k == "delivery" then
            addSorter(desc, function(l, r) return l.deliveryType - r.deliveryType end)
        elseif k == "rating" then
            addSorter(desc, CreateRatingSorter(auctions))
        end
    end
    return ns.CreateCompositeSorter(sorters)
end


local function queryAndSort(filter, sortParams)
    local auctions = ns.AuctionHouseAPI:QueryAuctions(filter)
    if #sortParams == 0 then
        return auctions
    end

    local sorter = CreateAuctionSorter(auctions, sortParams)
    table.sort(auctions, sorter)
    return auctions
end

ns.GetBrowseAuctions = function(browseParams)
    local filter = CreateBrowseAuctionFilters(browseParams)
    local auctions = ns.AuctionHouseAPI:QueryAuctions(filter)
    return auctions
end

ns.SortAuctions = function(auctions, sortParams)
    if #sortParams == 0 then
        return auctions
    end

    local sorter = CreateAuctionSorter(auctions, sortParams)
    table.sort(auctions, sorter)
    return auctions
end

ns.GetMyActiveAuctions = function(sortParams)
    local playerName = UnitName("player")
    local filter = ns.CreateCompositeFilter({
        function(item) return item.owner == playerName end,
        function(item) return item.status == ns.AUCTION_STATUS_ACTIVE end
    })
    return queryAndSort(filter, sortParams)
end

ns.GetMyPendingAuctions = function(sortParams)
    local playerName = UnitName("player")
    local filter = ns.CreateCompositeFilter({
        function(item) return item.owner == playerName or item.buyer == playerName end,
        function(item) return item.status ~= ns.AUCTION_STATUS_ACTIVE and item.status ~= ns.AUCTION_STATUS_COMPLETED end
    })
    return queryAndSort(filter, sortParams)
end

ns.GetMyAuctions = function()
    local playerName = UnitName("player")
    local filter = function(item) return item.owner == playerName end
    return ns.AuctionHouseAPI:QueryAuctions(filter)
end

ns.GetItemInfoTable = function(itemID)
    return ns.ItemInfoToTable(ns.GetItemInfo(itemID))
end

ns.GetItemInfoInstant = function(itemID)
    if ns.IsSpellItem(itemID) then
        return ns.GetSpellItemInfoInstant(itemID)
    end
    if ns.IsFakeItem(itemID) then
        return ns.GetFakeItemInfoInstant(itemID)
    end
    return GetItemInfoInstant(itemID)
end

ns.ItemInfoToTable = function(...)
    local name, itemLink, quality, level, minLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, texture, itemSellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent = ...
    if not name then
        return nil
    end

    return {
        name = name,
        itemLink = itemLink,
        quality = quality,
        level = level,
        minLevel = minLevel,
        itemType = itemType,
        itemSubType = itemSubType,
        itemStackCount = itemStackCount,
        itemEquipLoc = itemEquipLoc,
        texture = texture,
        itemSellPrice = itemSellPrice,
        classID = classID,
        subclassID = subclassID,
        bindType = bindType,
        expacID = expacID,
        setID = setID,
        isCraftingReagent = isCraftingReagent
    }
end

ns.CanCancelAuction = function(auction)
    return auction.owner == UnitName("player") and auction.status == ns.AUCTION_STATUS_ACTIVE
end

ns.GetPrettyDurationString = function(duration)
    if duration > 86400 then
        return string.format("%dd", math.floor(duration / 86400))
    elseif duration > 3600 then
        return string.format("%dh", math.floor(duration / 3600))
    elseif duration > 60 then
        return string.format("%dm", math.floor(duration / 60))
    else
        return string.format("%ds", duration)
    end
end

ns.GetAuctionStatusDisplayString = function(auction)
    local status = auction.status
    if status == ns.AUCTION_STATUS_ACTIVE then
        return "active"
    elseif status == ns.AUCTION_STATUS_PENDING_TRADE or status == ns.AUCTION_STATUS_PENDING_LOAN then
        return "pending"
    elseif status == ns.AUCTION_STATUS_SENT_COD then
        return "sent C.O.D. mail"
    elseif status == ns.AUCTION_STATUS_SENT_LOAN then
        local now = time()
        if auction.expiresAt < now then
            return string.format("loan (expired %s)", ns.GetPrettyDurationString(now - auction.expiresAt))
        else
            return string.format("loan (%s)", ns.GetPrettyDurationString(auction.expiresAt - time()))
        end
    else
        ns.DebugLog("[DEBUG] Unknown status: " .. status)
        return "Unknown"
    end
end


local WHITE_HEADER_COLOR = "|cffffffff"
local HEADER_COLOR = "|cff808080"     -- Grey
local BODY_COLOR   = "|cffffd100"     -- Gold-ish
local RESET_COLOR  = "|r"

local function SectionHeader(text)
    return HEADER_COLOR .. text .. ": " .. RESET_COLOR
end

local function BodyText(text)
    return BODY_COLOR .. text .. RESET_COLOR
end

ns.GetAuctionStatusTooltip = function(auction)
    local header, body
    if auction.status == ns.AUCTION_STATUS_ACTIVE then
        header = "Active"
        body = "This item is currently up for auction."
    elseif auction.status == ns.AUCTION_STATUS_PENDING_TRADE or auction.status == ns.AUCTION_STATUS_PENDING_LOAN then
        header = "Pending"
        if auction.deliveryType == ns.DELIVERY_TYPE_MAIL then
            body = "Mail the item"
        elseif auction.deliveryType == ns.DELIVERY_TYPE_TRADE then
            body = "Trade the item"
        else
            body = "Trade or mail the item"
        end
    elseif auction.status == ns.AUCTION_STATUS_SENT_COD then
        header = "sent C.O.D. mail"
        body = "Wait for the mail to arrive and complete the trade."
    elseif auction.status == ns.AUCTION_STATUS_SENT_LOAN then
        header = "Loan"
        body = "Waiting for the loan to be paid and/or marked as complete."
    elseif auction.status == ns.AUCTION_STATUS_COMPLETED then
        header = "Completed"
        body = "This auction has been completed."
    else
        header = "Unknown"
        body = "Unknown status"
    end

    return WHITE_HEADER_COLOR .. header .. RESET_COLOR .. "\n" .. BodyText(body)
end

-- can the owner decline the buyer from receiving the item of the auction (before the item has been sent via mail)
ns.CanDecline = function(status)
    return status == ns.AUCTION_STATUS_PENDING_TRADE or status == ns.AUCTION_STATUS_PENDING_LOAN
end

ns.GetAuctionTypeDisplayString = function(auctionType)
    local auctionTypeLabel
    if auctionType == ns.AUCTION_TYPE_BUY then
        auctionTypeLabel = "Wishlist"
    else
        auctionTypeLabel = "Auction"
    end
    return auctionTypeLabel
end

ns.GetDeliveryTypeDisplayString = function(auction)
    local deliveryType = auction.deliveryType
    local deliveryTypeLabel
    if deliveryType == ns.DELIVERY_TYPE_MAIL then
        deliveryTypeLabel = "Mail"
    elseif deliveryType == ns.DELIVERY_TYPE_TRADE then
        deliveryTypeLabel = "Trade"
    else
        deliveryTypeLabel = ""
    end


    if auction.roleplay then
        if deliveryTypeLabel ~= "" then
            deliveryTypeLabel = deliveryTypeLabel .. " & "
        end
        deliveryTypeLabel = deliveryTypeLabel .. "RP"
    end
    return deliveryTypeLabel
end

OF_ROLEPLAY_TOOLTIP = "Requires roleplay when doing the trade. Leave a note to specify the exact requirements."
OF_DEATH_ROLL_TOOLTIP = " The winner of the deathroll gets/keeps the item(s) and gold.\n\nOne player rolls 1-1000, each consecutive rolls is between 1 and the previous roll's result (eg. /roll 1-567). First player to roll 1 loses."
OF_DUEL_TOOLTIP = "Do a normal duel (not Mak`Gora!!). The winner of the duel gets/keeps the item(s) and gold."


ns.GetDeliveryTypeTooltip = function(auction)
    local sections = {}

    local deliveryTypeLabel
    local deliveryType = auction.deliveryType
    if deliveryType == ns.DELIVERY_TYPE_MAIL then
        deliveryTypeLabel = "Item has to be delivered via mail"
    elseif deliveryType == ns.DELIVERY_TYPE_TRADE then
        deliveryTypeLabel = "Item has to be delivered via trade"
    else
        deliveryTypeLabel = "Item can be delivered via trade or mail"
    end

    -- 1. Delivery Type section
    table.insert(sections, SectionHeader("Delivery") .. BodyText(deliveryTypeLabel))
    local hasNote = auction.note and auction.note ~= ""

    -- 3. Roleplay section (if applicable)
    if auction.roleplay then
        local roleplayInfo = "Roleplay is required during the trade."
        if hasNote then
            roleplayInfo = roleplayInfo .. "\nCheck the note below for potential details."
        end
        if deliveryType == ns.DELIVERY_TYPE_MAIL or deliveryType == ns.DELIVERY_TYPE_ANY then
            roleplayInfo = roleplayInfo ..
                    "\nFor mail delivery, be creative with the mail note you send."
        end

        table.insert(sections, SectionHeader("Roleplay") .. BodyText(roleplayInfo))
    end

    -- 4. Additional Notes (if applicable)
    if hasNote then
        table.insert(sections, SectionHeader("Note") .. BodyText(auction.note))
    end

    -- Join all sections with a blank line in between
    return table.concat(sections, "\n\n")
end
