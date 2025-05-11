local addonName, ns = ...

ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE = "EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE"
ns.EV_DEATH_CLIP_REVIEW_STATE_SYNCED = "EV_DEATH_CLIP_REVIEW_STATE_SYNCED"
ns.EV_DEATH_CLIP_OVERRIDE_UPDATED = "EV_DEATH_CLIP_OVERRIDE_UPDATED"


local function CreateSyncedState(name)
    local state = {
        name=name,
        persisted = {
            rev=0,
            lastUpdatedAt=0,
            state={},
        },
        listeners={},
    }

    function state:MarkDirty()
        self.persisted.rev = self.persisted.rev + 1
        self.persisted.lastUpdatedAt = time()
    end

    function state:FireEvent(eventName, ...)
        local callbacks = self.listeners[eventName]
        if callbacks then
            for _, func in ipairs(callbacks) do
                -- pcall prevents one faulty listener from
                -- interrupting subsequent listeners
                local success, err = pcall(func, ...)
                if not success then
                    -- You can optionally log or handle errors here
                    print(ChatPrefixError() .. L[" Error in event handler for "] .. eventName .. ": " .. err)
                end
            end
        end
    end

    function state:RegisterEvent(eventName, callback)
        if not self.listeners[eventName] then
            self.listeners[eventName] = {}
        end
        table.insert(self.listeners[eventName], callback)
    end

    function state:Load(globalVarName)
        local persistedState = _G[globalVarName]
        if persistedState then
            self.persisted = persistedState
            self.persisted.state = self.persisted.state or {}
            self.persisted.rev = self.persisted.rev or 0
            self.persisted.lastUpdatedAt = self.persisted.lastUpdatedAt or 0
        end
        _G[globalVarName] = self.persisted
    end

    function state:GetSyncedState()
        return {
            state=self.persisted.state,
            rev=self.persisted.rev,
            lastUpdatedAt=self.persisted.lastUpdatedAt,
        }
    end
    return state
end

local function CreateDeathClipReviewState()
    local state = CreateSyncedState("DeathClipReviews")
    state:Load("DeathClipReviewsSaved")
    state.persisted.archive = state.persisted.archive or {}
    state.persisted.clipOverrides = state.persisted.clipOverrides or {}

    function state:TrimReviews()
        local LIMIT = 200
        -- Quick check of table size first
        local reviewCount = 0
        for _ in pairs(self.persisted.state) do
            reviewCount = reviewCount + 1
        end

        -- If we don't exceed 200, do nothing
        if reviewCount <= LIMIT then
            return
        end

        -- Only build full trades array if we need to trim
        local allReviews = {}
        for id, data in pairs(self.persisted.state) do
            table.insert(allReviews, { id = id, data = data })
        end

        -- Sort by the lowest completedAt first (trades with earliest completion get trimmed first)
        table.sort(allReviews, function(a, b)
            return (a.data.createdAt or 0) < (b.data.createdAt or 0)
        end)

        local toRemoveCount = reviewCount - LIMIT
        for i = 1, toRemoveCount do
            local review = allReviews[i]

            -- Archive known trades before broadcasting deletes
            self.persisted.archive[review.id] = review.data
            self.persisted.state[review.id] = nil
        end

        ns.DebugLog(string.format("[DEBUG] TrimTrades removed %d trades from the global DB.", toRemoveCount))

    end

    function state:UpdateReview(reviewId, owner, clipID, rating, note)
        local existing = self.persisted.state[reviewId]
        local review = {
            id = reviewId,
            owner = owner,
            clipID = clipID,
            rating = rating,
            note = note,
            createdAt = existing and existing.createdAt or time(),
        }
        self.persisted.state[reviewId] = review
        self:TrimReviews()
        self:MarkDirty()
        self:FireEvent(ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE, {review=review, fromNetwork=false})
    end

    function state:UpdateReviewFromNetwork(review)
        self.persisted.state[review.id] = review
        self:TrimReviews()
        self:MarkDirty()
        self:FireEvent(ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE, {review=review, fromNetwork=true})
    end


    function state:SyncState(persisted)
        for key, value in pairs(persisted) do
            self.persisted[key] = value
        end
        self:FireEvent(ns.EV_DEATH_CLIP_REVIEW_STATE_SYNCED)
    end

    local baseGetSyncedState = state.GetSyncedState
    function state:GetSyncedState()
        local syncedState = baseGetSyncedState(self)
        syncedState.clipOverrides = self.persisted.clipOverrides or {}
        return syncedState
    end

    function state:GetReview(reviewId)
        return self.persisted.state[reviewId]
    end

    function state:GetRatingsByClip()
        local ratings = {}
        for _, review in pairs(self.persisted.state) do
            if not ratings[review.clipID] then
                ratings[review.clipID] = {}
            end
            table.insert(ratings[review.clipID], review.rating)
        end
        return ratings
    end

    function state:GetReviewsForClip(clipID)
        local reviews = {}
        for _, review in pairs(self.persisted.state) do
            if review.clipID == clipID then
                table.insert(reviews, review)
            end
        end
        return reviews
    end

    function state:UpdateClipOverrides(clipID, overrides, fromNetwork)
        self.persisted.clipOverrides[clipID] = overrides
        self:MarkDirty()
        self:FireEvent(ns.EV_DEATH_CLIP_OVERRIDE_UPDATED, {clipID=clipID, overrides=overrides, fromNetwork=fromNetwork})
    end

    function state:GetClipOverrides(clipID)
        return self.persisted.clipOverrides[clipID] or {}
    end

    return state
end

ns.GetClipReviewID = function(clipID, owner)
    return clipID .. "-" .. owner
end

ns.GetDeathClipReviewState = function()
    if ns.DeathClipReviewState then
        return ns.DeathClipReviewState
    end
    ns.DeathClipReviewState = CreateDeathClipReviewState()
    return ns.DeathClipReviewState
end

ns.GetDeathClipRatings = function()
    local reviews = ns.GetDeathClipReviewState().persisted.state
    local clipRatings = {}
    for _, review in pairs(reviews) do
        if not clipRatings[review.clipID] then
            clipRatings[review.clipID] = {}
        end
        table.insert(clipRatings[review.clipID], review.rating)
    end
    return clipRatings
end

ns.GetDeathClipReviewsForClip = function(clipID)
    local reviews = ns.GetDeathClipReviews()
    local result = {}
    for _, review in pairs(reviews) do
        if review.clipID == clipID then
            table.insert(result, review)
        end
    end
    return result
end

ns.GetRatingAverage = function(ratings)
    if #ratings == 0 then
        return 0
    end

    local sum = 0
    for _, rating in ipairs(ratings) do
        sum = sum + rating
    end
    return sum / #ratings
end

function ns.GetTopReactions(clipID, maxIcons)
    local state = ns.GetDeathClipReviewState()
    local reviews = state and state.persisted and state.persisted.state
    if not reviews then return {} end

    local counts = {}
    for _, r in pairs(reviews) do
        if r.clipID == clipID and type(r.rating) == "number" and r.rating >= 1 and r.rating <= 4 then
            counts[r.rating] = (counts[r.rating] or 0) + 1
        end
    end

    local list = {}
    for id, count in pairs(counts) do
        table.insert(list, { id = id, count = count })
    end

    table.sort(list, function(a, b)
        return a.count > b.count
    end)

    local result = {}
    for i = 1, math.min(maxIcons or 2, #list) do
        table.insert(result, list[i])
    end

    return result
end

function ns.GetReactionSummaryString(topReactions)
    local ICONS = {
        [1] = "|TInterface\\AddOns\\GoAgainAH\\Media\\laugh_64x64.tga:16:16:0:0|t",
        [2] = "|TInterface\\AddOns\\GoAgainAH\\Media\\candle_64x64.tga:16:16:0:0|t",
        [3] = "|TInterface\\AddOns\\GoAgainAH\\Media\\wheelchair_64x64.tga:16:16:0:0|t",
        [4] = "|TInterface\\AddOns\\GoAgainAH\\Media\\bicep_64x64.tga:16:16:0:0|t",
    }

    local parts = {}
    for _, entry in ipairs(topReactions or {}) do
        local icon = ICONS[entry.id] or ""
        table.insert(parts, icon .. " " .. entry.count)
    end
    return table.concat(parts, " ")
end
