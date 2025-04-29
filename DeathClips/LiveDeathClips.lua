local _, ns = ...

-- Define the global queue table to track both completed and death event characters
local queue = {}

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
        table.sort(newClips, function(l, r)
            return l.ts < r.ts
        end)
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
        -- Ensure that the clip has a valid ID and playedTime before attempting to add it
        if clip.id then
            clip.playedTime = clip.playedTime or nil  -- Initialize playedTime to nil if not set
            existingClips[clip.id] = clip
        else
            --print("Error: Clip ID is nil for character:", clip.characterName)
        end
    end
end


ns.RemoveDeathClip = function(clipID)
    local existingClips = ns.GetLiveDeathClips()
    existingClips[clipID] = nil
end

ns.GetCompletedDeathClips = function()
    local completedClips = {}
    for _, clip in pairs(ns.GetLiveDeathClips()) do
        if clip.completed then
            table.insert(completedClips, clip)
        end
    end
    return completedClips
end

ns.GetPlayedDeathClips = function()
    local playedClips = {}
    for _, clip in pairs(ns.GetLiveDeathClips()) do
        if clip.playedTime then  -- Check if the clip has playedTime
            table.insert(playedClips, clip)
        end
    end
    return playedClips
end

ns.GetNoPlayedDeathClips = function()
    local playedClips = {}
    for _, clip in pairs(ns.GetLiveDeathClips()) do
        if not clip.playedTime then  -- Check if the clip has playedTime
            table.insert(playedClips, clip)
        end
    end
    return playedClips
end


-- Create the frame to listen for addon messages
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix == "ASMSG_HARDCORE_DEATH" then
            -- Parsing the message (like before)
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

            -- Process the zone and death cause
            local firstWord, rest = string.match(rawZone or "", "^(%S+)%s*(.*)$")
            local zone = rest and rest ~= "" and firstWord .. "\n" .. rest or firstWord

            local deathCause = deathCauses[deathCauseId] or "Неизвестно"
            local mobLevelText = ""  -- Default empty

            -- Check if the death was caused by a creature and we have its name
            if deathCauseId == 7 and mobName ~= "" then
                -- Initially set deathCause to the mob name (uncolored)
                deathCause = mobName

                -- Check if we also have the mob's level
                if mobLevel ~= "" then
                    -- Calculate level difference and color logic
                    local playerLevel = level or 0 -- Ensure player level is a number
                    local mobLevelNum = tonumber(mobLevel)
                    local levelDiff = mobLevelNum - playerLevel

                    -- Determine color based on level difference
                    local color
                    if levelDiff >= 5 then
                        -- Red
                        color = "|cFFFF0000"
                    elseif levelDiff >= 3 then
                        -- Orange
                        color = "|cFFFF7F00"
                    elseif levelDiff >= -2 then
                        -- Yellow
                        color = "|cFFFFFF00"
                    elseif levelDiff >= -6 then
                        -- Green
                        color = "|cFF00FF00"
                    else
                        -- Gray
                        color = "|cFF808080"
                    end

                    -- Format mob level text with color and " ур." suffix
                    mobLevelText = string.format("%s%s|r", color, mobLevel)

                    -- Format death cause (mob name) with the same color
                    deathCause = string.format("%s%s|r", color, mobName)
                end
            end

            -- Directly build the clip ID here
            local deathCauseStr = deathCause and deathCause ~= "" and deathCause or "Unknown"
            local factionStr = (races[raceId] and races[raceId].faction) or "Unknown"
            local zoneStr = zone and zone ~= "" and zone or "Unknown"

            -- Replace newlines in 'zone' with spaces
            zoneStr = zoneStr:gsub("\n", " ")

            -- Build the ID using the full message (without BuildSimpleClipID)
            local clipID = string.format("%s-%d-%s-%s-%s", name, level, zoneStr, factionStr, deathCauseStr)

            -- Create the death clip entry
            local clip = {
                id = clipID,
                ts = GetServerTime(),
                streamer = ns.GetTwitchName(name) or name,
                characterName = name,
                race = (races[raceId] and races[raceId].name) or "Неизвестно",
                faction = factionStr,
                class = classes[classId] or "Неизвестно",
                level = level,
                where = zoneStr,
                deathCause = deathCauseStr,
                mobLevelText = mobLevelText,
                playedTime = nil,  -- `playedTime` is nil initially (we'll populate it later)
            }

            if not clip.id then
                return
            end

            -- Check if the clip ID already exists
            local existingClips = ns.GetLiveDeathClips()
            if existingClips[clip.id] then
                --print("Duplicate clip detected for: " .. name .. " with ID: " .. clip.id)
                return  -- Return early to prevent adding the duplicate clip
            end

            -- Add the completed clip to the queue (for both death and completed clips)
            -- Add the played clip to the queue (for both death and played clips)
            queue[name] = queue[name] or {}
            clip.playedTime = clip.playedTime or nil  -- Initialize playedTime if not set
            table.insert(queue[name], clip)

            -- If no duplicate, add the clip
--            print("Adding new clip for: " .. name .. " with ID: " .. clip.id)

            ns.AddNewDeathClips({ clip })
            ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)

        elseif prefix == "ASMSG_HARDCORE_COMPLETE" then
            local parts = { strsplit(":", message) }
            local name = parts[1]
            local raceId = tonumber(parts[2])
            local genderId = tonumber(parts[3])
            local classId = tonumber(parts[4])

            -- Default values (because these are missing in the message)
            local level = 80   -- Default level
            local zone = "Неизвестно"  -- Default zone
            local deathCause = "Неизвестно"  -- Default death cause (for consistency)
            local mobLevelText = ""  -- Default mob level text (empty)

            -- Directly build the clip ID here
            local deathCauseStr = deathCause and deathCause ~= "" and deathCause or "Unknown"
            local factionStr = (races[raceId] and races[raceId].faction) or "Unknown"
            local zoneStr = zone and zone ~= "" and zone or "Unknown"

            -- Replace newlines in 'zone' with spaces
            zoneStr = zoneStr:gsub("\n", " ")

            -- Build the ID using the full message (without BuildSimpleClipID)
            local clipID = string.format("%s-%d-%s-%s-%s", name, level, zoneStr, factionStr, deathCauseStr)

            -- Create the completed challenge clip
            local clip = {
                id = clipID,
                ts = GetServerTime(),
                streamer = ns.GetTwitchName(name) or name,
                characterName = name,
                race = (races[raceId] and races[raceId].name) or "Неизвестно",
                faction = factionStr,
                class = classes[classId] or "Неизвестно",
                level = level,
                where = zoneStr,
                deathCause = deathCauseStr,
                mobLevelText = mobLevelText,
                completed = true,
                playedTime = nil,  -- `playedTime` is nil initially (we'll populate it later)
            }

            if not clip.id then
                return
            end

            -- Check if the clip ID already exists
            local existingClips = ns.GetLiveDeathClips()
            if existingClips[clip.id] then
                --print("Duplicate clip detected for: " .. name .. " with ID: " .. clip.id)
                return  -- Return early to prevent adding the duplicate clip
            end

            -- Add the completed clip to the queue (for both death and completed clips)
            -- Add the played clip to the queue (for both death and played clips)
            queue[name] = queue[name] or {}
            clip.playedTime = clip.playedTime or nil  -- Initialize playedTime if not set
            table.insert(queue[name], clip)

            -- If no duplicate, add the clip
--            print("Adding new clip for: " .. name .. " with ID: " .. clip.id)

            ns.AddNewDeathClips({ clip })
            ns.AuctionHouseAPI:FireEvent(ns.EV_DEATH_CLIPS_CHANGED)
        end
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


--===== Hardcore Death → Ladder (with '|' splitting) =====--
local f = CreateFrame("Frame", "HardcoreDeathTimerReporter")
local listening = false
local nextUpdateDeadline = nil
local ladderBuffer = {}

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_ADDON")

f:SetScript("OnEvent", function(self, event, prefix, msg)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Iterate over completed clips and check if they don't have a playedTime
        local playedClips = ns.GetNoPlayedDeathClips()
        for _, clip in ipairs(playedClips) do
            if type(clip) == "table" then
                if not clip.playedTime and clip.characterName then
                    -- Ensure the queue for the character exists (initialize if not present)
                    if not queue[clip.characterName] then
                        queue[clip.characterName] = {}  -- Initialize the table for this character
                    end

                    -- Insert the clip into the character's queue
                    table.insert(queue[clip.characterName], clip)
                    C_Timer:After(10, function()
                        print(clip.characterName .. " added to the queue (no playedTime)")
                    end)
                end
            end
        end

        -- skip auto-refresh on login/reload
        C_Timer:After(3, function()
            listening = true
        end)
        return
    end

    if not listening then
        return
    end

    if prefix == "ASMSG_HARDCORE_DEATH" then
        local admin = UnitName("player")
        if admin == "Lenkomag" then
            PlaySoundFile("Sound\\interface\\MapPing.wav")
        end
        local name = msg:match("^([^:]+)")
        if name then
            if nextUpdateDeadline then
                local left = nextUpdateDeadline - GetTime()
                if left < 0 then left = 0 end
                print(("%s died — next ladder in %s"):format(name, SecondsToTime(left)))
            end
        end

        -- Modify the ASMSG_HARDCORE_LADDER_LIST handler to process the queue and update `playedTime`
    elseif prefix == "ASMSG_HARDCORE_LADDER_LIST" then
        -- Handle one or more <challengeID>:<chunk> blocks
        for block in msg:gmatch("([^|]+)") do
            local id, data = block:match("^(%d+):(.*)")
            if id and data then
                --print("Block found - ID: " .. id .. " Data: " .. data)

                -- Append data to the current buffer for the given ID
                ladderBuffer[id] = (ladderBuffer[id] or "") .. data

                -- If data ends with a semicolon, it's still incomplete; continue to accumulate data
                if data:match(";$") then
                    --print("Data ends with a semicolon, continuing to accumulate data for ID " .. id)
                else
                    -- Full data received for this block (no semicolon)
                    local full = ladderBuffer[id]
                    ladderBuffer[id] = nil  -- Clear the buffer for this ID
--                    print("Full data for ID " .. id .. ": " .. full)

                    -- Process the full data (split by semicolon)
                    for entry in full:gmatch("([^;]+)") do
                        -- Extract values from each entry
                        local _, n, _, _, _, _, tm = entry:match("^(%d+):([^:]+):(%d+):(%d+):(%d+):(%d+):(%d+)$")
                        if n and queue[n] then
--                            print("Found player ID: " .. n .. " with playedTime: " .. tm)

                            -- Process each clip in the queue (both deaths and completed)
                            -- Ensure that queue[n] is a table before using ipairs
                            if type(queue[n]) == "table" then
                                for _, clip in ipairs(queue[n]) do
--                                    print("Checking clip for player " .. n .. ": completed=" .. tostring(clip.completed) .. ", playedTime=" .. tostring(clip.playedTime))
                                    if clip.completed and clip.playedTime == nil then
                                        -- Update the `playedTime` (using `tm` from the ladder list)
                                        clip.playedTime = tm
                                        print(("%s's playedTime updated to: %d"):format(n, tm), "|cFF00FF00" .. ("%s's playedTime updated to: %d"):format(n, tm) .. "|r")

                                        -- Remove the player from the queue after updating `playedTime`
                                        queue[n] = nil
--                                        print(("%s removed from the queue after updating playedTime"):format(n))
                                    elseif not clip.completed then
                                        -- For death events, just print the lasted time (tm)
                                        clip.playedTime = tm
                                        print("|cFF00FF00" .. ("%s lasted %s"):format(n, SecondsToTime(tonumber(tm) or 0)) .. "|r")
                                        queue[n] = nil
                                    else
                                        print("Clip not updated due clip completed or playedTime missing")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        -- Set the next update deadline for 10 minutes (600 seconds) from now
        nextUpdateDeadline = GetTime() + 600  -- 600 seconds = 10 minutes
    end
end)
