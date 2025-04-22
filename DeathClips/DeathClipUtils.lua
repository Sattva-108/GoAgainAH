local addonName, ns = ...

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

function GOAHClearDBName(targetName)
    if not targetName then
        print(addonName .. ": GOAHClearDBName requires a targetName in brackets ''.")
        return {}
    end

    local allClips = ns.GetLiveDeathClips()

    if not allClips or type(allClips) ~= "table" then
        print(addonName .. ": LiveDeathClips table not found or not a table.")
        return {}
    end

    local removedClips = {}
    local clipKeysToRemove = {}
    local removedClipIDs = {} -- Store the IDs of the clips being removed { ["clipID1"] = true, ... }

    -- Pass 1: Identify clips to remove and collect their keys and IDs
    for key, clip in pairs(allClips) do
        if clip and type(clip) == "table" and clip.characterName and clip.characterName == targetName then
            local clipCopy = {}
            for k, v in pairs(clip) do clipCopy[k] = v end
            table.insert(removedClips, clipCopy)
            table.insert(clipKeysToRemove, key)
            -- Store the clip ID if it exists
            if clip.id then
                removedClipIDs[clip.id] = true
            end
        end
    end

    -- Remove the identified clips from LiveDeathClips
    if #clipKeysToRemove > 0 then
        print(string.format("%s: Found %d clips for '%s'. Removing them from LiveDeathClips.", addonName, #clipKeysToRemove, targetName))
        for _, key in ipairs(clipKeysToRemove) do
            allClips[key] = nil
        end
    else
        print(string.format("%s: No clips found for '%s' in LiveDeathClips.", addonName, targetName))
        -- If no clips found, no need to check reviews/overrides
        return {}
    end

    -- Now, remove associated reviews and overrides
    local reviewState = ns.GetDeathClipReviewState()
    local allReviews = reviewState.persisted.state
    local allOverrides = reviewState.persisted.clipOverrides
    local reviewIDsToRemove = {}
    local overrideClipIDsToRemove = {}
    local reviewsRemovedCount = 0
    local overridesRemovedCount = 0

    -- Check if there are any clip IDs to actually search for in reviews/overrides
    local hasRemovedClipIDs = false
    for _ in pairs(removedClipIDs) do
        hasRemovedClipIDs = true
        break
    end

    if hasRemovedClipIDs then
        -- Identify reviews associated with the removed clip IDs
        if allReviews and type(allReviews) == "table" then
            for reviewId, review in pairs(allReviews) do
                if review and review.clipID and removedClipIDs[review.clipID] then
                    table.insert(reviewIDsToRemove, reviewId)
                end
            end
        end

        -- Identify overrides associated with the removed clip IDs
        if allOverrides and type(allOverrides) == "table" then
            for clipID, _ in pairs(allOverrides) do
                if removedClipIDs[clipID] then
                    table.insert(overrideClipIDsToRemove, clipID)
                end
            end
        end

        -- Remove the identified reviews
        if #reviewIDsToRemove > 0 then
            reviewsRemovedCount = #reviewIDsToRemove
            print(string.format("%s: Removing %d associated reviews from DeathClipReviewsSaved.", addonName, reviewsRemovedCount))
            for _, reviewId in ipairs(reviewIDsToRemove) do
                allReviews[reviewId] = nil
            end
        end

        -- Remove the identified overrides
        if #overrideClipIDsToRemove > 0 then
            overridesRemovedCount = #overrideClipIDsToRemove
            print(string.format("%s: Removing %d associated clip overrides from DeathClipReviewsSaved.", addonName, overridesRemovedCount))
            for _, clipID in ipairs(overrideClipIDsToRemove) do
                allOverrides[clipID] = nil
            end
        end

        -- Mark the review state as dirty if anything was removed from it
        if reviewsRemovedCount > 0 or overridesRemovedCount > 0 then
            reviewState:MarkDirty()
        end
    else
        print(string.format("%s: No clip IDs found for removed clips of '%s' to check reviews/overrides.", addonName, targetName))
    end

    -- Update the UI if necessary
    if #clipKeysToRemove > 0 or reviewsRemovedCount > 0 or overridesRemovedCount > 0 then
        OFAuctionFrameDeathClips_Update()
    end

    return removedClips
end

-- Example Usage Comment: Needs updating to reflect the new function name.
-- /run GOAHClearDBName("Grommash")


-- TODO FIXME before release 3.3.5
-- a little hack to not get warning when running testing script:
-- /run SendAddonMessage("ASMSG_HARDCORE_DEATH", "Grommash:15:0:1:16:Цитадель Ледяной Короны:7:Ворг:12", "WHISPER", UnitName("player"))

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
