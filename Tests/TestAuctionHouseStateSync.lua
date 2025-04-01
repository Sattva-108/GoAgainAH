local _, ns = ...

local LibDeflate = LibStub("LibDeflate")

---------------------------------------------------------------------
-- Helpers for simulating delayed callbacks (the After wrapper)
---------------------------------------------------------------------
local scheduledCallbacks = {}

local function mockAfter(self, delay, callback)
    print(self.playerName, "mockAfter called with delay:", delay)
    table.insert(scheduledCallbacks, { delay = delay, callback = callback })
end

local function resetScheduledCallbacks()
    scheduledCallbacks = {}
end

local function runScheduledCallbacks()
    for _, sched in ipairs(scheduledCallbacks) do
        sched.callback()
    end
    resetScheduledCallbacks()
end

---------------------------------------------------------------------
-- Mocks for communication methods
---------------------------------------------------------------------
local function mockSendDm(self, message, target, prio)
    print(self.playerName, "mockSendDm to", target)
    self.sentMessages = self.sentMessages or {}
    local ok, deser = ns.AuctionHouseAddon:Deserialize(message)
    assert(ok, "Deserialize failed in mockSendDm")
    local dataType = deser[1]
    table.insert(self.sentMessages, {
        message = message,
        distribution = "WHISPER",
        dataType = dataType,
        target = target,
        prio = prio
    })
end

local function mockBroadcastMessage(self, message)
    print(self.playerName, "mockBroadcastMessage")
    self.sentMessages = self.sentMessages or {}
    local ok, deser = ns.AuctionHouseAddon:Deserialize(message)
    assert(ok, "Deserialize failed in mockBroadcastMessage")
    local dataType = deser[1]
    table.insert(self.sentMessages, {
        message = message,
        distribution = "GUILD",
        dataType = dataType
    })
end

---------------------------------------------------------------------
-- Helper to create a test AuctionHouse instance with minimal setup.
---------------------------------------------------------------------
local function createTestInstance(name, revision)
    local instance = ns.AuctionHouseClass:new()
    instance.playerName = name
    instance.db = { revision = revision, auctions = {}, lastUpdateAt = time() }
    instance.sentMessages = {}

    -- for convenient testing
    instance.ignoreSenderCheck = true

    instance.After = mockAfter
    instance.SendDm = mockSendDm
    instance.BroadcastMessage = mockBroadcastMessage
    -- By default, use the built‐in IsPrimaryResponder unless overridden in a test.
    return instance
end

---------------------------------------------------------------------
-- Test 1:
-- When a T_AUCTION_STATE_REQUEST is received and the local revision is not higher,
-- the instance should ignore the request (no response sent).
---------------------------------------------------------------------
local function test_ignore_state_request_due_to_low_revision()
    print("Running test_ignore_state_request_due_to_low_revision")
    local instance = createTestInstance("TestUser1", 3)
    local requestPayload = { revision = 3, auctions = {} }
    local requestMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE_REQUEST, requestPayload })

    instance:OnCommReceived(ns.COMM_PREFIX, requestMessage, "GUILD", "Requester")

    assert(not (instance.sentMessages and #instance.sentMessages > 0),
        "Instance should not respond when revision is not higher")
    print("Passed test_ignore_state_request_due_to_low_revision")
end

---------------------------------------------------------------------
-- Test 2:
-- Primary responder (forced as primary) immediately sends an update.
---------------------------------------------------------------------
local function test_primary_immediate_response()
    print("Running test_primary_immediate_response")
    local instance = createTestInstance("TestUserPrimary", 4)
    -- Force primary responder check to return true.
    instance.IsPrimaryResponder = function(self, playerName, dataType, sender) return true end

    local requestPayload = { revision = 3, auctions = {} }
    local requestMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE_REQUEST, requestPayload })

    instance:OnCommReceived(ns.COMM_PREFIX, requestMessage, "GUILD", "Requester")

    -- In the immediate-response case, SendDm should have been called.
    assert(instance.sentMessages and #instance.sentMessages == 1,
        "Primary responder should send a response immediately")
    local sent = instance.sentMessages[1]
    assert(sent.dataType == ns.T_AUCTION_STATE,
        "Sent message should be of type T_AUCTION_STATE")
    assert(#scheduledCallbacks == 0,
        "No scheduled callbacks should exist for primary responder")
    print("Passed test_primary_immediate_response")
end

---------------------------------------------------------------------
-- Test 3:
-- Non-primary responder schedules a delayed response and sends it when the timer fires.
---------------------------------------------------------------------
local function test_delayed_response_sends_update()
    print("Running test_delayed_response_sends_update")
    local instance = createTestInstance("TestUserDelayed", 4)
    -- Force non-primary (delayed) by having IsPrimaryResponder return false.
    instance.IsPrimaryResponder = function(self, playerName, dataType, sender) return false end

    local requestPayload = { revision = 3, auctions = {} }
    local requestMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE_REQUEST, requestPayload })

    instance:OnCommReceived(ns.COMM_PREFIX, requestMessage, "GUILD", "Requester")

    -- Immediately, no message should be sent – instead, a delayed callback is scheduled.
    assert((not instance.sentMessages or #instance.sentMessages == 0),
        "Delayed responder should not send update immediately")
    assert(#scheduledCallbacks > 0,
        "A delayed callback should be scheduled")

    runScheduledCallbacks() -- simulate the passage of time

    assert(instance.sentMessages and #instance.sentMessages == 1,
        "Delayed responder should send update after delay")
    local sent = instance.sentMessages[1]
    assert(sent.dataType == ns.T_AUCTION_STATE,
        "Sent message should be of type T_AUCTION_STATE")
    print("Passed test_delayed_response_sends_update")
end

---------------------------------------------------------------------
-- Test 4:
-- A delayed response should cancel sending an update if an ACK is received before the callback fires.
---------------------------------------------------------------------
local function test_delayed_response_cancellation_with_ack()
    print("Running test_delayed_response_cancellation_with_ack")
    local instance = createTestInstance("TestUserDelayedCancel", 4)
    instance.IsPrimaryResponder = function(self, playerName, dataType, sender) return false end

    local requestPayload = { revision = 3, auctions = {} }
    local requestMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE_REQUEST, requestPayload })

    instance:OnCommReceived(ns.COMM_PREFIX, requestMessage, "GUILD", "Requester")

    -- Before running the scheduled callback, simulate receiving an ACK.
    instance.lastAckAuctionRevisions["Requester"] = 4
    ns.DebugLog("mock update lastAckAuctionRevisions")

    runScheduledCallbacks() -- execute the delayed callback

    local assertMsg = ""
    if instance.sentMessages and #instance.sentMessages > 0 then
        for _, value in ipairs(instance.sentMessages) do
            assertMsg = assertMsg .. string.format(" - %s %d", value.dataType, value.distribution)
        end
    end

    assert(
        not (instance.sentMessages and #instance.sentMessages > 0),
        string.format("Delayed update should be cancelled due to received ACK. Messages sent: %d\n%s",
            #(instance.sentMessages or {}), assertMsg)
    )
    print("Passed test_delayed_response_cancellation_with_ack")
end

---------------------------------------------------------------------
-- Test 5:
-- The requester receives a T_AUCTION_STATE update (via WHISPER) with a higher revision.
-- The test verifies that:
--   • The requester's state is updated.
--   • The OnStateResponseHandled hook is called.
--   • An ACK message is broadcasted.
---------------------------------------------------------------------
local function test_state_update_with_higher_revision()
    print("Running test_state_update_with_higher_revision")
    local requester = createTestInstance("A", 3)

    local capturedState = nil
    requester.OnStateResponseHandled = function(self, sender, state)
        capturedState = state
    end

    -- Create a simulated state payload with a higher revision.
    local statePayload = {
        auctions = { ["123"] = { id = "123", rev = 1, status = "new" } },
        deletedAuctionIds = {},
        revision = 4,
        lastUpdateAt = time() + 10
    }
    
    -- Properly serialize and compress the state payload
    local serializedState = ns.AuctionHouseAddon:Serialize(statePayload)
    local compressedState = LibDeflate:CompressDeflate(serializedState)
    local stateMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE, compressedState })

    requester:OnCommReceived(ns.COMM_PREFIX, stateMessage, "WHISPER", "B")

    -- Verify state update.
    assert(requester.db.revision == 4,
        "Requester's revision should be updated to 4")
    assert(requester.db.auctions["123"],
        "Requester's auctions should include the new auction")
    -- Verify that an ACK was broadcasted.
    assert(requester.sentMessages and #requester.sentMessages == 1,
        "An ACK should have been broadcasted")
    local ackMsg = requester.sentMessages[1]
    assert(ackMsg.dataType == ns.T_AUCTION_ACK,
        "Broadcasted message should be T_AUCTION_ACK")
    -- Verify the hook was called.
    assert(capturedState and capturedState.revision == 4,
        "OnStateResponseHandled should capture state with revision 4")

    print("Passed test_state_update_with_higher_revision")
end

---------------------------------------------------------------------
-- Test 6:
-- The requester receives a T_AUCTION_STATE update with a lower revision.
-- In that case the state is not updated (the local db remains untouched),
-- yet an ACK is still broadcast and the hook called.
---------------------------------------------------------------------
local function test_state_update_with_lower_revision()
    print("Running test_state_update_with_lower_revision")
    local requester = createTestInstance("A", 4)
    -- Set up existing auction to ensure it is preserved.
    requester.db.auctions["existing"] = { id = "existing", rev = 2, status = "active" }

    local capturedState = nil
    requester.OnStateResponseHandled = function(self, sender, state)
        capturedState = state
    end

    -- Create a simulated state payload with a lower revision.
    local statePayload = {
        auctions = { ["new"] = { id = "new", rev = 1, status = "new" } },
        deletedAuctionIds = {},
        revision = 3,
        lastUpdateAt = time() + 10
    }

    -- Properly serialize and compress the state payload
    local serializedState = ns.AuctionHouseAddon:Serialize(statePayload)
    local compressedState = LibDeflate:CompressDeflate(serializedState)
    local stateMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE, compressedState })

    requester:OnCommReceived(ns.COMM_PREFIX, stateMessage, "WHISPER", "B")

    -- Verify that the local state was not updated.
    assert(requester.db.revision == 4,
        "Requester's revision should remain 4 when receiving a lower revision")
    assert(requester.db.auctions["existing"],
        "Existing auction should remain unchanged")
    assert(not requester.db.auctions["new"],
        "New auction from lower revision should not be added")
    -- Yet, an ACK is still broadcast and the hook is called.
    assert(requester.sentMessages and #requester.sentMessages == 1,
        "An ACK should be broadcasted even for a lower revision update")
    local ackMsg = requester.sentMessages[1]
    assert(ackMsg.dataType == ns.T_AUCTION_ACK,
        "Broadcasted message should be T_AUCTION_ACK")
    assert(capturedState and capturedState.revision == 3,
        "OnStateResponseHandled should capture the received state (revision 3)")
    print("Passed test_state_update_with_lower_revision")
end

---------------------------------------------------------------------
-- Test 7:
-- When deserialization of a T_AUCTION_STATE update fails, nothing should be updated,
-- no hook should be called, and no ACK is broadcast.
---------------------------------------------------------------------
local function test_state_update_deserialization_failure()
    print("Running test_state_update_deserialization_failure")
    local requester = createTestInstance("A", 3)
    local hookCalled = false
    requester.OnStateResponseHandled = function(self, sender, state)
        hookCalled = true
    end

    -- Temporarily override Deserialize to simulate a failure.
    local originalDeserialize = ns.AuctionHouseAddon.Deserialize
    ns.AuctionHouseAddon.Deserialize = function(data) return false, nil end

    local statePayload = {
        auctions = { ["fail"] = { id = "fail", rev = 1, status = "new" } },
        deletedAuctionIds = {},
        revision = 4,
        lastUpdateAt = time() + 10
    }
    -- serialize and compress
    local serializedState = ns.AuctionHouseAddon:Serialize(statePayload)
    local compressedState = LibDeflate:CompressDeflate(serializedState)
    local stateMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE, compressedState })

    requester:OnCommReceived(ns.COMM_PREFIX, stateMessage, "WHISPER", "B")

    -- Verify that no updates or hooks occur.
    assert(requester.db.revision == 3,
        "Requester's revision should remain unchanged on deserialization failure")
    assert(not hookCalled,
        "OnStateResponseHandled should not be called on deserialization failure")
    assert(not (requester.sentMessages and #requester.sentMessages > 0),
        "No ACK should be broadcasted on deserialization failure")

    -- Restore the original Deserialize function.
    ns.AuctionHouseAddon.Deserialize = originalDeserialize
    print("Passed test_state_update_deserialization_failure")
end

---------------------------------------------------------------------
-- Test 8:
-- Verify that deleted auctions are properly removed when processing state updates
---------------------------------------------------------------------
local function test_state_update_deleted_auctions()
    print("Running test_state_update_deleted_auctions")
    local requester = createTestInstance("A", 3)
    -- Set up existing auctions
    requester.db.auctions = {
        ["keep"] = { id = "keep", rev = 1, status = "active" },
        ["delete"] = { id = "delete", rev = 1, status = "active" }
    }

    local statePayload = {
        auctions = { ["keep"] = { id = "keep", rev = 1, status = "active" } },
        deletedAuctionIds = { "delete" },
        revision = 4,
        lastUpdateAt = time()
    }
    
    local serializedState = ns.AuctionHouseAddon:Serialize(statePayload)
    local compressedState = LibDeflate:CompressDeflate(serializedState)
    local stateMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE, compressedState })

    requester:OnCommReceived(ns.COMM_PREFIX, stateMessage, "WHISPER", "B")

    assert(requester.db.auctions["keep"], "Kept auction should remain")
    assert(not requester.db.auctions["delete"], "Deleted auction should be removed")
    print("Passed test_state_update_deleted_auctions")
end

---------------------------------------------------------------------
-- Test 10:
-- Verify that multiple delayed responses don't stack up
---------------------------------------------------------------------
local function test_multiple_state_requests()
    print("Running test_multiple_state_requests")
    local instance = createTestInstance("TestUser", 4)
    instance.IsPrimaryResponder = function() return false end

    local requestPayload = { revision = 3, auctions = {} }
    local requestMessage = ns.AuctionHouseAddon:Serialize({ ns.T_AUCTION_STATE_REQUEST, requestPayload })

    -- Send multiple requests
    instance:OnCommReceived(ns.COMM_PREFIX, requestMessage, "GUILD", "Requester1")
    instance:OnCommReceived(ns.COMM_PREFIX, requestMessage, "GUILD", "Requester2")

    local originalCallbackCount = #scheduledCallbacks
    runScheduledCallbacks()

    -- Verify only one response per requester
    local responseCount = 0
    for _, msg in ipairs(instance.sentMessages or {}) do
        if msg.dataType == ns.T_AUCTION_STATE then
            responseCount = responseCount + 1
        end
    end

    assert(responseCount == 2, "Should send exactly one response per requester")
    assert(originalCallbackCount == 2, "Should schedule exactly one callback per requester")
    print("Passed test_multiple_state_requests")
end

---------------------------------------------------------------------
-- Test 11:
-- Verify that RandomBiasedDelay produces values biased toward the max
---------------------------------------------------------------------
local function test_random_biased_delay_distribution()
    print("Running test_random_biased_delay_distribution")

    local min, max = 5, 50
    local samples = 5000
    local sum = 0
    local allInRange = true
    local examples = {}
    local allValues = {}

    -- Collect samples
    for i = 1, samples do
        local delay = ns.RandomBiasedDelay(min, max)
        sum = sum + delay

        -- Store first 30 values
        if #examples <= 50 then
            table.insert(examples, math.floor(delay))
        end

        -- Store all values for percentile calculation
        table.insert(allValues, delay)

        -- Check range
        if delay < min or delay > max then
            allInRange = false
            break
        end
    end

    -- Sort values for percentile calculation
    table.sort(allValues)

    -- Calculate percentiles
    local p2 = allValues[math.floor(samples * 0.02)]
    local p5 = allValues[math.floor(samples * 0.05)]
    local p10 = allValues[math.floor(samples * 0.1)]
    local p20 = allValues[math.floor(samples * 0.2)]
    local p30 = allValues[math.floor(samples * 0.3)]
    local p40 = allValues[math.floor(samples * 0.4)]
    local p50 = allValues[math.floor(samples * 0.5)]
    local p60 = allValues[math.floor(samples * 0.6)]
    local p70 = allValues[math.floor(samples * 0.7)]
    local p80 = allValues[math.floor(samples * 0.8)]
    local p90 = allValues[math.floor(samples * 0.9)]

    -- -- Print statistics
    -- print("example values:", table.concat(examples, ", "))
    -- print(string.format("Statistics (n=%d):", samples))
    -- print(string.format("  min: %.2f", allValues[1]))
    -- print(string.format("  max: %.2f", allValues[#allValues]))
    -- print(string.format("  average: %.2f", sum / samples))
    -- print(string.format("  p2: %.2f", p2))
    -- print(string.format("  p5: %.2f", p5))
    -- print(string.format("  p10: %.2f", p10))
    -- print(string.format("  p20: %.2f", p20))
    -- print(string.format("  p30: %.2f", p30))
    -- print(string.format("  p40: %.2f", p40))
    -- print(string.format("  p50: %.2f", p50))
    -- print(string.format("  p60: %.2f", p60))
    -- print(string.format("  p70: %.2f", p70))
    -- print(string.format("  p80: %.2f", p80))
    -- print(string.format("  p90: %.2f", p90))

    -- With the ^(1/8) power distribution, the expected average should be
    -- closer to the max than the middle of the range
    local middlePoint = (max + min) / 2
    local expectedMinimumAverage = middlePoint + ((max - min) * 0.2) -- At least 20% above middle

    assert(allInRange, "All delays should be within specified range")
    assert(sum / samples > expectedMinimumAverage, 
        string.format("Average (%f) should be biased toward max, above %f", 
        sum / samples, expectedMinimumAverage))

    print("Passed test_random_biased_delay_distribution")
end

---------------------------------------------------------------------
-- Run all tests sequentially.
---------------------------------------------------------------------
local function runAllTests()
    test_ignore_state_request_due_to_low_revision()
    test_primary_immediate_response()
    test_delayed_response_sends_update()
    test_delayed_response_cancellation_with_ack()
    test_state_update_with_higher_revision()
    test_state_update_with_lower_revision()
    test_state_update_deserialization_failure()
    test_state_update_deleted_auctions()
    test_multiple_state_requests()
    test_random_biased_delay_distribution()

    print("[OK] All Auction State Sync Expanded Tests passed!")
end

runAllTests()
