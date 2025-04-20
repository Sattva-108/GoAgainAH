local _, ns = ...

local races = {
    [1] = "человек",
    [2] = "орк",
    [3] = "дворф",
    [4] = "ночной эльф",
    [5] = "нежить",
    [6] = "таурен",
    [7] = "гном",
    [8] = "тролль",
    [9] = "гоблин",
    [10] = "син'дорей",
    [11] = "дреней",
    [12] = "ворген",
    [13] = "нага",
    [14] = "пандарен (альянс)",
    [15] = "высший эльф",
    [16] = "пандарен (орда)",
    [17] = "ночнорожденный", -- Placeholder for completeness
    [18] = "эльф бездны",
    [19] = "вульпера (альянс)",
    [20] = "вульпера (орда)",
    [21] = "вульпера (нейтрал)",
    --[21] = "эльф крови",
    [22] = "пандарен (нейтрал?)",
    [23] = "зандалар",
    [24] = "озаренный дреней",
    [25] = "эредар",
    [26] = "дворф Черного Железа",
    [27] = "драктир"
}



-- Define class mappings
local classes = {
    [8] = "MAGE",
    [7] = "SHAMAN",
    [2] = "PALADIN",
    [3] = "HUNTER",
    [1] = "WARRIOR",
    [4] = "ROGUE",
    [5] = "PRIEST",
    [11] = "DRUID",
    [9] = "WARLOCK" -- Corrected class ID for Warlock
}

-- Death cause mappings
local deathCauses = {
    [1] = "Утопление",
    [2] = "Падение",
    [3] = "Лава",
    [7] = "существом"
}

ns.GetLiveDeathClips = function()
    if LiveDeathClips == nil then
        LiveDeathClips = {}
    end
    return LiveDeathClips
end

ns.GetLastDeathClipTimestamp = function()
    local ts = 0
    for _, clip in pairs(ns.GetLiveDeathClips()) do
        ts = math.max(ts, clip.ts)
    end
    return ts
end

ns.GetNewDeathClips = function(since, existing)
    local allClips = ns.GetLiveDeathClips()
    local newClips = {}
    local seen = {}
    for _, clip in pairs(allClips) do
        if clip.ts > since then
            table.insert(newClips, clip)
            seen[clip.id] = true
        end
    end
    if #newClips > 100 then
        -- keep the latest 100 entries
        table.sort(newClips, function(l, r) return l.ts < r.ts end)
        local newClips2 = {}
        local seen2 = {}
        for i = #newClips - 99, #newClips do
            table.insert(newClips2, newClips[i])
            seen2[newClips[i].id] = true
        end
        newClips = newClips2
        seen = seen2
    end
    if existing then
        local fromTs = existing.fromTs
        local existingClips = existing.clips
        for clipID, clip in pairs(allClips) do
            if not existingClips[clipID] and not seen[clipID] and clip.ts >= fromTs then
                table.insert(newClips, clip)
                seen[clipID] = true
            end
        end
    end

    return newClips
end

ns.AddNewDeathClips = function(newClips)
    local existingClips = ns.GetLiveDeathClips()
    for _, clip in ipairs(newClips) do
        existingClips[clip.id] = clip
    end
end

ns.RemoveDeathClip = function(clipID)
    local existingClips = ns.GetLiveDeathClips()
    existingClips[clipID] = nil
end

-- Only keep the ASMSG_HARDCORE_DEATH handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == "ASMSG_HARDCORE_DEATH" then
        local parts = {}
        for part in string.gmatch(message, "([^:]+)") do
            table.insert(parts, part)
        end

        local name = parts[1]
        local raceId = tonumber(parts[2])
        local classId = tonumber(parts[4])
        local level = tonumber(parts[5])
        local zone = parts[6]
        local deathCauseId = tonumber(parts[7])
        local mobName = parts[8] or ""
        local mobLevel = parts[9] or ""

        -- Process death cause
        local deathCause = deathCauses[deathCauseId] or "Неизвестно"
        if deathCauseId == 7 and mobName ~= "" then
            if mobLevel ~= "" then
                deathCause = string.format("%s, %s уровня", mobName, mobLevel)
            else
                deathCause = mobName
            end
        end

        -- Create the death clip entry
        local clip = {
            id = string.format("%d-%s", GetServerTime(), name),
            ts = GetServerTime(),
            streamer = ns.GetTwitchName(name) or name,
            characterName = name,
            race = races[raceId] or "Неизвестно",
            class = classes[classId] or "Неизвестно",
            level = level,
            where = zone,
            deathCause = deathCause,
        }

        ns.AddNewDeathClips({clip})
        ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
    end
end)

--ns.GameEventHandler:On("PLAYER_DEAD", function()
--    if ns.CharacterPrefs:Get("diedAtLeastOnce") then
--        return
--    end
--    ns.CharacterPrefs:Set("diedAtLeastOnce", true)
--
--    local ts = GetServerTime()
--    local me = UnitName("player")
--    local twitchName = ns.GetTwitchName(me)
--    local clipId = string.format("%d-%s", ts, me)
--    local raceId = select(3, UnitRace("player"))
--    local classId = select(3, UnitClass("player"))
--    local mapId = C_Map.GetBestMapForUnit("player")
--    local mapInfo = C_Map.GetMapInfo(mapId)
--    local zone = mapInfo and mapInfo.name or nil
--    local level = UnitLevel("player")
--    local clip = {
--        id = clipId,
--        ts = ts,
--        streamer = twitchName,
--        characterName = me,
--        race = ns.id_to_race[raceId],
--        class = ns.id_to_class[classId],
--        level = level,
--        where = zone,
--        mapId = mapId,
--    }
--
--    ns.AddNewDeathClips({clip})
--    ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
--    ns.AuctionHouse:BroadcastDeathClipAdded(clip)
--    C_Timer:After(2, function()
--        ns.AuctionHouse:BroadcastDeathClipAdded(clip)
--    end)
--
--end)
