local _, ns = ...
local Database = {}
ns.ItemDB = Database
local ITEM_MATCH = '(%w%w%w%w)([^_]+)'


function Database:Find(search, class, subclass, slot, quality, minLevel, maxLevel)
    --regex escape search
    search = search and search:gsub("([^%w])", "%%%1")
    local results = {}

    search = search and search:lower()
    maxLevel = maxLevel or math.huge
    minLevel = minLevel or 0

    for category, subclasses in pairs(ns.AllItems) do
        if not class or class == category then
            for subcat, slots in pairs(subclasses) do
                if not subclass or subclass == subcat then
                    for equipSlot, qualities in pairs(slots) do
                        if not slot or slot == equipSlot then
                            for rarity, levels in pairs(qualities) do
                                if not quality or quality == rarity then
                                    for level, items in pairs(levels) do
                                        if level >= minLevel and level <= maxLevel then
                                            local function maybeAddItem(id, name)
                                                if search and not name:lower():find(search) then
                                                    return
                                                end
                                                tinsert(results, {
                                                    id = id,
                                                    name = name,
                                                    quality = rarity,
                                                    level = level,
                                                    equipSlot = equipSlot,
                                                    subclass = subcat,
                                                    class = category,

                                                    -- auction compat for sorting
                                                    quantity = 0,
                                                    price = 0,
                                                    owner = "",
                                                    expiresAt = 0,
                                                    status = "",
                                                    auctionType = 0,
                                                    deliveryType = 0,
                                                })

                                            end 
                                            if type(items) == "table" then
                                                for id, name in pairs(items) do
                                                    maybeAddItem(id, name)
                                                end
                                            else
                                                for id, name in items:gmatch(ITEM_MATCH) do
                                                    id = tonumber(id, 36)
                                                    maybeAddItem(id, name)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return results
end

function Database:FindClosest(search)
    local size = #search
    local search = '^' .. search:lower()
    local distance = math.huge
    local bestID, bestName, bestQuality

    for class, subclasses in pairs(ns.AllItems) do
        for subclass, slots in pairs(subclasses) do
            for equipSlot, qualities in pairs(slots) do
                for quality, levels in pairs(qualities) do
                    for level, items in pairs(levels) do
                        for id, name in items:gmatch(ITEM_MATCH) do
                            if name:lower():match(search) then
                                local off = #name - size
                                if off >= 0 and off < distance then
                                    bestID, bestName, bestQuality = id, name, quality
                                    distance = off
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if bestID then
        return tonumber(bestID, 36), bestName, bestQuality
    end
end

function Database:ClassExists(class, subclass, slot)
    if slot then
        return ns.AllItems[class] and ns.AllItems[class][subclass] and ns.AllItems[class][subclass][slot]
    elseif subclass then
        return ns.AllItems[class] and ns.AllItems[class][subclass]
    else
        return ns.AllItems[class]
    end
end

function Database:HasEquipSlots(class, subclass)
    for slot in pairs(ns.AllItems[class][subclass]) do
        if slot ~= 0 then
            return true
        end
    end
end


--[[ Utilities ]]--

function Database:GetLink(id, name, quality)
    return ('%s|Hitem:%d:::::::::::::::|h[%s]|h|r'):format(ITEM_QUALITY_COLORS[quality].hex, id, name)
end
