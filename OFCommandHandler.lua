local _, ns = ...
local COMM_COMMAND_DIRECT_EVENT = "DE"
local COMM_HEARTBEAT = "HB"
local COMM_COMMAND_DELIM = "|"
local COMM_FIELD_DELIM = "~"
local COMM_CHANNEL = "GUILD"
local INIT_TIME = 1730639674

local DEATH_EVENTS = {
    [4]=1,   -- death
    [139]=1, -- DrowningDeath
    [141]=1, -- LavaDeath
    [146]=1, -- FallDamageDeath
    [149]=1, -- PVPDeath
    [166]=1, -- FireDeath
    [167]=1, -- FatigueDeath
}

local function fromAdjustedTime(t)
    if t + INIT_TIME > 1730639674 + 157680000 then
        return t
    end

    return t + INIT_TIME
end

---- FIXME TODO 3.3.5 does it ever affect our custom clips aka deaths?
ns.HandleOFCommMessage = function(message, sender, channel)
    if channel ~= COMM_CHANNEL then
        return
    end

    local command, data = string.split(COMM_COMMAND_DELIM, message)
    if command ~= COMM_COMMAND_DIRECT_EVENT then
        if command ~= COMM_HEARTBEAT then
            ns.DebugLog("[DEBUG] ignoring command: ", command)
        end
        return
    end

    local _fletcher, _date, _race_id, _event_id, _class_id, _add_args = string.split(COMM_FIELD_DELIM, data)
    ns.DebugLog("[DEBUG] received event: ", _event_id, " from ", sender, " at ", _date)
    -- if event id is not a death event skip
    if not DEATH_EVENTS[tonumber(_event_id)] then
        return
    end

    local _sender_short, realmname = string.split("-", sender)
    local ts = fromAdjustedTime(tonumber(_date))
    local twitchName = ns.GetTwitchName(_sender_short)
    local userInfo = ns.GuildRegister.table[_sender_short .. "-" .. (realmname or GetRealmName())] or {}
    local clipId = string.format("%d-%s", ts, _sender_short)
    local clip = {
        id=clipId,
        ts=ts,
        streamer=twitchName,
        characterName=_sender_short,
        race=ns.id_to_race[tonumber(_race_id)],
        class=ns.id_to_class[tonumber(_class_id)],
        level=userInfo.level,
        where=userInfo.zone,
    }
    ns.AddNewDeathClips({clip})
    ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
    local magicLink = ns.CreateMagicLink(ns.SPELL_ID_DEATH_CLIPS, "watch death clip")
    print(string.format("%s has died at Lv. %d. %s", ns.GetDisplayName(_sender_short), userInfo.level or 1, magicLink))
end