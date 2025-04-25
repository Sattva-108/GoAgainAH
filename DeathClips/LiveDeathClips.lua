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
    [24] = { name = "Озарён. дреней", faction = "Alliance" },
    [25] = { name = "Эредар", faction = "Horde" },
    [26] = { name = "Дворф Ч. Железа", faction = "Alliance" },
    [27] = { name = "Драктир", faction = "Horde" }
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
    [6] = "Падение в бездну",
    [7] = "существом",
    [8] = "Умер в PVP схватке",
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
        local mobLevelText = ""  -- Default empty

        -- Check if the death was caused by a creature and we have its name
        if deathCauseId == 7 and mobName ~= "" then
            -- Initially set deathCause to the mob name (uncolored)
            deathCause = mobName

            -- Check if we also have the mob's level
            if mobLevel ~= "" then
                -- Calculate level difference
                local playerLevel = level or 0 -- Ensure player level is a number
                local mobLevelNum = tonumber(mobLevel)
                local levelDiff = mobLevelNum - playerLevel

                -- Determine color based on level difference
                local color
                if levelDiff >= 5 then       -- Red
                    color = "|cFFFF0000"
                elseif levelDiff >= 3 then    -- Orange
                    color = "|cFFFF7F00"
                elseif levelDiff >= -2 then   -- Yellow
                    color = "|cFFFFFF00"
                elseif levelDiff >= -6 then   -- Green
                    color = "|cFF00FF00"
                else                          -- Gray
                    color = "|cFF808080"
                end

                -- Format mob level text with color and " ур." suffix
                mobLevelText = string.format("%s%s|r", color, mobLevel)

                -- Format death cause (mob name) with the same color
                deathCause = string.format("%s%s|r", color, mobName)
                -- else: mobLevel is empty, so keep deathCause as plain mobName and mobLevelText as empty
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
            level = level,
            where = zone,
            deathCause = deathCause,
            mobLevelText = mobLevelText
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


SLASH_CHECKHC1 = "/checkhc"
SlashCmdList["CHECKHC"] = function()
    print("|cff00ffff[Hardcore]|r Checking leaderboard entries...")
    local challengeID = C_Hardcore.GetSelectedChallenge()
    if not challengeID then
        print("No active challenge selected.")
        return
    end

    local numEntries = C_Hardcore.GetNumLeaderboardEntries(challengeID)
    if numEntries == 0 then
        print("No entries found.")
        return
    end

    for i = 1, numEntries do
        local entry = C_Hardcore.GetLeaderboardEntry(challengeID, i)
        if entry then
            local statusText
            if entry.status == Enum.Hardcore.Status.Failed then
                statusText = "FAILED"
            elseif entry.status == Enum.Hardcore.Status.Completed then
                statusText = "COMPLETED"
            else
                statusText = "IN PROGRESS"
            end

            local timeText = ""
            if entry.time and entry.time > 0 then
                timeText = string.format(" - Time: %s", SecondsToTime(entry.time))
            end

            print(string.format(" - %s (Lv %d) [%s]%s", entry.name, entry.level, statusText, timeText))
        end
    end

end


-- one frame to catch death → wait for ladder → report that character’s leaderboard entry
local f = CreateFrame("Frame", "HardcoreDeathThenLadder")
local deathName         -- name of the character who just died
local ladderBuffer = {} -- buffers per-challengeID fragments

f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
    if prefix == "ASMSG_HARDCORE_DEATH" then
        -- fire when someone dies; msg = "name:race:gender:class:level:zone:reason[:npc[:npcLevel]]"
        deathName = msg:match("^([^:]+)") or nil
        if deathName then
            print("|cffff0000[Hardcore] Death detected:|r", deathName)
            ladderBuffer = {}  -- reset any in-flight ladder data
        end

    elseif prefix == "ASMSG_HARDCORE_LADDER_LIST" and deathName then
        -- msg = "challengeID:dataFragment"
        local challengeID, data = msg:match("^(%d+):(.*)")
        if not challengeID or not data then return end

        -- accumulate fragments
        ladderBuffer[challengeID] = (ladderBuffer[challengeID] or "") .. data

        -- final fragment has no trailing ";"
        if not data:match(";$") then
            local full = ladderBuffer[challengeID]
            ladderBuffer[challengeID] = nil

            -- split each "status:name:class:race:gender:level:time"
            for entry in full:gmatch("([^;]+)") do
                local s,n,cls,r,g,lvl,tm = entry:match("^(%d+):([^:]+):%d+:%d+:%d+:(%d+):(%d+)$")
                if n == deathName then
                    s   = tonumber(s)
                    lvl = tonumber(lvl)
                    tm  = tonumber(tm)
                    -- status 3 = Completed, 2 = InProgress, 1 = Failed
                    local statusText = (s==3 and "COMPLETED") or (s==2 and "IN PROGRESS") or "FAILED"
                    print((
                            "|cff00ff00[Hardcore Ladder]|r %s died → Status: %s, Level: %d, Time: %s"
                    ):format(n, statusText, lvl, SecondsToTime(tm)))
                    deathName = nil  -- stop watching until next death
                    break
                end
            end
        end
    end
end)


