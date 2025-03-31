local addonName, ns = ...

local LibDeflate = LibStub("LibDeflate")

local AH = ns.AuctionHouse
local DB = ns.AuctionHouseDB
local API = ns.AuctionHouseAPI
local prevOnInit = AH.OnInitialize

local function assertEq(actual, expected, msg)
    assert(actual == expected, string.format("%s: expected '%s' but got '%s'", msg or "Assertion failed", tostring(expected), tostring(actual)))
end

function assertWithMessage(condition, message, errorValue)
    if errorValue then
        assert(condition, string.format("%s: %s", message, tostring(errorValue)))
    else
        assert(condition, message)
    end
end

local function RunLifecycleTest()
    local messagesSent = {}

    -- Store originals before override
    AH.SendDm = function(self, message, recipient, prio)
        table.insert(messagesSent, {message, recipient, prio})
        return true
    end

    local broadcasts = 0
    local broadcastMessages = {}
    AH.BroadcastMessage = function(self, message)
        broadcasts = broadcasts + 1
        table.insert(broadcastMessages, message)
    end

    -- Create test auction
    local itemID = 159  -- Refreshing Spring Water
    local price = 0.01
    local quantity = 2
    local allowLoan = false

    local auction, err = API:CreateAuction(itemID, price, quantity, allowLoan)
    assert(auction, "Failed to create auction: " .. (err or "unknown error"))
    assert(auction.status == ns.AUCTION_STATUS_ACTIVE, "New auction should be active")

    -- Verify broadcast was sent
    assertEq(broadcasts, 1, "Broadcast count after auction creation")
    local success, data = AH:Deserialize(broadcastMessages[1])
    assert(success, "Failed to deserialize broadcast message")
    assertEq(data[1], ns.T_AUCTION_ADD_OR_UPDATE, "Broadcast message type")
    assertEq(data[2].auction.id, auction.id, "Broadcast auction ID")
    assertEq(data[2].auction.itemID, itemID, "Broadcast item ID")
    assertEq(data[2].auction.price, price, "Broadcast price")
    print("[OK] Verified auction creation broadcast")

    -- Verify it appears in my unsold auctions
    local unsoldAuctions = API:GetMyUnsoldAuctions()
    local found = false
    for _, a in pairs(unsoldAuctions) do
        if a.id == auction.id then
            found = true
            break
        end
    end
    assert(found, "Auction should appear in my unsold auctions")

    -- Update status to pending
    local prevBroadcasts = broadcasts
    local updated = API:UpdateAuctionStatus(auction.id, ns.AUCTION_STATUS_PENDING_TRADE)

    -- Verify status update broadcast
    assertEq(broadcasts, prevBroadcasts + 1, "Broadcast count after status update")
    success, data = AH:Deserialize(broadcastMessages[#broadcastMessages])
    assert(success, "Failed to deserialize status update broadcast")
    assertEq(data[1], ns.T_AUCTION_ADD_OR_UPDATE, "Status update message type")
    assertEq(data[2].auction.id, auction.id, "Status update auction ID")
    assertEq(data[2].auction.status, ns.AUCTION_STATUS_PENDING_TRADE, "Status update auction status")
    print("[OK] Verified status update broadcast")

    -- Verify it appears in pending lists
    local pendingSells = API:GetMySellPendingAuctions()
    found = false
    for _, a in pairs(pendingSells) do
        if a.id == auction.id then
            found = true
            break
        end
    end

    local auctionId = auction.id
    assert(found, "Auction should appear in pending sells")

    -- Try to cancel pending auction (should succeed now)
    prevBroadcasts = broadcasts
    local success, cancelErr = API:CancelAuction(auctionId)
    assertWithMessage(success, "Should be able to cancel pending auction", cancelErr)

    -- Verify deletion broadcast
    success, data = AH:Deserialize(broadcastMessages[#broadcastMessages])
    assert(success, "Failed to deserialize deletion broadcast")
    assertEq(data[1], ns.T_AUCTION_DELETED, "Deletion message type")
    assertEq(data[2], auction.id, "Deletion auction ID")
    assertEq(broadcasts, prevBroadcasts + 1, "Broadcast count after deletion")

    assert(not DB.auctions[auction.id], "Auction should be deleted")
    print("[OK] Successfully deleted test auction")
end

local function RunExpirationTest()
    local broadcasts = 0
    local broadcastMessages = {}

    -- Store original before override
    AH.BroadcastMessage = function(self, message)
        broadcasts = broadcasts + 1
        table.insert(broadcastMessages, message)
    end

    -- Create auction that expires immediately (expires at current time)
    local now = time()
    local itemID = 159
    local auction = API:CreateAuction(itemID, 0.01, 1, false)
    auction.owner = "Owner"
    assert(auction, "Failed to create test auction")
    assertEq(broadcasts, 1, "Broadcast count after create")

    API:UpdateAuctionExpiry(auction.id, now)  -- Set expiry using new method
    assertEq(broadcasts, 2, "Broadcast count after create")
    local auctionId = auction.id

    -- Verify initial state
    assertEq(auction.status, ns.AUCTION_STATUS_ACTIVE)
    assert(auction.expiresAt <= now, "Auction should be set to expire immediately")

    -- Run expiration check
    API:ExpireAuctions()

    -- Verify auction was deleted
    assert(not DB.auctions[auctionId], "Expired auction should be deleted")
    assertEq(broadcasts, 3, "Broadcast count after expiration")

    -- Verify deletion broadcast
    local success, data = AH:Deserialize(broadcastMessages[#broadcastMessages])
    assert(success, "Failed to deserialize deletion broadcast")
    assertEq(data[1], ns.T_AUCTION_DELETED, "Should broadcast deletion")
    assertEq(data[2], auctionId, "Should broadcast deleted auction ID")

    -- Create a future auction to verify it doesn't expire
    local futureAuction = API:CreateAuction(itemID, 0.01, 1, false)
    local futureId = futureAuction.id

    -- Run expiration check again
    API:ExpireAuctions()

    -- Verify future auction remains
    assert(DB.auctions[futureId], "Future auction should not be expired")
    assertEq(DB.auctions[futureId].status, ns.AUCTION_STATUS_ACTIVE, "Future auction should remain active")

    print("[OK] RunExpirationTest")
end

local function RunErrorCasesTest()
    -- obsolete - AuctionHouse UI takes care of it
    -- -- Test insufficient quantity
    -- local auction, err = API:CreateAuction(159, 0.01, 1, false)
    -- assert(not auction, "Should fail with insufficient quantity")
    -- assertEq(err, "Insufficient quantity of that item in inventory.")

    -- Test invalid auction cancellation
    local success, err = API:CancelAuction("nonexistent-id")
    assert(not success, "Should fail to cancel nonexistent auction")
    assertEq(err, "Auction does not exist")

    -- Test canceling someone else's auction
    local auction = API:CreateAuction(159, 0.01, 1, false)
    auction.owner = "Owner"
    auction.owner = "SomeoneElse"
    success, err = API:CancelAuction(auction.id)
    assert(not success, "Should fail to cancel other's auction")
    assertEq(err, "You do not own this auction")

    print("[OK] RunErrorCasesTest")
end

local function RunInvalidInputTest()
    -- Test nil values
    local auction, err = API:CreateAuction(nil, 1, 1, false)
    assert(not auction, "Should fail with nil itemID")

    -- Test invalid status update
    local success, err = API:UpdateAuctionStatus("nonexistent", "invalid_status")
    assert(not success, "Should fail with invalid status")

    -- Test nil broadcaster
    DB.broadcaster = nil
    local auction = API:CreateAuction(159, 0.01, 1, false)
    auction.owner = "Owner"
    assert(auction, "Should create auction even without broadcaster")

    print("[OK] RunInvalidInputTest")
end

local function RunStateManagementTest()
    -- Test GetSerializableState
    local state = API:GetSerializableState()
    assert(state.auctions, "Serializable state should include auctions")
    assert(state.trades, "Serializable state should include trades")
    assert(type(state.revision) == "number", "Revision should be a number")
    assert(type(state.lastUpdateAt) == "number", "LastUpdateAt should be a number")

    -- Test revision increments
    local startingRevision = DB.revision
    local auction, err = API:CreateAuction(159, 0.01, 1, true)
    assertEq(err, nil, "Should succesfully create auction")
    assertEq(DB.revision, startingRevision + 1, "Revision should increment on create")

    API:UpdateAuctionStatus(auction.id, ns.AUCTION_STATUS_PENDING_TRADE)
    assertEq(DB.revision, startingRevision + 2, "Revision should increment on update")

    API:DeleteAuctionInternal(auction.id)
    assertEq(DB.revision, startingRevision + 3, "Revision should increment on delete")

    print("[OK] RunStateManagementTest")
end

local function RunAuctionQueriesTest()
    local me = UnitName("player")
    local otherPlayer = "OtherPlayer"

    -- Create test auctions in various states
    local active = API:CreateAuction(159, 0.01, 1, false)
    local pending = API:CreateAuction(159, 0.01, 1, false)
    API:UpdateAuctionStatus(pending.id, ns.AUCTION_STATUS_PENDING_TRADE)

    -- Create an auction "owned" by someone else
    local othersAuction = API:CreateAuction(159, 0.01, 1, false)
    othersAuction.owner = otherPlayer

    -- Create an auction where we're the buyer
    local buying = API:CreateAuction(159, 0.01, 1, false)
    buying.owner = otherPlayer
    buying.buyer = me
    buying.status = ns.AUCTION_STATUS_PENDING_TRADE

    -- Test GetMyUnsoldAuctions
    local unsold = API:GetMyUnsoldAuctions()
    local foundActive = false
    for _, a in pairs(unsold) do
        if a.id == active.id then foundActive = true end
        assert(a.status == ns.AUCTION_STATUS_ACTIVE, "Unsold auctions should be active")
        assert(a.owner == me, "Unsold auctions should be mine")
    end
    assert(foundActive, "Active auction should be in unsold list")

    -- Test GetMyBuyPendingAuctions
    local buyPending = API:GetMyBuyPendingAuctions()
    local foundBuying = false
    for _, a in pairs(buyPending) do
        if a.id == buying.id then foundBuying = true end
        assert(a.buyer == me, "Buy pending auctions should have me as buyer")
        assert(a.status == ns.AUCTION_STATUS_PENDING_TRADE, "Buy pending should be in pending state")
    end
    assert(foundBuying, "Buying auction should be in buy pending list")

    -- Test GetMySellPendingAuctions
    local sellPending = API:GetMySellPendingAuctions()
    local foundPending = false
    for _, a in pairs(sellPending) do
        if a.id == pending.id then foundPending = true end
        assert(a.owner == me, "Sell pending auctions should be mine")
        assert(a.status == ns.AUCTION_STATUS_PENDING_TRADE, "Sell pending should be in pending state")
    end
    assert(foundPending, "Pending auction should be in sell pending list")

    print("[OK] RunAuctionQueriesTest")
end

local function RunSyncTest()
    local messagesSent = {}
    local broadcastMessages = {}
    local receivedMessages = {}

    -- Mock SendDm and BroadcastMessage
    AH.SendDm = function(self, message, recipient, prio)
        table.insert(messagesSent, {message = message, recipient = recipient, prio = prio})
        return true
    end

    AH.BroadcastMessage = function(self, message)
        table.insert(broadcastMessages, message)
        return true
    end

    -- Helper to simulate receiving a message
    local function simulateReceive(statePayload, label)
        local compressed = LibDeflate:CompressDeflate(AH:Serialize(statePayload))
        local message = AH:Serialize({ ns.T_AUCTION_STATE, compressed })
        AH.ignoreSenderCheck = true
        AH:OnCommReceived(ns.COMM_PREFIX, message, "GUILD", UnitName("player"))
        table.insert(receivedMessages, {payload = statePayload, label = label})
    end

    -- Start from clean state
    API:ClearPersistence()
    API:Load()

    --------------------------------------------------
    -- Wave 1: Two auctions, both in 'active' state --
    --------------------------------------------------
    local wave1 = {
        v = 1,
        auctions = {},
        deletedAuctionIds = {},
        revision = 101,
        lastUpdateAt = time(),
    }

    local auction1 = {
        id = "auction_wave1_a",
        owner = UnitName("player"),
        itemID = 159,
        quantity = 2,
        price = 100,
        status = ns.AUCTION_STATUS_ACTIVE,
        createdAt = time(),
        expiresAt = time() + ns.GetConfig().auctionExpiry,
        allowLoan = false,
        rev = 0,
    }

    local auction2 = {
        id = "auction_wave1_b",
        owner = UnitName("player"),
        itemID = 159,
        quantity = 1,
        price = 200,
        status = ns.AUCTION_STATUS_ACTIVE,
        createdAt = time(),
        expiresAt = time() + ns.GetConfig().auctionExpiry,
        allowLoan = true,
        rev = 0,
    }

    wave1.auctions[auction1.id] = auction1
    wave1.auctions[auction2.id] = auction2

    simulateReceive(wave1, "Wave 1: Create two active auctions")
    assertEq(DB.revision, 101, "DB revision should be updated after wave 1")
    assert(DB.auctions[auction1.id], "Auction 1 should exist")
    assert(DB.auctions[auction2.id], "Auction 2 should exist")

    ---------------------------------------------------------
    -- Wave 2: Auction1 goes from 'active' -> 'pending_trade'
    ---------------------------------------------------------
    local wave2 = {
        v = 1,
        auctions = {},
        deletedAuctionIds = {},
        revision = 102,
        lastUpdateAt = time(),
    }

    auction1.status = ns.AUCTION_STATUS_PENDING_TRADE
    auction1.buyer = "Onefingerjoe"
    auction1.rev = auction1.rev + 1
    wave2.auctions[auction1.id] = auction1

    simulateReceive(wave2, "Wave 2: Auction1 is now 'pending_trade'")
    assertEq(DB.revision, 102, "DB revision should be updated after wave 2")
    assertEq(DB.auctions[auction1.id].status, ns.AUCTION_STATUS_PENDING_TRADE, "Auction 1 status should be pending_trade")
    assertEq(DB.auctions[auction1.id].buyer, "Onefingerjoe", "Auction 1 buyer should be set")

    ---------------------------------------------------------
    -- Wave 3: Auction2 goes from 'active' -> 'pending_loan'
    ---------------------------------------------------------
    local wave3 = {
        v = 1,
        auctions = {},
        deletedAuctionIds = {},
        revision = 103,
        lastUpdateAt = time(),
    }

    auction2.status = ns.AUCTION_STATUS_PENDING_LOAN
    auction2.buyer = "BuyerChris"
    auction2.rev = auction2.rev + 1

    wave3.auctions[auction1.id] = auction1
    wave3.auctions[auction2.id] = auction2

    simulateReceive(wave3, "Wave 3: Auction2 is now 'pending_loan'")
    assertEq(DB.revision, 103, "DB revision should be updated after wave 3")
    assertEq(DB.auctions[auction2.id].status, ns.AUCTION_STATUS_PENDING_LOAN, "Auction 2 status should be pending_loan")
    assertEq(DB.auctions[auction2.id].buyer, "BuyerChris", "Auction 2 buyer should be set")

    ----------------------------------------------------------
    -- Wave 5: Delete Auction2
    ----------------------------------------------------------
    local wave5 = {
        v = 1,
        auctions = {},
        deletedAuctionIds = { auction2.id },
        revision = 105,
        lastUpdateAt = time(),
    }

    simulateReceive(wave5, "Wave 5: Auction2 is deleted")
    assertEq(DB.revision, 105, "DB revision should be updated after wave 5")
    assert(not DB.auctions[auction2.id], "Auction 2 should be deleted")
    assert(DB.auctions[auction1.id], "Auction 1 should still exist")

    print("[OK] RunSyncTest")
end

local function RunAuctionStatusTest()
    local me = UnitName("player")

    -- Create test auctions with different statuses
    local pendingLoanAuction = API:CreateAuction(159, 0.01, 1, false)
    pendingLoanAuction.status = ns.AUCTION_STATUS_PENDING_LOAN

    local pendingTradeAuction = API:CreateAuction(159, 0.01, 1, false)
    pendingTradeAuction.status = ns.AUCTION_STATUS_PENDING_TRADE

    local sentLoanAuction = API:CreateAuction(159, 0.01, 1, false)
    sentLoanAuction.status = ns.AUCTION_STATUS_SENT_LOAN

    -- Create an auction owned by someone else (shouldn't appear in results)
    local otherPlayerAuction = API:CreateAuction(159, 0.01, 1, false)
    otherPlayerAuction.owner = "OtherPlayer"
    otherPlayerAuction.buyer = me
    otherPlayerAuction.status = ns.AUCTION_STATUS_PENDING_LOAN

    -- Test single status query
    local pendingLoans = API:GetAuctionsWithOwnerAndStatus(me, {ns.AUCTION_STATUS_PENDING_LOAN})
    assertEq(#pendingLoans, 1, "Should find one pending loan auction")
    assertEq(pendingLoans[1].id, pendingLoanAuction.id, "Should find correct pending loan auction")

    -- Test multiple status query
    local allPending = API:GetAuctionsWithOwnerAndStatus(me, {
        ns.AUCTION_STATUS_PENDING_LOAN,
        ns.AUCTION_STATUS_PENDING_TRADE
    })
    assertEq(#allPending, 2, "Should find both types of pending auctions")

    -- Verify other status not included
    for _, auction in ipairs(allPending) do
        assert(auction.status == ns.AUCTION_STATUS_PENDING_LOAN or auction.status == ns.AUCTION_STATUS_PENDING_TRADE,
               "Should only include requested statuses")
    end


    -- 'buyer' version
    local pendingLoansBuyerMe = API:GetAuctionsWithBuyerAndStatus(me, {ns.AUCTION_STATUS_PENDING_LOAN})
    assertEq(#pendingLoansBuyerMe, 1, "Should find one pending loan auction (me buyer)")

    assertEq(pendingLoansBuyerMe[1].id, otherPlayerAuction.id, "Should find correct pending loan auction (me buyer)")

    -- otherPlayerAuction from their perspective
    local pendingLoansOwnerOther = API:GetAuctionsWithOwnerAndStatus("OtherPlayer", {ns.AUCTION_STATUS_PENDING_LOAN})
    assertEq(#pendingLoansOwnerOther, 1, "Should find one pending loan auction (OtherPlayer owner)")

    assertEq(pendingLoansOwnerOther[1].id, otherPlayerAuction.id, "Should find correct pending loan auction (otherplayer owner)")


    -- otherPlayerAuction from their perspective
    local pendingLoansBuyerOther = API:GetAuctionsWithBuyerAndStatus("OtherPlayer", {ns.AUCTION_STATUS_PENDING_LOAN})
    assertEq(#pendingLoansBuyerOther, 0, "Should not find pending trade auction (OtherPlayer buyer)")

    local pendingLoansOwnerMe = API:GetAuctionsWithOwnerAndStatus(me, {ns.AUCTION_STATUS_PENDING_LOAN})
    assertEq(#pendingLoansOwnerMe, 1, "Should not find pending trade that OtherPlayer owns (count)")
    assertEq(pendingLoansOwnerMe[1].owner, me, "Should not find pending trade that OtherPlayer owns")


    print("[OK] RunAuctionStatusTest")
end

local originalBroadcastMessage
local originalSendDm
-- Add original WoW API function storage
local originalGetInboxHeaderInfo
local originalGetInboxItem
local originalGetInboxItemLink
local originalUnitName

local function ResetTestHooks()
    -- Restore original methods instead of setting to nil
    if originalBroadcastMessage then
        AH.BroadcastMessage = originalBroadcastMessage
    end
    if originalSendDm then
        AH.SendDm = originalSendDm
    end
    -- Restore WoW API functions
    if originalGetInboxHeaderInfo then
        GetInboxHeaderInfo = originalGetInboxHeaderInfo
    end
    if originalGetInboxItem then
        GetInboxItem = originalGetInboxItem
    end
    if originalGetInboxItemLink then
        GetInboxItemLink = originalGetInboxItemLink
    end
    if originalUnitName then
        UnitName = originalUnitName
    end
end

local function RunMailboxTest()
    -- Test setup helper
    local function setupMockMail(opts)
        GetInboxHeaderInfo = function(index)
            return
                "packageIcon",               -- packageIcon
                "stationeryIcon",            -- stationeryIcon
                opts.sender or opts.me or "TestSender", -- sender
                "Test Subject",              -- subject
                opts.money or 0,             -- money
                opts.cod or 100,             -- CODAmount
                3,                           -- daysLeft
                opts.quantity or 1,          -- quantity
                false,                       -- wasRead
                opts.returned or false,      -- wasReturned
                false,                       -- textCreated
                true                         -- canReply
        end

        GetInboxItem = function(index, itemSlot)
            return
                opts.itemName or "Test Item", -- itemName
                opts.itemID or 159,           -- itemID
                "itemTexture",                -- itemTexture
                opts.quantity or 1,           -- itemQuantity
                1,                            -- quality
                true                          -- canUse
        end

        GetInboxItemLink = function(index, itemSlot)
            return string.format("|cffffffff|Hitem:%d::::::::20:257::::::|h[%s]|h|r",
                opts.itemID or 159,
                opts.itemName or "Test Item")
        end

        UnitName = function(unit)
            return opts.me
        end
    end

    local function testExactMatch()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction that exactly matches mail
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- verify test setup
        local me = UnitName("player")
        local candidates = ns.AuctionHouseAPI:GetAuctionsWithBuyerAndStatus(
            me,
            {ns.AUCTION_STATUS_SENT_COD, ns.AUCTION_STATUS_SENT_LOAN}
        )
        assertEq(#candidates, 1, string.format("sanity check: testExactMatch auction didn't point to %s, got %s", me, auction.owner))


        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local updated = DB.auctions[auction.id]
        assert(updated, "Auction should exist")
        assertEq(updated.status, ns.AUCTION_STATUS_COMPLETED, "Exact match: Status should be COMPLETED")

        print("[TEST] testExactMatch passed")
    end

    local function testReturnedMail()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
            returned = true -- Mail was returned
        })

        -- Setup: Create auction for returned mail
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local updated = DB.auctions[auction.id]
        assert(updated, "Auction should exist")
        -- this is not a successful trade, and just a coincidence that it also showed up in GetAuctionsWithBuyerAndStatus
        -- COD auction expiry will take care of the edge-case
        assertEq(updated.status, ns.AUCTION_STATUS_SENT_COD, "Returned mail: Status should be unmodified")

        print("[TEST] testReturnedMail passed")
    end

    local function testWrongItem()
        setupMockMail({
            itemID = 160, -- Different item
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction with different item
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_SENT_COD, "Wrong item: Status should remain unchanged")

        print("[TEST] testWrongItem passed")
    end

    local function testLoanMail()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 0, -- Loan mails have 0 COD
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction that matches loan mail
        local auction = API:CreateAuction(159, 100, 2, true)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_LOAN

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local updated = DB.auctions[auction.id]
        assert(updated, "Auction should exist")
        assertEq(updated.status, ns.AUCTION_STATUS_COMPLETED, "Loan mail: Status should be COMPLETED")

        print("[TEST] testLoanMail passed")
    end

    local function testLowerQuantity()
        setupMockMail({
            itemID = 159,
            quantity = 1, -- Only taking part of the items
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction expecting more items
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_COMPLETED, "Lower quantity: Status should be COMPLETED")

        print("[TEST] testLowerQuantity passed")
    end

    local function testHigherQuantity()
        setupMockMail({
            itemID = 159,
            quantity = 3,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction expecting fewer items
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_COMPLETED, "Higher quantity: Status should be COMPLETED")

        print("[TEST] testHigherQuantity passed")
    end

    local function testMultipleMatchingAuctions()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create two auctions that could match
        local auction1 = API:CreateAuction(159, 100, 2, false)
        auction1.owner = "Owner"
        auction1.buyer = "Buyer"
        auction1.status = ns.AUCTION_STATUS_SENT_COD

        local auction2 = API:CreateAuction(159, 100, 2, false)
        auction2.owner = "Owner"
        auction2.buyer = "Buyer"
        auction2.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify only one auction was completed
        local completedCount = 0
        if DB.auctions[auction1.id].status == ns.AUCTION_STATUS_COMPLETED then
            completedCount = completedCount + 1
        end
        if DB.auctions[auction2.id].status == ns.AUCTION_STATUS_COMPLETED then
            completedCount = completedCount + 1
        end
        assertEq(completedCount, 1, "Exactly one auction should be completed")

        print("[TEST] testMultipleMatchingAuctions passed")
    end

    local function testWrongSender()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "WrongPlayer",
        })

        -- Setup: Create auction for different recipient
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_SENT_COD, "Wrong recipient: Status should remain unchanged")

        print("[TEST] testWrongRecipient passed")
    end

    local function testOwnReturnedMail()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction where I'm both buyer and owner (shouldn't match)
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Buyer"  -- Same as 'me'
        auction.buyer = "Buyer"  -- Same as 'me'. shouldn't happen in reality, but rather have OnTakeInboxItem be robust in case we missed some edgecase
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_SENT_COD, 
            "Own returned mail: Status should remain unchanged")

        print("[TEST] testOwnReturnedMail passed")
    end

    local function testLowerCOD()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 90, -- Lower COD than auction price
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction expecting higher COD
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_COMPLETED, "Lower COD: allowed (no price checking by design)")

        print("[TEST] testLowerCOD passed")
    end

    local function testHigherCOD()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 110, -- Higher COD than auction price
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction with lower price
        local auction = API:CreateAuction(159, 100, 2, false)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_COMPLETED, "Higher COD: allowed")

        print("[TEST] testHigherCOD passed")
    end

    local function testTradeOnlyDelivery()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction that requires trade delivery
        local auction = API:CreateAuction(159, 100, 2, false, nil, ns.DELIVERY_TYPE_TRADE)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local unchanged = DB.auctions[auction.id]
        assertEq(unchanged.status, ns.AUCTION_STATUS_SENT_COD, 
            "Trade-only delivery: Status should remain unchanged")

        print("[TEST] testTradeOnlyDelivery passed")
    end

    local function testMailOnlyDelivery()
        setupMockMail({
            itemID = 159,
            quantity = 2,
            cod = 100,
            me = "Buyer",
            sender = "Owner",
        })

        -- Setup: Create auction that requires mail delivery
        local auction = API:CreateAuction(159, 100, 2, false, nil, ns.DELIVERY_TYPE_MAIL)
        auction.owner = "Owner"
        auction.buyer = "Buyer"
        auction.status = ns.AUCTION_STATUS_SENT_COD

        -- Execute
        ns.MailboxUI:OnTakeInboxItem(1, 1)

        -- Verify
        local updated = DB.auctions[auction.id]
        assertEq(updated.status, ns.AUCTION_STATUS_COMPLETED, 
            "Mail-only delivery: Status should be completed")

        print("[TEST] testMailOnlyDelivery passed")
    end

    local tests = {
        testExactMatch,
        testLoanMail,
        testLowerQuantity,
        testHigherQuantity,
        testMultipleMatchingAuctions,
        testWrongSender,
        testReturnedMail,
        testWrongItem,
        testOwnReturnedMail,
        testLowerCOD,
        testHigherCOD,
        testTradeOnlyDelivery,
        testMailOnlyDelivery
    }

    for _, test in ipairs(tests) do
        -- Clear auction database before each test to ensure isolation
        API:ClearPersistence()
        ResetTestHooks()

        test()
    end

    print("[OK] RunMailboxTest")
end

local function RunTest(testFunc)
    API:ClearPersistence()
    ResetTestHooks()
    testFunc()
end

AH.OnInitialize = function()
    -- Store original functions
    originalBroadcastMessage = AH.BroadcastMessage
    originalSendDm = AH.SendDm
    originalGetInboxHeaderInfo = GetInboxHeaderInfo
    originalGetInboxItem = GetInboxItem
    originalGetInboxItemLink = GetInboxItemLink
    originalUnitName = UnitName


    API:ClearPersistence()
    ResetTestHooks()
    prevOnInit(AH)

    RunTest(RunExpirationTest)
    RunTest(RunLifecycleTest)
    RunTest(RunErrorCasesTest)
    RunTest(RunInvalidInputTest)
    RunTest(RunStateManagementTest)
    RunTest(RunAuctionQueriesTest)
    RunTest(RunSyncTest)
    RunTest(RunAuctionStatusTest)
    RunTest(RunMailboxTest)

    ResetTestHooks()
end
