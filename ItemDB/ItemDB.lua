local _, ns = ...
local L = ns.L
local Database = {}
ns.ItemDB = Database

function Database:Find(search, class, subclass, slot, quality, minLevel, maxLevel)
    -- Start timer
    local startTime = GetTime()

    search = search and search:lower()
    minLevel = minLevel or 0
    maxLevel = maxLevel or math.huge

    local results = {}
    local lowerSearch = search or ""

    for id, data in pairs(ItemsCache) do
        local nameEN, nameRU = data[1], data[2]
        local itemQuality = data[3]
        local itemLevel = data[4]
        local itemClass = data[6]
        local itemSubclass = data[7]
        local price = data[11]

        -- Filter by class, subclass, and level first (cheap checks)
        if (not class or class == itemClass) and
                (not subclass or subclass == itemSubclass) and
                itemLevel >= minLevel and itemLevel <= maxLevel then

            -- Check if the item meets the quality condition
            if not quality or quality == itemQuality then
                -- If search string is provided, check the name match (optimized)
                local meetsSearch = true
                if lowerSearch ~= "" then
                    local nameENLower = nameEN:lower()
                    local nameRULower = nameRU and nameRU:lower() or ""
                    meetsSearch = nameENLower:find(lowerSearch, 1, true) or nameRULower:find(lowerSearch, 1, true)
                end

                -- If it meets all conditions, add to results
                if meetsSearch then
                    table.insert(results, {
                        id = id,
                        name = nameRU or nameEN,
                        quality = itemQuality,
                        level = itemLevel,
                        equipSlot = slot,
                        subclass = itemSubclass,
                        class = itemClass,
                        quantity = 0,
                        price = price or 0,
                        owner = "",
                        expiresAt = 0,
                        status = "",
                        auctionType = 0,
                        deliveryType = 0,
                    })
                end
            end
        end
    end

    -- End timer and calculate elapsed time
    local endTime = GetTime()
    local elapsedTime = endTime - startTime

    -- Print the time taken in seconds
    print(string.format("Search took %.2f seconds", elapsedTime))

    return results
end

function Database:FindClosest(search)
    local size = #search
    search = '^' .. search:lower()
    local bestID, bestName, bestQuality
    local distance = math.huge

    for id, data in pairs(ItemsCache) do
        local nameEN, nameRU, itemQuality = data[1], data[2], data[3]
        if nameEN:lower():match(search) or (nameRU and nameRU:lower():match(search)) then
            local name = nameEN:lower():match(search) and nameEN or nameRU
            local off = #name - size
            if off >= 0 and off < distance then
                bestID, bestName, bestQuality = id, name, itemQuality
                distance = off
            end
        end
    end

    if bestID then
        return bestID, bestName, bestQuality
    end
end

function Database:ClassExists(class, subclass, slot)
    for _, data in pairs(ItemsCache) do
        if subclass and slot then
            if data[6] == class and data[7] == subclass and slot ~= 0 then
                return true
            end
        elseif subclass then
            if data[6] == class and data[7] == subclass then
                return true
            end
        else
            if data[6] == class then
                return true
            end
        end
    end
    return false
end

function Database:HasEquipSlots(class, subclass)
    -- We simulate "slots" by checking if at least one item with class/subclass has nonzero slot (if applicable)
    for _, data in pairs(ItemsCache) do
        if data[6] == class and data[7] == subclass then
            return true
        end
    end
    return false
end


--[[ Utilities ]]--

function Database:GetLink(id, name, quality)
    return ('%s|Hitem:%d:::::::::::::::|h[%s]|h|r'):format(ITEM_QUALITY_COLORS[quality or 1].hex, id, name)
end

--function Database:Translate()
--    if ItemTranslations == nil then
--        ItemTranslations = {}
--    end
--    local translations = ItemTranslations
--    local allItems = self:Find()
--    local toTranslate = {}
--
--    for _, item in ipairs(allItems) do
--        if item.class ~= ns.SPELL_ITEM_CLASS_ID and translations[item.name] == nil then
--            tinsert(toTranslate, item)
--        end
--    end
--
--    if #toTranslate == 0 then
--        print("All items are translated")
--        return
--    end
--
--    local i = 1
--    C_Timer:NewTicker(0.2, function()
--        local item = toTranslate[i]
--        ns.GetItemInfoAsync(item.id, function(...)
--            local info = ns.ItemInfoToTable(...)
--            translations[item.name] = info.name
--            print("Translated", item.name, "to", info.name)
--        end)
--        i = i + 1
--    end, #toTranslate)
--end
