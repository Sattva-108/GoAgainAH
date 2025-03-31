local _, ns = ...

local CLIP_URL_TEMPLATE = "https://deathclips.athenegpt.ai/deathclip?streamerName=%s&deathTimestamp=%d"

ns.GetClipUrl = function(streamer, ts)
    if streamer == nil then
        return nil
    end
    return string.format(CLIP_URL_TEMPLATE, streamer, ts)
end

local function stringCompare(l,r, field)
    return (l[field] or "") < (r[field] or "") and -1 or (l[field] or "") > (r[field] or "") and 1 or 0
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
            addSorter(desc, function(l, r) return stringCompare(l, r, "streamer") end)
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
            addSorter(desc, function(l, r) return stringCompare(l, r, "clip") end)
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