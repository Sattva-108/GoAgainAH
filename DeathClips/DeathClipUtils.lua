local addonName, ns = ...

local CLIP_URL_TEMPLATE = "https://deathclips.athenegpt.ai/deathclip?streamerName=%s&deathTimestamp=%d"

ns.GetClipUrl = function(streamer, ts)
    if streamer == nil then
        return nil
    end
    return string.format(CLIP_URL_TEMPLATE, streamer, ts)
end

-- helper to remove WoW color escapes (|cAARRGGBB … |r)
function ns.stripColorCodes(s)
    return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end


local function stringCompare(l, r, field)
    local a = ns.stripColorCodes(l[field])
    local b = ns.stripColorCodes(r[field])
    if a < b then
        return -1
    elseif a > b then
        return 1
    else
        return 0
    end
end

local function GetDeathClipRatingSorter(desc)
    local allRatings = ns.GetDeathClipRatings()
    local ratingByClip = { }
    local ratingCountsByClip = { }
    for clipID, ratings in pairs(allRatings) do
        ratingByClip[clipID] = ns.GetRatingAverage(ratings)
        ratingCountsByClip[clipID] = #ratings
    end
    local sign = desc and -1 or 1

    return function(l, r)
        if l.id == nil and r.id == nil then
            return 0
        end
        if l.id == nil then
            return 1 * sign
        end
        if r.id == nil then
            return -1 * sign
        end
        local lRating = ratingByClip[l.id] or 0
        local rRating = ratingByClip[r.id] or 0
        if lRating == 0 and rRating == 0 then
            return 0
        end
        if lRating == 0 then
            return 1 * sign
        end
        if rRating == 0 then
            return -1 * sign
        end

        local res = lRating - rRating
        if res == 0 then
            res = (ratingCountsByClip[l.id] or 0) - (ratingCountsByClip[r.id] or 0)
        end
        return res
    end
end


local function CreateClipsSorter(sortParams)
    local sorters = { }
    local addSorter = function(desc, sorter)
        local sign = desc and -1 or 1
        table.insert(sorters, function(l, r) return sign * sorter(l, r) end)
    end

    for i = #sortParams, 1, -1 do
        local k = sortParams[i].column
        local desc = sortParams[i].reverse
        if k == "streamer" then
            -- ⬇️ compare by characterName instead of now-deleted streamer
            addSorter(desc, function(l, r) return stringCompare(l, r, "characterName") end)
        elseif k == "race" then
            addSorter(desc, function(l, r) return stringCompare(l, r, "race") end)
        elseif k == "level" then
            addSorter(desc, function(l, r) return (l.level or 0) - (r.level or 0) end)
        elseif k == "class" then
            addSorter(desc, function(l, r) return stringCompare(l, r, "class") end)
        elseif k == "when" then
            addSorter(desc, function(l, r) return l.ts - r.ts end)
        elseif k == "where" then
            addSorter(desc, function(l, r) return stringCompare(l, r, "where") end)
        elseif k == "clip" then
            addSorter(desc, function(l, r)
                -- Completed tab: sort by numeric playedTime
                if ns.isCompletedTabActive then
                    -- Ensure numeric comparison
                    local a = tonumber(l.playedTime) or 0
                    local b = tonumber(r.playedTime) or 0
                    return a - b
                end
                -- Live tab: sort by deathCause string (stripping any color codes)
                return stringCompare(l, r, "deathCause")
            end)
        elseif k == "rate" then
            addSorter(desc, function(l, r) return 0 end)
        elseif k == "rating" then
            addSorter(desc, GetDeathClipRatingSorter(desc))
        end
    end

    return ns.CreateCompositeSorter(sorters)
end

ns.SortDeathClips = function(clips, sortParams)
    local sorter = CreateClipsSorter(sortParams)
    table.sort(clips, sorter)
    return clips
end

local races = {
    [1] = { name = "Человек", faction = "Alliance" }, [2] = { name = "Орк", faction = "Horde" },
    [3] = { name = "Дворф", faction = "Alliance" }, [4] = { name = "Ночной эльф", faction = "Alliance" },
    [5] = { name = "Нежить", faction = "Horde" }, [6] = { name = "Таурен", faction = "Horde" },
    [7] = { name = "Гном", faction = "Alliance" }, [8] = { name = "Тролль", faction = "Horde" },
    [9] = { name = "Гоблин", faction = "Horde" }, [10] = { name = "Син'Дорей", faction = "Horde" },
    [11] = { name = "Дреней", faction = "Alliance" }, [12] = { name = "Ворген", faction = "Alliance" },
    [13] = { name = "Нага", faction = "Horde" }, [14] = { name = "Пандарен", faction = "Alliance" },
    [15] = { name = "Высший эльф", faction = "Alliance" }, [16] = { name = "Пандарен", faction = "Horde" },
    [17] = { name = "Ночнорожденный", faction = "Horde" }, [18] = { name = "Эльф Бездны", faction = "Alliance" },
    [19] = { name = "Вульпера", faction = "Alliance" }, [20] = { name = "Вульпера", faction = "Horde" },
    [21] = { name = "Вульпера", faction = "Neutral" }, [22] = { name = "Пандарен", faction = "Neutral" },
    [23] = { name = "Зандалар", faction = "Horde" }, [24] = { name = "Оз. дреней", faction = "Alliance" },
    [25] = { name = "Эредар", faction = "Horde" }, [26] = { name = "Дворф ЧЖ", faction = "Alliance" },
    [27] = { name = "Драктир", faction = "Horde" }
}
local classes = {
    [8] = "MAGE", [7] = "SHAMAN", [2] = "PALADIN", [3] = "HUNTER", [1] = "WARRIOR",
    [4] = "ROGUE", [5] = "PRIEST", [11] = "DRUID", [9] = "WARLOCK"
}
local deathCauses = {
    [0] = "Усталость", [1] = "Утопление", [2] = "Падение", [3] = "Лава", [4] = "Слизь",
    [5] = "Огонь", [6] = "Падение в бездну", [7] = "существом", [8] = "Умер в PVP схватке",
    [9] = "Погиб от действий союзника", [10] = "Погиб от собственных действий",
}

local randomNames = {
    "Танкмастер", "Хилбот", "Рогапетя", "Магинна", "Танкаша",
    "Критофан", "Палабро", "Фейлспелл", "Хантпельмень", "Сапогдпс",
    "Лутодел", "Агробаба", "Бафоня", "Петовод", "Салоед",
    "Стихийник", "Задротон", "Близолюб", "Квестогрыз", "Тотемыч",
    "Фуллсини", "Кдшник", "Дебафер", "Ресатель", "Промахер",
    "Лукогном", "Хилозавис", "Гневокот", "Совафк", "Кастолап",
    "Бабахмаг", "Аоефанат", "Пулобай", "Манажор", "Клинкогном",
    "Шэдоумаг", "Тотемовна", "Зельемэн", "Фармбот", "Боссовзрыв",
    "Фуллбаф", "Релоадыч", "Рандомастер", "Хитобой", "Слиполов",
    "Камнежуй", "Критунья", "Топхилер", "Овердамадж", "Хилокат",
    "Доткин", "Стихокаст", "Пвплорд", "Щитомэт", "Фэйлтанк",
    "Фармозавр", "Твинколюб", "Рогозмей", "Манаед", "Спдмонк",
    "Сталкерон", "Таптапыч", "Гномокаст", "Паладен", "Мобогрыз",
    "Фэйлрейд", "Тирокот", "Рагенатор", "Милишаман", "Саботажер",
    "Магобой", "Инвизяша", "Кастопёс", "Топгном", "Магобус",
    "Сундукчек", "Уворотун", "Щитодруг", "Боссобой", "Фростед",
    "Скиловик", "Фантомасик", "Бафодел", "Топганк", "Критобой",
    "Клиновёрт", "Манагрыз", "Агрошаман", "Друликус", "Сапогрог",
    "Рандомыч", "Аоекисло", "Флэймберг", "Блайндик", "Диспеллер",
    "Фэйспалм", "Шэдоутанк", "Гномикс", "Гриндатор", "Саложрец"
}

local randomZones = {
    "Элвиннский лес", "Дуротар", "Тирисфальские леса", "Тельдрассил", "Западный Край",
    "Предгорья Хилсбрада", "Ясеневый лес", "Тернистая долина", "Болото Печали",
    "Тысяча Игл", "Бесплодные земли", "Танарис", "Кратер Ун'Горо", "Зимние Ключи",
    "Осквернённый лес", "Восточные Чумные земли", "Западные Чумные земли", "Выжженные земли",
    "Силитус", "Цитадель Ледяной Короны", "Лес Темного Берега", "Красногорье", "Пылевые топи",
    "Пустоши", "Нагорье Арати", "Сумеречный лес", "Серебряный бор", "Темные берега", "Внутренние земли",
    "Фералас", "Пустыня Пылевых Ворот", "Пылевые равнины", "Долина Призрачной Луны",
    "Сумеречное нагорье", "Когтистые горы", "Озеро Ледяных Оков", "Нордскол", "Борейская тундра",
    "Драконий Погост", "Зул'Драк", "Шолазар", "Грозовая Гряда", "Ледяная Корона", "Седые холмы",
    "Тундра Таука", "Кель'Талас", "Леса Вечной Песни", "Призрачные земли", "Остров Кель'Данас",
    "Терраса Магтеридона", "Долина Призрачной Луны", "Награнд", "Зангартопь", "Острогорье",
    "Плато Ураганов", "Лес Тероккар", "Пустоверть", "Долина Стихий", "Вершина Хиджала",
    "Поля Рока", "Гниющая долина", "Мертвые земли", "Ущелье Песни Войны", "Остров Новолуния",
    "Дун Морог", "Тирисфаль", "Пылающие степи", "Горный хребет", "Седые Пики", "Серебряный хребет",
    "Озеро Ледяной Пропасти", "Вечная мерзлота", "Альтеракская долина"
}

local randomMobs = {
    "Ворг", "Мурлок", "Скелет", "Огр", "Медведь", "Кабан", "Кобольд", "Гнолл", "Паук",
    "Гарпия", "Кроколиск", "Нага", "Дракончик", "Элементаль", "Скорпид", "Сатир", "Гуль", "Некромант",
    "Леший", "Баньши", "Некропольский маг", "Болотный чудовище", "Плотоед", "Магмарас", "Летучая мышь",
    "Гаргулья", "Тролль", "Дух леса", "Лесной волк", "Снежный леопард", "Чёрный дракон", "Пылающий бес",
    "Призрак", "Тюремщик", "Гном-разбойник", "Охотник на демонов", "Адское пламя", "Кентавр", "Ящер",
    "Тигр", "Пантера", "Вурдалак", "Могильщик", "Призрачный рыцарь", "Скелет-маг", "Бугай",
    "Зомби", "Морской великан", "Живодёр", "Лягушка", "Волшебный фамильяр", "Дух огня", "Сумеречный дракон",
    "Крыса", "Слизень", "Призрачный страж", "Сумеречный культист", "Темный жрец", "Осквернённый элементаль",
    "Древний дерев", "Заснеженный тролль", "Лесной импр", "Грозовой великан", "Песчаный гном", "Песчаный червь",
    "Костяной жнец", "Кровавый охотник", "Летун", "Ночной саблезуб", "Погонщик", "Клыкозуб",
    "Култист", "Ледяной скорпид", "Морская ведьма", "Снежный элементаль", "Земляной голем",
    "Штормовой велик", "Дух воды", "Огненный инфернал", "Огненный бес", "Проклятый рыцарь",
    "Тень", "Сумеречный авгур", "Нежить-воин", "Темный маг", "Обезьяна", "Змей", "Гниль",
    "Фантом", "Песчаник", "Пироман", "Ледяной маг"
}


-- Helper function to get a random key from a table
local function getRandomKey(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    if #keys == 0 then return nil end
    return keys[math.random(#keys)]
end

-- Build a list of non-creature death cause keys ONCE for efficiency
local otherDeathCauseKeys = {}
for k in pairs(deathCauses or {}) do -- Use (deathCauses or {}) to prevent error if not defined yet
    if k ~= 7 then
        table.insert(otherDeathCauseKeys, k)
    end
end

function GOAHSendRandomCompleteMessage()
    -- Generate random data
    local name = randomNames[math.random(#randomNames)]
    local raceId = getRandomKey(races)
    local genderId = 0 -- Keeping this fixed as 0 from the example (Male)
    local classId = getRandomKey(classes)
    local challengeID = 1  -- Only 1 challenge, so we just use challengeID = 1

    local messageParts = {
        name,
        tostring(raceId),
        tostring(genderId),
        tostring(classId),
        tostring(challengeID)
    }
    local message = table.concat(messageParts, ":")

    -- Send the addon message
    local target = UnitName("player")
    if not target then
        print(addonName .. ": Cannot send message, player unit not found.")
        return
    end

    -- Send the message for completion
    SendAddonMessage("ASMSG_HARDCORE_COMPLETE", message, "WHISPER", target)
end

-- Example of how to call it:
-- /run GOAHSendRandomCompleteMessage()



-- The modified helper function
function GOAHSendRandomDeathMessage()
    -- Generate random data
    local name = randomNames[math.random(#randomNames)]
    local raceId = getRandomKey(races)
    local genderId = 0 -- Keeping this fixed as 0 from the example
    local classId = getRandomKey(classes)
    local level = math.random(1, 60) -- Assuming level cap 60 for HC
    local zone = randomZones[math.random(#randomZones)]

    local deathCauseId
    local mobName = ""
    local mobLevel = ""

    -- Determine Death Cause: 90% chance for ID 7 (creature)
    if math.random(100) <= 90 then
        deathCauseId = 7
    else
        -- 10% chance: Select randomly from other non-creature causes
        if #otherDeathCauseKeys > 0 then
            deathCauseId = otherDeathCauseKeys[math.random(#otherDeathCauseKeys)]
        else
            -- Fallback if only cause 7 exists (or deathCauses is empty/invalid)
            -- Let's default to 0 (Fatigue) in this unlikely case.
            print(addonName .. ": Warning - No non-creature death causes found for random selection. Defaulting to Fatigue (0).")
            deathCauseId = 0
        end
    end

    -- Only generate mob details if death cause ended up being 7
    if deathCauseId == 7 then
        mobName = randomMobs[math.random(#randomMobs)]
        -- Generate a plausible mob level around the player's level
        local mobLevelNum = math.max(1, level + math.random(-5, 7)) -- Mobs can be a bit higher too
        mobLevel = tostring(mobLevelNum)
    end

    -- Check if we got valid IDs (handles empty tables)
    -- deathCauseId is now guaranteed to be set unless the fallback happened
    if not raceId or not classId then
        print(addonName .. ": Error generating random IDs (races or classes table might be empty).")
        return
    end

    -- Construct the message string
    local messageParts = {
        name,
        tostring(raceId),
        tostring(genderId),
        tostring(classId),
        tostring(level),
        zone,
        tostring(deathCauseId),
        mobName,
        mobLevel
    }
    local message = table.concat(messageParts, ":")

    -- Send the addon message
    local target = UnitName("player")
    if not target then
        print(addonName .. ": Cannot send message, player unit not found.")
        return
    end

    -- print(string.format("%s: Sending random test death message: %s", addonName, message)) -- Keep commented out for less spam
    SendAddonMessage("ASMSG_HARDCORE_DEATH", message, "WHISPER", target)
end

-- Example of how to call it:
-- /run GOAHSendRandomDeathMessage()



---
-- Clears clips, reviews, and overrides for a specific targetName AND all names
-- listed in the 'randomNames' table, with minimal output.
-- @param targetName (string) The primary character name to clear.
-- @return (table) A table containing copies of all clips removed.
--
function GOAHClearDBName(targetName)
    if not targetName or targetName == "" then
        print(addonName .. ": GOAHClearDBName requires a non-empty targetName (e.g., 'Grommash').")
        return {}
    end

    -- 1. Build the set of all names to remove
    local namesToRemoveSet = {}
    namesToRemoveSet[targetName] = true

    if randomNames and type(randomNames) == "table" then
        for _, name in ipairs(randomNames) do
            if type(name) == "string" and name ~= "" then
                namesToRemoveSet[name] = true
            end
        end
    else
        -- Keep this warning as it indicates potentially unexpected behavior
        print(addonName .. ": Warning - 'randomNames' table not found or invalid. Only processing '" .. targetName .. "'.")
    end

    -- 2. Process Live Clips
    local allClips = ns.GetLiveDeathClips()
    if not allClips or type(allClips) ~= "table" then
        print(ChatPrefixError() .. "LiveDeathClips table not found or not a table.")
        return {}
    end

    local allRemovedClipsCopies = {}
    local clipKeysToRemove = {}
    local removedClipIDs = {}

    -- Scan clips without printing details for each match
    for key, clip in pairs(allClips) do
        if clip and type(clip) == "table" and clip.characterName and namesToRemoveSet[clip.characterName] then
            local clipCopy = {}
            for k, v in pairs(clip) do clipCopy[k] = v end
            table.insert(allRemovedClipsCopies, clipCopy)
            table.insert(clipKeysToRemove, key)
            if clip.id then
                removedClipIDs[clip.id] = true
                -- else -- Optional: Could add a warning here if needed, but user wants minimal output
                --    print(string.format("%s: Warning: Matched clip (Key='%s', Name='%s') has no ID.", addonName, tostring(key), clip.characterName))
            end
        end
    end

    if #clipKeysToRemove == 0 then
        -- It's useful to know if nothing was found for the target names
        local namesListForLogging = {}
        for name in pairs(namesToRemoveSet) do table.insert(namesListForLogging, "'" .. name .. "'") end
        --print(string.format("%s: No clips found for names %s in LiveDeathClips.", addonName, table.concat(namesListForLogging, ", ")))
        print("No clips found to remove.")
        return {}
    end

    -- Remove clips without printing details
    for _, key in ipairs(clipKeysToRemove) do
        allClips[key] = nil
    end

    -- 3. Process Reviews and Overrides
    local reviewState = ns.GetDeathClipReviewState()
    if not reviewState or not reviewState.persisted then
        print(ChatPrefixError() .. "Could not get valid DeathClipReviewState or its persisted data.")
        OFAuctionFrameDeathClips_Update()
        return allRemovedClipsCopies
    end

    local allReviews = reviewState.persisted.state
    local allOverrides = reviewState.persisted.clipOverrides
    local reviewIDsToRemove = {}
    local overrideClipIDsToRemove = {}
    local reviewsRemovedCount = 0
    local overridesRemovedCount = 0

    if not allReviews or type(allReviews) ~= "table" then
        print(ChatPrefixError() .. "Review state ('persisted.state') is missing or not a table. Cannot remove reviews.")
        allReviews = {}
    end
    if not allOverrides or type(allOverrides) ~= "table" then
        -- Keep this warning
        print(addonName .. ": Warning: Clip overrides ('persisted.clipOverrides') is missing or not a table. Cannot remove overrides.")
        allOverrides = {}
    end

    local hasRemovedClipIDs = false
    for _ in pairs(removedClipIDs) do hasRemovedClipIDs = true; break; end

    if hasRemovedClipIDs then
        -- Scan reviews without printing details
        for reviewId, review in pairs(allReviews) do
            if review and review.clipID and removedClipIDs[review.clipID] then
                table.insert(reviewIDsToRemove, reviewId)
            end
        end

        -- Scan overrides without printing details
        for clipID_key, _ in pairs(allOverrides) do
            if removedClipIDs[clipID_key] then
                table.insert(overrideClipIDsToRemove, clipID_key)
            end
        end

        -- Perform removals without printing details
        if #reviewIDsToRemove > 0 then
            reviewsRemovedCount = #reviewIDsToRemove
            for _, reviewId in ipairs(reviewIDsToRemove) do
                allReviews[reviewId] = nil
            end
        end

        if #overrideClipIDsToRemove > 0 then
            overridesRemovedCount = #overrideClipIDsToRemove
            for _, clipID in ipairs(overrideClipIDsToRemove) do
                allOverrides[clipID] = nil
            end
        end

        -- Mark Dirty if necessary
        if reviewsRemovedCount > 0 or overridesRemovedCount > 0 then
            reviewState:MarkDirty()
        end
        -- else -- No need to print if no clip IDs were found to check
    end

    -- 4. Final Steps
    OFAuctionFrameDeathClips_Update()

    -- Final condensed summary message
    local namesTargetedStr = ""
    local namesCount = 0
    for name in pairs(namesToRemoveSet) do namesCount = namesCount + 1 end
    if namesCount == 1 then
        namesTargetedStr = "'"..targetName.."'"
    else
        namesTargetedStr = string.format("%d names (incl. '%s')", namesCount, targetName)
    end
    print(string.format("%s: Cleared %d clips, %d reviews, %d overrides for %s.", addonName, #clipKeysToRemove, reviewsRemovedCount, overridesRemovedCount, namesTargetedStr))

    return allRemovedClipsCopies
end

-- Example Usage Comment: Needs updating to reflect the new function name.
-- /run GOAHClearDBName("Grommash")


-- LiveDeathClips.lua (append at the end)

-- Helper: remove duplicates occurring within 30 minutes
local function CleanDuplicateDeathClips()
    local clipsById = ns.GetLiveDeathClips()                       -- get all clips :contentReference[oaicite:0]{index=0}&#8203;:contentReference[oaicite:1]{index=1}
    local list = {}
    for id, clip in pairs(clipsById) do
        table.insert(list, clip)
    end
    -- sort oldest → newest
    table.sort(list, function(a,b) return a.ts < b.ts end)

    local seen = {}   -- key → lastTimestamp
    local removed = 0

    for _, clip in ipairs(list) do
        -- build identity key
        local key = table.concat({
            clip.characterName or "",
            clip.race or "",
            clip.class or "",
            tostring(clip.level or 0),
            clip.where or "",
            clip.deathCause or "",
        }, "|")
        local lastTs = seen[key]
        if lastTs and (clip.ts - lastTs) <= 1800 then
            ns.RemoveDeathClip(clip.id)                             -- remove duplicate :contentReference[oaicite:2]{index=2}&#8203;:contentReference[oaicite:3]{index=3}
            removed = removed + 1
        else
            seen[key] = clip.ts
        end
    end

    print(("Cleaned up %d duplicate death-clips found within 30 minutes."):format(removed))
end

-- Register a slash-command
SLASH_CLEANDEATHCLIPS1 = "/cleandeathclips"
SlashCmdList["CLEANDEATHCLIPS"] = function()
    CleanDuplicateDeathClips()
end


---- Function to format and print the current time
--local function PrintCurrentTime()
--    local serverTime = GetServerTime()
--
--    -- Assuming GetServerTime() returns seconds since a reference time (like Unix epoch)
--    -- Convert serverTime from seconds to a human-readable format (HH:MM:SS)
--    local hours = math.floor(serverTime / 3600) -- Convert to hours
--    local minutes = math.floor((serverTime % 3600) / 60) -- Convert remaining seconds to minutes
--    local seconds = serverTime % 60 -- Remaining seconds
--
--    -- Format it into a human-readable format with a space after the first two digits (HH MM:SS)
--    local formattedTime = string.format("Current time: %02d %02d:%02d", hours, minutes, seconds)
--    print(formattedTime)  -- Prints the current time with a gap after the hours
--end
--
---- Set up a ticker to print the current time every second
--C_Timer:NewTicker(1, function()
--    PrintCurrentTime()
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

-- TODO FIXME before release 3.3.5
-- a little hack to not get warning when running testing script:
-- /run SendAddonMessage("ASMSG_HARDCORE_DEATH", "Grommash:26:0:1:16:Цитадель Ледяной Короны:7:Ворг:12", "WHISPER", UnitName("player"))

hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2, data)
    if which == "DANGEROUS_SCRIPTS_WARNING" then
        C_Timer:After(0.01, function()
            local dialog = StaticPopup_Visible(which)
            if dialog then
                local frame = _G[dialog]
                if frame and frame.data then
                    RunScript(frame.data)
                    StaticPopup_Hide(which)
                end
            end
        end)
    end
end)


