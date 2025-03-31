local _, ns = ...

local function stringCompare(l,r, field)
    return (l[field] or "") < (r[field] or "") and -1 or (l[field] or "") > (r[field] or "") and 1 or 0
end

local function CreateSorter(sortParams)
    local sorters = { }
    local addSorter = function(desc, sorter)
        local sign = desc and -1 or 1
        table.insert(sorters, function(l, r) return sign * sorter(l, r) end)
    end

    for i = #sortParams, 1, -1 do
        local k = sortParams[i].column
        local desc = sortParams[i].reverse
        if k == "name" then
            addSorter(desc, function(l, r) return stringCompare(l, r, "name") end)
        elseif k == "minLevel" then
            addSorter(desc, function(l, r) return (l.level or 0) - (r.level or 0) end)
        elseif k == "class" then
            addSorter(desc, function(l, r) return stringCompare(l, r, "class") end)
        elseif k == "minViewers" then
            addSorter(desc, function(l, r) return (l.minViewers or 0) - (r.minViewers or 0) end)
        elseif k == "level" then
            addSorter(desc, function(l, r) return (l.level or 0) - (r.level or 0) end)
        elseif k == "isOnline" then
            addSorter(desc, function(l, r) 
                if l.isOnline == r.isOnline then return 0
                elseif l.isOnline then return 1
                else return -1 end
            end)
        elseif k == "isLeveling" then
            addSorter(desc, function(l, r)
                if l.isLeveling == r.isLeveling then return 0
                elseif l.isLeveling then return 1
                else return -1 end
            end)
        elseif k == "meetsRequirements" then
            addSorter(desc, function(l, r)
                if l.meetsRequirements == r.meetsRequirements then return 0
                elseif l.meetsRequirements then return 1
                else return -1 end
            end)
        elseif k == "isDungeon" then
            addSorter(desc, function(l, r)
                if l.isDungeon == r.isDungeon then return 0
                elseif l.isDungeon then return 1
                else return -1 end
            end)
        end
    end

    return ns.CreateCompositeSorter(sorters)
end

ns.SortLFG = function(clips, sortParams)
    local sorter = CreateSorter(sortParams)
    table.sort(clips, sorter)
    return clips
end
