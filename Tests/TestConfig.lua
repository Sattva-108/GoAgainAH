local addonName, ns = ...

local AH = ns.AuctionHouse
local API = ns.AuctionHouseAPI
local prevOnInit = AH.OnInitialize

local function RunConfigTest()
    local messagesSent = {}
    function AH:SendDm(dataType, payload, recipient, prio)
        table.insert(messagesSent, {dataType, payload, recipient, prio})
        return true
    end

    local broadcasts = 0
    function AH:BroadcastMessage(dataType, payload)
        broadcasts = broadcasts + 1
    end

    AH:OnCommReceived(ns.COMM_PREFIX, AH:Serialize({ns.T_CONFIG_REQUEST, {version = AH.config.version}}), "CHANNEL", "bob")

    -- should not send config update if other user has same config version
    assert(#messagesSent == 0)

    AH:OnCommReceived(ns.COMM_PREFIX, AH:Serialize({ns.T_CONFIG_REQUEST, {version = AH.config.version + 1}}), "CHANNEL", "bob")

    -- should not send config update if other user has higher config version
    assert(#messagesSent == 0)

    AH:OnCommReceived(ns.COMM_PREFIX, AH:Serialize({ns.T_CONFIG_REQUEST, {version = AH.config.version - 1}}), "CHANNEL", "bob")

    -- should send config update if other user has lower config version
    assert(#messagesSent == 1)
    assert(messagesSent[1][1] == ns.T_CONFIG_CHANGED)
    assert(messagesSent[1][2].version == AH.config.version)
    assert(messagesSent[1][3] == "bob")
    assert(messagesSent[1][4] == "BULK")

    messagesSent = {}
    local expected = AH.config.version
    AH:OnCommReceived(ns.COMM_PREFIX, AH:Serialize({ns.T_CONFIG_CHANGED, {version = AH.config.version - 1}}), "CHANNEL", "bob")

    -- should not update config if other user has lower config version
    assert(AH.config.version == expected)


    AH:OnCommReceived(ns.COMM_PREFIX, AH:Serialize({ns.T_CONFIG_CHANGED, {version = AH.config.version + 1, test="hi"}}), "CHANNEL", "bob")

    -- should update config if other user has higher config version
    assert(AH.config.version == expected + 1)
    assert(AH.config.test == "hi")
    assert(broadcasts == 0)
    print("Config tests passed")
end



AH.OnInitialize = function()
    API:ClearPersistence()
    prevOnInit(AH)
    RunConfigTest()
end

