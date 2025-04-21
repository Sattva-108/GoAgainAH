local _, ns = ...

local races = {
    [1] = { name = "Человек", faction = "Alliance" },
    [2] = { name = "Орк", faction = "Horde" },
    [3] = { name = "Дворф", faction = "Alliance" },
    [4] = { name = "Ночной эльф", faction = "Alliance" },
    [5] = { name = "Нежить", faction = "Horde" },
    [6] = { name = "Таурен", faction = "Horde" },
    [7] = { name = "Гном", faction = "Alliance" },
    [8] = { name = "Тролль", faction = "Horde" },
    [9] = { name = "Гоблин", faction = "Horde" },
    [10] = { name = "Син'Дорей", faction = "Horde" },
    [11] = { name = "Дреней", faction = "Alliance" },
    [12] = { name = "Ворген", faction = "Alliance" },
    [13] = { name = "Нага", faction = "Horde" },
    [14] = { name = "Пандарен", faction = "Alliance" },
    [15] = { name = "Высший эльф", faction = "Alliance" },
    [16] = { name = "Пандарен", faction = "Horde" },
    [17] = { name = "Ночнорожденный", faction = "Horde" },
    [18] = { name = "Озаренный дреней", faction = "Alliance" },
    [19] = { name = "Вульпера", faction = "Alliance" },
    [20] = { name = "Вульпера", faction = "Horde" },
    [21] = { name = "Вульпера", faction = "Neutral" },
    [22] = { name = "Пандарен", faction = "Neutral" },
    [23] = { name = "Зандалар", faction = "Horde" },
    [24] = { name = "Эльф Бездны", faction = "Alliance" },
    [25] = { name = "Эредар", faction = "Horde" },
    [26] = { name = "Дворф Черного Железа", faction = "Alliance" },
    [27] = { name = "Драктир", faction = "Neutral" },
    [28] = { name = "Драктир", faction = "Horde" },
    [29] = { name = "Драктир", faction = "Alliance" }
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
    [0] = "Усталость",
    [1] = "Утопление",
    [2] = "Падение",
    [3] = "Лава",
    [4] = "Слизь",
    [5] = "Огонь",
    [6] = "Падение",
    [7] = "существом",
    [8] = "PVP",
    [9] = "Погиб от действий союзника",
    [10] = "Погиб от собственных действий",
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
        local rawZone = parts[6]
        local deathCauseId = tonumber(parts[7])
        local mobName = parts[8] or ""
        local mobLevel = parts[9] or ""

        -- Always wrap after first zone word
        local firstWord, rest = string.match(rawZone or "", "^(%S+)%s*(.*)$")
        local zone = rest and rest ~= "" and firstWord .. "\n" .. rest or firstWord


        -- Process death cause
        local deathCause = deathCauses[deathCauseId] or "Неизвестно"
        if deathCauseId == 7 and mobName ~= "" then
            if mobLevel ~= "" then
                -- Calculate level difference
                local levelDiff = tonumber(mobLevel) - (level or 0)  -- Use player's level (default to 0 if nil)

                -- Determine color based on level difference (WoW standard colors)
                local color
                if levelDiff >= 5 then       -- Red (very dangerous)
                    color = "|cFFFF0000"
                elseif levelDiff >= 3 then    -- Orange
                    color = "|cFFFF7F00"
                elseif levelDiff >= -2 then   -- Yellow
                    color = "|cFFFFFF00"
                elseif levelDiff >= -6 then   -- Green
                    color = "|cFF00FF00"
                else                          -- Gray (trivial)
                    color = "|cFF808080"
                end

                deathCause = string.format("%s%s\n%s ур.|r", color, mobName, mobLevel)
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
            race = (races[raceId] and races[raceId].name) or "Неизвестно",
            faction = (races[raceId] and races[raceId].faction) or "Неизвестно",
            class = classes[classId] or "Неизвестно",
            level = level,          -- Keep numeric for sorting
            levelText = levelText,     -- Display colorized version in UI
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
