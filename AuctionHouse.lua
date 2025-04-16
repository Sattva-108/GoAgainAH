local addonName, ns = ...
local L = ns.L

local Addon = LibStub("AceAddon-3.0"):NewAddon("AuctionHouse", "AceComm-3.0", "AceSerializer-3.0")
ns.AuctionHouseAddon = Addon
local LibDeflate = LibStub("LibDeflate")
local API = ns.AuctionHouseAPI

-- backport from ClassicAPI by Tsoukie
local InitalGTPSCall
local function GetTimePreciseSec()
    local Time = GetTime()
    if InitalGTPSCall == nil then InitalGTPSCall = Time end
    return Time - InitalGTPSCall
end


local COMM_PREFIX = "OFAuctionHouse"
local OF_COMM_PREFIX = "OnlyFangsAddon"
local T_AUCTION_STATE_REQUEST = "AUCTION_STATE_REQUEST"
local T_AUCTION_STATE = "AUCTION_STATE"

local T_CONFIG_REQUEST = "CONFIG_REQUEST"
local T_CONFIG_CHANGED = "CONFIG_CHANGED"

local T_AUCTION_ADD_OR_UPDATE = "AUCTION_ADD_OR_UPDATE"
local T_AUCTION_SYNCED = "AUCTION_SYNCED"
local T_AUCTION_DELETED = "AUCTION_DELETED"

-- Ratings
local T_RATING_ADD_OR_UPDATE = "RATING_ADD_OR_UPDATE"
local T_RATING_DELETED = "RATING_DELETED"
local T_RATING_SYNCED = "RATING_SYNCED"

-- LFG (Looking for Group)
ns.T_LFG_ADD_OR_UPDATE = "LFG_ADD_OR_UPDATE"
ns.T_LFG_DELETED       = "LFG_DELETED"
ns.T_LFG_SYNCED        = "LFG_SYNCED"
ns.T_ON_LFG_STATE_UPDATE = "OnLFGStateUpdate"
ns.T_LFG_STATE_REQUEST = "LFG_STATE_REQUEST"
ns.T_LFG_STATE         = "LFG_STATE"

-- 1) Add new constants for BLACKLIST in the same style as LFG or trades.
local T_BLACKLIST_STATE_REQUEST = "BLACKLIST_STATE_REQUEST"
local T_BLACKLIST_STATE         = "BLACKLIST_STATE"
local T_BLACKLIST_ADD_OR_UPDATE = "BLACKLIST_ADD_OR_UPDATE"
local T_BLACKLIST_DELETED       = "BLACKLIST_DELETED"
local T_BLACKLIST_SYNCED        = "BLACKLIST_SYNCED"
local T_ON_BLACKLIST_STATE_UPDATE = "OnBlacklistStateUpdate"

-- Add them to the ns table so they can be referenced elsewhere
ns.T_BLACKLIST_STATE_REQUEST = T_BLACKLIST_STATE_REQUEST
ns.T_BLACKLIST_STATE = T_BLACKLIST_STATE
ns.T_BLACKLIST_ADD_OR_UPDATE = T_BLACKLIST_ADD_OR_UPDATE
ns.T_BLACKLIST_DELETED = T_BLACKLIST_DELETED
ns.T_BLACKLIST_SYNCED = T_BLACKLIST_SYNCED
ns.T_ON_BLACKLIST_STATE_UPDATE = T_ON_BLACKLIST_STATE_UPDATE

-- Pending transactions
local T_PENDING_TRANSACTION_STATE_REQUEST = "PENDING_TRANSACTION_STATE_REQUEST"
local T_PENDING_TRANSACTION_STATE         = "PENDING_TRANSACTION_STATE"
local T_PENDING_TRANSACTION_ADD_OR_UPDATE  = "PENDING_TRANSACTION_ADD_OR_UPDATE"
local T_PENDING_TRANSACTION_DELETED        = "PENDING_TRANSACTION_DELETED"
local T_PENDING_TRANSACTION_SYNCED         = "PENDING_TRANSACTION_SYNCED"

ns.T_PENDING_TRANSACTION_STATE_REQUEST = T_PENDING_TRANSACTION_STATE_REQUEST
ns.T_PENDING_TRANSACTION_STATE = T_PENDING_TRANSACTION_STATE
ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE = T_PENDING_TRANSACTION_ADD_OR_UPDATE
ns.T_PENDING_TRANSACTION_DELETED = T_PENDING_TRANSACTION_DELETED
ns.T_PENDING_TRANSACTION_SYNCED = T_PENDING_TRANSACTION_SYNCED
ns.T_ON_PENDING_TRANSACTION_STATE_UPDATE = "OnPendingTransactionStateUpdate"

local T_AUCTION_ACK = "AUCTION_ACK"
local T_TRADE_ACK             = "TRADE_ACK"
local T_RATING_ACK            = "RATING_ACK"
local T_LFG_ACK               = "LFG_ACK"
local T_BLACKLIST_ACK         = "BLACKLIST_ACK"
local T_PENDING_TRANSACTION_ACK = "PENDING_TRANSACTION_ACK"

ns.T_AUCTION_ACK = T_AUCTION_ACK
ns.T_TRADE_ACK               = T_TRADE_ACK
ns.T_RATING_ACK              = T_RATING_ACK
ns.T_LFG_ACK                 = T_LFG_ACK
ns.T_BLACKLIST_ACK           = T_BLACKLIST_ACK
ns.T_PENDING_TRANSACTION_ACK = T_PENDING_TRANSACTION_ACK

local knownAddonVersions = {}

local ADMIN_USERS = {
    --["Athenegpt-Soulseeker"] = 1,
   -- ["Maralle-Soulseeker"] = 1,
}

-- Constants
local TEST_USERS = {
    --["Lenkomag"] = "AtheneDev-lenkomag",
    --["Lenkomage"] = "AtheneDev-lenkomage"
  --  ["Pencilbow"] = "AtheneDev-pencilbow",
   -- ["Onefingerjoe"] = "AtheneDev-jannysice",
  --  ["Flawlezzgg"] = "AtheneDev-flawlezzgg",
   -- ["Pencilshaman"] = "AtheneDev-pencilshaman",
   -- ["Smorcstronk"] = "AtheneDev-smorcstronk",
}
ns.TEST_USERS = TEST_USERS
local TEST_USERS_RACE = {
--    ["Lenkomag"] = "Troll",
--    ["Lenkomage"] = "Troll"
  --  ["Pencilbow"] = "Human",
   -- ["Onefingerjoe"] = "Human",
   -- ["Flawlezzgg"] = "Human",
   -- ["Pencilshaman"] = "Undead",
   -- ["Smorcstronk"] = "Orc",
}

ns.COMM_PREFIX = COMM_PREFIX
ns.T_GUILD_ROSTER_CHANGED = "GUILD_ROSTER_CHANGED"

ns.T_CONFIG_REQUEST = T_CONFIG_REQUEST
ns.T_CONFIG_CHANGED = T_CONFIG_CHANGED
ns.T_AUCTION_ADD_OR_UPDATE = T_AUCTION_ADD_OR_UPDATE
ns.T_AUCTION_DELETED = T_AUCTION_DELETED
ns.T_AUCTION_STATE = T_AUCTION_STATE
ns.T_AUCTION_STATE_REQUEST = T_AUCTION_STATE_REQUEST
ns.T_AUCTION_SYNCED = T_AUCTION_SYNCED
ns.T_ON_AUCTION_STATE_UPDATE = "OnAuctionStateUpdate"

-- trades
ns.T_TRADE_ADD_OR_UPDATE = "TRADE_ADD_OR_UPDATE"
ns.T_TRADE_DELETED = "TRADE_DELETED"
ns.T_TRADE_SYNCED = "TRADE_SYNCED"

ns.T_ON_TRADE_STATE_UPDATE = "OnTradeStateUpdate"
ns.T_TRADE_STATE_REQUEST = "TRADE_REQUEST"
ns.T_TRADE_STATE = "TRADE_STATE"

-- trade ratings
ns.T_RATING_ADD_OR_UPDATE = T_RATING_ADD_OR_UPDATE
ns.T_RATING_DELETED = T_RATING_DELETED
ns.T_RATING_SYNCED = T_RATING_SYNCED

ns.T_ON_RATING_STATE_UPDATE = "OnRatingStateUpdate"
ns.T_RATING_STATE_REQUEST = "RATING_STATE_REQUEST"
ns.T_RATING_STATE = "RATING_STATE"

-- death clips
ns.T_DEATH_CLIPS_STATE_REQUEST = "DEATH_CLIPS_STATE_REQUEST"
ns.T_DEATH_CLIPS_STATE = "DEATH_CLIPS_STATE"
ns.T_ADMIN_REMOVE_CLIP = "ADMIN_REMOVE_CLIP"
ns.T_DEATH_CLIPS_MARK_OFFLINE = "DEATH_CLIPS_MARK_OFFLINE"
ns.EV_DEATH_CLIPS_CHANGED = "DEATH_CLIPS_CHANGED"
ns.T_ADMIN_UPDATE_CLIP_OVERRIDES = "ADMIN_UPDATE_CLIP_OVERRIDES"
ns.T_DEATH_CLIP_ADDED = "DEATH_CLIP_ADDED"

ns.T_DEATH_CLIP_REVIEW_STATE_REQUEST = "DEATH_CLIP_REVIEW_STATE_REQUEST"
ns.T_DEATH_CLIP_REVIEW_STATE = "DEATH_CLIP_REVIEW_STATE"
ns.T_DEATH_CLIP_REVIEW_UPDATED = "DEATH_CLIP_REVIEW_UPDATED"

-- version check
ns.T_ADDON_VERSION_REQUEST = "ADDON_VERSION_REQUEST"
ns.T_ADDON_VERSION_RESPONSE = "ADDON_VERSION_RESPONSE"

ns.T_SET_GUILD_POINTS = "SET_GUILD_POINTS"

local G, W = "GUILD", "WHISPER"

local CHANNEL_WHITELIST = {
    [ns.T_CONFIG_REQUEST] = {[G]=1},
    [ns.T_CONFIG_CHANGED] = {[W]=1},

    [ns.T_AUCTION_STATE_REQUEST] = {[G]=1},
    [ns.T_AUCTION_STATE] = {[W]=1},
    [ns.T_AUCTION_ADD_OR_UPDATE] = {[G]=1},
    [ns.T_AUCTION_DELETED] = {[G]=1},

    [ns.T_AUCTION_ACK] = {[G]=1},
    [ns.T_TRADE_ACK] = {[G]=1},
    [ns.T_RATING_ACK] = {[G]=1},
    [ns.T_LFG_ACK] = {[G]=1},
    [ns.T_BLACKLIST_ACK] = {[G]=1},
    [ns.T_PENDING_TRANSACTION_ACK] = {[G]=1},

    [ns.T_TRADE_STATE_REQUEST] = {[G]=1},
    [ns.T_TRADE_STATE] = {[W]=1},
    [ns.T_TRADE_ADD_OR_UPDATE] = {[G]=1},
    [ns.T_TRADE_DELETED] = {[G]=1},

    [ns.T_RATING_STATE_REQUEST] = {[G]=1},
    [ns.T_RATING_STATE] = {[W]=1},
    [ns.T_RATING_ADD_OR_UPDATE] = {[G]=1},
    [ns.T_RATING_DELETED] = {[G]=1},

    [ns.T_DEATH_CLIPS_STATE_REQUEST] = {[G]=1},
    [ns.T_DEATH_CLIPS_STATE] = {[W]=1},
    [ns.T_ADMIN_REMOVE_CLIP] = {}, --admin only
    [ns.T_DEATH_CLIP_REVIEW_STATE_REQUEST] = {[G]=1},
    [ns.T_DEATH_CLIP_REVIEW_STATE] = {[W]=1},
    [ns.T_DEATH_CLIP_REVIEW_UPDATED] = {[G]=1},
    [ns.T_ADMIN_UPDATE_CLIP_OVERRIDES] = {}, --admin only
    [ns.T_DEATH_CLIP_ADDED] = {[G]=1},


    [ns.T_ADDON_VERSION_REQUEST] = {[G]=1},
    [ns.T_ADDON_VERSION_RESPONSE] = {[W]=1},

    -- LFG
    [ns.T_LFG_STATE_REQUEST] = {[G]=1},
    [ns.T_LFG_STATE] = {[W]=1},
    [ns.T_LFG_ADD_OR_UPDATE] = {[G]=1},
    [ns.T_LFG_DELETED] = {[G]=1},

    -- Blacklist
    [ns.T_BLACKLIST_STATE_REQUEST] = {[G] = 1},
    [ns.T_BLACKLIST_STATE]         = {[W] = 1},
    [ns.T_BLACKLIST_ADD_OR_UPDATE] = {[G] = 1},
    [ns.T_BLACKLIST_DELETED]       = {[G] = 1},

    [ns.T_SET_GUILD_POINTS] = {[W] = 1},

    -- Pending transaction
    [ns.T_PENDING_TRANSACTION_DELETED] = {[G] = 1},
    [ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE] = {[G] = 1},
    [ns.T_PENDING_TRANSACTION_STATE_REQUEST] = {[G] = 1},
    [ns.T_PENDING_TRANSACTION_STATE] = {[W] = 1},
}

local function getFullName(name)
    local shortName, realmName = string.split("-", name)
    return shortName .. "-" .. (realmName  or GetRealmName())
end

local function isMessageAllowed(sender, channel, messageType)
    local fullName = getFullName(sender)
    if ADMIN_USERS[fullName] then
        return true
    end
    if not CHANNEL_WHITELIST[messageType] then
        return false
    end
    if not CHANNEL_WHITELIST[messageType][channel] then
        return false
    end
    return true
end

local AuctionHouse = {}
AuctionHouse.__index = AuctionHouse

function AuctionHouse.new()
    local instance = setmetatable({}, AuctionHouse)

    -- Initialize ack tables
    instance.lastAckAuctionRevisions = {}
    instance.lastAckTradeRevisions = {}
    instance.lastAckRatingRevisions = {}
    instance.lastAckLFGRevisions = {}
    instance.lastAckBlacklistRevisions = {}
    instance.lastAckPendingTransactionRevisions = {}

    -- Initialize ack broadcast flags for various state types
    instance.ackBroadcasted = false
    instance.tradeAckBroadcasted = false
    instance.ratingAckBroadcasted = false
    instance.lfgAckBroadcasted = false
    instance.blacklistAckBroadcasted = false
    instance.pendingTransactionAckBroadcasted = false

    -- Hooks for testing; by default they do nothing.
    instance.OnStateRequestHandled = function(self, sender, payload)
    end
    instance.OnStateResponseHandled = function(self, sender, payload)
    end

    return instance
end

function AuctionHouse:SetupTestUsers()
    local realmName = GetRealmName()
    realmName = realmName:gsub("%s+", "")

    if _G.OnlyFangsStreamerMap then
        for name, value in pairs(TEST_USERS) do
            _G.OnlyFangsStreamerMap[name .. "-" .. realmName] = value
        end
    end
    if _G.OnlyFangsRaceMap then
        for name, value in pairs(TEST_USERS_RACE) do
            _G.OnlyFangsRaceMap[name .. "-" .. realmName] = value
        end
    end

    if _G.SixtyProject and _G.SixtyProject.dbGlobal and _G.SixtyProject.dbGlobal.Guild then
        for name, twitchName in pairs(TEST_USERS) do
            local guildEntry = _G.SixtyProject.dbGlobal.Guild[name] or {}
            guildEntry.Streamer = twitchName
            guildEntry.Race = TEST_USERS_RACE[name] or "Human"
            guildEntry.Class = "Warrior"  -- Default dummy value
            guildEntry.Level = 60         -- Max level
            guildEntry.Gender = 2         -- 2 typically represents female
            guildEntry.Honor = 0          -- Starting honor
            guildEntry.Alive = true       -- Default to alive
            guildEntry.Points = 0         -- Starting points
            guildEntry.LastSync = time()
            _G.SixtyProject.dbGlobal.Guild[name] = guildEntry
        end
    end
end

function AuctionHouse:Initialize()
    self.playerName = UnitName("player")
    self.addonVersion = GetAddOnMetadata(addonName, "Version")
    knownAddonVersions[self.addonVersion] = true

    ChatUtils_Initialize()

    -- Initialize API
    ns.AuctionHouseAPI:Initialize({
        broadcastAuctionUpdate = function(dataType, payload)
            self:BroadcastAuctionUpdate(dataType, payload)
        end,
        broadcastTradeUpdate = function(dataType, payload)
            self:BroadcastTradeUpdate(dataType, payload)
        end,
        broadcastRatingUpdate = function(dataType, payload)
            self:BroadcastRatingUpdate(dataType, payload)
        end,
        broadcastLFGUpdate = function(dataType, payload)
            self:BroadcastLFGUpdate(dataType, payload)
        end,
        broadcastBlacklistUpdate = function(dataType, payload)
            self:BroadcastBlacklistUpdate(dataType, payload)
        end,
        broadcastPendingTransactionUpdate = function(dataType, payload)
            self:BroadcastPendingTransactionUpdate(dataType, payload)
        end,
    })
    ns.AuctionHouseAPI:Load()
    self.db = ns.AuctionHouseDB

    -- If needed for test users, show debug UI on load
    if ns.AuctionHouseDB.revision == 0 and TEST_USERS[UnitName("player")] then
        ns.AuctionHouseDB.showDebugUIOnLoad = true
    end

    local clipReviewState = ns.GetDeathClipReviewState()
    clipReviewState:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE, function(payload)
        if payload.fromNetwork then
            return
        end
        self:BroadcastMessage(Addon:Serialize({ ns.T_DEATH_CLIP_REVIEW_UPDATED,  {review=payload.review}}))
    end)
    clipReviewState:RegisterEvent(ns.EV_DEATH_CLIP_MARKED_OFFLINE, function(payload)
        if payload.fromNetwork then
            return
        end
        self:BroadcastMessage(Addon:Serialize({ ns.T_DEATH_CLIPS_MARK_OFFLINE,  {clipID=payload.clipID}}))
    end)
    clipReviewState:RegisterEvent(ns.EV_DEATH_CLIP_OVERRIDE_UPDATED, function(payload)
        if payload.fromNetwork then
            return
        end
        self:BroadcastMessage(Addon:Serialize({ ns.T_ADMIN_UPDATE_CLIP_OVERRIDES,  {clipID=payload.clipID, overrides=payload.overrides}}))
    end)

    -- Initialize UI
    ns.TradeAPI:OnInitialize()
    ns.MailboxUI:Initialize()
    ns.AuctionAlertWidget:OnInitialize()
    OFAuctionFrameReviews_Initialize()
    LfgUI_Initialize()
    SettingsUI_Initialize()
    OFAtheneUI_Initialize()

    local age = time() - ns.AuctionHouseDB.lastUpdateAt
    local auctions = ns.AuctionHouseDB.auctions
    local auctionCount = 0
    for _, _ in pairs(auctions) do
        auctionCount = auctionCount + 1
    end
    ns.DebugLog(string.format("[DEBUG] db loaded from persistence. rev: %s, lastUpdateAt: %d (%ds old) with %d auctions",
            ns.AuctionHouseDB.revision, ns.AuctionHouseDB.lastUpdateAt, age, auctionCount))

    AHConfigSaved = ns.GetConfig()

    -- Register comm prefixes
    Addon:RegisterComm(COMM_PREFIX)
    Addon:RegisterComm(OF_COMM_PREFIX)

    -- chat commands
    SLASH_GAH1 = "/gah"
    SlashCmdList["GAH"] = function(msg) self:OpenAuctionHouse() end

    -- Start auction expiration and trade trimming
    C_Timer:NewTicker(10, function()
        API:ExpireAuctions()
    end)
    C_Timer:NewTicker(61, function()
        API:TrimTrades()
    end)

    -- Add TEST_USERS to OnlyFangsStreamerMap for debugging. eg the mail don't get auto returned
    -- run periodically because these maps get rebuilt regularly when the guild roster updates
    if TEST_USERS[UnitName("player")] then
        -- Run setup immediately
        self:SetupTestUsers()

        C_Timer:NewTicker(1, function()
            self:SetupTestUsers()
        end)
    end

    self.initAt = time()
    self:RequestLatestConfig()
    self:RequestLatestState()
    self:RequestLatestTradeState()
    self:RequestLatestRatingsState()
    self:RequestLatestDeathClipState(self.initAt)
    self:RequestLatestLFGState()
    self:RequestLatestBlacklistState()
    self:RequestAddonVersion()
    self:RequestDeathClipReviewState()
    self:RequestLatestPendingTransactionState()

    if self.db.showDebugUIOnLoad and self.CreateDebugUI then
        self:CreateDebugUI()
        self.debugUI:Show()
    end
    if self.db.openAHOnLoad then
        -- needs a delay to work properly, for whatever reason
        C_Timer:NewTimer(0.5, function()
            OFAuctionFrame_OverrideInitialTab(ns.AUCTION_TAB_BROWSE)
            OFAuctionFrame:Show()
        end)
    end

    self.ignoreSenderCheck = false
end

function AuctionHouse:BroadcastMessage(message)
    local channel = "GUILD"
    Addon:SendCommMessage(COMM_PREFIX, message, channel)
    return true
end

function AuctionHouse:SendDm(message, recipient, prio)
    -- FIXME TODO 3.3.5 HC guys must have weird names right???
    Addon:SendCommMessage(COMM_PREFIX, message, "WHISPER", recipient, prio)
end

function AuctionHouse:BroadcastAuctionUpdate(dataType, payload)
    self:BroadcastMessage(Addon:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastTradeUpdate(dataType, payload)
    self:BroadcastMessage(Addon:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastRatingUpdate(dataType, payload)
    self:BroadcastMessage(Addon:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastLFGUpdate(dataType, payload)
    self:BroadcastMessage(Addon:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastBlacklistUpdate(dataType, payload)
    self:BroadcastMessage(Addon:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastPendingTransactionUpdate(dataType, payload)
    self:BroadcastMessage(Addon:Serialize({ dataType, payload }))
end

function AuctionHouse:BroadcastDeathClipAdded(clip)
    self:BroadcastMessage(Addon:Serialize({ ns.T_DEATH_CLIP_ADDED, clip }))
end

function AuctionHouse:IsSyncWindowExpired()
    -- safety: only allow initial state within 2 minutes after login (chat can be very slow due to ratelimit, so has to be high)
    -- just in case there's a bug we didn't anticipate
    return GetTime() - self.initAt > 120
end

-- Helper: a random delay biased toward the higher end.
local function randomBiasedDelay(min, max)
    -- Using an exponent to skew the result toward 'max'
    return min + (max - min) * (math.random()^(1/3))
end

ns.RandomBiasedDelay = randomBiasedDelay

-- Helper: converts a string into a numeric seed.
local function stringToSeed(s)
    local seed = 0
    for i = 1, #s do
        seed = seed + s:byte(i) * i
    end
    return seed
end

-- Helper: performs a Fisher–Yates shuffle using a simple linear congruential generator.
local function seededShuffle(t, seed)
    local m = 2147483647  -- a large prime for modulus
    local a = 16807       -- common multiplier for LCG
    local localSeed = seed
    for i = #t, 2, -1 do
        localSeed = (localSeed * a) % m
        local j = (localSeed % i) + 1
        t[i], t[j] = t[j], t[i]
    end
end

-- Helper: decide if we are a primary responder based on a deterministic shuffle of the guild roster.
function AuctionHouse:IsPrimaryResponder(playerName, dataType, sender)
    local myName = getFullName(playerName)
    local guildMembers = {}
    local senderFullName = getFullName(sender)

    table.insert(guildMembers, myName)

    -- Use DB.blacklists as source of names, but filter for online guild members
    if ns.GuildRegister.table then
        for name, _ in pairs(self.db.blacklists or {}) do
            -- Check if this player is in the guild and online, and is not the sender
            if ns.GuildRegister.table[name] and
               ns.GuildRegister.table[name].isOnline and
               name ~= senderFullName and
               name ~= myName then
                table.insert(guildMembers, name)
            end
        end
    end
    table.sort(guildMembers)

    -- Derive a seed from the sender so that the shuffle is deterministic
    local seed = stringToSeed(dataType .. "#" .. sender)
    seededShuffle(guildMembers, seed)

    local myRank = nil
    for i, name in ipairs(guildMembers) do
        if name == myName then
            myRank = i
            break
        end
    end

    -- Top 2 in the shuffled order are the primary responders
    return (myRank ~= nil and myRank <= 2)
end

-- wrapper function for overridding during tests
function AuctionHouse:After(delay, callback)
    C_Timer:After(delay, callback)
end

function Addon:OnCommReceived(prefix, message, distribution, sender)
    ns.AuctionHouse:OnCommReceived(prefix, message, distribution, sender)
end

function AuctionHouse:HandleStateUpdate(sender, dataType, cfg, sendPayloadFn)
    local dbRev = cfg.rev
    if dbRev <= cfg.payloadRev then
        ns.DebugLog("[DEBUG] Ignoring", dataType, ". local rev:", dbRev, "requester rev:", cfg.payloadRev)
        return
    end
    cfg.setLastAck(sender, nil)

    local function sendUpdate()
        local ackRev = cfg.getLastAck(sender)
        if ackRev and ackRev >= dbRev then
            ns.DebugLog("[DEBUG] Delayed " .. dataType .. " update cancelled due to ACK received")
            return
        end

        sendPayloadFn()
        ns.DebugLog(string.format("[DEBUG] Sent %s: rev %d, requester rev %d, ack %s",
            dataType, dbRev, cfg.payloadRev, tostring(ackRev or -1)))
    end

    if self:IsPrimaryResponder(self.playerName, dataType, sender) then
        ns.DebugLog("[DEBUG] Immediate " .. dataType .. " state update (primary responder)")
        sendUpdate()
    else
        local delay = randomBiasedDelay(5, 15)
        ns.DebugLog("[DEBUG] Scheduling delayed " .. dataType .. " state update in " .. math.floor(delay) .. "s")
        self:After(delay, sendUpdate)
    end
end

function AuctionHouse:HandleAck(dataType, sender, payload, ackTable)
    local lastAckRev = ackTable[sender]

    ns.DebugLog(string.format("[DEBUG] Received %s ACK from %s with revision: %d local:%d",
        dataType,
        sender,
        payload.revision,
        (lastAckRev or -1)
    ))

    if not lastAckRev or lastAckRev < payload.revision then
        ackTable[sender] = payload.revision
    end
end

function AuctionHouse:BroadcastAck(ackType, revision, isHigherRevision, broadcastFlag)
    if not self[broadcastFlag] or isHigherRevision then
        ns.DebugLog("[DEBUG] Broadcasting " .. ackType .. " ACK with revision: " .. tostring(revision))
        self:BroadcastMessage(Addon:Serialize({ ackType, { revision = revision } }))
        self[broadcastFlag] = true
    end
end

function AuctionHouse:OnCommReceived(prefix, message, distribution, sender)
    -- disallow whisper messages from outside the guild to avoid bad actors to inject malicious data
    -- this means that early on during login we might discard messages from guild members until the guild roaster is known.
    -- however, since we sync the state with the guild roaster on login this shouldn't be a problem.
    if not self.ignoreSenderCheck and distribution == W and not ns.IsGuildMember(sender) then
        return
    end

    if prefix == OF_COMM_PREFIX then
        ns.HandleOFCommMessage(message, sender, distribution)
        return
    end
    if prefix ~= COMM_PREFIX then
        return
    end

    local success, data = Addon:Deserialize(message)
    if not success then
        return
    end
    if sender == UnitName("player") and not self.ignoreSenderCheck then
        return
    end

    local dataType = data[1]
    local payload = data[2]

    ns.DebugLog("[DEBUG]", self.playerName, "recv", dataType, sender)
    if not isMessageAllowed(sender, distribution, dataType) then
        ns.DebugLog("[DEBUG] Ignoring message from", sender, "of type", dataType, "in channel", distribution)
        return
    end

    -- Auction
    if dataType == T_AUCTION_ADD_OR_UPDATE then
        API:UpdateDB(payload)
        API:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, {auction = payload.auction, source = payload.source})

    elseif dataType == T_AUCTION_DELETED then
        API:DeleteAuctionInternal(payload, true)
        API:FireEvent(ns.T_AUCTION_DELETED, payload)

    -- Trades
    elseif dataType == ns.T_TRADE_ADD_OR_UPDATE then
        API:UpdateDBTrade({trade = payload.trade})
        API:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, {auction = payload.auction, source = payload.source})

    elseif dataType == ns.T_TRADE_DELETED then
        API:DeleteTradeInternal(payload, true)

    -- Ratings
    elseif dataType == ns.T_RATING_ADD_OR_UPDATE then
        API:UpdateDBRating(payload)
        API:FireEvent(ns.T_RATING_ADD_OR_UPDATE, { rating = payload.rating, source = payload.source })

    elseif dataType == ns.T_RATING_DELETED then
        API:DeleteRatingInternal(payload, true)
        API:FireEvent(ns.T_RATING_DELETED, { ratingID = payload.ratingID })

    -- LFG
    elseif dataType == ns.T_LFG_ADD_OR_UPDATE then
        ns.LfgAPI:UpdateDBLFG(payload)
        API:FireEvent(ns.T_LFG_ADD_OR_UPDATE, { lfg = payload.lfg, source = payload.source })

    elseif dataType == ns.T_LFG_DELETED then
        local success, err = ns.LfgAPI:DeleteEntry(payload, true, true)
        if not success then
            ns.DebugLog("Failed to delete LFG entry:", payload, err)
        end
        API:FireEvent(ns.T_LFG_DELETED, { lfgKey = payload })

    elseif dataType == ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE then
        -- Update the pending transaction in the DB and fire event
        ns.PendingTxAPI:UpdateDBPendingTransaction(payload)
        API:FireEvent(ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE, { pendingTransaction = payload.transaction, source = payload.source })

        -- Handle the transaction
        ns.PendingTxAPI:HandlePendingTransactionChange(payload.transaction)

    elseif dataType == ns.T_PENDING_TRANSACTION_DELETED then
        -- Delete the pending transaction and fire event
        local success, err = ns.PendingTxAPI:RemovePendingTransaction(payload, true)
        if not success then
            ns.DebugLog("Failed to delete Pending Tx:", payload, err)
        end

    elseif dataType == T_AUCTION_STATE_REQUEST then
        self:HandleStateUpdate(sender, T_AUCTION_STATE_REQUEST, {
            rev = self.db.revision,
            payloadRev = payload.revision,
            getLastAck = function(sender) return self.lastAckAuctionRevisions[sender] end,
            setLastAck = function(sender, value) self.lastAckAuctionRevisions[sender] = value end
        }, function()
            local responsePayload, _, __ = self:BuildDeltaState(payload.revision, payload.auctions)
            local compressed = LibDeflate:CompressDeflate(Addon:Serialize(responsePayload))

            self:SendDm(Addon:Serialize({ T_AUCTION_STATE, compressed }), sender, "BULK")
        end)

    elseif dataType == T_AUCTION_STATE then
        local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000

        local deserializeStart = GetTimePreciseSec()
        local success, state = Addon:Deserialize(decompressed)
        local deserializeTime = (GetTimePreciseSec() - deserializeStart) * 1000

        if not success then
            return
        end

        -- Update revision and lastUpdateAt if necessary
        local isHigherRevision = state.revision > self.db.revision
        if isHigherRevision then
            -- Update local auctions with received data
            for id, auction in pairs(state.auctions or {}) do
                local oldAuction = self.db.auctions[id]
                self.db.auctions[id] = auction

                -- Fire event only if auction changed, with appropriate source
                if not oldAuction then
                    -- New auction
                    API:FireEvent(ns.T_AUCTION_SYNCED, {auction = auction, source = "create"})

                elseif oldAuction.rev == auction.rev then
                    -- no events to fire

                elseif oldAuction.status ~= auction.status then
                    -- status change event
                    local source = "status_update"
                    if auction.status == ns.AUCTION_STATUS_PENDING_TRADE then
                        source = "buy"
                    elseif auction.status == ns.AUCTION_STATUS_PENDING_LOAN then
                        source = "buy_loan"
                    end

                    API:FireEvent(ns.T_AUCTION_SYNCED, {auction = auction, source = source})
                else
                    -- unknown update reason (source)
                    API:FireEvent(ns.T_AUCTION_SYNCED, {auction = auction})
                end
            end

            -- Delete auctions that are no longer valid
            for _, id in ipairs(state.deletedAuctionIds or {}) do
                self.db.auctions[id] = nil
            end

            self.db.revision = state.revision
            self.db.lastUpdateAt = state.lastUpdateAt

            API:FireEvent(ns.T_ON_AUCTION_STATE_UPDATE)

            ns.DebugLog(string.format("[DEBUG] Updated local state with %d new auctions, %d deleted auctions, revision %d (bytes-compressed: %d, decompress: %.0fms, deserialize: %.0fms)",
                #(state.auctions or {}), #(state.deletedAuctionIds or {}),
                self.db.revision,
                #payload,
                decompressTime, deserializeTime
            ))
        end

        -- Broadcast an ACK on the guild channel
        self:BroadcastAck(ns.T_AUCTION_ACK, self.db.revision, isHigherRevision, "ackBroadcasted")

        -- Added hook call so that (for example) tests can capture state response data:
        if self.OnStateResponseHandled then
            self:OnStateResponseHandled(sender, state)
        end

    elseif dataType == T_CONFIG_REQUEST then
        if AHConfigSaved and payload.version < AHConfigSaved.version then
            self:SendDm(Addon:Serialize({ T_CONFIG_CHANGED, AHConfigSaved }), sender, "BULK")
        end
    elseif dataType == ns.T_DEATH_CLIPS_STATE_REQUEST then
        local newClips = ns.GetNewDeathClips(payload.since, payload.clips)
        if #newClips > 0 then
            local newClipsCompressed = LibDeflate:CompressDeflate(Addon:Serialize(newClips))
            self:SendDm(Addon:Serialize({ ns.T_DEATH_CLIPS_STATE, newClipsCompressed }), sender, "BULK")
        end
    elseif dataType == ns.T_DEATH_CLIPS_STATE then
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local success, newClips = Addon:Deserialize(decompressed)
        if success then
            ns.AddNewDeathClips(newClips)
            API:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
        end
    elseif dataType == ns.T_DEATH_CLIPS_MARK_OFFLINE then
        local reviewState = ns.GetDeathClipReviewState()
        reviewState:MarkClipOffline(payload.clipID, true)
    elseif dataType == ns.T_DEATH_CLIP_REVIEW_STATE_REQUEST then
        local rev = payload.rev
        local state = ns.GetDeathClipReviewState()
        if state.persisted.rev > rev then
            local responsePayload = state:GetSyncedState()
            local compressed = LibDeflate:CompressDeflate(Addon:Serialize(responsePayload))
            self:SendDm(Addon:Serialize({ ns.T_DEATH_CLIP_REVIEW_STATE, compressed }), sender, "BULK")
        end
    elseif dataType == ns.T_DEATH_CLIP_REVIEW_STATE then
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local success, state = Addon:Deserialize(decompressed)
        if success then
            local reviewState = ns.GetDeathClipReviewState()
            reviewState:SyncState(state)
        end
    elseif dataType == ns.T_DEATH_CLIP_REVIEW_UPDATED then
        local review = payload.review
        local reviewState = ns.GetDeathClipReviewState()
        reviewState:UpdateReviewFromNetwork(review)
    elseif dataType == ns.T_ADMIN_UPDATE_CLIP_OVERRIDES then
        local reviewState = ns.GetDeathClipReviewState()
        reviewState:UpdateClipOverrides(payload.clipID, payload.overrides, true)
    elseif dataType == ns.T_ADMIN_REMOVE_CLIP then
        ns.RemoveDeathClip(payload.clipID)
    elseif dataType == ns.T_DEATH_CLIP_ADDED then
        ns.AddNewDeathClips({payload})
        local magicLink = ns.CreateMagicLink(ns.SPELL_ID_DEATH_CLIPS, L["watch death clip"])
        print(string.format(L["%s has died at Lv. %d."], ns.GetDisplayName(payload.characterName), payload.level) .. " " .. magicLink)
    elseif dataType == T_CONFIG_CHANGED then
        if payload.version > AHConfigSaved.version then
            AHConfigSaved = payload
        end

    elseif dataType == ns.T_TRADE_STATE_REQUEST then
        self:HandleStateUpdate(sender, ns.T_TRADE_STATE_REQUEST, {
            rev = self.db.revTrades or 0,
            payloadRev = payload.revTrades,
            getLastAck = function(sender) return self.lastAckTradeRevisions[sender] end,
            setLastAck = function(sender, value) self.lastAckTradeRevisions[sender] = value end
        }, function()
            local responsePayload, tradeCount, deletedCount = self:BuildTradeDeltaState(payload.revision, payload.trades)
            local compressed = LibDeflate:CompressDeflate(Addon:Serialize(responsePayload))
            self:SendDm(Addon:Serialize({ ns.T_TRADE_STATE, compressed }), sender, "BULK")
        end)

    elseif dataType == ns.T_TRADE_STATE then
        local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000

        local deserializeStart = GetTimePreciseSec()
        local ok, state = Addon:Deserialize(decompressed)
        local deserializeTime = (GetTimePreciseSec() - deserializeStart) * 1000

        if not ok then
            return
        end

        -- apply the trade state delta if it is ahead of ours
        local isHigherRevision = state.revTrades > self.db.revTrades
        if isHigherRevision then
            for id, trade in pairs(state.trades or {}) do
                local oldTrade = self.db.trades[id]
                self.db.trades[id] = trade

                if not oldTrade then
                    -- new trade
                    API:FireEvent(ns.T_TRADE_SYNCED, { trade = trade, source = "create" })
                elseif oldTrade.rev == trade.rev then
                    -- same revision, skip
                else
                    -- trade updated
                    API:FireEvent(ns.T_TRADE_SYNCED, { trade = trade })
                end
            end

            for _, id in ipairs(state.deletedTradeIds or {}) do
                self.db.trades[id] = nil
            end

            self.db.revTrades = state.revTrades
            self.db.lastTradeUpdateAt = state.lastTradeUpdateAt

            API:FireEvent(ns.T_ON_TRADE_STATE_UPDATE)

            -- optionally fire a "trade state updated" event
            ns.DebugLog(string.format("[DEBUG] Updated local trade state with %d new/updated trades, %d deleted trades, revTrades %d (compressed bytes: %d, decompress: %.0fms, deserialize: %.0fms)",
                #(state.trades or {}), #(state.deletedTradeIds or {}),
                self.db.revTrades,
                #payload, decompressTime, deserializeTime
            ))
        else
            ns.DebugLog("[DEBUG] Outdated trade state ignored", state.revTrades, self.db.revTrades)
        end

        -- Broadcast trade ACK
        self:BroadcastAck(ns.T_TRADE_ACK, self.db.revTrades, isHigherRevision, "tradeAckBroadcasted")

    elseif dataType == ns.T_RATING_STATE_REQUEST then
        self:HandleStateUpdate(sender, ns.T_RATING_STATE_REQUEST, {
            rev = self.db.revRatings or 0,
            payloadRev = payload.revision,
            getLastAck = function(sender) return self.lastAckRatingRevisions[sender] end,
            setLastAck = function(sender, value) self.lastAckRatingRevisions[sender] = value end
        }, function()
            local responsePayload, ratingCount, deletedCount = self:BuildRatingsDeltaState(payload.revision, payload.ratings)
            local compressed = LibDeflate:CompressDeflate(Addon:Serialize(responsePayload))

            self:SendDm(Addon:Serialize({ ns.T_RATING_STATE, compressed }), sender, "BULK")
        end)

    elseif dataType == ns.T_RATING_STATE then
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local ok, state = Addon:Deserialize(decompressed)
        if not ok then
            return
        end

        local isHigherRevision = state.revision > self.db.revRatings
        if isHigherRevision then
            -- Update local ratings with received data
            for id, rating in pairs(state.ratings or {}) do
                self.db.ratings[id] = rating
                API:FireEvent(ns.T_RATING_SYNCED, {rating=rating})
            end

            -- Delete ratings that are no longer valid
            for _, id in ipairs(state.deletedRatingIds or {}) do
                self.db.ratings[id] = nil
            end

            self.db.revRatings = state.revision
            self.db.lastRatingUpdateAt = state.lastUpdateAt
            API:FireEvent(ns.T_ON_RATING_STATE_UPDATE)
        end

        -- Broadcast rating ACK
        self:BroadcastAck(ns.T_RATING_ACK, self.db.revRatings, isHigherRevision, "ratingAckBroadcasted")

    elseif dataType == ns.T_LFG_STATE_REQUEST then
        self:HandleStateUpdate(sender, ns.T_LFG_STATE_REQUEST, {
            rev = self.db.revLfg or 0,
            payloadRev = payload.revLfg,
            getLastAck = function(sender) return self.lastAckLFGRevisions[sender] end,
            setLastAck = function(sender, value) self.lastAckLFGRevisions[sender] = value end
        }, function()
            local responsePayload, lfgCount, deletedCount = self:BuildLFGDeltaState(payload.revLfg, payload.lfgEntries)
            local compressed = LibDeflate:CompressDeflate(Addon:Serialize(responsePayload))

            self:SendDm(Addon:Serialize({ ns.T_LFG_STATE, compressed }), sender, "BULK")
        end)

    elseif dataType == ns.T_LFG_STATE then
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local ok, state = Addon:Deserialize(decompressed)
        if not ok then
            return
        end

        local isHigherRevision = state.revLfg > self.db.revLfg
        if isHigherRevision then
            for user, entry in pairs(state.lfg or {}) do
                local oldEntry = self.db.lfg[user]
                self.db.lfg[user] = entry
                if not oldEntry then
                    API:FireEvent(ns.T_LFG_SYNCED, { lfg = entry, source = "create" })
                else
                    API:FireEvent(ns.T_LFG_SYNCED, { lfg = entry })
                end
            end
            for _, user in ipairs(state.deletedLFGIds or {}) do
                self.db.lfg[user] = nil
            end
            self.db.revLfg = state.revLfg
            self.db.lastLfgUpdateAt = state.lastUpdateAt
            API:FireEvent(ns.T_ON_LFG_STATE_UPDATE)
        end

        -- Broadcast LFG ACK
        self:BroadcastAck(ns.T_LFG_ACK, self.db.revLfg, isHigherRevision, "lfgAckBroadcasted")

    elseif dataType == ns.T_ADDON_VERSION_REQUEST then
        knownAddonVersions[payload.version] = true
        local latestVersion = ns.GetLatestVersion(knownAddonVersions)
        if latestVersion ~= payload.version then
            payload = {version=latestVersion}
            if ns.ChangeLog[latestVersion] then
                payload.changeLog = ns.ChangeLog[latestVersion]
            end
            self:SendDm(Addon:Serialize({ ns.T_ADDON_VERSION_RESPONSE, payload  }), sender, "BULK")
        end
    elseif dataType == ns.T_ADDON_VERSION_RESPONSE then
        ns.DebugLog("[DEBUG] new addon version available", payload.version)
        knownAddonVersions[payload.version] = true
        if payload.changeLog then
            ns.ChangeLog[payload.version] = payload.changeLog
        end

    elseif dataType == ns.T_BLACKLIST_ADD_OR_UPDATE then
        -- "payload" looks like { playerName = "Alice", rev = 5, namesByType = { review = { "enemy1", "enemy2" } } }
        ns.BlacklistAPI:UpdateDBBlacklist(payload)
        API:FireEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, payload)

    -- deletions are not supported, top-level entries just become empty if everything's been un-blacklisted
    -- elseif dataType == ns.T_BLACKLIST_DELETED then
    --     -- "payload" might be { playerName = "Alice" }
    --     if self.db.blacklists[payload.playerName] ~= nil then
    --         self.db.blacklists[payload.playerName] = nil
    --         if (self.db.revBlacklists or 0) < (payload.rev or 0) then
    --             self.db.revBlacklists = payload.rev
    --             self.db.lastBlacklistUpdateAt = time()
    --         end
    --         API:FireEvent(ns.T_BLACKLIST_DELETED, payload)
    --     end

    elseif dataType == ns.T_BLACKLIST_STATE_REQUEST then
        self:HandleStateUpdate(sender, ns.T_BLACKLIST_STATE_REQUEST, {
            rev = self.db.revBlacklists or 0,
            payloadRev = payload.revBlacklists,
            getLastAck = function(sender) return self.lastAckBlacklistRevisions[sender] end,
            setLastAck = function(sender, value) self.lastAckBlacklistRevisions[sender] = value end
        }, function()
            local responsePayload, blCount, deletedCount = self:BuildBlacklistDeltaState(payload.revBlacklists, payload.blacklistEntries)
            local compressed = LibDeflate:CompressDeflate(Addon:Serialize(responsePayload))

            self:SendDm(Addon:Serialize({ ns.T_BLACKLIST_STATE, compressed }), sender, "BULK")
        end)

    elseif dataType == ns.T_BLACKLIST_STATE then
        local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000

        local deserializeStart = GetTimePreciseSec()
        local ok, state = Addon:Deserialize(decompressed)
        local deserializeTime = (GetTimePreciseSec() - deserializeStart) * 1000

        if not ok then
            return
        end

        local isHigherRevision = state.revBlacklists > (self.db.revBlacklists or 0)
        if isHigherRevision then
            -- Update local blacklists
            for user, entry in pairs(state.blacklists or {}) do
                local oldEntry = self.db.blacklists[user]
                self.db.blacklists[user] = entry
                if not oldEntry then
                    API:FireEvent(ns.T_BLACKLIST_SYNCED, { blacklist = entry, source = "create" })
                else
                    API:FireEvent(ns.T_BLACKLIST_SYNCED, { blacklist = entry })
                end
            end
            -- Delete blacklists from local that are no longer in the received state
            for _, user in ipairs(state.deletedBlacklistIds or {}) do
                self.db.blacklists[user] = nil
            end

            -- Bump our local revision
            self.db.revBlacklists = state.revBlacklists
            self.db.lastBlacklistUpdateAt = state.lastBlacklistUpdateAt

            API:FireEvent(ns.T_ON_BLACKLIST_STATE_UPDATE)

            ns.DebugLog(string.format(
                "[DEBUG] Updated local blacklists with %d new/updated, %d deleted, revBlacklists %d (compressed: %d, decompress: %.0fms, deserialize: %.0fms)",
                #(state.blacklists or {}), #(state.deletedBlacklistIds or {}),
                self.db.revBlacklists, #payload, decompressTime, deserializeTime
            ))
        else
            ns.DebugLog("[DEBUG] Outdated blacklist state ignored", state.revBlacklists, self.db.revBlacklists)
        end

        self:BroadcastAck(ns.T_BLACKLIST_ACK, self.db.revBlacklists, isHigherRevision, "blacklistAckBroadcasted")

    elseif dataType == ns.T_SET_GUILD_POINTS then
        ns.OffsetMyGuildPoints(payload.points, payload.txId)

    elseif dataType == ns.T_PENDING_TRANSACTION_STATE_REQUEST then
        self:HandleStateUpdate(sender, ns.T_PENDING_TRANSACTION_STATE_REQUEST, {
            rev = self.db.revPendingTransactions or 0,
            payloadRev = payload.revPendingTransactions,
            getLastAck = function(sender) return self.lastAckPendingTransactionRevisions[sender] end,
            setLastAck = function(sender, value) self.lastAckPendingTransactionRevisions[sender] = value end
        }, function()
            local responsePayload, txnCount, deletedCount = self:BuildPendingTransactionsDeltaState(payload.revPendingTransactions, payload.pendingTransactions)
            local compressed = LibDeflate:CompressDeflate(Addon:Serialize(responsePayload))

            self:SendDm(Addon:Serialize({ ns.T_PENDING_TRANSACTION_STATE, compressed }), sender, "BULK")
        end)

    elseif dataType == ns.T_PENDING_TRANSACTION_STATE then
        local decompressStart = GetTimePreciseSec()
        local decompressed = LibDeflate:DecompressDeflate(payload)
        local decompressTime = (GetTimePreciseSec() - decompressStart) * 1000

        local ok, state = Addon:Deserialize(decompressed)
        if not ok then
            return
        end

        local isHigherRevision = state.revPendingTransactions > (self.db.revPendingTransactions or 0)
        if isHigherRevision then
            for id, txn in pairs(state.pendingTransactions or {}) do
                local oldTxn = (self.db.pendingTransactions or {})[id]
                if not self.db.pendingTransactions then self.db.pendingTransactions = {} end
                self.db.pendingTransactions[id] = txn
                if not oldTxn then
                    API:FireEvent(ns.T_PENDING_TRANSACTION_SYNCED, { pendingTransaction = txn, source = "create" })
                else
                    API:FireEvent(ns.T_PENDING_TRANSACTION_SYNCED, { pendingTransaction = txn })
                end

                -- Handle each transaction in the sync
                ns.PendingTxAPI:HandlePendingTransactionChange(txn)
            end

            for _, id in ipairs(state.deletedTxnIds or {}) do
                if self.db.pendingTransactions then
                    self.db.pendingTransactions[id] = nil
                end
            end

            self.db.revPendingTransactions = state.revPendingTransactions
            self.db.lastPendingTransactionUpdateAt = state.lastPendingTransactionUpdateAt

            API:FireEvent(ns.T_ON_PENDING_TRANSACTION_STATE_UPDATE)

            ns.DebugLog(string.format("[DEBUG] Updated local pending transactions with %d new/updated, %d deleted, revPendingTransactions %d (compressed: %d, decompress: %.0fms)",
                #(state.pendingTransactions or {}), #(state.deletedTxnIds or {}), self.db.revPendingTransactions, #payload, decompressTime))
        else
            ns.DebugLog("[DEBUG] Outdated pending transactions state ignored", state.revPendingTransactions, self.db.revPendingTransactions)
        end

        -- Broadcast pending transaction ACK
        self:BroadcastAck(ns.T_PENDING_TRANSACTION_ACK, self.db.revPendingTransactions, isHigherRevision, "pendingTransactionAckBroadcasted")

    elseif dataType == ns.T_AUCTION_ACK then
        self:HandleAck("auction", sender, payload, self.lastAckAuctionRevisions)
    elseif dataType == ns.T_TRADE_ACK then
        self:HandleAck("trade", sender, payload, self.lastAckTradeRevisions)
    elseif dataType == ns.T_RATING_ACK then
        self:HandleAck("rating", sender, payload, self.lastAckRatingRevisions)
    elseif dataType == ns.T_LFG_ACK then
        self:HandleAck("LFG", sender, payload, self.lastAckLFGRevisions)
    elseif dataType == ns.T_BLACKLIST_ACK then
        self:HandleAck("blacklist", sender, payload, self.lastAckBlacklistRevisions)
    elseif dataType == ns.T_PENDING_TRANSACTION_ACK then
        self:HandleAck("pending transaction", sender, payload, self.lastAckPendingTransactionRevisions)

    else
        ns.DebugLog("[DEBUG] unknown event type", dataType)
    end
end

function AuctionHouse:BuildDeltaState(requesterRevision, requesterAuctions)
    local auctionsToSend = {}
    local deletedAuctionIds = {}
    local auctionCount = 0
    local deletionCount = 0

    if not requesterRevision or requesterRevision < self.db.revision then
        -- Convert requesterAuctions array to lookup table with revisions
        local requesterAuctionLookup = {}
        for _, auctionInfo in ipairs(requesterAuctions or {}) do
            requesterAuctionLookup[auctionInfo.id] = auctionInfo.rev
        end

        -- Find auctions to send (those that requester doesn't have or has older revision)
        for id, auction in pairs(self.db.auctions) do
            local requesterRev = requesterAuctionLookup[id]
            if not requesterRev or (auction.rev > requesterRev) then
                auctionsToSend[id] = auction
                auctionCount = auctionCount + 1
            end
        end

        -- Find deleted auctions (present in requester but not in current state)
        for id, _ in pairs(requesterAuctionLookup) do
            if not self.db.auctions[id] then
                table.insert(deletedAuctionIds, id)
                deletionCount = deletionCount + 1
            end
        end
    end

    -- Construct the response payload
    return {
        v = 1,
        auctions = auctionsToSend,
        deletedAuctionIds = deletedAuctionIds,
        revision = self.db.revision,
        lastUpdateAt = self.db.lastUpdateAt,
    }, auctionCount, deletionCount
end

function AuctionHouse:BuildTradeDeltaState(requesterRevision, requesterTrades)
    local tradesToSend = {}
    local deletedTradeIds = {}
    local tradeCount = 0
    local deletionCount = 0

    -- If requester is behind, then we figure out what trades changed or were deleted
    if not requesterRevision or requesterRevision < self.db.revTrades then
        -- Build a lookup table of the requester's trades, keyed by trade id → revision
        local requesterTradeLookup = {}
        for _, tradeInfo in ipairs(requesterTrades or {}) do
            requesterTradeLookup[tradeInfo.id] = tradeInfo.rev
        end

        -- Collect trades that need to be sent because the requester doesn't have them
        for id, trade in pairs(self.db.trades) do
            local requesterRev = requesterTradeLookup[id]
            if not requesterRev or (trade.rev > requesterRev) then
                tradesToSend[id] = trade
                tradeCount = tradeCount + 1
            end
        end

        -- Detect trades the requester has, but we don't (deleted or no longer valid)
        for id, _ in pairs(requesterTradeLookup) do
            if not self.db.trades[id] then
                table.insert(deletedTradeIds, id)
                deletionCount = deletionCount + 1
            end
        end
    end

    return {
        v = 1,
        trades = tradesToSend,
        deletedTradeIds = deletedTradeIds,
        revTrades = self.db.revTrades or 0,
        lastTradeUpdateAt = self.db.lastTradeUpdateAt,
    }, tradeCount, deletionCount
end

function AuctionHouse:BuildRatingsDeltaState(requesterRevision, requesterRatings)
    local ratingsToSend = {}
    local deletedRatingIds = {}
    local ratingCount = 0
    local deletionCount = 0

    if not requesterRevision or requesterRevision < self.db.revRatings then
        -- Convert requesterRatings array to lookup table with revisions
        local requesterRatingLookup = {}
        for _, ratingInfo in ipairs(requesterRatings or {}) do
            requesterRatingLookup[ratingInfo.id] = ratingInfo.rev
        end

        -- Find ratings to send (those that requester doesn't have or has older revision)
        for id, rating in pairs(self.db.ratings) do
            local requesterRev = requesterRatingLookup[id]
            if not requesterRev or (rating.rev > requesterRev) then
                ratingsToSend[id] = rating
                ratingCount = ratingCount + 1
            end
        end

        -- Find deleted ratings (present in requester but not in current state)
        for id, _ in pairs(requesterRatingLookup) do
            if not self.db.ratings[id] then
                table.insert(deletedRatingIds, id)
                deletionCount = deletionCount + 1
            end
        end
    end

    -- Construct the response payload
    return {
        v = 1,
        ratings = ratingsToSend,
        deletedRatingIds = deletedRatingIds,
        revision = self.db.revRatings,
        lastUpdateAt = self.db.lastRatingUpdateAt,
    }, ratingCount, deletionCount
end

-- Newly added BuildLFGDeltaState function to handle LFG syncing
function AuctionHouse:BuildLFGDeltaState(requesterRevision, requesterLFG)
    local lfgToSend = {}
    local deletedLFGIds = {}
    local lfgCount = 0
    local deletionCount = 0

    if not requesterRevision or requesterRevision < (self.db.revLfg or 0) then
        local requesterLFGLookup = {}
        for _, info in ipairs(requesterLFG or {}) do
            requesterLFGLookup[info.name] = info.rev
        end

        for user, entry in pairs(self.db.lfg or {}) do
            local rRev = requesterLFGLookup[user]
            if not rRev or (entry.rev > rRev) then
                lfgToSend[user] = entry
                lfgCount = lfgCount + 1
            end
        end
        for user, _ in pairs(requesterLFGLookup) do
            if not self.db.lfg[user] then
                table.insert(deletedLFGIds, user)
                deletionCount = deletionCount + 1
            end
        end
    end

    return {
        v = 1,
        lfg = lfgToSend,
        deletedLFGIds = deletedLFGIds,
        revLfg = self.db.revLfg or 0,
        lastUpdateAt = self.db.lastLfgUpdateAt or 0,
    }, lfgCount, deletionCount
end

function AuctionHouse:BuildBlacklistDeltaState(requesterRevision, requesterBlacklists)
    -- We'll return a table of updated items plus a list of deleted ones.
    local blacklistsToSend = {}
    local deletedBlacklistIds = {}
    local blacklistCount = 0
    local deletionCount = 0

    if not requesterRevision or requesterRevision < (self.db.revBlacklists or 0) then
        -- Convert the requester's blacklist array into a name->rev lookup with blType
        local requesterBLLookup = {}
        for _, info in ipairs(requesterBlacklists or {}) do
            requesterBLLookup[info.playerName] = info.rev
        end

        -- For each local playerName in blacklists
        for playerName, blacklist in pairs(self.db.blacklists or {}) do
            local requesterRev = requesterBLLookup[playerName]
            if not requesterRev or (blacklist.rev > requesterRev) then
                blacklistsToSend[playerName] = blacklist
                blacklistCount = blacklistCount + 1
            end
        end

        -- Detect blacklists the requester has, but we don't (deleted)
        for playerName, _ in pairs(requesterBLLookup) do
            if not self.db.blacklists[playerName] then
                table.insert(deletedBlacklistIds, playerName)
                deletionCount = deletionCount + 1
            end
        end
    end

    return {
        v = 1,
        blacklists = blacklistsToSend,
        deletedBlacklistIds = deletedBlacklistIds,
        revBlacklists = self.db.revBlacklists or 0,
        lastBlacklistUpdateAt = self.db.lastBlacklistUpdateAt or 0,
    }, blacklistCount, deletionCount
end

function AuctionHouse:BuildPendingTransactionsDeltaState(requesterRevision, requesterTxns)
    local txnsToSend = {}
    local deletedTxnIds = {}
    local txnCount = 0
    local deletionCount = 0

    if not requesterRevision or requesterRevision < (self.db.revPendingTransactions or 0) then
        local requesterTxnLookup = {}
        for _, info in ipairs(requesterTxns or {}) do
            requesterTxnLookup[info.id] = info.rev
        end

        for id, txn in pairs(self.db.pendingTransactions or {}) do
            local requesterRev = requesterTxnLookup[id]
            if not requesterRev or (txn.rev > requesterRev) then
                txnsToSend[id] = txn
                txnCount = txnCount + 1
            end
        end

        for id, _ in pairs(requesterTxnLookup) do
            if not self.db.pendingTransactions or not self.db.pendingTransactions[id] then
                table.insert(deletedTxnIds, id)
                deletionCount = deletionCount + 1
            end
        end
    end

    return {
        v = 1,
        pendingTransactions = txnsToSend,
        deletedTxnIds = deletedTxnIds,
        revPendingTransactions = self.db.revPendingTransactions or 0,
        lastPendingTransactionUpdateAt = self.db.lastPendingTransactionUpdateAt or 0,
    }, txnCount, deletionCount
end

function AuctionHouse:RequestLatestConfig()
    self:BroadcastMessage(Addon:Serialize({ T_CONFIG_REQUEST, { version = AHConfigSaved.version } }))
end

function AuctionHouse:RequestOffsetGuildPoints(playerName, points, txId)
    self:SendDm(Addon:Serialize({ ns.T_SET_GUILD_POINTS, { points = points, txId=txId } }), playerName, "NORMAL")
end


function AuctionHouse:BuildAuctionsTable()
    local auctions = {}
    for id, auction in pairs(self.db.auctions) do
        table.insert(auctions, {id = id, rev = auction.rev})
    end
    return auctions
end

function AuctionHouse:BuildTradesTable()
    local trades = {}
    for id, trade in pairs(self.db.trades) do
        table.insert(trades, { id = id, rev = trade.rev })
    end
    return trades
end

function AuctionHouse:BuildRatingsTable()
    local ratings = {}
    for id, rating in pairs(self.db.ratings) do
        table.insert(ratings, { id = id, rev = rating.rev })
    end
    return ratings
end

function AuctionHouse:BuildDeathClipsTable(now)
    local allClips = ns.GetLiveDeathClips()
    local fromTs = now - ns.GetConfig().deathClipsSyncWindow
    local clips = {}
    for clipID, clip in pairs(allClips) do
        if clip.ts and clip.ts >= fromTs then
            clips[clipID] = true
        end
    end

    local payload = { fromTs = fromTs, clips = clips }
    return payload
end

-- Build a table of LFG entries for a request
function AuctionHouse:BuildLFGTable()
    local lfgEntries = {}
    for user, entry in pairs(self.db.lfg or {}) do
        table.insert(lfgEntries, { name = user, rev = entry.rev })
    end
    return lfgEntries
end

function AuctionHouse:BuildBlacklistTable()
    local blacklistEntries = {}
    for playerName, blacklist in pairs(self.db.blacklists or {}) do
        table.insert(blacklistEntries, { playerName = playerName, rev = blacklist.rev })
    end
    return blacklistEntries
end

function AuctionHouse:BuildPendingTransactionsTable()
    local pendingTxns = {}
    for id, txn in pairs(self.db.pendingTransactions or {}) do
        table.insert(pendingTxns, { id = id, rev = txn.rev })
    end
    return pendingTxns
end


function AuctionHouse:RequestLatestState()
    -- Reset ACK flags for a new request cycle.
    self.ackBroadcasted = false
    self.lastAckAuctionRevisions = {} -- Clear all ACKs when starting a new request

    local auctions = self:BuildAuctionsTable()
    local payload = { T_AUCTION_STATE_REQUEST, { revision = self.db.revision, auctions = auctions } }
    local msg = Addon:Serialize(payload)

    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestTradeState()
    local trades = self:BuildTradesTable()
    local payload = { ns.T_TRADE_STATE_REQUEST, { revTrades = self.db.revTrades, trades = trades } }
    local msg = Addon:Serialize(payload)

    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestRatingsState()
    local ratings = self:BuildRatingsTable()
    local payload = { ns.T_RATING_STATE_REQUEST, { revision = self.db.revRatings, ratings = ratings } }
    local msg = Addon:Serialize(payload)

    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestDeathClipState(now)
    local clips = self:BuildDeathClipsTable(now)
    local payload = { ns.T_DEATH_CLIPS_STATE_REQUEST, { since = ns.GetLastDeathClipTimestamp(), clips = clips } }
    local msg = Addon:Serialize(payload)
    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestLFGState()
    local lfgEntries = self:BuildLFGTable()
    local payload = { ns.T_LFG_STATE_REQUEST, { revLfg = self.db.revLfg or 0, lfgEntries = lfgEntries } }
    local msg = Addon:Serialize(payload)
    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestBlacklistState()
    local blacklistEntries = self:BuildBlacklistTable()
    local payload = {
        ns.T_BLACKLIST_STATE_REQUEST,
        { revBlacklists = self.db.revBlacklists or 0, blacklistEntries = blacklistEntries }
    }
    local msg = Addon:Serialize(payload)
    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestDeathClipReviewState()
    local payload = { ns.T_DEATH_CLIP_REVIEW_STATE_REQUEST, { rev = ns.GetDeathClipReviewState().persisted.rev } }
    local msg = Addon:Serialize(payload)
    self:BroadcastMessage(msg)
end

function AuctionHouse:RequestLatestPendingTransactionState()
    local pendingTransactions = self:BuildPendingTransactionsTable()
    local payload = { ns.T_PENDING_TRANSACTION_STATE_REQUEST, { revPendingTransactions = self.db.revPendingTransactions or 0, pendingTransactions = pendingTransactions } }
    local msg = Addon:Serialize(payload)
    self:BroadcastMessage(msg)
end

SLASH_atheneclear1 = "/atheneclear"
SlashCmdList["atheneclear"] = function(msg)
    AtheneClearPersistence()
end

function AtheneClearPersistence()
    ns.AuctionHouseAPI:ClearPersistence()
    print("Persistence cleared")
end

function AuctionHouse:RequestAddonVersion()
    local payload = { ns.T_ADDON_VERSION_REQUEST, { version = self.addonVersion } }
    local msg = Addon:Serialize(payload)
    self:BroadcastMessage(msg)
end
function AuctionHouse:GetLatestVersion()
    return ns.GetLatestVersion(knownAddonVersions)
end

function AuctionHouse:IsUpdateAvailable()
    local latestVersion = ns.GetLatestVersion(knownAddonVersions)
    return ns.CompareVersions(latestVersion, self.addonVersion) > 0
end

function AuctionHouse:IsImportantUpdateAvailable()
    local latestVersion = ns.GetLatestVersion(knownAddonVersions)
    return ns.CompareVersionsExclPatch(latestVersion, self.addonVersion) > 0
end


function AuctionHouse:OpenAuctionHouse()
    ns.TryExcept(
        function()
            if self:IsImportantUpdateAvailable() and not ns.ShowedUpdateAvailablePopupRecently() then
                ns.ShowUpdateAvailablePopup()
            else
                OFAuctionFrame:Show()
            end
        end,
        function(err)
            ns.DebugLog("[ERROR] Failed to open auction house", err)
            OFAuctionFrame:Show()
        end
    )
end

ns.GameEventHandler:On("PLAYER_REGEN_DISABLED", function()
    -- player entered combat, close the auction house to be safe
    if OFAuctionFrame:IsShown() then
        OFAuctionFrame:Hide()
    else
        OFCloseAuctionStaticPopups()
    end
    StaticPopup_Hide("OF_LEAVE_REVIEW")
    StaticPopup_Hide("OF_UPDATE_AVAILABLE")
    StaticPopup_Hide("OF_BLACKLIST_PLAYER_DIALOG")
    StaticPopup_Hide("OF_DECLINE_ALL")
    StaticPopup_Hide("GAH_MAIL_CANCEL_AUCTION")
end)

-- Function to clean up auctions and trades
function AuctionHouse:CleanupAuctionsAndTrades()
    local me = UnitName("player")

    -- cleanup auctions
    local auctions = API:QueryAuctions(function(auction)
        return auction.owner == me or auction.buyer == me
    end)
    for _, auction in ipairs(auctions) do
        if auction.status == ns.AUCTION_STATUS_SENT_LOAN then
            if auction.owner == me then
                API:MarkLoanComplete(auction.id)
            else
                API:DeclareBankruptcy(auction.id)
            end
        else
            API:DeleteAuctionInternal(auction.id)
        end
    end

    local trades = API:GetMyTrades()
    for _, trade in ipairs(trades) do
        if trade.auction.buyer == me then
            API:SetBuyerDead(trade.id)
        end
        if trade.auction.owner == me then
            API:SetSellerDead(trade.id)
        end
    end
end

local function playRandomDeathClip()
    if GetRealmName() ~= "Doomhowl" then
        return
    end

    local clipNum = random(1, 24)
    PlaySoundFile("Interface\\AddOns\\"..addonName.."\\Media\\DeathAudioClips\\death_" .. clipNum .. ".mp3", "Master")
end

ns.GameEventHandler:On("PLAYER_DEAD", function()
    print(ChatPrefix() .. " " .. L["removing auctions after death"])
    AuctionHouse:CleanupAuctionsAndTrades()
    playRandomDeathClip()
end)


local function cleanupIfKicked()
    if not IsInGuild() then
        print(ChatPrefix() .. " " .. L["removing auctions after gkick"])
        AuctionHouse:CleanupAuctionsAndTrades()
    end
end

ns.GameEventHandler:On("PLAYER_GUILD_UPDATE", function()
    -- Check guild status after some time, to make sure IsInGuild is accurate
    C_Timer:After(3, cleanupIfKicked)
end)
ns.GameEventHandler:On("PLAYER_ENTERING_WORLD", function()
    C_Timer:After(10, cleanupIfKicked)
end)


ns.AuctionHouseClass = AuctionHouse
ns.AuctionHouse = AuctionHouse.new(UnitName("player"))

function Addon:OnInitialize()
    ns.AuctionHouse:Initialize()
end