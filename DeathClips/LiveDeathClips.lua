local _, ns = ...

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

ns.GameEventHandler:On("PLAYER_DEAD", function()
    if ns.CharacterPrefs:Get("diedAtLeastOnce") then
        return
    end
    ns.CharacterPrefs:Set("diedAtLeastOnce", true)

    local ts = GetServerTime()
    local me = UnitName("player")
    local twitchName = ns.GetTwitchName(me)
    local clipId = string.format("%d-%s", ts, me)
    local raceId = select(3, UnitRace("player"))
    local classId = select(3, UnitClass("player"))
    local mapId = C_Map.GetBestMapForUnit("player")
    local mapInfo = C_Map.GetMapInfo(mapId)
    local zone = mapInfo and mapInfo.name or nil
    local level = UnitLevel("player")
    local clip = {
        id = clipId,
        ts = ts,
        streamer = twitchName,
        characterName = me,
        race = ns.id_to_race[raceId],
        class = ns.id_to_class[classId],
        level = level,
        where = zone,
        mapId = mapId,
    }

    ns.AddNewDeathClips({clip})
    ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
    ns.AuctionHouse:BroadcastDeathClipAdded(clip)
    C_Timer:After(2, function()
        ns.AuctionHouse:BroadcastDeathClipAdded(clip)
    end)

end)
