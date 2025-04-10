local _, ns = ...
local L = ns.L
local Database = {}
ns.ItemDB = Database

-- Let's say you have a file or string of comma-separated IDs:
local rawBlacklist = "49623, 50818, 49050, 46017, 43228, 47242, 46109, 49040, 49636, 50274, 44707, 50048, 44151, 39769, 44234, 44050, 44502, 44503, 50362, 50255, 46102, 49888, 40343, 43154, 54590, 45693, 46007, 49426, 50429, 52025, 39152, 43952, 44235, 43962, 46874, 49869, 50737, 43155, 44957, 46114, 43951, 44178, 43698, 39878, 44135, 40752, 43953, 50363, 45801, 50730, 39344, 19019, 50653, 43508, 44164, 42187, 44175, 47214, 47241, 44168, 50367, 52027, 51954, 50012, 50741, 43157, 44149, 50198, 49177, 40491, 43954, 37111, 45931, 44751, 52026, 40775, 37254, 39644, 40497, 44133, 44160, 46051, 54588, 40684, 44935, 45518, 52023, 22559, 39883, 50735, 43986, 50402, 54583, 16217, 43955, 47545, 51955, 45802, 46348, 43085, 44159, 40643, 44492, 34114, 47179, 43510, 45038, 54860, 50731, 50398, 13335, 43499, 45992, 50624, 54811, 50348, 50732, 29434, 32768, 43017, 47115, 50415, 50049, 50343, 50707, 199210, 18348, 43349, 45037, 12938, 45609, 50309, 50365, 41267, 44083, 47546, 50733, 47303, 47541, 48685, 50369, 45638, 45535, 9149, 40384, 47196, 51901, 22691, 22909, 45725, 47213, 54569, 54578, 12753, 54576, 45639, 47131, 54580, 43016, 45640, 46746, 46778, 52676, 24111, 50267, 44430, 44495, 52019, 54797, 44077, 44096, 44177, 44558, 50675, 54572, 54582, 19182, 28558, 39629, 43599, 8411, 8412, 16207, 22462, 34109, 44510, 40266, 40456, 43156, 49044, 49912, 45516, 50028, 54581, 42184, 44230, 45074, 46814, 47557, 51315, 11808, 42142, 44717, 45574, 47464, 45858, 49096, 50656, 40616, 45632, 47180, 50360, 50470, 50734, 44987, 45774, 46780, 35797, 38551, 50052, 50694, 10575, 46027, 50706, 50736, 22461, 39427, 45581, 47316, 50335, 50618, 50664, 5396, 50342, 50684, 13704, 22484, 23574, 34834, 42950, 43959, 43961, 45072, 50273, 5175, 32458, 37788, 45656, 45949, 50724, 52022, 11000, 22523, 50051, 50699, 51909, 37836, 40614, 43958, 45579, 45991, 50259, 8529, 9240, 11516, 13086, 50356, 50613, 50654, 207097, 18160, 34597, 40586, 42946, 49098, 53126, 19970, 22907, 41755, 44718, 47271, 49844, 50046, 52030, 54573, 25772, 33871, 42492, 43029, 43509, 44998, 53132, 206392, 3898, 33820, 40613, 41704, 45192, 45212, 45585, 45649, 45658, 46815, 51205, 42949, 46032, 47884, 50355, 53125, 27991, 30480, 33307, 40612, 45583, 47559, 50366, 51580, 40406, 40895, 43507, 44150, 45591, 46813, 50047, 50351, 5863, 32449, 35498, 40615, 42553, 42947, 42991, 45580, 45597, 49953, 50210, 50368, 50427, 9449, 11815, 19902, 38237, 40700, 40705, 40753, 44086, 44224, 44724, 45634, 49303, 18542, 40336, 40383, 44452, 45205, 46708, 50690, 54806, 6975, 40256, 42153, 44228, 45610, 49954, 6265, 30622, 37012, 40400, 40639, 41824, 43650, 50353, 50719, 51534, 54218, 23888, 33844, 40585, 44956, 45165, 45308, 45620, 46097, 47285, 48691, 50226, 50629, 31546, 40407, 42943, 47548, 50289, 50404, 50620, 11684, 41710, 45637, 47059, 48724, 50640, 50709, 5060, 13873, 22463, 47216, 47525, 48681, 50692, 51316, 52572, 12302, 29759, 40396, 45466, 45570, 45624, 32235, 32837, 33925, 42190, 44136, 45841, 45877, 46038, 46861, 47672, 49112, 49976, 51573, 6687, 7731, 12735, 19103, 20131, 31062, 37653, 39276, 40631, 40638, 44092, 44093, 44569, 44843, 44937, 46036, 47069, 50268, 50685, 54798, 4127, 5813, 13955, 27388, 31780, 34334, 35504, 40345, 41556, 43089, 43348, 44113, 44871, 45700, 45868, 47665, 50622, 50726, 51011, 4614, 7717, 13178, 18249, 37360, 40628, 40682, 44489, 45059, 47661, 49052, 50633, 22736, 34486, 40255, 41817, 43589, 46172, 47041, 47558, 49495, 49498, 50231, 50287, 50316, 50319, 50340, 50406, 50426, 50639, 50647, 50704, 51354, 5088, 6953, 12590, 22524, 22589, 22780, 35188, 40432, 40637, 43876, 44738, 44990, 45607, 48718, 50850, 51355, 52006, 13523, 23720, 33857, 34484, 36767, 37852, 39327, 41212, 43036, 44115, 45294, 45470, 45490, 49835, 50021, 50660, 50670, 50718, 54579, 6893, 12690, 12739, 17182, 37108, 42070, 43300, 44069, 44719, 45039, 45798, 49086, 49956, 50414, 50469, 50616, 51378, 2820, 7666, 18268, 22999, 23709, 28395, 33875, 37631, 37684, 38311, 38346, 39973, 42185, 42186, 42482, 43506, 45320, 45595, 45655, 45659, 45983, 46917, 47668, 49961, 50612, 50619, 50672, 50697, 51305, 54452, 6802, 6897, 7146, 7298, 19029, 24314, 25537, 28337, 29735, 34777, 35513, 35671, 38321, 39245, 42295, 42549, 44283, 44297, 45501, 46035, 47468, 47673, 48023, 48689, 49704, 50065, 50345, 50376, 50603, 50621, 50738, 51312, 52028, 54587, 3604, 7726, 7987, 11122, 11474, 13965, 17962, 18521, 23705, 39233, 39254, 40385, 40402, 40610, 42944, 43505, 44067, 44487, 45145, 46052, 47215, 47489, 50191, 50250, 50302, 50364, 50607, 6469, 6505, 8410, 9372, 17780, 40420, 40618, 40624, 40627, 42333, 42945, 43346, 45078, 45115, 45118, 45587, 45682, 46707, 47432, 47522, 50070, 50423, 50628, 51187, 51332, 201699, 6218, 6324, 7054, 7682, 8564, 23577, 31084, 32375, 33869, 33873, 34616, 40401, 41121, 44225, 44494, 46809, 47493, 48716, 49643, 49793, 49802, 49833, 49972, 49992, 50034, 50050, 50358, 50466, 50638, 51285, 51791, 3342, 3765, 6830, 20536, 24344, 25459, 28428, 29762, 33004, 37719, 38050, 39514, 40611, 40707, 40819, 42188, 43308, 43838, 44103, 45724, 46067, 46817, 46964, 48420, 49046, 49299, 50658, 50659, 50729, 50798, 51392, 51572, 54577, 1322, 2041, 6948, 7512, 19968, 27488, 28184, 28760, 30769, 33870, 34214, 37220, 37574, 37873, 38368, 38578, 39417, 40623, 40629, 40822, 42144, 42321, 44249, 45283, 45592, 45593, 45613, 45633, 46201, 47314, 48677, 49288, 49298, 49959, 50173, 50315, 50338, 50400, 50425, 50428, 50457, 51224, 51418, 53133, 54584, 1262, 1404, 2933, 5191, 18538, 19872, 22551, 22555, 27418, 27505, 40189, 40617, 40633, 40698, 40699, 42183, 42952, 44938, 45073, 45495, 46106, 46344, 47302, 47451, 47678, 48458, 49801, 49981, 50019, 50727, 50761, 51227, 51796, 53486, 1307, 7709, 11902, 13246, 16606, 19323, 27427, 28767, 29745, 35221, 37616, 40207, 40265, 45170, 45459, 45584, 45940, 46747, 47101, 47483, 49646, 49821, 50230, 50241, 51126, 51277, 51281, 51317, 6414, 7714, 10652, 10725, 18817, 19024, 19364, 23193, 27490, 29337, 31090, 35295, 38661, 40630, 44098, 44201, 44800, 45112, 45586, 45982, 47477, 50303, 50314, 50412, 50435, 50455, 50691, 50805, 51321, 51802, 54585, 54589, 2044, 3251, 6320, 6339, 7688, 10823, 14622, 16544, 18816, 19972, 22779, 23143, 27912, 33224, 35348, 37064, 37620, 38660, 39393, 40475, 41888, 44874, 45506, 45661, 46752, 47266, 47437, 48697, 49325, 50357, 50627, 51333, 51557, 737, 2411, 4120, 6682, 6916, 7994, 9452, 9492, 11364, 12871, 20371, 23192, 27510, 30256, 32387, 33289, 34247, 37191, 37401, 39395, 41152, 42550, 42984, 42985, 43068, 43345, 43494, 44099, 44606, 44689, 44791, 46046, 46171, 46346, 47138, 47737, 48446, 48722, 49343, 49842, 49974, 50359, 50458, 50668, 50688, 50710, 51129, 51465, 52000, 54810, 872, 1146, 5274, 6641, 7720, 7997, 8029, 8623, 13505, 13517, 28444, 28573, 28825, 29765, 30278, 30633, 31097, 32378, 33225, 34092, 34652, 38632, 40625, 44075, 44141, 44240, 44303, 44725, 47088, 47516, 47569, 49963, 49982, 50067, 50227, 50290, 50711, 50794, 51795, 51855, 51898, 51981, 198647"

local function buildBlacklistSet(raw)
    local set = {}
    for id in raw:gmatch("%d+") do
        set[tonumber(id)] = true
    end
    return set
end

local blacklistedIDs = buildBlacklistSet(rawBlacklist)

local blacklistedCount = 0

function Database:Find(search, class, subclass, slot, quality, minLevel, maxLevel)
    local startTime = GetTime()

    search = search and search:lower()
    minLevel = minLevel or 0
    maxLevel = maxLevel or math.huge

    local results = {}
    local lowerSearch = search or ""

    for id, data in pairs(ItemsCache) do
        if blacklistedIDs[id] then
            blacklistedCount = blacklistedCount + 1
        else
            local nameRU = data[2]
            local itemQuality = data[3]
            local itemLevel = data[4]
            local itemClass = data[6]
            local itemSubclass = data[7]
            local price = data[11]

            if (not class or class == itemClass) and
                    (not subclass or subclass == itemSubclass) and
                    itemLevel >= minLevel and itemLevel <= maxLevel and
                    (not quality or quality == itemQuality) then

                local meetsSearch = true
                if lowerSearch ~= "" then
                    local nameRULower = nameRU and nameRU:lower() or ""
                    meetsSearch = nameRULower:find(lowerSearch, 1, true)
                end

                if meetsSearch then
                    table.insert(results, {
                        id = id,
                        name = nameRU,
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

    local endTime = GetTime()
    local elapsedTime = endTime - startTime
    print(string.format("Search took %.2f seconds", elapsedTime))
    print(string.format("Skipped %d blacklisted items", blacklistedCount))

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
