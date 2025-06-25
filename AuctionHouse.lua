local addonName, ns = ...
local L = ns.L

local Addon = LibStub("AceAddon-3.0"):NewAddon("AuctionHouse", "AceComm-3.0", "AceSerializer-3.0")
ns.AuctionHouseAddon = Addon
local LibDeflate = LibStub("LibDeflate")
local API = ns.AuctionHouseAPI

ns.MobNameByID = {}
ns.MobIDByName = {}

for i, mobName in ipairs(ns.MobNames) do
    ns.MobNameByID[i] = mobName
    ns.MobIDByName[mobName] = i
end

-- For debugging, print the generated tables (optional)
-- print("ns.MobNameByID = {")
-- for id, name in pairs(ns.MobNameByID) do
--     print(string.format("    [%d] = \"%s\",", id, name:gsub("\"", "\\\""))) -- Escape quotes in names
-- end
-- print("}")

-- print("\nns.MobIDByName = {")
-- for name, id in pairs(ns.MobIDByName) do
--     print(string.format("    [\"%s\"] = %d,", name:gsub("\"", "\\\""), id)) -- Escape quotes in names
-- end
-- print("}")

-- in Utils.lua (once):
ns.ClassNameByID = {
    [1] = "WARRIOR",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [7] = "SHAMAN",
    [8] = "MAGE",
    [9] = "WARLOCK",
    [11] = "DRUID",
}
ns.ClassIDByName = {}
for id, name in pairs(ns.ClassNameByID) do
    ns.ClassIDByName[name] = id
end

ns.DeathCauseByID = {
    [0] = "Усталость",
    [1] = "Утопление",
    [2] = "Падение",
    [3] = "Лава",
    [4] = "Слизь",
    [5] = "Огонь",
    [6] = "Падение в бездну",
    [7] = "существом", -- this one uses mob name instead
    [8] = "Умер в PVP схватке",
    [9] = "Погиб от действий союзника",
    [10] = "Погиб от собственных действий",
}

function ns.GetDeathCauseByID(id, mobName)
    if id == 7 and mobName and mobName ~= "" then
        return mobName
    else
        return ns.DeathCauseByID[id] or ("UnknownCause(" .. tostring(id) .. ")")
    end
end

ns.RaceInfoByID = {
    [1] = { name = "Человек", faction = "Alliance" },
    [2] = { name = "Орк", faction = "Horde" },
    [3] = { name = "Дворф", faction = "Alliance" },
    [4] = { name = "Ночной эльф", faction = "Alliance" },
    [5] = { name = "Нежить", faction = "Horde" },
    [6] = { name = "Таурен", faction = "Horde" },
    [7] = { name = "Гном", faction = "Alliance" },
    [8] = { name = "Тролль", faction = "Horde" },
    [9] = { name = "Гоблин", faction = "Horde" },
    [10] = { name = "Эльф крови", faction = "Horde" },
    [11] = { name = "Дреней", faction = "Alliance" },
    [12] = { name = "Ворген", faction = "Alliance" },
    [13] = { name = "Нага", faction = "Horde" },
    [14] = { name = "Пандарен", faction = "Alliance" },
    [15] = { name = "Высший эльф", faction = "Alliance" },
    [16] = { name = "Пандарен", faction = "Horde" },
    [17] = { name = "Ночноро\nждённый", faction = "Horde" },
    [18] = { name = "Эльф Бездны", faction = "Alliance" },
    [19] = { name = "Вульпера", faction = "Alliance" },
    [20] = { name = "Вульпера", faction = "Horde" },
    [21] = { name = "Вульпера", faction = "Neutral" },
    [22] = { name = "Пандарен", faction = "Neutral" },
    [23] = { name = "Зандалар", faction = "Horde" },
    [24] = { name = "Озар. дреней", faction = "Alliance" },
    [25] = { name = "Эредар", faction = "Horde" },
    [26] = { name = "Дворф Ч. Железа", faction = "Alliance" },
    [27] = { name = "Драктир", faction = "Horde" }
}

-- Build race name -> ID map for the sender
ns.RaceIDByName = {}
for id, info in pairs(ns.RaceInfoByID) do
    ns.RaceIDByName[info.name] = id
end

-- Helper: get race info by code
function ns.GetRaceInfoByID(id)
    return ns.RaceInfoByID[id] or { name = ("UnknownRace(%d)"):format(id), faction = nil }
end

-- Invert for sender: localized zone name → zoneID
ns.ZoneIDByName = {}
for id, name in pairs(ns.ZoneNameByID) do
    ns.ZoneIDByName[name] = id
end

-- Helper: lookup zone name from ID
function ns.GetZoneNameByID(id)
    return ns.ZoneNameByID[id] or ("Неизвестно(" .. tostring(id) .. ")")
end

-- ============================================================================
-- 2) Realm lookup: short key → numeric Blizzard realm ID
--    (from E_REALM_ID on Sirus / 3.3.5)
-- ============================================================================
-- exact Blizzard GetRealmName() → numeric Sirus ID
ns.RealmFullNameToID = {
    ["Soulseeker x1 - 3.3.5a+"] = 42,
    ["Sirus"] = 57,
    ["Neltharion"] = 21,
    ["Frostmourne"] = 16,
    ["Legacy x10"] = 5,
    ["Scourge"] = 9,
    ["Algalon"] = 33,
    -- add any other exact realm strings here
}

-- invert it: numeric ID → full Blizzard realm string
ns.RealmIDToFullName = {}
for fullname, id in pairs(ns.RealmFullNameToID) do
    ns.RealmIDToFullName[id] = fullname
end

-- helper: lookup ID → full name
function ns.GetRealmNameByID(id)
    return ns.RealmIDToFullName[id] or ("UnknownRealm(" .. tostring(id) .. ")")
end

-- backport from ClassicAPI by Tsoukie
local InitalGTPSCall
local function GetTimePreciseSec()
    local Time = GetTime()
    if InitalGTPSCall == nil then
        InitalGTPSCall = Time
    end
    return Time - InitalGTPSCall
end

--[[-----------------------------------------------------------------
  PROTOTYPE / EXPERIMENTAL NETWORK ISOLATION
  ---------------------------------------------------------------
  All AceComm traffic is namespaced by the *prefix* (max 16 chars).
  By appending a one-character protocol tag we ensure that only
  clients built from the same branch ("prototype A") will talk to
  each other.  Users on the public/stable release (old prefix
  "OFAuctionHouse") will silently ignore messages coming from this
  build and vice-versa – no risk of desync or Lua errors.

  Increase/alter the suffix whenever you introduce an incompatible
  wire-format change.  Keep the total length ≤16 characters.
-----------------------------------------------------------------]]

local PROTOTYPE_SUFFIX = "A"        -- change to "B", "C" … on next break
local COMM_PREFIX = "OFAuctionHouse" .. PROTOTYPE_SUFFIX  -- 14+1 = 15 ≤ 16
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
ns.T_LFG_DELETED = "LFG_DELETED"
ns.T_LFG_SYNCED = "LFG_SYNCED"
ns.T_ON_LFG_STATE_UPDATE = "OnLFGStateUpdate"
ns.T_LFG_STATE_REQUEST = "LFG_STATE_REQUEST"
ns.T_LFG_STATE = "LFG_STATE"

-- 1) Add new constants for BLACKLIST in the same style as LFG or trades.
local T_BLACKLIST_STATE_REQUEST = "BLACKLIST_STATE_REQUEST"
local T_BLACKLIST_STATE = "BLACKLIST_STATE"
local T_BLACKLIST_ADD_OR_UPDATE = "BLACKLIST_ADD_OR_UPDATE"
local T_BLACKLIST_DELETED = "BLACKLIST_DELETED"
local T_BLACKLIST_SYNCED = "BLACKLIST_SYNCED"
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
local T_PENDING_TRANSACTION_STATE = "PENDING_TRANSACTION_STATE"
local T_PENDING_TRANSACTION_ADD_OR_UPDATE = "PENDING_TRANSACTION_ADD_OR_UPDATE"
local T_PENDING_TRANSACTION_DELETED = "PENDING_TRANSACTION_DELETED"
local T_PENDING_TRANSACTION_SYNCED = "PENDING_TRANSACTION_SYNCED"

ns.T_PENDING_TRANSACTION_STATE_REQUEST = T_PENDING_TRANSACTION_STATE_REQUEST
ns.T_PENDING_TRANSACTION_STATE = T_PENDING_TRANSACTION_STATE
ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE = T_PENDING_TRANSACTION_ADD_OR_UPDATE
ns.T_PENDING_TRANSACTION_DELETED = T_PENDING_TRANSACTION_DELETED
ns.T_PENDING_TRANSACTION_SYNCED = T_PENDING_TRANSACTION_SYNCED
ns.T_ON_PENDING_TRANSACTION_STATE_UPDATE = "OnPendingTransactionStateUpdate"

local T_AUCTION_ACK = "AUCTION_ACK"
local T_TRADE_ACK = "TRADE_ACK"
local T_RATING_ACK = "RATING_ACK"
local T_LFG_ACK = "LFG_ACK"
local T_BLACKLIST_ACK = "BLACKLIST_ACK"
local T_PENDING_TRANSACTION_ACK = "PENDING_TRANSACTION_ACK"

ns.T_AUCTION_ACK = T_AUCTION_ACK
ns.T_TRADE_ACK = T_TRADE_ACK
ns.T_RATING_ACK = T_RATING_ACK
ns.T_LFG_ACK = T_LFG_ACK
ns.T_BLACKLIST_ACK = T_BLACKLIST_ACK
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
    --["Lenkomag"] = "Troll",
    --["Lenkomage"] = "Naga"
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
ns.EV_DEATH_CLIPS_CHANGED = "DEATH_CLIPS_CHANGED"
ns.EV_PLAYED_TIME_UPDATED = "EV_PLAYED_TIME_UPDATED"
--ns.T_ADMIN_UPDATE_CLIP_OVERRIDES = "ADMIN_UPDATE_CLIP_OVERRIDES"
ns.T_DEATH_CLIP_ADDED = "DEATH_CLIP_ADDED"

ns.T_DEATH_CLIP_REVIEW_STATE_REQUEST = "DEATH_CLIP_REVIEW_STATE_REQUEST"
ns.T_DEATH_CLIP_REVIEW_STATE = "DEATH_CLIP_REVIEW_STATE"
ns.T_DEATH_CLIP_REVIEW_UPDATED = "DEATH_CLIP_REVIEW_UPDATED"

-- version check
ns.T_ADDON_VERSION_REQUEST = "ADDON_VERSION_REQUEST"
ns.T_ADDON_VERSION_RESPONSE = "ADDON_VERSION_RESPONSE"

ns.T_SET_GUILD_POINTS = "SET_GUILD_POINTS"

-- Watched friend / resurrected notification
ns.T_WATCH_ADD_OR_UPDATE = "WATCH_ADD_OR_UPDATE"

local G, W = "GUILD", "WHISPER"

local CHANNEL_WHITELIST = {
    [ns.T_CONFIG_REQUEST] = { [G] = 1 },
    [ns.T_CONFIG_CHANGED] = { [W] = 1 },

    [ns.T_AUCTION_STATE_REQUEST] = { [G] = 1 },
    [ns.T_AUCTION_STATE] = { [W] = 1 },
    [ns.T_AUCTION_ADD_OR_UPDATE] = { [G] = 1 },
    [ns.T_AUCTION_DELETED] = { [G] = 1 },

    [ns.T_AUCTION_ACK] = { [G] = 1 },
    [ns.T_TRADE_ACK] = { [G] = 1 },
    [ns.T_RATING_ACK] = { [G] = 1 },
    [ns.T_LFG_ACK] = { [G] = 1 },
    [ns.T_BLACKLIST_ACK] = { [G] = 1 },
    [ns.T_PENDING_TRANSACTION_ACK] = { [G] = 1 },

    [ns.T_TRADE_STATE_REQUEST] = { [G] = 1 },
    [ns.T_TRADE_STATE] = { [W] = 1 },
    [ns.T_TRADE_ADD_OR_UPDATE] = { [G] = 1 },
    [ns.T_TRADE_DELETED] = { [G] = 1 },

    [ns.T_RATING_STATE_REQUEST] = { [G] = 1 },
    [ns.T_RATING_STATE] = { [W] = 1 },
    [ns.T_RATING_ADD_OR_UPDATE] = { [G] = 1 },
    [ns.T_RATING_DELETED] = { [G] = 1 },

    [ns.T_DEATH_CLIPS_STATE_REQUEST] = { [G] = 1 },
    [ns.T_DEATH_CLIPS_STATE] = { [W] = 1 },
    [ns.T_ADMIN_REMOVE_CLIP] = {}, --admin only
    [ns.T_DEATH_CLIP_REVIEW_STATE_REQUEST] = { [G] = 1 },
    [ns.T_DEATH_CLIP_REVIEW_STATE] = { [W] = 1 },
    [ns.T_DEATH_CLIP_REVIEW_UPDATED] = { [G] = 1 },
    --[ns.T_ADMIN_UPDATE_CLIP_OVERRIDES] = {}, --admin only
    [ns.T_DEATH_CLIP_ADDED] = { [G] = 1 },


    [ns.T_ADDON_VERSION_REQUEST] = { [G] = 1 },
    [ns.T_ADDON_VERSION_RESPONSE] = { [W] = 1 },

    -- LFG
    [ns.T_LFG_STATE_REQUEST] = { [G] = 1 },
    [ns.T_LFG_STATE] = { [W] = 1 },
    [ns.T_LFG_ADD_OR_UPDATE] = { [G] = 1 },
    [ns.T_LFG_DELETED] = { [G] = 1 },

    -- Blacklist
    [ns.T_BLACKLIST_STATE_REQUEST] = { [G] = 1 },
    [ns.T_BLACKLIST_STATE] = { [W] = 1 },
    [ns.T_BLACKLIST_ADD_OR_UPDATE] = { [G] = 1 },
    [ns.T_BLACKLIST_DELETED] = { [G] = 1 },

    [ns.T_SET_GUILD_POINTS] = { [W] = 1 },

    -- Pending transaction
    [ns.T_PENDING_TRANSACTION_DELETED] = { [G] = 1 },
    [ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE] = { [G] = 1 },
    [ns.T_PENDING_TRANSACTION_STATE_REQUEST] = { [G] = 1 },
    [ns.T_PENDING_TRANSACTION_STATE] = { [W] = 1 },
    -- Watched friends sync
    [ns.T_WATCH_ADD_OR_UPDATE] = { [G] = 1 },
}

-- make isMessageAllowed use name-only
local function getFullName(unitName)
    return unitName   -- since UnitName("player") is just the name
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

    -- Cache for players we recently detected as offline when whispering. key -> expireTime (GetTime())
    instance._offlineWhisperCache = {}
    -- Helper vars for temporarily suppressing the next PLAYER_NOT_FOUND system message
    instance._pendingWhisperTarget = nil
    instance._pendingWhisperTs = 0

    -- Initialize ack broadcast flags for various state types
    instance.ackBroadcasted = false
    instance.tradeAckBroadcasted = false
    instance.ratingAckBroadcasted = false
    instance.lfgAckBroadcasted = false
    instance.blacklistAckBroadcasted = false
    instance.pendingTransactionAckBroadcasted = false

    -- Track ongoing bulk sync sessions (recipient -> expiryTimestamp)
    instance._activeSyncSessions = {}

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
        -- AUCTIONS ---------------------------------------------------------------
        broadcastAuctionUpdate = function(dataType, payload)
            -- Only ship auctions from my realm
            if dataType == ns.T_AUCTION_DELETED then
                -- For deletions, payload is just auctionID - always broadcast
                self:BroadcastAuctionUpdate(dataType, payload)
            elseif payload.auction and payload.auction.realm == ns.CURRENT_REALM then
                self:BroadcastAuctionUpdate(dataType, payload)
            end
        end,

        -- TRADES -----------------------------------------------------------------
        broadcastTradeUpdate = function(dataType, payload)
            -- Trades inherit the auction's realm when they are created
            if payload.trade and payload.trade.realm == ns.CURRENT_REALM then
                self:BroadcastTradeUpdate(dataType, payload)
            end
        end,

        -- RATINGS ---------------------------------------------------------------
        broadcastRatingUpdate = function(dataType, payload)
            -- Ratings reference a trade → same realm flag
            if payload.rating and payload.rating.realm == ns.CURRENT_REALM then
                self:BroadcastRatingUpdate(dataType, payload)
            end
        end,

        -- LFG POSTS --------------------------------------------------------------
        broadcastLFGUpdate = function(dataType, payload)
            -- LFG posts are always realm-scoped by design, keep the symmetry
            if dataType == ns.T_LFG_DELETED then
                -- For LFG deletions, payload is just player name - always broadcast
                self:BroadcastLFGUpdate(dataType, payload)
            elseif payload.lfg and payload.lfg.realm == ns.CURRENT_REALM then
                self:BroadcastLFGUpdate(dataType, payload)
            end
        end,

        -- BLACKLIST --------------------------------------------------------------
        broadcastBlacklistUpdate = function(dataType, payload)
            -- Blacklist entries carry the offending player's realm
            -- For Speed Clips removal, payload doesn't have 'entry' field, check realm directly
            if payload.realm == ns.CURRENT_REALM then
                self:BroadcastBlacklistUpdate(dataType, payload)
            end
        end,

        -- PENDING TRANSACTIONS ---------------------------------------------------
        broadcastPendingTransactionUpdate = function(dataType, payload)
            -- Same guard for buy/sell confirmation messages
            if payload.transaction and payload.transaction.realm == ns.CURRENT_REALM then
                self:BroadcastPendingTransactionUpdate(dataType, payload)
            end
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
        --print("SENDING REVIEW", payload.review and payload.review.id)
        self:BroadcastMessage(Addon:Serialize({ ns.T_DEATH_CLIP_REVIEW_UPDATED, { review = payload.review } }))
    end)
    --clipReviewState:RegisterEvent(ns.EV_DEATH_CLIP_OVERRIDE_UPDATED, function(payload)
    --    if payload.fromNetwork then
    --        return
    --    end
    --    self:BroadcastMessage(Addon:Serialize({ ns.T_ADMIN_UPDATE_CLIP_OVERRIDES, { clipID = payload.clipID, overrides = payload.overrides } }))
    --end)

    -- Initialize UI
    ns.TradeAPI:OnInitialize()
    ns.MailboxUI:Initialize()
    ns.AuctionAlertWidget:OnInitialize()
    OFAuctionFrameReviews_Initialize()
    LfgUI_Initialize()
    SettingsUI_Initialize()
    OFAtheneUI_Initialize()

    -- === SPEED_CLIPS: PlayedTime Tracking ===
    -- Register for TIME_PLAYED_MSG event
    if not self.frame then
        self.frame = CreateFrame("Frame")
    end
    self.frame:RegisterEvent("TIME_PLAYED_MSG")
    self.frame:RegisterEvent("PLAYER_LOGOUT")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        if event == "TIME_PLAYED_MSG" then
            local totalTimePlayed, levelTimePlayed = ...
            if ns.AuctionHouse and ns.AuctionHouse.OnTimePlayedUpdate then
                ns.AuctionHouse:OnTimePlayedUpdate(event, totalTimePlayed, levelTimePlayed)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Request played time immediately when entering world (don't wait 5 minutes)
            --print("[DEBUG] Player entering world - requesting played time immediately")
            -- Small delay to ensure player data is ready
            C_Timer:After(2, function()
                if UnitIsConnected("player") then
                    if ns.SuppressTimePlayedMessages then ns.SuppressTimePlayedMessages() end
                    RequestTimePlayed()
                    C_Timer:After(1, function()
                        if ns.AllowTimePlayedMessages then ns.AllowTimePlayedMessages() end
                    end)
                end
            end)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            -- Update played time when entering new zones (important for location tracking)
            --print("[DEBUG] Zone changed - updating played time")
            if UnitIsConnected("player") then
                if ns.SuppressTimePlayedMessages then ns.SuppressTimePlayedMessages() end
                RequestTimePlayed()
                C_Timer:After(1, function()
                    if ns.AllowTimePlayedMessages then ns.AllowTimePlayedMessages() end
                end)
            end
        elseif event == "PLAYER_LOGOUT" then
            if ns.playedTimeUpdateTicker then
                ns.playedTimeUpdateTicker:Cancel()
                ns.playedTimeUpdateTicker = nil
            end
            -- Cleanup played time simulations
            if ns.CleanupPlayedTimeSimulations then
                ns.CleanupPlayedTimeSimulations()
            end
        end
    end)

    -- Periodically request played time every 5 minutes
    if ns.playedTimeUpdateTicker then
        ns.playedTimeUpdateTicker:Cancel()
    end
    ns.playedTimeUpdateTicker = C_Timer:NewTicker(300, function()
        if UnitIsConnected("player") then
            if ns.SuppressTimePlayedMessages then ns.SuppressTimePlayedMessages() end
            RequestTimePlayed()
            C_Timer:After(1, function()
                if ns.AllowTimePlayedMessages then ns.AllowTimePlayedMessages() end
            end)
        end
    end)

    local age = time() - ns.AuctionHouseDB.lastUpdateAt
    local auctions = ns.AuctionHouseDB.auctions
    local auctionCount = 0
    for _ in pairs(ns.FilterAuctionsThisRealm(auctions)) do
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
    SlashCmdList["GAH"] = function(msg)
        self:OpenAuctionHouse()
    end

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
        C_Timer:After(0.5, function()
            OFAuctionFrame_OverrideInitialTab(ns.AUCTION_TAB_BROWSE)
            OFAuctionFrame:Show()
        end)
    end

    self.ignoreSenderCheck = false

    -- ---------------------------------------------------------------------
    -- Spam-suppression: filter the system error that appears when trying to
    -- whisper an offline character ("Персонаж по имени \"X\" в игре не найден.").
    -- We only suppress the line if it matches the very last whisper target we
    -- attempted from SendDm and that attempt happened very recently (< 2s).
    -- When such a line is detected we also mark the target as offline for the
    -- next 3 minutes so future SendDm calls are short-circuited.
    -- ---------------------------------------------------------------------
    if not self._playerNotFoundFilterRegistered then
        local function PlayerNotFoundFilter(chatFrame, event, msg, ...)
            if not msg then return false end

            -- Try to extract the player name from common RU / EN variants.
            local player = msg:match("Персонаж по имени \"([^\"]+)\"")
            if not player then
                player = msg:match("Player '([^']+)' not found")
            end
            if not player then
                return false
            end

            -- Suppress if player is already known offline OR if we just attempted whisper
            local now = GetTime()
            
            -- Check if player is already in offline cache
            if ns.AuctionHouse and ns.AuctionHouse._offlineWhisperCache[player] then
                local ttl = ns.AuctionHouse._offlineWhisperCache[player]
                if ttl > now then
                    return true -- suppress - we know they're offline
                end
            end
            
            -- Check if we have active sync session with this player
            if ns.AuctionHouse and ns.AuctionHouse._activeSyncSessions and ns.AuctionHouse._activeSyncSessions[player] then
                local sessionEnd = ns.AuctionHouse._activeSyncSessions[player]
                if sessionEnd > now then
                    -- Mark as offline for 3 minutes
                    ns.AuctionHouse._offlineWhisperCache[player] = now + 180
                    return true  -- suppress message
                end
            end
            
            return false -- let it through
        end

        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", PlayerNotFoundFilter)
        self._playerNotFoundFilterRegistered = true
    end
    
    -- Global handler for Speed Clips removal requests (works in background)
    local function HandleSpeedClipsRemovalRequest(event)
        if event and event.blType == ns.BLACKLIST_TYPE_SPEED_CLIPS_REMOVAL then
            local names = event.names or {}
            local ownerName = event.playerName
            
            -- Track previous state for this owner to detect removals
            if not ns._speedClipsBlacklistState then
                ns._speedClipsBlacklistState = {}
            end
            
            local previousNames = ns._speedClipsBlacklistState[ownerName] or {}
            local currentNames = {}
            
            -- Convert current names to lookup table
            for _, playerName in ipairs(names) do
                currentNames[playerName] = true
            end
            
            -- Process additions (players now in blacklist = opt-out)
            for _, playerName in ipairs(names) do
                if not previousNames[playerName] then
                    -- Player was added to opt-out
                    local removed = ns.RemovePlayerFromSpeedClips and ns.RemovePlayerFromSpeedClips(playerName) or 0
                    if ns.SpeedClipsOptedOut then
                        ns.SpeedClipsOptedOut[playerName] = true
                    end
                    if removed > 0 then
                        print(string.format("Удален %s (%d клипов) из Speed Clips по их запросу.", playerName, removed))
                    end
                end
            end
            
            -- Process removals (players no longer in blacklist = opt-in)
            for playerName, _ in pairs(previousNames) do
                if not currentNames[playerName] then
                    -- Player was removed from opt-out (opted back in)
                    -- Restore clips from archive if available
                    local restoredCount = 0
                    if ns.RestorePlayerSpeedClips then
                        restoredCount = ns.RestorePlayerSpeedClips(playerName)
                    else
                        -- Fallback: just clear opt-out status
                        if ns.SpeedClipsOptedOut then
                            ns.SpeedClipsOptedOut[playerName] = nil
                        end
                        -- Trigger UI update
                        ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
                    end
                    
                    if restoredCount > 0 then
                        print(string.format("%s восстановил участие в Speed Clips (%d клипов)", ns.GetDisplayName(playerName), restoredCount))
                    else
                        print(string.format("%s восстановил участие в Speed Clips", ns.GetDisplayName(playerName)))
                    end
                end
            end
            
            -- Update state tracking
            ns._speedClipsBlacklistState[ownerName] = currentNames
        end
    end
    
    -- Register the handler immediately after initialization
    ns.AuctionHouseAPI:RegisterEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, HandleSpeedClipsRemovalRequest)
 end

function AuctionHouse:BroadcastMessage(message)
    local channel = "GUILD"
    Addon:SendCommMessage(COMM_PREFIX, message, channel)
    return true
end

function AuctionHouse:SendDm(message, recipient, prio)
    -- Lightweight spam-suppression for offline whisper targets.
    -- 1) If we recently detected that the recipient is offline, skip the send entirely
    local now = GetTime()
    local ttl = self._offlineWhisperCache[recipient]
    if ttl and ttl > now then
        return -- skip: we know the player is offline, avoid chat spam
    end

    -- If this is part of a bulk sync, extend/mark an active sync session window
    if prio == "BULK" then
        -- Keep the session active for up to 15 minutes after the last BULK whisper
        self._activeSyncSessions[recipient] = now + 900 -- 900s = 15min
    end

    -- 2) Remember that we're about to whisper this target so the CHAT_MSG_SYSTEM
    --    filter can suppress the inevitable "player not found" line (if any).
    self._pendingWhisperTarget = recipient
    self._pendingWhisperTs = now

    -- 3) Fire the whisper. Any system-level "player not found" will be filtered
    --    in the message filter registered during Initialise().
    pcall(function()
        Addon:SendCommMessage(COMM_PREFIX, message, "WHISPER", recipient, prio)
    end)
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

function AuctionHouse:TrimAuctionForSync(auction)
    -- Create a copy to avoid modifying original
    local trimmed = {}
    for k, v in pairs(auction) do
        trimmed[k] = v
    end
    
    -- WHITE-LIST: Remove only fields that are safe to omit
    -- Based on code analysis - these fields are checked with nil-safe patterns
    
    if trimmed.roleplay == false then
        trimmed.roleplay = nil
    end
    
    if trimmed.deathRoll == false then
        trimmed.deathRoll = nil
    end
    
    if trimmed.duel == false then
        trimmed.duel = nil
    end
    
    -- Remove numeric fields with default/zero values
    if trimmed.priceType == 0 then
        trimmed.priceType = nil
    end
    
    if trimmed.deliveryType == 0 then
        trimmed.deliveryType = nil
    end
    
    if trimmed.raidAmount == 0 then
        trimmed.raidAmount = nil
    end
    
    if trimmed.points == 0 then
        trimmed.points = nil
    end
    
    if trimmed.allowLoan == false then
        trimmed.allowLoan = nil
    end
    
    if trimmed.wish == false then
        trimmed.wish = nil
    end
    
    if trimmed.note == "" then
        trimmed.note = nil
    end
    
    if trimmed.buyer == nil then
        trimmed.buyer = nil -- already nil, but explicit for clarity
    end
    
    return trimmed
end

function AuctionHouse:SendAuctionStateChunked(responsePayload, recipient, auctionCount, deletionCount)
    --
    --  NEW IMPLEMENTATION (mirrors Death-Clips approach):
    --  ----------------------------------------------------
    --  • Split the Lua table itself into smaller tables (by number of auctions)
    --  • Each chunk is compressed *individually* so that the receiver can
    --    deserialize and apply updates as soon as the first chunk arrives.
    --  • The last chunk additionally carries the deletedAuctionIds list so the
    --    receiver can prune state incrementally as well.
    --

    local CHUNK_AUCTIONS = 50        -- ≈ payload size ~1.5-2KB with typical auction table
    local auctionIDs = {}
    for id, _ in pairs(responsePayload.auctions or {}) do
        auctionIDs[#auctionIDs + 1] = id
    end
    table.sort(auctionIDs)

    local totalChunks = math.max(1, math.ceil(#auctionIDs / CHUNK_AUCTIONS))
    local chunkIndex  = 1

    -- diagnostic
    self.benchDebugCounter = (self.benchDebugCounter or 0) + 1
    local dbgID     = self.benchDebugCounter
    local syncStart = GetTime()

    local function sendNext()
        -- slice the auction IDs for this chunk
        local i1 = (chunkIndex - 1) * CHUNK_AUCTIONS + 1
        local iN = math.min(chunkIndex * CHUNK_AUCTIONS, #auctionIDs)

        local auctionsChunk = {}
        for i = i1, iN do
            local aID = auctionIDs[i]
            auctionsChunk[aID] = responsePayload.auctions[aID]
        end

        -- Only include deletions on the last chunk to avoid duplicates
        local deletionsChunk = {}
        if chunkIndex == totalChunks then
            deletionsChunk = responsePayload.deletedAuctionIds or {}
        end

        -- Build the per-chunk state table (keep same revision fields)
        local chunkState = {
            v                 = responsePayload.v,
            auctions          = auctionsChunk,
            deletedAuctionIds = deletionsChunk,
            revision          = responsePayload.revision,
            lastUpdateAt      = responsePayload.lastUpdateAt,
        }

        -- Compress & encode this chunk
        local serialized = Addon:Serialize(chunkState)
        local compressed = LibDeflate:CompressDeflate(serialized, { level = 1 })
        local encoded    = LibDeflate:EncodeForWoWAddonChannel(compressed)

        local outerPayload = {
            label = ("chunk_%dof%d"):format(chunkIndex, totalChunks),
            data  = encoded,
        }

        self:SendDm(Addon:Serialize({ T_AUCTION_STATE, outerPayload }), recipient, "BULK")

        -- Next
        chunkIndex = chunkIndex + 1
        if chunkIndex <= totalChunks then
            C_Timer:After(0.05, sendNext)
        else
            local dt = GetTime() - syncStart
            print(("[AUCTION-%d] sync completed: %d auctions → %d chunks, took %.2f s")
                    :format(dbgID, auctionCount, totalChunks, dt))
        end
    end

    -- Fast-path: tiny payloads (≤ CHUNK_AUCTIONS) will still run through the
    -- same flow which results in a single chunk – keeps the code simple.
    sendNext()
end

function AuctionHouse:IsSyncWindowExpired()
    -- safety: only allow initial state within 2 minutes after login (chat can be very slow due to ratelimit, so has to be high)
    -- just in case there's a bug we didn't anticipate
    return GetTime() - self.initAt > 120
end

-- Helper: a random delay biased toward the higher end.
local function randomBiasedDelay(min, max)
    -- Using an exponent to skew the result toward 'max'
    return min + (max - min) * (math.random() ^ (1 / 3))
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
    --print(message .. sender)
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
        local delay = randomBiasedDelay(1, 4)
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
    --print(message..sender)
    -- disallow whisper messages from outside the guild to avoid bad actors to inject malicious data
    -- this means that early on during login we might discard messages from guild members until the guild roaster is known.
    -- however, since we sync the state with the guild roaster on login this shouldn't be a problem.
    if not self.ignoreSenderCheck and distribution == "GUILD" and not ns.IsGuildMember(sender) then
        return
    end

    -- handle OF-specific prefix first
    if prefix == OF_COMM_PREFIX then
        ns.HandleOFCommMessage(message, sender, distribution)
        return
    end

    -- only handle our addon's COMM_PREFIX from here
    if prefix ~= COMM_PREFIX then
        return
    end
    if sender == UnitName("player") and not self.ignoreSenderCheck then
        return
    end

    -- ==== DESERIALIZE: either compressed "DF:" payload or raw ====
    local dataType, payload

    if message:sub(1, 3) == "DF:" then
        local deflated = message:sub(4)

        -- decode Base64 → compressed bytes
        local compressed = LibDeflate:DecodeForWoWAddonChannel(deflated)
        if type(compressed) ~= "string" then
            ChatFrame1:AddMessage("!DBG: DecodeForWoWAddonChannel failed")
            return
        end

        -- decompress → serialized JSON string
        local serialized = LibDeflate:DecompressDeflate(compressed)
        if type(serialized) ~= "string" then
            ChatFrame1:AddMessage("!DBG: DecompressDeflate failed")
            return
        end

        -- deserialize → Lua table { dataType, payload }
        local ok, tbl = Addon:Deserialize(serialized)
        if not ok then
            ChatFrame1:AddMessage("!DBG: Deserialize failed")
            return
        end

        dataType = tbl[1]
        payload = tbl[2]

    else
        -- legacy, raw path for everything else
        local ok, tbl = Addon:Deserialize(message)
        if not ok then
            ChatFrame1:AddMessage("!DBG: Deserialize(raw) failed")
            return
        end
        dataType = tbl[1]
        payload = tbl[2]
    end

    ns.DebugLog("[DEBUG]", self.playerName, "recv", dataType, sender)
    if not isMessageAllowed(sender, distribution, dataType) then
        ns.DebugLog("[DEBUG] Ignoring message from", sender, "of type", dataType, "in channel", distribution)
        return
    end

    -- Auction
    if dataType == T_AUCTION_ADD_OR_UPDATE then
        API:UpdateDB(payload)
        API:FireEvent(ns.T_AUCTION_ADD_OR_UPDATE, { auction = payload.auction, source = payload.source })

    elseif dataType == T_AUCTION_DELETED then
        API:DeleteAuctionInternal(payload, true)
        API:FireEvent(ns.T_AUCTION_DELETED, payload)

        -- Trades
    elseif dataType == ns.T_TRADE_ADD_OR_UPDATE then
        API:UpdateDBTrade({ trade = payload.trade })
        API:FireEvent(ns.T_TRADE_ADD_OR_UPDATE, { auction = payload.auction, source = payload.source })

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
        print(("DBG: Received AUCTION_STATE_REQUEST from %s - their_rev=%d, our_rev=%d, their_auctions=%d"):format(
            sender, payload.revision or 0, self.db.revision or 0, #(payload.auctions or {})
        ))
        self:HandleStateUpdate(sender, T_AUCTION_STATE_REQUEST, {
            rev = self.db.revision,
            payloadRev = payload.revision,
            getLastAck = function(sender)
                return self.lastAckAuctionRevisions[sender]
            end,
            setLastAck = function(sender, value)
                self.lastAckAuctionRevisions[sender] = value
            end
        }, function()
            local responsePayload, auctionCount, deletionCount = self:BuildDeltaState(payload.revision, payload.auctions)
            print((" >> DEBUG: Sending %d auctions, %d deletions to %s"):format(auctionCount, deletionCount, sender))
            
            -- Chunked sending for large auction payloads
            self:SendAuctionStateChunked(responsePayload, sender, auctionCount, deletionCount)
        end)

    elseif dataType == T_AUCTION_STATE then
        -- Handle both chunked and non-chunked formats
        local decompressed, label
        
        if type(payload) == "table" and payload.label then
            -- New progressive-sync format (each chunk is self-contained)
            label = payload.label
            local compressed = LibDeflate:DecodeForWoWAddonChannel(payload.data)
            if not compressed then return end

            -- Attempt to decompress this chunk directly. If it succeeds, we are on
            -- the new format and can apply the delta immediately. If it fails, we
            -- fall back to the legacy accumulation logic further below.
            local tryDecomp = LibDeflate:DecompressDeflate(compressed)
            if tryDecomp then
                local ok, partial = Addon:Deserialize(tryDecomp)
                if ok and type(partial) == "table" then
                    -- Merge auctions
                    for id, auction in pairs(partial.auctions or {}) do
                        local prev = self.db.auctions[id]
                        self.db.auctions[id] = auction

                        if not prev then
                            API:FireEvent(ns.T_AUCTION_SYNCED, { auction = auction, source = "create" })
                        elseif prev.rev ~= auction.rev or prev.status ~= auction.status then
                            API:FireEvent(ns.T_AUCTION_SYNCED, { auction = auction })
                        end
                    end

                    -- Handle deletions
                    for _, id in ipairs(partial.deletedAuctionIds or {}) do
                        self.db.auctions[id] = nil
                    end

                    -- Only bump revision on the last chunk (to avoid prematurely claiming full sync)
                    local allowRevisionBump = true
                    if label then
                        local cNum, cTot = label:match("chunk_(%d+)of(%d+)")
                        cNum, cTot = tonumber(cNum), tonumber(cTot)
                        if cNum and cTot and cNum < cTot then
                            allowRevisionBump = false -- not the final chunk yet
                        end
                    end
                    if allowRevisionBump and partial.revision and partial.revision > (self.db.revision or 0) then
                        self.db.revision     = partial.revision
                        self.db.lastUpdateAt = partial.lastUpdateAt
                    end

                    API:FireEvent(ns.T_ON_AUCTION_STATE_UPDATE)

                    -- ACK once per sync (flag prevents duplicates)
                    self:BroadcastAck(ns.T_AUCTION_ACK, self.db.revision, false, "ackBroadcasted")

                    -- Determine if this was the final chunk – purely for bench logs
                    local cNum, cTot = label:match("chunk_(%d+)of(%d+)")
                    if tonumber(cNum) == tonumber(cTot) then
                        -- Final chunk processed – nothing else to do
                    end

                    return -- done with this chunk
                end
            end

            -- === Legacy flow (one compressed stream split over multiple raw chunks) ===
            -- Keep the original accumulation logic for backwards-compat.
            self.auctionChunkBuffer            = self.auctionChunkBuffer or {}
            self.auctionChunkBuffer[sender]    = self.auctionChunkBuffer[sender] or {}
            local buffer = self.auctionChunkBuffer[sender]

            local chunkNum, totalChunks = label:match("chunk_(%d+)of(%d+)")
            chunkNum, totalChunks = tonumber(chunkNum), tonumber(totalChunks)
            if not chunkNum or not totalChunks then return end

            buffer.chunks           = buffer.chunks or {}
            buffer.chunks[chunkNum] = compressed
            buffer.totalChunks      = totalChunks
            if #buffer.chunks < totalChunks then return end

            -- reconstruct full compressed payload
            local fullCompressed = ""
            for i=1,totalChunks do fullCompressed = fullCompressed .. (buffer.chunks[i] or "") end

            decompressed = LibDeflate:DecompressDeflate(fullCompressed)
            if not decompressed then return end

            local ok, merged = Addon:Deserialize(decompressed)
            if not ok then return end

            self.auctionChunkBuffer[sender] = nil -- cleanup legacy buffer

            state = merged
        else
            -- Legacy single-chunk format 
            decompressed = LibDeflate:DecompressDeflate(payload)
            
            if not decompressed then
                return
            end

            local success, singleState = Addon:Deserialize(decompressed)
            if not success then
                return
            end
            
            state = singleState
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
                    API:FireEvent(ns.T_AUCTION_SYNCED, { auction = auction, source = "create" })

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

                    API:FireEvent(ns.T_AUCTION_SYNCED, { auction = auction, source = source })
                else
                    -- unknown update reason (source)
                    API:FireEvent(ns.T_AUCTION_SYNCED, { auction = auction })
                end
            end

            -- Delete auctions that are no longer valid
            for _, id in ipairs(state.deletedAuctionIds or {}) do
                self.db.auctions[id] = nil
            end

            self.db.revision = state.revision
            self.db.lastUpdateAt = state.lastUpdateAt

            API:FireEvent(ns.T_ON_AUCTION_STATE_UPDATE)

            ns.DebugLog(string.format("[DEBUG] Updated local state with %d new auctions, %d deleted auctions, revision %d",
                    #(state.auctions or {}), #(state.deletedAuctionIds or {}),
                    self.db.revision
            ))
        end

        -- Broadcast an ACK on the guild channel
        self:BroadcastAck(ns.T_AUCTION_ACK, self.db.revision, isHigherRevision, "ackBroadcasted")

        -- ── AUCTION BENCHMARK END ──
        local entry = table.remove(self.auctionBenchQueue or {}, 1)
        if entry then
            local elapsed = GetTime() - entry.start
            print(("|cff00ff00>> [AUCTION-%d] sync completed at %s (took %.2f s)|r"):format(
                entry.id, date("%H:%M"), elapsed
            ))
        end

        -- Added hook call so that (for example) tests can capture state response data:
        if self.OnStateResponseHandled then
            self:OnStateResponseHandled(sender, state)
        end

    elseif dataType == T_CONFIG_REQUEST then
        if AHConfigSaved and payload.version < AHConfigSaved.version then
            self:SendDm(Addon:Serialize({ T_CONFIG_CHANGED, AHConfigSaved }), sender, "BULK")
        end


        -- === Sender: T_DEATH_CLIPS_STATE_REQUEST ===
    elseif dataType == ns.T_DEATH_CLIPS_STATE_REQUEST then
        local since = payload.since
        local clips = payload.clips or {}
        --print(("🔍DBG: Payload since TS = %s, have %d clip-IDs"):format(
        --        tostring(since), #clips
        --))

        local rawClips = ns.GetNewDeathClips(since, clips)
        --print((" >> DEBUG: %d death-clips to sync"):format(#rawClips))
        if #rawClips == 0 then
            return
        end

        -- sort by ts (sync newest→old)
        table.sort(rawClips, function(a, b)
            return (a.ts or 0) > (b.ts or 0)
        end)

        -- precompute our realm
        local fullRealm = GetRealmName() or ""
        local realmID = ns.RealmFullNameToID[fullRealm] or 0

        -- build all rows
        local rows = {}
        for i, c in ipairs(rawClips) do
            local ts = c.ts or 0

            -- strip color from mob name
            local mobName = (c.deathCause or "")
                    :gsub("|c%x%x%x%x%x%x%x%x", "")
                    :gsub("|r", "")

            -- determine causeCode
            local causeCode
            if c.deathCause == "ALIVE" then
                causeCode = "A"
            else
                causeCode = 7
                for id, text in pairs(ns.DeathCauseByID) do
                    if id ~= 7 and c.deathCause:find(text, 1, true) then
                        causeCode = id
                        break
                    end
                end
            end
            local mobData
            if causeCode == 7 and mobName ~= "" then
                mobData = ns.MobIDByName[mobName] or mobName
            else
                mobData = ""
            end

            -- zone → ID + fallback string
            local zid = ns.ZoneIDByName[c.where] or 0
            local rawZone = (zid > 0) and nil or (c.where or "")

            -- faction → code
            local facCode = (c.faction == "Alliance" and 1)
                    or (c.faction == "Horde" and 2)
                    or 3

            -- race & class codes
            local raceCode = ns.RaceIDByName[c.race] or 0
            local classCode = ns.ClassIDByName[c.class] or 0

            -- read the raw mobLevel field directly
            local mobLevelNum = c.mobLevel or 0

            -- build the row
            local row = {
                c.characterName or "", -- [1]
                ts,                     -- [2]
                classCode,              -- [3]
                c.completed and 0 or causeCode, -- [4]
                raceCode,               -- [5]
                c.completed and 0 or zid,       -- [6]
                facCode,                -- [7]
                realmID,                -- [8]
                c.level or 0,           -- [9]
                c.getPlayedTry or 0,    -- [10]
                tonumber(c.playedTime) or nil, -- [11]
                (not c.completed) and mobData or "", -- [12]
                mobLevelNum,            -- [13]
                c.completed or nil,     -- [14]
            }

            -- optional zone + realm strings
            local idx = 15
            if (not c.completed) and row[6] == 0 and rawZone then
                row[idx] = rawZone
                idx = idx + 1
            end
            if (not c.completed) and row[8] == 0 and fullRealm then
                row[idx] = fullRealm
            end

            rows[i] = row
        end

        -- Debug: pretty-print one RAW 'rows' entry
        local function DebugDumpClipArr(arr)
            local labels = {
                "name","ts","classID","causeID","raceID",
                "zoneID","factionID","realmID","level",
                "getPlayedTry","playedTime","mobName",
                "mobLevel","completed","zoneName","realmName",
            }
            local parts = {}
            for i = 1, #arr do
                parts[i] = labels[i] .. "=" .. tostring(arr[i])
            end
            --print("SEND-RAW {" .. table.concat(parts, ", ") .. "}")
        end
        local debugShown = 0
        for _, arr in ipairs(rows) do
            if debugShown < 100 then
                DebugDumpClipArr(arr)
                debugShown = debugShown + 1
            end
        end

        -- batching setup
        local CHUNK_SIZE = 100
        local batchAfter = 0
        local totalChunks = math.ceil(#rows / CHUNK_SIZE)
        local chunkIndex = 1
        local syncStart, totalSer, totalComp = GetTime(), 0, 0

        local function sendNext()
            local i1 = (chunkIndex - 1) * CHUNK_SIZE + 1
            local iN = math.min(chunkIndex * CHUNK_SIZE, #rows)
            local chunkRows = {}
            for i = i1, iN do
                chunkRows[#chunkRows+1] = rows[i]
            end

            local ser = Addon:Serialize(chunkRows)
            local comp = LibDeflate:CompressDeflate(ser, { level = 1 })
            totalSer = totalSer + #ser
            totalComp = totalComp + #comp

            local payload = {
                label = ("chunk_%dof%d"):format(chunkIndex, totalChunks),
                data  = LibDeflate:EncodeForWoWAddonChannel(comp),
            }
            self:SendDm(Addon:Serialize({ ns.T_DEATH_CLIPS_STATE, payload }), sender, "BULK")

            -- cleanup
            chunkRows, ser, comp = nil, nil, nil
            collectgarbage("step")

            chunkIndex = chunkIndex + 1
            if chunkIndex <= totalChunks then
                C_Timer:After(batchAfter, sendNext)
            else
                local dt = GetTime() - syncStart
                --print((" >> DEBUG: serialized rows = %d bytes"):format(totalSer))
                --print((" >> DEBUG: compressed rows = %d bytes (Level 1)"):format(totalComp))
                --print((" >> DEBUG: sent %d clips in %d chunks, took %.2f s total"):format(#rows, totalChunks, dt))
            end
        end
        sendNext()


        -- === Receiver: T_DEATH_CLIPS_STATE ===
    elseif dataType == ns.T_DEATH_CLIPS_STATE then
        ------------------------------------------------------------------
        -- 0) extract compressed + label
        ------------------------------------------------------------------
        local compressed, label
        if type(payload) == "table" then
            label      = payload.label                 -- e.g. "chunk_3of12"
            compressed = LibDeflate:DecodeForWoWAddonChannel(payload.data)
        else
            compressed = payload
        end
        if type(compressed) ~= "string" then
            return
        end

        ------------------------------------------------------------------
        -- 1) decompress & deserialize
        ------------------------------------------------------------------
        local decompressed = LibDeflate:DecompressDeflate(compressed)
        local ok, rows     = Addon:Deserialize(decompressed)
        if not ok then
            return
        end

        ------------------------------------------------------------------
        -- 2) rebuild & store each clip (logic unchanged)
        ------------------------------------------------------------------
        for _, arr in ipairs(rows) do
            ----------------------------------------------------------------
            -- 1) pull in the raw ts
            ----------------------------------------------------------------
            local clipTS = arr[2] or 0
            local now = GetServerTime()
            if clipTS > now then
                clipTS = now
            end

            ----------------------------------------------------------------
            -- 2) look-ups and fallbacks
            ----------------------------------------------------------------
            local zid      = arr[6] or 0
            local zoneName = (zid > 0 and ns.GetZoneNameByID(zid)) or arr[15] or ""

            local rid      = arr[8] or 0
            local realmStr = (rid > 0 and ns.GetRealmNameByID(rid))
                    or ((zid == 0 and arr[16]) or arr[15])
                    or "UnknownRealm"

            local clipCompleted  = arr[14] ~= nil
            local causeID        = arr[4] -- может быть nil
            local mobPayload     = arr[12] or ""
            local mobNameForCause = ""
            if type(mobPayload) == "number" then
                mobNameForCause = ns.MobNameByID[mobPayload] or "Неизвестный моб"
            elseif type(mobPayload) == "string" then
                mobNameForCause = mobPayload
            end

            -- deathCause
            local causeStr
            if causeID == "A" then
                causeStr = "ALIVE"
            elseif clipCompleted then
                causeStr = ""
            else
                causeStr = ns.GetDeathCauseByID(causeID, mobNameForCause)
            end

            ----------------------------------------------------------------
            -- 3) class & race names
            ----------------------------------------------------------------
            local classStr = ns.ClassNameByID[arr[3]] or ""
            local raceInfo = ns.GetRaceInfoByID(arr[5])

            ----------------------------------------------------------------
            -- 4) rebuild the clip table
            ----------------------------------------------------------------
            local clip = {
                characterName = arr[1] or "",
                ts            = clipTS,
                classCode     = arr[3],
                class         = classStr,
                causeCode     = (causeStr ~= "ALIVE" and causeID) or (causeID == "A" and "A" or nil),
                deathCause    = causeStr,
                raceCode      = arr[5],
                race          = raceInfo.name,
                where         = clipCompleted and "" or zoneName,
                factionCode   = arr[7],
                realmCode     = rid,
                realm         = realmStr,
                level         = arr[9],
                getPlayedTry  = arr[10],
                playedTime    = arr[11],
                mobLevel      = (arr[13] and arr[13] > 0) and arr[13] or nil,
                completed     = clipCompleted and true or nil,
            }

            ----------------------------------------------------------------
            -- 5) faction string
            ----------------------------------------------------------------
            if clip.factionCode == 1 then
                clip.faction = "Alliance"
            elseif clip.factionCode == 2 then
                clip.faction = "Horde"
            else
                clip.faction = "Neutral"
            end

            ----------------------------------------------------------------
            -- 6) ✂️ Minimal cleanup: drop unused or default fields
            ----------------------------------------------------------------
            clip.classCode, clip.raceCode, clip.factionCode, clip.realmCode = nil, nil, nil, nil
            if clip.playedTime then
                clip.getPlayedTry = nil
            end

            ----------------------------------------------------------------
            -- 7) build unique ID
            ----------------------------------------------------------------
            clip.id = ns.GenerateClipID(clip, clip.completed)
            LiveDeathClips[clip.id] = clip
            
            -- Add to queue if no playedTime and not failed (same logic as AddNewDeathClips)
            if ns.AddClipToQueue then
                ns.AddClipToQueue(clip)
            end
        end

        ------------------------------------------------------------------
        --  STOP BENCHMARK (debug only): only on the last chunk
        ------------------------------------------------------------------
        if label then
            local i, n = label:match("chunk_(%d+)of(%d+)")
            i, n = tonumber(i), tonumber(n)
            if i and n and i == n then                      -- last batch only :contentReference[oaicite:0]{index=0}
                local entry = table.remove(self.benchDebugQueue or {}, 1)
                if entry then
                    local elapsed = GetTime() - entry.start
                    --print(("|cff00ff00>> Bench[%d]: DeathClip sync completed at %s (took %.2f s)|r")
                    --        :format(entry.id, date("%H:%M"), elapsed))
                end
            end
        else
            -- legacy: no label → behave as before :contentReference[oaicite:1]{index=1}
            local entry = table.remove(self.benchDebugQueue or {}, 1)
            if entry then
                local elapsed = GetTime() - entry.start
                --print(("|cff00ff00>> Bench[%d]: DeathClip sync completed at %s (took %.2f s)|r")
                --        :format(entry.id, date("%H:%M"), elapsed))
            end
        end

        API:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)


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
    --elseif dataType == ns.T_ADMIN_UPDATE_CLIP_OVERRIDES then
    --    local reviewState = ns.GetDeathClipReviewState()
    --    reviewState:UpdateClipOverrides(payload.clipID, payload.overrides, true)
    elseif dataType == ns.T_ADMIN_REMOVE_CLIP then
        ns.RemoveDeathClip(payload.clipID)
    elseif dataType == ns.T_DEATH_CLIP_ADDED then
        ns.AddNewDeathClips({ payload })

        -- Start simulation for ALIVE clips from other players
        if payload.deathCause == "ALIVE" and payload.characterName ~= UnitName("player") then
            ns.StartPlayedTimeSimulation(payload)
        end

        -- Fire event to update UI immediately for incoming clips
        ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)

        local magicLink = ns.CreateMagicLink(ns.SPELL_ID_DEATH_CLIPS, L["watch death clip"])
        --print(string.format(L["%s has died at Lv. %d."], ns.GetDisplayName(payload.characterName), payload.level) .. " " .. magicLink)
    elseif dataType == T_CONFIG_CHANGED then
        if payload.version > AHConfigSaved.version then
            AHConfigSaved = payload
        end

    elseif dataType == ns.T_TRADE_STATE_REQUEST then
        self:HandleStateUpdate(sender, ns.T_TRADE_STATE_REQUEST, {
            rev = self.db.revTrades or 0,
            payloadRev = payload.revTrades,
            getLastAck = function(sender)
                return self.lastAckTradeRevisions[sender]
            end,
            setLastAck = function(sender, value)
                self.lastAckTradeRevisions[sender] = value
            end
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
            getLastAck = function(sender)
                return self.lastAckRatingRevisions[sender]
            end,
            setLastAck = function(sender, value)
                self.lastAckRatingRevisions[sender] = value
            end
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
                API:FireEvent(ns.T_RATING_SYNCED, { rating = rating })
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
            getLastAck = function(sender)
                return self.lastAckLFGRevisions[sender]
            end,
            setLastAck = function(sender, value)
                self.lastAckLFGRevisions[sender] = value
            end
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
            payload = { version = latestVersion }
            if ns.ChangeLog[latestVersion] then
                payload.changeLog = ns.ChangeLog[latestVersion]
            end
            self:SendDm(Addon:Serialize({ ns.T_ADDON_VERSION_RESPONSE, payload }), sender, "BULK")
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
            getLastAck = function(sender)
                return self.lastAckBlacklistRevisions[sender]
            end,
            setLastAck = function(sender, value)
                self.lastAckBlacklistRevisions[sender] = value
            end
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
            getLastAck = function(sender)
                return self.lastAckPendingTransactionRevisions[sender]
            end,
            setLastAck = function(sender, value)
                self.lastAckPendingTransactionRevisions[sender] = value
            end
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
                if not self.db.pendingTransactions then
                    self.db.pendingTransactions = {}
                end
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

    elseif dataType == ns.T_WATCH_ADD_OR_UPDATE then
        if payload and payload.characterName then
            local lowerName = string.lower(payload.characterName)
            AuctionHouseDBSaved = AuctionHouseDBSaved or {}
            AuctionHouseDBSaved.watchedFriends = AuctionHouseDBSaved.watchedFriends or {}

            -- Avoid overwriting if user already tracks with more info
            if not AuctionHouseDBSaved.watchedFriends[lowerName] then
                AuctionHouseDBSaved.watchedFriends[lowerName] = payload
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage(ChatPrefix() .. string.format(" %s сообщил о возродившемся геройе %s (ур. %d). Щёлкните клип, чтобы добавить в отслеживание.", sender, payload.characterName, payload.clipLevel or 0))
                end

                if ns.RefreshDeathClipsUIForFriendUpdates then
                    ns.RefreshDeathClipsUIForFriendUpdates()
                end
            end
        end

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
        for id, auction in pairs(ns.FilterAuctionsThisRealm(self.db.auctions)) do
            local requesterRev = requesterAuctionLookup[id]
            if not requesterRev or (auction.rev > requesterRev) then
                auctionsToSend[id] = self:TrimAuctionForSync(auction)
                auctionCount = auctionCount + 1
            end
        end

        -- Only send deletions if the requester is at the same revision or newer.
        -- This prevents the rare edge-case where we would delete a brand-new
        -- auction created while the initial sync of the other side was
        -- incomplete (requesterRevision < self.db.revision).
        if requesterRevision and requesterRevision >= self.db.revision then
            -- Use tombstones to decide safe deletions (avoid nuking brand-new auctions created only on requester).
            local tombstones = (self.db.deletedHistory or {})
            local retention  = 7 * 24 * 60 * 60 -- 7 дней
            local nowTs      = time()

            for id, _ in pairs(requesterAuctionLookup) do
                if not self.db.auctions[id] then
                    local delTs = tombstones[id]
                    if delTs and (nowTs - delTs < retention) then
                        table.insert(deletedAuctionIds, id)
                        deletionCount = deletionCount + 1
                    end
                end
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
    self:SendDm(Addon:Serialize({ ns.T_SET_GUILD_POINTS, { points = points, txId = txId } }), playerName, "NORMAL")
end

function AuctionHouse:BuildAuctionsTable()
    local auctions = {}
    for id, auction in pairs(ns.FilterAuctionsThisRealm(self.db.auctions)) do
        table.insert(auctions, { id = id, rev = auction.rev })
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

    -- ── AUCTION BENCHMARK ──
    self.auctionBenchCounter = (self.auctionBenchCounter or 0) + 1
    local dbgID = self.auctionBenchCounter
    local dbgStart = GetTime()
    self.auctionBenchQueue = self.auctionBenchQueue or {}
    table.insert(self.auctionBenchQueue, { id = dbgID, start = dbgStart })

    local auctions = self:BuildAuctionsTable()
    print(("DBG: [AUCTION-%d] RequestLatestState at %s - revision=%d, auctions=%d"):format(
        dbgID, date("%H:%M"), self.db.revision or 0, #auctions
    ))
    local payload = { T_AUCTION_STATE_REQUEST, { revision = self.db.revision, auctions = auctions } }
    
    -- 1. Serialize
    local serialized = Addon:Serialize(payload)
    -- 2. Compress (raw bytes)
    local compressionConfigs = {level = 9}
    local compressed = LibDeflate:CompressDeflate(serialized, compressionConfigs)
    -- 3. Encode (ASCII-safe)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
    -- 4. Prepend our marker
    local msg = "DF:" .. encoded

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
    -- ── DEBUG TICKET ──
    -- assign a unique ID and enqueue this run's start time
    self.benchDebugCounter = (self.benchDebugCounter or 0) + 1
    local dbgID            = self.benchDebugCounter
    local dbgStart         = GetTime()
    self.benchDebugQueue   = self.benchDebugQueue or {}
    table.insert(self.benchDebugQueue, { id = dbgID, start = dbgStart })

    -- unchanged print
    --print(("|cff00ff00>> Bench[%d]: DeathClip sync requested at %s|r")
    --        :format(dbgID, date("%H:%M")))

    local clips   = self:BuildDeathClipsTable(now)
    local payload = {
        ns.T_DEATH_CLIPS_STATE_REQUEST,
        { since = ns.GetLastDeathClipTimestamp(), clips = clips }
    }

    -- 1. Serialize
    local serialized = Addon:Serialize(payload)
    -- 2. Compress (raw bytes)
    local compressionConfigs = {level = 9}
    local compressed = LibDeflate:CompressDeflate(serialized, compressionConfigs)
    -- 3. Encode (ASCII-safe)
    local encoded    = LibDeflate:EncodeForWoWAddonChannel(compressed)
    -- 4. Prepend our marker
    local msg        = "DF:" .. encoded

    -- 5. Send it off
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

    ------------------------------------------------------------------
    -- NEW: also reset other per-char guild-sensitive tables so that
    --       nothing leaks into a future guild with higher revisions.
    ------------------------------------------------------------------
    local DB = ns.AuctionHouseDB

    -- Ratings
    DB.ratings               = {}
    DB.revRatings            = 0

    -- LFG entries
    DB.lfg                   = {}
    DB.revLfg                = 0

    -- Blacklists
    DB.blacklists            = {}
    DB.revBlacklists         = 0

    -- Pending transactions
    DB.pendingTransactions   = {}
    DB.revPendingTransactions = 0

    -- Reset their timestamps to avoid triggering unnecessary syncs
    DB.lastRatingUpdateAt            = 0
    DB.lastLfgUpdateAt               = 0
    DB.lastBlacklistUpdateAt         = 0
    DB.lastPendingTransactionUpdateAt = 0

    -- Notify interested UI modules, if any
    if ns.AuctionHouseAPI and ns.AuctionHouseAPI.FireEvent then
        ns.AuctionHouseAPI:FireEvent(ns.T_RATING_DELETED, {})
        ns.AuctionHouseAPI:FireEvent(ns.T_LFG_DELETED, {})
        ns.AuctionHouseAPI:FireEvent(ns.T_BLACKLIST_DELETED, {})
        ns.AuctionHouseAPI:FireEvent(ns.T_PENDING_TRANSACTION_DELETED, {})
    end
end

local function playRandomDeathClip()
    if GetRealmName() ~= "Doomhowl" then
        return
    end

    local clipNum = random(1, 24)
    PlaySoundFile("Interface\\AddOns\\" .. addonName .. "\\Media\\DeathAudioClips\\death_" .. clipNum .. ".mp3", "Master")
end

ns.GameEventHandler:On("PLAYER_DEAD", function()
    print(ChatPrefix() .. " " .. L["removing auctions after death"])
    AuctionHouse:CleanupAuctionsAndTrades()
    --playRandomDeathClip()
end)

local function cleanupIfKicked()
    if not IsInGuild() then
        --print(ChatPrefix() .. " " .. L["removing auctions after gkick"])
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

function ns.AuctionHouse:OnTimePlayedUpdate(event, totalTimePlayed, levelTimePlayed)
    -- Respect the user's Speed-Clips privacy preference
    if ns.PlayerPrefs and ns.PlayerPrefs.Get then
        local participate = ns.PlayerPrefs:Get("participateInSpeedClips")
        if participate == false then
            return -- user opted-out; do not record or broadcast
        end
    end

    local playerName = UnitName("player")
    local playerRealm = GetRealmName()
    local playerLevel = UnitLevel("player")
    -- === ИСПРАВЛЕНИЕ ДЛЯ КЛАССА: Используем playerClassToken (английский токен) ===
    local _, playerClassLocalized, playerClassID = UnitClass("player") -- Получаем ID класса
    local playerClassToken = ns.ClassNameByID and ns.ClassNameByID[playerClassID] -- Получаем английский токен по ID
    -- === КОНЕЦ ИСПРАВЛЕНИЯ ДЛЯ КЛАССА ===

    local localizedRaceName, _, _ = UnitRace("player")
    local raceIDFromMap = ns.RaceIDByName and ns.RaceIDByName[localizedRaceName]
    local raceInfo = raceIDFromMap and ns.GetRaceInfoByID and ns.GetRaceInfoByID(raceIDFromMap)
    local playerFaction = (raceInfo and raceInfo.faction) or "UnknownFaction"

    local playerZone = GetZoneText() or "Неизвестно"

    local clip = nil
    for clipId, clipData in pairs(ns.GetLiveDeathClips()) do
        if clipData.characterName == playerName and clipData.realm == playerRealm and not clipData.completed and clipData.deathCause == "ALIVE" then
            clip = clipData
            break
        end
    end

    if not clip then
        clip = {
            characterName = playerName,
            realm = playerRealm,
            deathCause = "ALIVE",
            completed = false,
        }
    else
        clip.deathCause = "ALIVE"
    end

    clip.level = playerLevel
    clip.faction = playerFaction
    clip.class = playerClassToken -- <<<< ТЕПЕРЬ ЗДЕСЬ ТОЧНО АНГЛИЙСКИЙ ТОКЕН
    clip.race = localizedRaceName
    clip.where = playerZone
    clip.playedTime = totalTimePlayed
    clip.ts = GetServerTime()
    -- Важно: ns.GenerateClipID должен быть адаптирован, чтобы ID для "ALIVE" клипов не включал зону, если это требуется
    clip.id = ns.GenerateClipID(clip, false)

    ns.GetLiveDeathClips()[clip.id] = clip

    ns.AuctionHouse:BroadcastDeathClipAdded(clip)

    -- Update/start simulation for own character
    ns.UpdatePlayedTimeSimulation(clip)

    ns.AuctionHouseAPI:FireEvent(ns.EV_PLAYED_TIME_UPDATED, clip.id)
end

-- Global test function for creating 1000 test auctions
-- TODO REMOVE ME BEFORE RELEASE
function CreateTestAuctions()
    local count = 0
    
    -- Get real itemIDs from ItemDB
    local allItems = ns.ItemDB:Find() -- Get all items
    local realItemIDs = {-1} -- Start with gold
    
    -- Collect first 1000 real itemIDs for unique auctions
    for i, item in ipairs(allItems) do
        if i <= 1000 and item.id then
            table.insert(realItemIDs, item.id)
        end
    end
    
    print("Using " .. #realItemIDs .. " unique itemIDs for test auctions")
    
    local auctionTypes = {0, 1} -- sell, buy-order  
    local deliveryTypes = {0, 1, 2} -- any, mail, trade
    local priceTypes = {0, 1, 2, 3} -- money, twitch raid, custom, guild points
    
    for i = 1, math.min(200, #realItemIDs) do
        local itemID = realItemIDs[i] -- Use unique itemID for each auction
        local price = math.random(1, 1000000)
        local quantity = math.random(1, 50)
        local allowLoan = math.random() > 0.5
        local priceType = priceTypes[math.random(#priceTypes)]
        local deliveryType = deliveryTypes[math.random(#deliveryTypes)]
        local auctionType = auctionTypes[math.random(#auctionTypes)]
        local roleplay = math.random() > 0.8
        local deathRoll = math.random() > 0.9
        local duel = math.random() > 0.9
        local raidAmount = priceType == 1 and math.random(1, 100) or 0
        local points = priceType == 3 and math.random(1, 1000) or 0
        local note = i % 10 == 0 and ("Test note " .. i) or ""
        
        local success, err = ns.AuctionHouseAPI:CreateAuction(
            itemID, price, quantity, allowLoan, priceType, deliveryType, 
            auctionType, roleplay, deathRoll, duel, raidAmount, points, note
        )
        
        if success then
            count = count + 1
        else
            print("Failed to create auction " .. i .. ": " .. (err or "unknown error"))
        end
        
        if count % 100 == 0 then
            print("Created " .. count .. " test auctions...")
        end
    end
    
    print("Created " .. count .. " test auctions total!")
end

-- =====================  WATCHED FRIEND SYNC  =====================
ns.T_WATCH_ADD_OR_UPDATE = "WATCH_ADD_OR_UPDATE"
