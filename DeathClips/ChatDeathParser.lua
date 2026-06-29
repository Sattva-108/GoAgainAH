local _, ns = ...

------------------------------------------------------------------------
-- ChatDeathParser: парсинг CHAT_MSG_SYSTEM для 3.3.5 серверов
-- Извлекает данные о смерти из текстовых системных сообщений
------------------------------------------------------------------------

-- Удаление форматирования WoW из строки
local function StripFormatting(msg)
    if not msg or msg == "" then return "" end
    local cleaned = msg:gsub("|H[^|]*|h(.-)|h", "%1")
    cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x(.-)|r", "%1")
    cleaned = cleaned:gsub("|[%a][^|]*|", "")
    cleaned = cleaned:gsub("|", "")
    cleaned = cleaned:gsub("[%z\1-\31]", "")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    return cleaned
end

-- Проверка: является ли сообщение сообщением о смерти
local function HasDeathKeywords(msg)
    if not msg or msg == "" then return false end
    local lower = string.lower(msg)
    return (lower:find("поги[бл]") and lower:find("на %d+ уровне"))
end

-- Разбиение строки с обработкой апострофов в именах (Ладим'Ладан)
local function SplitString(inputstr, sep)
    if type(inputstr) ~= "string" then return {} end
    if sep == nil then sep = "%s" end

    local processedStr = inputstr:gsub("([%a])'([%a])", "%1###%2")

    local t = {}
    for str in string.gmatch(processedStr, "([^" .. sep .. "]+)") do
        if type(str) == "string" then
            local restored = str:gsub("###", "'")
            t[#t + 1] = restored
        end
    end
    return t
end

-- Парсинг сообщения о смерти, возвращает таблицу или nil
local function ParseDeathMessage(fullMessage)
    if not HasDeathKeywords(fullMessage) then return nil end

    local cleanMsg = StripFormatting(fullMessage):gsub("^%s*,%s*", "")
    if cleanMsg == "" then return nil end

    -- Имя игрока в скобках [Имя]
    local playerName = cleanMsg:match("%[([^%]]+)%]")
    if not playerName then return nil end

    -- Убираем имя, работаем с оставшимся текстом
    local msgBody = cleanMsg:gsub("%[([^%]]+)%]", "", 1):gsub("^%s*,%s*", "")
    local words = SplitString(msgBody)

    -- Находим индекс "погиб"/"погибла"
    local deathIndex = nil
    for i, w in ipairs(words) do
        if w == "погиб" or w == "погибла" then
            deathIndex = i
            break
        end
    end
    if not deathIndex then return nil end

    ----------------------------------------------------------------
    -- Раса и класс (до слова "погиб")
    ----------------------------------------------------------------
    local raceClassPart = {}
    for i = 1, deathIndex - 1 do
        local w = words[i]
        if type(w) == "string" then
            raceClassPart[#raceClassPart + 1] = w:gsub(",", "")
        end
    end

    local race = ""
    local class = ""
    local fullRaceClass = table.concat(raceClassPart, " ")

    -- Двусловные расы: "эльф крови", "ночной эльф" и т.д.
    local twoWordRaces = {
        "эльф крови", "ночной эльф", "эльфы крови", "ночные эльфы"
    }

    local foundTwoWordRace = false
    for _, twoWordRace in ipairs(twoWordRaces) do
        if fullRaceClass:lower():find(twoWordRace:lower()) then
            local raceStart, raceEnd = fullRaceClass:lower():find(twoWordRace:lower())
            if raceStart then
                race = fullRaceClass:sub(raceStart, raceEnd)
                local dashPos = fullRaceClass:find("-", raceEnd + 1)
                if dashPos then
                    class = fullRaceClass:sub(dashPos + 1):gsub("^%s+", ""):gsub("%s+$", "")
                    foundTwoWordRace = true
                    break
                end
            end
        end
    end

    -- Однословные расы: "орк-воин", "человек-маг" и т.д.
    if not foundTwoWordRace then
        local foundDash = false
        for _, part in ipairs(raceClassPart) do
            if type(part) == "string" and part:find("-") then
                local parts = SplitString(part, "-")
                if #parts == 2 then
                    race = parts[1]
                    class = parts[2]
                    foundDash = true
                    break
                end
            end
        end

        if not foundDash and #raceClassPart >= 2 then
            class = raceClassPart[#raceClassPart]
            local raceParts = {}
            for i = 1, #raceClassPart - 1 do raceParts[#raceParts + 1] = raceClassPart[i] end
            race = table.concat(raceParts, " ")
        elseif not foundDash and #raceClassPart == 1 then
            class = raceClassPart[1]
        end
    end

    race = (race or ""):gsub("[,%.]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    class = (class or ""):gsub("[,%.]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if class == "" then return nil end

    ----------------------------------------------------------------
    -- Уровень: "на N уровне"
    ----------------------------------------------------------------
    local level = 0
    for i = deathIndex + 1, #words do
        if words[i] == "на" and i + 2 <= #words
           and words[i + 1]:match("^%d+$") and words[i + 2] == "уровне" then
            level = tonumber(words[i + 1]) or 0
            break
        end
    end

    ----------------------------------------------------------------
    -- Локация: "в локации X" или "в X"
    ----------------------------------------------------------------
    local location = "Неизвестно"

    -- Приоритет: "в локации X"
    for i = 1, #words do
        if words[i] == "в" and i + 1 <= #words and words[i + 1] == "локации" and i + 2 <= #words then
            local locWords = {}
            for k = i + 2, #words do
                local w = words[k]
                if type(w) ~= "string" then break end
                if w == "-" or w == "," or w == "." or w == "его" or w == "её"
                   or w == "победил" or w == "победила" or w == "убил" or w == "убила"
                   or w == "гравитация" then break end
                table.insert(locWords, w)
            end
            if #locWords > 0 then
                location = table.concat(locWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                break
            end
        end
    end

    -- Фоллбэк: "в Зона"
    if location == "Неизвестно" then
        for i = 1, #words do
            if words[i] == "в" and i + 1 <= #words then
                local nextWord = words[i + 1]
                if type(nextWord) == "string" and not nextWord:match("^[%.%,]-$") then
                    local locWords = {}
                    for j = i + 1, #words do
                        local w = words[j]
                        if type(w) ~= "string" then break end
                        if w == "-" or w == "," or w == "." or w == "его" or w == "её"
                           or w == "победил" or w == "победила" or w == "убил" or w == "убила"
                           or w == "гравитация" then break end
                        table.insert(locWords, w)
                    end
                    if #locWords > 0 then
                        location = table.concat(locWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        break
                    end
                end
            end
        end
    end

    ----------------------------------------------------------------
    -- Убийца: текст после тире и глагола
    ----------------------------------------------------------------
    local killer = "Неизвестно"

    if msgBody:find("гравитация оказалась сильнее") then
        killer = "Падение"
    else
        -- Ищем тире как разделитель между "погиб" и "убил"
        local dashIndex = nil
        for i, w in ipairs(words) do
            if w == "-" then dashIndex = i break end
        end

        local killerPhrases = {
            "победил", "победила", "убил", "убила",
            "разорвал", "разорвала", "сокрушил", "сокрушила",
            "раздавил", "раздавила", "погубил", "погубила",
        }

        -- Местоимения перед глаголом
        local pronounPhrases = {
            {"его", "победил"}, {"её", "победил"}, {"его", "победила"}, {"её", "победила"},
            {"его", "убил"}, {"её", "убила"}, {"его", "разорвал"}, {"её", "разорвала"},
            {"его", "сокрушил"}, {"её", "сокрушила"}, {"его", "раздавил"}, {"её", "раздавила"},
            {"его", "погубил"}, {"её", "погубила"},
        }

        -- Стратегия 1: после тире
        if dashIndex then
            local killerStart = nil
            for i = dashIndex + 1, #words do
                for _, phrase in ipairs(pronounPhrases) do
                    if words[i] == phrase[1] and i + 1 <= #words and words[i + 1] == phrase[2] then
                        killerStart = i + 2
                        break
                    end
                end
                if not killerStart then
                    for _, verb in ipairs(killerPhrases) do
                        if words[i] == verb then
                            killerStart = i + 1
                            break
                        end
                    end
                end
                if killerStart then break end
            end

            if killerStart then
                local killerWords = {}
                for i = killerStart, #words do
                    if type(words[i]) == "string" then
                        local word = words[i]:gsub("[%.]", "")
                        if word ~= "" then
                            -- Обработка апострофов в именах типа Ладим'Ладан
                            if word:find("'") and i < #words and words[i + 1] and words[i + 1]:find("Ладим") then
                                table.insert(killerWords, word .. " " .. words[i + 1])
                            else
                                table.insert(killerWords, word)
                            end
                        end
                    end
                end
                killer = table.concat(killerWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            end
        end

        -- Стратегия 2: ищем глагол после "погиб на N уровне"
        if killer == "Неизвестно" then
            local killerStart = nil
            for i = deathIndex + 1, #words do
                -- Пропускаем "на N уровне"
                if words[i] == "на" and i + 2 <= #words
                   and words[i + 1]:match("^%d+$") and words[i + 2] == "уровне" then
                    -- пропущено
                else
                    for _, phrase in ipairs(pronounPhrases) do
                        if words[i] == phrase[1] and i + 1 <= #words and words[i + 1] == phrase[2] then
                            killerStart = i + 2
                            break
                        end
                    end
                    if not killerStart then
                        for _, verb in ipairs(killerPhrases) do
                            if words[i] == verb then
                                killerStart = i + 1
                                break
                            end
                        end
                    end
                end
                if killerStart then break end
            end

            if killerStart then
                local killerEnd = #words
                for i = killerStart, #words do
                    if words[i] == "в" and i + 1 <= #words and words[i + 1] == "локации" then
                        killerEnd = i - 1
                        break
                    end
                    if words[i] == "-" then killerEnd = i - 1 break end
                end

                local killerWords = {}
                for i = killerStart, killerEnd do
                    if i <= #words and type(words[i]) == "string" then
                        local word = words[i]:gsub("[,%.]", "")
                        if word ~= "" then
                            if word:find("'") and i < #words and words[i + 1] and words[i + 1]:find("Ладим") then
                                table.insert(killerWords, word .. " " .. words[i + 1])
                            else
                                table.insert(killerWords, word)
                            end
                        end
                    end
                end
                killer = table.concat(killerWords, " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                if killer == "" then killer = "Неизвестно" end
            end
        end

        -- Стратегия 3: последнее слово перед точкой
        if killer == "Неизвестно" then
            for i = #words, 1, -1 do
                if words[i] == "." and i > 1 then
                    local prevWord = words[i - 1]:gsub("[%.]", "")
                    if prevWord ~= "" then
                        if prevWord:find("'") and i > 2 then
                            killer = words[i - 2] .. " " .. prevWord
                        else
                            killer = prevWord
                        end
                        break
                    end
                end
            end
        end
    end

    return {
        playerName = playerName,
        race      = race,
        class     = class,
        level     = level,
        killer    = killer,
        location  = location,
    }
end

------------------------------------------------------------------------
-- Маппинг: русские строки → формат clipData
------------------------------------------------------------------------

-- Кэш для быстрого поиска расы по имени
local raceByName = nil
local function GetRaceByName()
    if raceByName then return raceByName end
    raceByName = {}
    for _, info in pairs(ns.RaceInfoByID) do
        local key = info.name:lower()
        raceByName[key] = info
    end
    return raceByName
end

-- Конвертация распарсенных данных в clipData
local function MapToClipData(parsed)
    -- Класс: русское название → английский токен
    local classToken = nil
    if parsed.class and parsed.class ~= "" then
        classToken = ns.russianClassNameToEnglishToken[parsed.class]
                   or ns.russianClassNameToEnglishToken[parsed.class:lower()]
                   or ns.russianClassNameToEnglishToken[parsed.class:upper()]
    end

    -- Раса: русское название → {name, faction}
    local raceInfo = nil
    if parsed.race and parsed.race ~= "" then
        local raceMap = GetRaceByName()
        raceInfo = raceMap[parsed.race:lower()]
    end

    -- Причина смерти → causeCode
    local causeCode = 7  -- по умолчанию: убит существом
    local deathCause = parsed.killer or "Неизвестно"

    if parsed.killer == "Падение" or parsed.killer:lower():find("гравитацию") then
        causeCode = 2  -- Падение
        deathCause = ns.DeathCauseByID[2] or "Падение"
    elseif parsed.killer == "Неизвестно" then
        causeCode = 0
        deathCause = ns.DeathCauseByID[0] or "Неизвестно"
    end

    return {
        characterName = parsed.playerName,
        race          = (raceInfo and raceInfo.name) or parsed.race or "Неизвестно",
        faction       = (raceInfo and raceInfo.faction) or "Unknown",
        class         = classToken or "Неизвестно",
        level         = parsed.level or 0,
        where         = parsed.location or "Неизвестно",
        causeCode     = causeCode,
        deathCause    = deathCause,
        mobLevel      = 0,
    }
end

------------------------------------------------------------------------
-- Обработчик CHAT_MSG_SYSTEM
------------------------------------------------------------------------
local chatFrame = CreateFrame("Frame")
chatFrame:RegisterEvent("CHAT_MSG_SYSTEM")
chatFrame:SetScript("OnEvent", function(self, event, message)
    local parsed = ParseDeathMessage(message)
    if not parsed then return end

    local clipData = MapToClipData(parsed)

    -- Дедупликация: проверяем, не пришло ли уже CHAT_MSG_ADDON с тем же именем
    local existingClips = ns.GetLiveDeathClips()
    local now = GetServerTime()
    for _, clip in pairs(existingClips) do
        if clip.characterName == clipData.characterName
           and math.abs((clip.ts or 0) - now) < 10 then
            return  -- Уже добавлен через CHAT_MSG_ADDON
        end
    end

    ns.AddDeathClipFromData(clipData)
end)
