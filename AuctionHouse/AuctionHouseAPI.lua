local addonName, ns = ...
local L = ns.L

local AuctionHouseAPI = {}
ns.AuctionHouseAPI = AuctionHouseAPI

local DB = ns.AuctionHouseDB

-- the auction is up for people to buy
ns.AUCTION_STATUS_ACTIVE = "active"
-- the auction is waiting for the owner to send out the item via mail to the buyer via C.O.D mail (or trade)
ns.AUCTION_STATUS_PENDING_TRADE = "pending_trade"
-- the auction is waiting for the owner to send out the item via mail for a loan
ns.AUCTION_STATUS_PENDING_LOAN = "pending_loan_mail"
-- the auction owner sent the item to the "buyer" but the buyer didn't pay and instead ows the owner money.
-- the buyer has 7 days to pay the loan before the buyer is declared as bankrupt.
ns.AUCTION_STATUS_SENT_LOAN = "sent_loan_mail"
-- the auction owner sent the item via C.O.D. mail to the buyer but the buyer still has to pay the money.
ns.AUCTION_STATUS_SENT_COD = "sent_cod_mail"
ns.AUCTION_STATUS_COMPLETED = "completed"

ns.REVIEW_TYPE_BUYER = "buyer"
ns.REVIEW_TYPE_SELLER = "seller"

ns.PRICE_TYPE_MONEY = 0
ns.PRICE_TYPE_TWITCH_RAID = 1
ns.PRICE_TYPE_CUSTOM = 2
ns.PRICE_TYPE_GUILD_POINTS = 3

ns.DELIVERY_TYPE_ANY = 0
ns.DELIVERY_TYPE_MAIL = 1
ns.DELIVERY_TYPE_TRADE = 2

ns.AUCTION_TYPE_SELL = 0
ns.AUCTION_TYPE_BUY = 1

ns.LOAN_RESULT_BANKRUPTCY = "bankruptcy"
ns.LOAN_RESULT_PAID = "paid"

function AuctionHouseAPI:GetSerializableState()
    -- For saved variables
    return {
        auctions = DB.auctions,
        trades = DB.trades,
        ratings = DB.ratings,
        revision = DB.revision,
        revTrades = DB.revTrades,
        revRatings = DB.revRatings,
        lastUpdateAt = DB.lastUpdateAt,
        lastRatingUpdateAt = DB.lastRatingUpdateAt,
        lastLfgUpdateAt = DB.lastLfgUpdateAt,
        lfg = DB.lfg,
        revLfg = DB.revLfg,
        blacklists = DB.blacklists,
        revBlacklists = DB.revBlacklists,
        lastBlacklistUpdateAt = DB.lastBlacklistUpdateAt,
        pendingTransactions = DB.pendingTransactions,
        revPendingTransactions = DB.revPendingTransactions,
        lastPendingTransactionUpdateAt = DB.lastPendingTransactionUpdateAt,
    }
end

function AuctionHouseAPI:Load()
    if AuctionHouseDBSaved then
        for k, v in pairs(AuctionHouseDBSaved) do
            if k ~= "listeners" then
                DB[k] = v
            end
        end
    end
    -- Ensure required tables exist
    if not DB.reviews then
        DB.reviews = {}
    end
    if not DB.trades then
        DB.trades = {}
    end
    if not DB.tradesArchive then
        DB.tradesArchive = {}
    end
    if not DB.revTrades then
        DB.revTrades = 0
    end
    -- Initialize ratings table
    if not DB.ratings then
        DB.ratings = {}
    end
    if not DB.revRatings then
        DB.revRatings = 0
    end
    -- Initialize LFG table
    if not DB.lfg then
        DB.lfg = {}
    end
    if not DB.revLfg then
        DB.revLfg = 0
    end
    if not DB.blacklists then
        DB.blacklists = {}
    end
    if not DB.revBlacklists then
        DB.revBlacklists = 0
    end
    if not DB.lastBlacklistUpdateAt then
        DB.lastBlacklistUpdateAt = 0
    end
    -- Initialize pending transactions table
    if not DB.pendingTransactions then
        DB.pendingTransactions = {}
    end
    if not DB.revPendingTransactions then
        DB.revPendingTransactions = 0
    end
    if not DB.lastPendingTransactionUpdateAt then
        DB.lastPendingTransactionUpdateAt = 0
    end

    -- After requesting other states, also request the blacklist state:
    AuctionHouseDBSaved = DB
end

function AuctionHouseAPI:Initialize(deps)
    self.broadcastAuctionUpdate = deps.broadcastAuctionUpdate
    self.broadcastTradeUpdate = deps.broadcastTradeUpdate
    self.broadcastRatingUpdate = deps.broadcastRatingUpdate
    self.broadcastLFGUpdate = deps.broadcastLFGUpdate
    self.broadcastBlacklistUpdate = deps.broadcastBlacklistUpdate
    self.broadcastPendingTransactionUpdate = deps.broadcastPendingTransactionUpdate
end

function AuctionHouseAPI:ClearPersistence()
    AuctionHouseDBSaved = nil
    AHConfigSaved = nil
    LiveDeathClips = nil
    PlayerPrefsSaved = nil
    DeathClipReviewsSaved = nil
    ns.AuctionHouseDB.revision = 0
    ns.AuctionHouseDB.revTrades = 0
    ns.AuctionHouseDB.revRatings = 0
    ns.AuctionHouseDB.revLfg = 0
    ns.AuctionHouseDB.revBlacklists = 0
    ns.AuctionHouseDB.revPendingTransactions = 0

    ns.AuctionHouseDB.auctions = {}
    ns.AuctionHouseDB.trades = {}
    ns.AuctionHouseDB.ratings = {}
    ns.AuctionHouseDB.lfg = {}
    ns.AuctionHouseDB.blacklists = {}
    ns.AuctionHouseDB.pendingTransactions = {}
    ns.AuctionHouseDB.lastUpdateAt = 0
    ns.AuctionHouseDB.lastRatingUpdateAt = 0
    ns.AuctionHouseDB.lastLfgUpdateAt = 0
    ns.AuctionHouseDB.lastBlacklistUpdateAt = 0
    ns.AuctionHouseDB.lastPendingTransactionUpdateAt = 0
end


--[[

# auction lifecycle


the seller creates the auction:
  AUCTION_STATUS_ACTIVE
  auction.owner == seller

-> the item will show in the AuctionHouse as buyable


the buyer declares interest by clicking buyout or loan:
  AUCTION_STATUS_PENDING_TRADE | AUCTION_STATUS_PENDING_LOAN
  auction.buyer == buyer

-> the item will now show in the seller's mailbox sidepanel
-> the item will no longer show in the AuctionHouse as buyable


the seller sends the mail:
  AUCTION_STATUS_SENT_COD | AUCTION_STATUS_SENT_LOAN

-> the item will no longer show in the seller's mailbox sidepanel
-> the item will arrive in ~1hr in the buyer's mailbox


the buyer pays the amount on the COD mail and receives the item:

-> the auction is 'delivered' and will be deleted


]]--

-- GetMyUnsoldAuctions()
--   Return all auctions that I own and are still in "active" or perhaps "unsold" states.
function AuctionHouseAPI:GetMyUnsoldAuctions()
    local me = UnitName("player")
    local myList = {}
    for _, auction in pairs(DB.auctions) do
        if auction.owner == me and auction.status == ns.AUCTION_STATUS_ACTIVE then
            table.insert(myList, auction)
        end
    end
    return myList
end


-- GetMyBuyPendingAuctions()
--   auctions that I tried to buy (i.e. I'm the buyer) but are still waiting for the owner to send the item
function AuctionHouseAPI:GetMyBuyPendingAuctions()
    local me = UnitName("player")
    local pending = {}
    for _, auction in pairs(DB.auctions) do
        if auction.buyer == me and (auction.status == ns.AUCTION_STATUS_PENDING_TRADE or auction.status == ns.AUCTION_STATUS_PENDING_LOAN) then
            table.insert(pending, auction)
        end
    end
    return pending
end


function AuctionHouseAPI:GetAuctionsWithOwnerAndStatus(owner, statuses)
    local results = {}
    for _, auction in pairs(DB.auctions) do
        if auction.owner == owner then
            for _, status in ipairs(statuses) do
                if auction.status == status then
                    table.insert(results, auction)
                    break
                end
            end
        end
    end
    return results
end

function AuctionHouseAPI:GetAuctionsWithBuyerAndStatus(buyer, statuses)
    local results = {}
    for _, auction in pairs(DB.auctions) do
        if auction.buyer == buyer then
            for _, status in ipairs(statuses) do
                if auction.status == status then
                    table.insert(results, auction)
                    break
                end
            end
        end
    end
    return results
end


-- GetMySellPendingAuctions()
--   auctions that I own, a buyer has indicated interest in, and I haven't sent a mail/traded yet
function AuctionHouseAPI:GetMySellPendingAuctions()
    local me = UnitName("player")
    local pending = {}
    for _, auction in pairs(DB.auctions) do
        if auction.owner == me and (auction.status == ns.AUCTION_STATUS_PENDING_TRADE or auction.status == ns.AUCTION_STATUS_PENDING_LOAN) then
            table.insert(pending, auction)
        end
    end
    return pending
end


-- GetMyTrades()
--   trades I was involved in
function AuctionHouseAPI:GetMyTrades()
    local me = UnitName("player")
    local results = {}
    for _, trade in pairs(DB.trades) do
        local auction = trade.auction
        if auction.owner == me or auction.buyer == me then
            table.insert(results, trade)
        end
    end
    return results
end

function AuctionHouseAPI:GetTrades()
    local results = {}
    for _, trade in pairs(DB.trades) do
        table.insert(results, trade)
    end
    return results
end

-- GetPendingReviewCount()
--   Return the number of trades where I still need to leave a review
function AuctionHouseAPI:GetPendingReviewCount()
    local me = UnitName("player")
    local count = 0

    for _, trade in pairs(DB.trades) do
        local auction = trade.auction
        local isAtheneFeedback = auction.buyer == "Athenegpt" and (trade.sellerText and (trade.sellerText:find("^Feedback:") or trade.sellerText:find("^I want my own AI")))

        if not isAtheneFeedback then
            -- Check if I'm the buyer and haven't left a buyer review
            if auction.buyer == me and trade.buyerRating == nil then
                    count = count + 1
            -- Check if I'm the seller and haven't left a seller review
            elseif auction.owner == me and trade.sellerRating == nil then
                count = count + 1
            end
        end
    end

    return count
end


function AuctionHouseAPI:UpdateDB(payload)
    DB.auctions[payload.auction.id] = payload.auction
    DB.lastUpdateAt = time()
    DB.revision = DB.revision + 1
end

function AuctionHouseAPI:CreateAuction(itemID, price, quantity, allowLoan, priceType, deliveryType, auctionType, roleplay, deathRoll, duel, raidAmount, points, note, overrides)
    overrides = overrides or {}
    if priceType == nil then
        priceType = ns.PRICE_TYPE_MONEY
    end
    if deliveryType == nil then
        deliveryType = ns.DELIVERY_TYPE_ANY
    end

    if not itemID then
        return nil, L["Missing itemID"]
    end
    if not quantity then
        return nil, L["Missing quantity"]
    end
    if priceType ~= ns.PRICE_TYPE_MONEY and priceType ~= ns.PRICE_TYPE_TWITCH_RAID and priceType ~= ns.PRICE_TYPE_CUSTOM and priceType ~= ns.PRICE_TYPE_GUILD_POINTS then
        return nil, L["Invalid priceType"]
    end
    if deliveryType ~= ns.DELIVERY_TYPE_ANY and deliveryType ~= ns.DELIVERY_TYPE_MAIL and deliveryType ~= ns.DELIVERY_TYPE_TRADE then
        return nil, L["Invalid deliveryType"]
    end

    local owner = UnitName("player")

    -- Create the record
    local id = ns.NewId()
    local now = time()
    local expiresAt = now + ns.GetConfig().auctionExpiry

    local auction = {
        id = id,
        owner = owner,
        itemID = itemID,
        quantity = quantity,
        price = price, -- amount of copper
        tip = 0, -- amount of copper, set by buyer
        status = ns.AUCTION_STATUS_ACTIVE,
        createdAt = now,
        expiresAt = expiresAt,
        v = 1,
        buyer = nil, -- not yet purchased
        allowLoan = allowLoan or false,
        priceType = priceType,
        deliveryType = deliveryType,
        auctionType = auctionType or ns.AUCTION_TYPE_SELL,
        wish = false,  -- this flag is set after a wishlist auction is fulfilled, which converts itself from AUCTION_TYPE_BUY into a new auction with AUCTION_TYPE_SELL
        roleplay = roleplay or false,
        deathRoll = deathRoll or false,
        duel = duel or false,
        raidAmount = raidAmount or 0,
        points = points or 0,
        completeAt = 0,
        note = note or "",
        rev = 0,
    }
    for k, v in pairs(overrides) do
        auction[k] = v
    end

    self:UpdateDB({auction = auction})
    self:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "create"})
    self.broadcastAuctionUpdate(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "create"})
    return auction
end

-- CreateTrade will create a new trade object tied to a specific auction
function AuctionHouseAPI:CreateTrade(auction)
    local trade = {
        id = "t" .. auction.id,
        auction = auction,
        buyerText = nil,
        buyerRating = nil,
        sellerText = nil,
        sellerRating = nil,
        rev = 0,
    }

    self:UpdateDBTrade({trade = trade})

    self:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "create"})
    self.broadcastTradeUpdate(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "create"})

    return trade
end

-- trade complete after seller and buyer left or rating,
-- or 24h after auction completion
function AuctionHouseAPI:IsTradeCompleted(trade)
    return (self:GetTradeTimeLeft(trade) <= 0) or (trade.sellerRating and trade.buyerRating)
end

-- time before initial review window expirs, and the review becomes public
function AuctionHouseAPI:GetTradeTimeLeft(trade)
    local reviewDeadline = trade.auction.completeAt + (24 * 60 * 60)
    return reviewDeadline - time()
end

function AuctionHouseAPI:RegisterEvent(eventName, callbackFunc)
    if not DB.listeners[eventName] then
        DB.listeners[eventName] = {}
    end
    table.insert(DB.listeners[eventName], callbackFunc)
end

function AuctionHouseAPI:FireEvent(eventName, ...)
    local callbacks = DB.listeners[eventName]
    if callbacks then
        for _, func in ipairs(callbacks) do
            -- pcall prevents one faulty listener from
            -- interrupting subsequent listeners
            local success, err = pcall(func, ...)
            if not success then
                -- You can optionally log or handle errors here
                print(ChatPrefixError() .. " Error in event handler for " .. eventName .. ": " .. err)
            end
        end
    end
end

function AuctionHouseAPI:RequestBuyAuction(auctionID, tip, overrides)
    overrides = overrides or {}

    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, L["No such auction"]
    end
    if auction.status ~= ns.AUCTION_STATUS_ACTIVE then
        return nil, L["Auction is not active"]
    end
    local buyer = overrides.buyer or UnitName("player")
    if auction.owner == buyer then
        return nil, L["Cannot buy your own auction"]
    end

    -- validation: ensure we have the money (skip validation if simulating)
    local money = overrides.money or GetMoney()
    if money < (auction.price + (tip or 0)) then
        return nil, L["Insufficient funds"]
    end

    -- update the auction data
    auction.rev = (auction.rev or 0) + 1
    auction.buyer = buyer
    auction.tip = tip or 0
    auction.status = ns.AUCTION_STATUS_PENDING_TRADE
    self:UpdateDB({auction = auction})
    self:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "buy"})
    self.broadcastAuctionUpdate(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "buy"})
    return auction
end

-- for auctions with AUCTION_TYPE_BUY (wishlist)
function AuctionHouseAPI:RequestFulfillAuction(auctionID, overrides)
    overrides = overrides or {}

    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, L["No such auction"]
    end
    if auction.status ~= ns.AUCTION_STATUS_ACTIVE then
        return nil, L["Auction is not active"]
    end

    -- Who is actually fulfilling this?
    local fulfiller = UnitName("player")

    -- The buyer is the one who originally posted the buy order (i.e., the "auction.owner").
    local buyer = overrides.buyer or auction.owner
    if fulfiller == buyer then
        return nil, L["Cannot fulfill your own buy order"]
    end

    -- Remove the original buy-order auction from the DB
    local success, errorMsg = self:DeleteAuctionInternal(auctionID)
    if not success then
        return nil, errorMsg
    end

    ------------------------------------------------------------------------
    -- 1) Create a new auction that matches what the original buyer wanted
    ------------------------------------------------------------------------
    local newAuction, createErr = self:CreateAuction(
        auction.itemID,
        auction.price,
        auction.quantity,
        auction.allowLoan or false,
        auction.priceType or ns.PRICE_TYPE_MONEY,
        auction.deliveryType or ns.DELIVERY_TYPE_ANY,
        -- The fulfiller is effectively 'selling' to the original buyer
        ns.AUCTION_TYPE_SELL,
        auction.roleplay or false,
        auction.deathRoll or false,
        auction.duel or false,
        auction.raidAmount or 0,
        auction.points or 0,
        auction.note,
        overrides.createOverrides   -- optional extra data to override
    )
    -- special flag for converted AUCTION_TYPE_BUY auctions
    newAuction.wish = true

    if not newAuction then
        return nil, createErr
    end

    ------------------------------------------------------------------------
    -- 2) Immediately have the original buyer "buy" this new auction
    --    We skip the tip here (pass tip = 0)
    ------------------------------------------------------------------------
    local purchasedAuction, buyErr = self:RequestBuyAuction(newAuction.id, 0, {
        buyer = buyer,
        money = 9999*100*100, -- so the check won't fail, the buyer ran validation when creating the auction
    })

    if not purchasedAuction then
        -- Roll back by deleting the new selling auction
        self:DeleteAuctionInternal(newAuction.id)
        return nil, buyErr
    end

    return purchasedAuction
end

function AuctionHouseAPI:RequestBuyAuctionWithLoan(auctionID, tip, overrides)
    overrides = overrides or {}
    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, L["No such auction"]
    end
    if auction.status ~= ns.AUCTION_STATUS_ACTIVE then
        return nil, L["Auction is not active"]
    end

    local buyer = overrides.buyer or UnitName("player")
    if auction.owner == buyer then
        return nil, L["Cannot buy your own auction"]
    end

    -- validation: ensure owner allows to give the item for a loan
    if not auction.allowLoan then
        return nil, L["Owner does not allow loaning the item"]
    end

    -- update the auction data
    auction.rev = (auction.rev or 0) + 1
    auction.buyer = buyer
    auction.tip = tip or 0
    auction.status = ns.AUCTION_STATUS_PENDING_LOAN

    self:UpdateDB({auction = auction})
    self:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "buy_loan"})
    self.broadcastAuctionUpdate(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "buy_loan"})
    return auction
end

function AuctionHouseAPI:UpdateAuctionStatus(auctionID, status)
    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, L["No such auction"]
    end
    if auction.status == status then
        return auction, nil
    end

    -- note: No validation. We just do it and then raise an event.
    auction.rev = (auction.rev or 0) + 1
    auction.status = status
    if status == ns.AUCTION_STATUS_SENT_LOAN then
        auction.expiresAt = time() + ns.GetConfig().loanDuration
    elseif status == ns.AUCTION_STATUS_SENT_COD then
        auction.expiresAt = time() + ns.GetConfig().auctionExpiry
    end

    self:UpdateDB({auction = auction})
    self:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "status_update"})
    self.broadcastAuctionUpdate(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "status_update"})
    return auction, nil
end

function AuctionHouseAPI:UpdateAuctionExpiry(auctionID, newExpiryTime)
    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, L["No such auction"]
    end

    auction.rev = (auction.rev or 0) + 1
    auction.expiresAt = newExpiryTime

    self:UpdateDB({auction = auction})
    -- NOTE: expiry_update source is not present when it comes in through T_AUCTION_STATE
    self:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "expiry_update"})
    self.broadcastAuctionUpdate(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "expiry_update"})
    return auction, nil
end

-- CancelAuction(auctionID)
function AuctionHouseAPI:CancelAuction(auctionID)
    local me = UnitName("player")
    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, L["Auction does not exist"]
    end
    local isOwner
    if auction.wish then
        isOwner = auction.buyer == me
    else
        isOwner = auction.owner == me
    end
    if not isOwner then
        return nil, L["You do not own this auction"]
    end

    -- check if auction is not already C.O.D.
    -- special: user can cancel the auction in case the buyer is owing money loan to "forgive" the loan
    if auction.status == ns.AUCTION_STATUS_SENT_COD then
        return nil, L["Cannot cancel auction after COD has been sent"]
    end

    local success, error = self:DeleteAuctionInternal(auctionID)
    if not success then
        return nil, error
    end

    return true, nil
end

-- only for use by the API internally. use CancelAuction for user requests
function AuctionHouseAPI:DeleteAuctionInternal(auctionID, isNetworkUpdate)
    if not auctionID then
        return nil, L["No auction ID provided"]
    end
    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, L["Auction does not exist"]
    end

    DB.auctions[auctionID] = nil
    DB.lastUpdateAt = time()
    DB.revision = DB.revision + 1

    if not isNetworkUpdate then
        self:FireEvent(ns.T_AUCTION_DELETED, auctionID)
        -- Broadcast the deletion
        self.broadcastAuctionUpdate(ns.T_AUCTION_DELETED, auctionID)
    end
    return true
end

-- CompleteAuction is called in these cases:
-- * mail: when the buyer accepts the COD mail
-- * trade: when the trade happens
function AuctionHouseAPI:CompleteAuction(auctionID, overrides)
    local auction = DB.auctions[auctionID]
    if not auction then
        return nil, nil, L["No such auction"]
    end
    if auction.status == ns.AUCTION_STATUS_COMPLETED then
        return nil, nil, L["Auction already completed"]
    end
    overrides = overrides or {}

    -- Update the auction status
    auction.rev = (auction.rev or 0) + 1
    auction.status = ns.AUCTION_STATUS_COMPLETED
    auction.completeAt = time()
    for k, v in pairs(overrides) do
        auction[k] = v
    end
    auction.expiry = auction.completeAt + ns.GetConfig().completedAuctionExpiry

    -- Update DB and fire events
    self:UpdateDB({auction = auction})
    self:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "complete"})
    self.broadcastAuctionUpdate(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "complete"})

    -- create a trade to record the auction
    local trade = self:CreateTrade(auction)

    -- delete immediately afterwards
    AuctionHouseAPI:DeleteAuctionInternal(auctionID)

    return auction, trade
end

function AuctionHouseAPI:MarkLoanComplete(auctionID, overrides)
    overrides = overrides or {}
    local auction = DB.auctions[auctionID]
    if not auction then
        return L["No such auction"]
    end
    if auction.status ~= ns.AUCTION_STATUS_SENT_LOAN then
        return L["No loan pending for this auction"]
    end
    local me = overrides["me"] or UnitName("player")
    if auction.owner ~= me then
        return L["You are not the owner of this auction"]
    end

    local _, _, err = self:CompleteAuction(auctionID, {loanResult = ns.LOAN_RESULT_PAID})
    return err
end

function AuctionHouseAPI:DeclareBankruptcy(auctionID, overrides)
    overrides = overrides or {}
    local auction = DB.auctions[auctionID]
    if not auction then
        return L["No such auction"]
    end
    if auction.status ~= ns.AUCTION_STATUS_SENT_LOAN then
        return L["No loan pending for this auction"]
    end
    local me = overrides["me"] or UnitName("player")
    if auction.buyer ~= me then
        return L["You are not the buyer of this auction"]
    end

    local _, _, err = self:CompleteAuction(auctionID, {loanResult = ns.LOAN_RESULT_BANKRUPTCY})
    return err
end

function AuctionHouseAPI:ExpireAuctions()
    local now = time()
    local deletes = {}
    local bankruptcies = {}

    for k, v in pairs(DB.auctions) do
        if v.expiresAt and v.expiresAt <= now then
            if v.status == ns.AUCTION_STATUS_SENT_LOAN then
                bankruptcies[k] = v
            else
                deletes[k] = v
            end
        end
    end

    for k, v in pairs(deletes) do
        ns.DebugLog(string.format("[DEBUG] Auction %s expired", k))
        AuctionHouseAPI:DeleteAuctionInternal(k)
    end
    for k, v in pairs(bankruptcies) do
        ns.DebugLog(string.format("[DEBUG] Auction %s expired %s is marked as bankrupt", k, v.buyer))
        AuctionHouseAPI:DeclareBankruptcy(k, {me = v.buyer})
    end
end

function AuctionHouseAPI:TrimTrades()
    -- Quick check of table size first
    local tradeCount = 0
    for _ in pairs(DB.trades) do
        tradeCount = tradeCount + 1
    end

    -- If we don't exceed 200, do nothing
    if tradeCount <= 200 then
        return
    end

    -- Only build full trades array if we need to trim
    local allTrades = {}
    for tradeId, tradeData in pairs(DB.trades) do
        table.insert(allTrades, { id = tradeId, trade = tradeData })
    end

    -- Sort by the lowest completedAt first (trades with earliest completion get trimmed first)
    table.sort(allTrades, function(a, b)
        return (a.trade.completedAt or 0) < (b.trade.completedAt or 0)
    end)

    local toRemoveCount = tradeCount - 200
    for i = 1, toRemoveCount do
        local tradeEntry = allTrades[i]
        local tradeId = tradeEntry.id
        local tradeData = tradeEntry.trade

        -- Archive known trades before broadcasting deletes
        DB.tradesArchive[tradeId] = tradeData

        -- Use the API to delete from the global DB
        self:DeleteTradeInternal(tradeId)
    end

    ns.DebugLog(string.format("[DEBUG] TrimTrades removed %d trades from the global DB.", toRemoveCount))
end


function AuctionHouseAPI:GetAllAuctions()
    local auctionList = {}
    for _, auction in pairs(DB.auctions) do
        table.insert(auctionList, auction)
    end
    return auctionList
end

function AuctionHouseAPI:QueryAuctions(filter)
    local auctionList = {}
    for _, auction in pairs(DB.auctions) do
        if filter(auction) then
            table.insert(auctionList, auction)
        end
    end
    return auctionList
end

-- Add isDebug parameter (defaults to false)
function AuctionHouseAPI:TryCompleteItemTransfer(sender, recipient, items, copper, deliveryType, isDebug)
    isDebug = isDebug or false -- Ensure boolean

    if isDebug then
        print("|cffffdd00[AH Debug] === Running TryCompleteItemTransfer (DEBUG MODE) ===|r")
        print(string.format("|cffcccccc[AH Debug] Inputs: Sender='%s', Recipient='%s', Delivery=%s, Copper=%d|r",
                sender or "NIL", recipient or "NIL", deliveryType or "NIL", copper or 0))
        print("|cffcccccc[AH Debug] Items Received:|r", (items and #items or 0), "items")
        if items and #items > 0 then
            for i, item in ipairs(items) do
                print(string.format("  - Item %d: ID=%s, Count=%s", i, tostring(item.itemID or "NIL"), tostring(item.count or "NIL")))
            end
        else
            print("  (No items provided)")
        end
    end

    -- 1. Fetch potential auctions
    local possibleStatuses = {}
    if deliveryType == ns.DELIVERY_TYPE_TRADE then
        possibleStatuses = { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN }
    elseif deliveryType == ns.DELIVERY_TYPE_MAIL then
        possibleStatuses = { ns.AUCTION_STATUS_SENT_COD, ns.AUCTION_STATUS_SENT_LOAN }
    else -- Should not happen for trade/mail, but include for completeness
        possibleStatuses = { ns.AUCTION_STATUS_PENDING_TRADE, ns.AUCTION_STATUS_PENDING_LOAN, ns.AUCTION_STATUS_SENT_COD, ns.AUCTION_STATUS_SENT_LOAN }
    end

    if isDebug then print("|cffcccccc[AH Debug] Fetching auctions for Recipient:", recipient, "with Statuses:", table.concat(possibleStatuses, ", ")) end

    local auctions = self:GetAuctionsWithBuyerAndStatus(recipient, possibleStatuses)

    if isDebug then
        print(string.format("|cffcccccc[AH Debug] Found %d potential auctions.|r", auctions and #auctions or 0))
        if auctions and #auctions > 0 then
            for i, auction in ipairs(auctions) do
                print(string.format("  - Candidate %d: ID=%s, Owner=%s, ItemID=%s, Qty=%s, Price=%d, Tip=%d, Status=%s, Delivery=%s",
                        i, auction.id or "N/A", auction.owner or "N/A", auction.itemID or "N/A", auction.quantity or "N/A",
                        auction.price or 0, auction.tip or 0, auction.status or "N/A", auction.deliveryType or "N/A"))
            end
        end
    end

    -- 2. Define helper functions (modified to include isDebug prints)
    local function isExactMatch(auction, items, copper, isDebug)
        if isDebug then print(string.format("|cffbbbbff[AH Debug] -> Checking Exact Match for Auction ID: %s", auction.id)) end

        -- Check Owner
        if auction.owner ~= sender then
            if isDebug then print("|cffffaaaa  - FAIL: Owner mismatch (AuctionOwner:", auction.owner or "nil", "!= ExpectedSender:", sender or "nil", ")") end
            return false
        end
        if isDebug then print("|cffaaaaff  - OK: Owner matches.") end

        -- Check Recipient not Owner (avoid matching self-returned mail/trades)
        if auction.owner == recipient then
            if isDebug then print("|cffffaaaa  - FAIL: Recipient is the owner (Self-trade/return scenario)") end
            return false
        end
        if isDebug then print("|cffaaaaff  - OK: Recipient is not owner.") end

        -- Check Delivery Type
        if auction.deliveryType ~= ns.DELIVERY_TYPE_ANY and auction.deliveryType ~= deliveryType then
            if isDebug then print("|cffffaaaa  - FAIL: Delivery type mismatch (AuctionDelivery:", auction.deliveryType or "nil", "!= ExpectedDelivery:", deliveryType or "nil", ")") end
            return false
        end
        if isDebug then print("|cffaaaaff  - OK: Delivery type matches.") end

        -- Check Status based on delivery type
        local statusMatch = false
        if deliveryType == ns.DELIVERY_TYPE_MAIL then
            statusMatch = (auction.status == ns.AUCTION_STATUS_SENT_COD or auction.status == ns.AUCTION_STATUS_SENT_LOAN)
        elseif deliveryType == ns.DELIVERY_TYPE_TRADE then
            statusMatch = (auction.status == ns.AUCTION_STATUS_PENDING_TRADE or auction.status == ns.AUCTION_STATUS_PENDING_LOAN)
        end
        if not statusMatch then
            if isDebug then print("|cffffaaaa  - FAIL: Status mismatch (AuctionStatus:", auction.status or "nil", "is not valid for DeliveryType:", deliveryType or "nil", ")") end
            return false
        end
        if isDebug then print("|cffaaaaff  - OK: Status matches.") end

        -- Find matching item (CRITICAL CHECK)
        local matchingItem = nil
        local itemMatch = false
        if isDebug then print("|cffaaaaff  - Checking item match...") end
        for i, item in ipairs(items) do
            local currentItemMatches = false
            local auctionItemID = auction.itemID
            local providedItemID = item.itemID
            if isDebug then print(string.format("    - Comparing Auction ItemID '%s' (Qty %s) vs Provided Item %d: ID '%s' (Count %s)",
                    tostring(auctionItemID), tostring(auction.quantity), i, tostring(providedItemID), tostring(item.count) )) end

            -- Special handling for Gold "item"
            if auctionItemID == ns.ITEM_ID_GOLD then
                currentItemMatches = (auctionItemID == providedItemID) and (auction.quantity == item.count)
                if isDebug and currentItemMatches then print("      -> Match: Gold item ID and quantity match.") end
                if isDebug and not currentItemMatches then print("      -> No Match: Gold item ID or quantity differs.") end
            else
                -- Normal item check (only ItemID needs to match for 'isExactMatch' stage, quantity doesn't matter here, only price/tip does)
                currentItemMatches = (auctionItemID == providedItemID)
                if isDebug and currentItemMatches then print("      -> Match: Item IDs match.") end
                if isDebug and not currentItemMatches then print("      -> No Match: Item IDs differ.") end
            end

            if currentItemMatches then
                matchingItem = item -- Store the item from the input 'items' list that matched
                itemMatch = true
                break -- Found a matching item in the provided list, no need to check further
            end
        end

        if not itemMatch then
            if isDebug then print("|cffffaaaa  - FAIL: No item provided in the 'items' list matched the Auction's ItemID:", auction.itemID) end
            return false
        end
        if isDebug then print("|cffaaaaff  - OK: Found matching item in provided list (ItemID:", matchingItem.itemID, ")") end

        -- Check price (ONLY if NOT a loan and NOT the Gold item itself)
        local isLoan = (auction.status == ns.AUCTION_STATUS_PENDING_LOAN or auction.status == ns.AUCTION_STATUS_SENT_LOAN)
        local isGoldItem = (auction.itemID == ns.ITEM_ID_GOLD)

        if not isLoan and not isGoldItem then
            local expectedPrice = (auction.price or 0) + (auction.tip or 0)
            if isDebug then print(string.format("|cffaaaaff  - Checking price (AuctionPrice+Tip: %d vs ProvidedCopper: %d)", expectedPrice, copper)) end
            if copper ~= expectedPrice then
                if isDebug then print("|cffffaaaa  - FAIL: Price mismatch.") end
                return false
            end
            if isDebug then print("|cffaaaaff  - OK: Price matches.") end
        else
            if isDebug then print("|cffaaaaff  - SKIPPING Price check (Loan or Gold Item)") end
        end

        -- All checks passed for Exact Match
        if isDebug then print("|cff55ff55  -> SUCCESS: Exact Match found!") end
        return true
    end

    -- NOTE: Flexible match is less strict, mainly used as a fallback. Keep its debugging simpler.
    local function isFlexibleMatch(auction, items, copper, isDebug)
        if isDebug then print(string.format("|cffbbbbff[AH Debug] -> Checking Flexible Match for Auction ID: %s", auction.id)) end

        -- Check Owner
        if auction.owner ~= sender then
            if isDebug then print("|cffffaaaa  - FAIL: Owner mismatch.") end
            return false
        end
        -- Check Recipient not Owner
        if auction.owner == recipient then
            if isDebug then print("|cffffaaaa  - FAIL: Recipient is owner.") end
            return false
        end
        -- Check Delivery Type
        if auction.deliveryType ~= ns.DELIVERY_TYPE_ANY and auction.deliveryType ~= deliveryType then
            if isDebug then print("|cffffaaaa  - FAIL: Delivery type mismatch.") end
            return false
        end

        -- Find matching item ID (no quantity/price check here for flexible)
        local itemMatch = false
        if isDebug then print("|cffaaaaff  - Checking flexible item ID match...") end
        for i, item in ipairs(items) do
            if isDebug then print(string.format("    - Comparing Auction ItemID '%s' vs Provided Item %d: ID '%s'", tostring(auction.itemID), i, tostring(item.itemID))) end
            if auction.itemID == item.itemID then
                if isDebug then print("      -> Match: Item IDs match.") end
                itemMatch = true
                break
            end
            if isDebug then print("      -> No Match.") end
        end
        if not itemMatch then
            if isDebug then print("|cffffaaaa  - FAIL: No item provided matched auction ItemID.") end
            return false
        end

        if isDebug then print("|cff55ff55  -> SUCCESS: Flexible Match found (based on Owner, Delivery, ItemID only).") end
        return true
    end

    -- 3. Try to find an exact match first
    local matchedAuction = nil
    local hasCandidates = false -- Track if *any* auction from the initial fetch was relevant

    if isDebug then print("|cffcccccc[AH Debug] --- Starting Exact Match Loop ---") end
    for i, auction in ipairs(auctions or {}) do
        hasCandidates = true -- If we are in this loop, there was at least one candidate
        if isDebug then print(string.format("|cffcccccc[AH Debug] Checking Candidate %d (ID: %s) for exact match...", i, auction.id)) end
        if isExactMatch(auction, items, copper, isDebug) then
            if isDebug then print("|cff55ff55[AH Debug] Exact Match FOUND with Auction ID:", auction.id) end
            matchedAuction = auction
            break -- Stop after first exact match
        elseif isDebug then
            print("|cffcccccc[AH Debug] Candidate %d did not exactly match.", i)
        end
    end
    if isDebug then print("|cffcccccc[AH Debug] --- Finished Exact Match Loop ---") end

    -- 4. If no exact match, try flexible matching (only if an exact wasn't found)
    if not matchedAuction then
        if isDebug then print("|cffcccccc[AH Debug] No exact match found. --- Starting Flexible Match Loop ---") end
        for i, auction in ipairs(auctions or {}) do
            if isDebug then print(string.format("|cffcccccc[AH Debug] Checking Candidate %d (ID: %s) for flexible match...", i, auction.id)) end
            if isFlexibleMatch(auction, items, copper, isDebug) then
                if isDebug then print("|cff55ff55[AH Debug] Flexible Match FOUND with Auction ID:", auction.id) end
                matchedAuction = auction
                break -- Stop after first flexible match
            elseif isDebug then
                print("|cffcccccc[AH Debug] Candidate %d did not flexibly match.", i)
            end
        end
        if isDebug then print("|cffcccccc[AH Debug] --- Finished Flexible Match Loop ---") end
    end

    -- 5. Process result
    if not matchedAuction then
        local reason = auctions and #auctions > 0 and L["No matching auction found"] or "No candidate auctions found for recipient/status"
        if isDebug then print("|cffffaaaa[AH Debug] No Match Found. HasCandidates:", tostring(hasCandidates), "Reason:", reason) end
        return false, hasCandidates, reason, nil
    end

    -- We found a match, update the auction record (or simulate in debug)
    if isDebug then
        print(string.format("|cff55ff55[AH Debug] Match Found! Auction ID: %s (Status: %s)", matchedAuction.id, matchedAuction.status))
    end

    local err, trade
    local updateStatus = nil
    if matchedAuction.status == ns.AUCTION_STATUS_PENDING_LOAN then
        updateStatus = ns.AUCTION_STATUS_SENT_LOAN
        if isDebug then print("|cffffdd00[AH Debug] --> Simulating UpdateAuctionStatus:", matchedAuction.id, "to", updateStatus) end
        if not isDebug then
            _, err = self:UpdateAuctionStatus(matchedAuction.id, updateStatus)
        end
    else
        if isDebug then print("|cffffdd00[AH Debug] --> Simulating CompleteAuction:", matchedAuction.id) end
        if not isDebug then
            _, trade, err = self:CompleteAuction(matchedAuction.id)
        end
        -- In debug, create a dummy trade object if needed for return consistency testing
        if isDebug and not err then trade = { id = matchedAuction.id .. "-debug", auction = matchedAuction } end
    end

    if err then
        if isDebug then print("|cffff0000[AH Debug] Error during simulated/actual auction update:", err) end
        return false, hasCandidates, string.format(L["failed to mark auction completed after transfer: %s"], err), nil
    end

    if isDebug then print("|cff55ff55[AH Debug] Auction update successful (or simulated). Returning success.") end
    if isDebug then print("|cffffdd00[AH Debug] === Finished TryCompleteItemTransfer (DEBUG MODE) ===|r") end
    return true, hasCandidates, nil, trade
end

-- Create a helper function similar to UpdateDB but for reviews.
function AuctionHouseAPI:UpdateDBTrade(payload)
    DB.trades[payload.trade.id] = payload.trade
    DB.lastUpdateAt = time()
    DB.revTrades = DB.revTrades + 1
end

-- add or update buyer's comment and rating on a trade object
function AuctionHouseAPI:SetBuyerReview(tradeID, data)
    local trade = DB.trades[tradeID]
    if not trade then
        return nil, L["No such trade"]
    end

    trade.buyerText = data.text
    trade.buyerRating = data.rating
    trade.rev = trade.rev + 1

    self:UpdateDBTrade({trade = trade})
    self:CreateOrUpdateRating(tradeID, trade.auction.buyer, trade.auction.owner, data.rating, nil)

    self:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "buyer_review"})
    self.broadcastTradeUpdate(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "buyer_review"})

    return trade
end

-- add or update seller's comment and rating on a trade object
function AuctionHouseAPI:SetSellerReview(tradeID, data)
    local trade = DB.trades[tradeID]
    if not trade then
        return nil, L["No such trade"]
    end

    trade.sellerText = data.text
    trade.sellerRating = data.rating
    trade.rev = trade.rev + 1

    self:UpdateDBTrade({trade = trade})
    self:CreateOrUpdateRating(tradeID, trade.auction.buyer, trade.auction.owner, nil, data.rating)

    self:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "seller_review"})
    self.broadcastTradeUpdate(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "seller_review"})

    return trade
end

-- add or update buyer's dead status on a trade object
function AuctionHouseAPI:SetBuyerDead(tradeID)
    local trade = DB.trades[tradeID]
    if not trade then
        return nil, L["No such trade"]
    end

    trade.buyerDead = true
    trade.rev = trade.rev + 1

    self:UpdateDBTrade({trade = trade})
    self:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "buyer_dead"})
    self.broadcastTradeUpdate(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "buyer_dead"})

    return trade
end

-- add or update seller's dead status on a trade object
function AuctionHouseAPI:SetSellerDead(tradeID)
    local trade = DB.trades[tradeID]
    if not trade then
        return nil, L["No such trade"]
    end

    trade.sellerDead = true
    trade.rev = trade.rev + 1

    self:UpdateDBTrade({trade = trade})
    self:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "seller_dead"})
    self.broadcastTradeUpdate(ns.T_TRADE_ADD_OR_UPDATE, {trade = trade, source = "seller_dead"})

    return trade
end

-- add or update seller's comment and rating on a trade object
function AuctionHouseAPI:DebugSetTradeCompleteAt(trade, completeAt)
    trade.auction.completeAt = completeAt

    -- dummy update to trigger UpdateDB and events
    AuctionHouseAPI:SetSellerReview(trade.id, {text = trade.sellerText, rating = trade.sellerRating})

    return trade
end

-- only for use by the API internally
function AuctionHouseAPI:DeleteTradeInternal(tradeID, isNetworkUpdate)
    if not tradeID then
        return nil, L["No trade ID provided"]
    end
    local trade = DB.trades[tradeID]
    if not trade then
        return nil, L["Trade does not exist"]
    end

    DB.trades[tradeID] = nil
    DB.lastTradeUpdateAt = time()
    DB.revTrades = DB.revTrades + 1


    if not isNetworkUpdate then
        self:FireEvent(ns.T_TRADE_DELETED, tradeID)
        -- Broadcast the deletion
        self.broadcastTradeUpdate(ns.T_TRADE_DELETED, tradeID)
    end

    return true
end

-- Function to update ratings in DB
function AuctionHouseAPI:UpdateDBRating(payload)
    local rating = payload.rating

    DB.ratings[rating.id] = rating
    DB.lastRatingUpdateAt = time()
    DB.revRatings = DB.revRatings + 1
end


function AuctionHouseAPI:CreateOrUpdateRating(tradeID, buyer, seller, buyerRating, sellerRating)
    local rating = DB.ratings[tradeID]

    if not rating then
        -- Create new rating if it doesn't exist
        rating = {
            id = tradeID,
            buyer = buyer,
            seller = seller,
            buyerRating = buyerRating,
            sellerRating = sellerRating,
            rev = 0,
        }
    else
        -- Update existing rating
        if buyerRating ~= nil then
            rating.buyerRating = buyerRating
        end
        if sellerRating ~= nil then
            rating.sellerRating = sellerRating
        end
        rating.rev = (rating.rev or 0) + 1
    end

    self:UpdateDBRating({rating = rating})
    self:FireEvent(ns.T_RATING_ADD_OR_UPDATE, {rating = rating, source = "update"})
    self.broadcastRatingUpdate(ns.T_RATING_ADD_OR_UPDATE, {rating = rating, source = "update"})

    return rating
end

function AuctionHouseAPI:DeleteRatingInternal(ratingID, isNetworkUpdate)
    if not ratingID then
        return nil, L["No rating ID provided"]
    end
    local rating = DB.ratings[ratingID]
    if not rating then
        return nil, L["Rating does not exist"]
    end

    DB.ratings[ratingID] = nil
    DB.lastRatingUpdateAt = time()
    DB.revRatings = DB.revRatings + 1

    if not isNetworkUpdate then
        self:FireEvent(ns.T_RATING_DELETED, ratingID)
        -- Broadcast the deletion
        self.broadcastRatingUpdate(ns.T_RATING_DELETED, { ratingID = ratingID })
    end

    return true
end

-- Function to get all ratings
function AuctionHouseAPI:GetAllRatings()
    local ratingList = {}
    for _, rating in pairs(DB.ratings) do
        table.insert(ratingList, rating)
    end
    return ratingList
end

function AuctionHouseAPI:GetAverageRatingForUser(userName)
    local totalRating = 0
    local ratingCount = 0
    local me = UnitName("player")

    for _, rating in pairs(DB.ratings) do
        if rating.seller == userName and rating.buyerRating then
            -- User was seller
            -- only include if I didn't blacklist this buyer
            if not ns.BlacklistAPI:IsBlacklisted(me, ns.BLACKLIST_TYPE_REVIEW, rating.buyer) then
                totalRating = totalRating + rating.buyerRating
                ratingCount = ratingCount + 1
            end

        elseif rating.buyer == userName and rating.sellerRating then
            -- User was buyer
            -- only include if I didn't blacklist this seller
            if not ns.BlacklistAPI:IsBlacklisted(me, ns.BLACKLIST_TYPE_REVIEW, rating.seller) then
                totalRating = totalRating + rating.sellerRating
                ratingCount = ratingCount + 1
            end
        end
    end

    if ratingCount == 0 then
        return 0, 0  -- Return 0 rating and 0 count if no ratings found
    end

    return totalRating / ratingCount, ratingCount
end

function AuctionHouseAPI:UpdateDBBlacklist(payload)
    DB.blacklists[payload.playerName] = {
        rev = payload.rev,
        names = payload.names
    }
    DB.lastBlacklistUpdateAt = time()
    DB.revBlacklists = (DB.revBlacklists or 0) + 1
end

function AuctionHouseAPI:AddToBlacklist(playerName, blacklistedNames)
    if not playerName then
        return nil, L["Missing player name"]
    end
    if not blacklistedNames or #blacklistedNames == 0 then
        return nil, L["No names to blacklist"]
    end

    local entry = {
        playerName = playerName,
        rev = (DB.blacklists[playerName] and DB.blacklists[playerName].rev or 0) + 1,
        names = blacklistedNames
    }

    self:UpdateDBBlacklist(entry)
    self:FireEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, entry)
    self.broadcastBlacklistUpdate(ns.T_BLACKLIST_ADD_OR_UPDATE, entry)
    return entry
end

function AuctionHouseAPI:RemoveFromBlacklist(ownerName, unblacklistName)
    if not ownerName then
        return nil, L["Missing owner name"]
    end
    if not unblacklistName then
        return nil, L["Missing name to unblacklist"]
    end

    local blacklist = DB.blacklists[ownerName]
    if not blacklist then
        return nil, L["Owner has no blacklist"]
    end

    -- Find and remove the name from the blacklist
    local found = false
    local newNames = {}
    for _, name in ipairs(blacklist.names) do
        if name ~= unblacklistName then
            table.insert(newNames, name)
        else
            found = true
        end
    end

    if not found then
        return nil, L["Name not found in blacklist"]
    end

    -- Update the blacklist with the filtered names
    local entry = {
        playerName = ownerName,
        rev = blacklist.rev + 1,
        names = newNames
    }

    self:UpdateDBBlacklist(entry)
    self:FireEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, entry)
    self.broadcastBlacklistUpdate(ns.T_BLACKLIST_ADD_OR_UPDATE, entry)
    return true
end

function AuctionHouseAPI:GetBlacklist(playerName)
    return DB.blacklists[playerName]
end

function AuctionHouseAPI:GetAllBlacklists()
    local result = {}
    for playerName, blacklist in pairs(DB.blacklists) do
        result[playerName] = blacklist
    end
    return result
end


function AuctionHouseAPI:ExtendAuction(auctionId)
    local auction = DB.auctions[auctionId]
    if not auction then
        return nil, L["No such auction"]
    end

    auction.expiresAt = time() + ns.GetConfig().auctionExpiry
    self:UpdateDB({auction = auction})
    self:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "extend"})
    self.broadcastAuctionUpdate(ns.T_AUCTION_ADD_OR_UPDATE, {auction = auction, source = "extend"})
    return auction, nil
end