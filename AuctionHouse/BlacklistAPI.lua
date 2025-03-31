local addonName, ns = ...

-----------------------------------------------------------------------------
-- Add numeric enums for blacklist types
-----------------------------------------------------------------------------
local BL_TYPE_REVIEW = 1
local BL_TYPE_ORDERS = 2

ns.BLACKLIST_TYPE_REVIEW = BL_TYPE_REVIEW
ns.BLACKLIST_TYPE_ORDERS = BL_TYPE_ORDERS

local BlacklistAPI = {}
ns.BlacklistAPI = BlacklistAPI

local DB = ns.AuctionHouseDB
local API = ns.AuctionHouseAPI

-----------------------------------------------------------------------------
-- UpdateDBBlacklist
-- Now stores names in a namesByType sub-table keyed by payload.blType.
-- "names" becomes payload.names, and is inserted under namesByType[@blType].
-----------------------------------------------------------------------------
function BlacklistAPI:UpdateDBBlacklist(payload)
    -- If we have an existing entry, re-use it; otherwise create a fresh one.
    local existingEntry = DB.blacklists[payload.playerName]
    if not existingEntry then
        existingEntry = {
            rev = 0,
            namesByType = {},
            c = time(), -- createdAt. present only since v1.0.8
        }
    end
    existingEntry.rev = payload.rev

    -- Ensure sub-table is present before assigning.
    existingEntry.namesByType = existingEntry.namesByType or {}
    existingEntry.namesByType[payload.blType] = payload.names

    DB.blacklists[payload.playerName] = existingEntry
    DB.lastBlacklistUpdateAt = time()
    DB.revBlacklists = (DB.revBlacklists or 0) + 1
end

-----------------------------------------------------------------------------
-- AddToBlacklist
-- Adds a single name to the specified blacklist type if not already present.
-----------------------------------------------------------------------------
function BlacklistAPI:AddToBlacklist(playerName, blType, blacklistedName)
    if not playerName then
        return nil, "Missing player name"
    end
    if not blType then
        return nil, "Missing blacklist type"
    end
    if not blacklistedName then
        return nil, "No name to blacklist"
    end

    local currentEntry = DB.blacklists[playerName]
    local currentNames = currentEntry and currentEntry.namesByType and currentEntry.namesByType[blType] or {}

    -- Check if name already exists in the blacklist
    for _, name in ipairs(currentNames) do
        if name == blacklistedName then
            return nil, "Name already in blacklist"
        end
    end

    -- Create new array with existing names plus new name
    local newNames = {}
    for _, name in ipairs(currentNames) do
        table.insert(newNames, name)
    end
    table.insert(newNames, blacklistedName)

    local newRev = (currentEntry and currentEntry.rev or 0) + 1
    local payload = {
        playerName = playerName,
        rev = newRev,
        blType = blType,
        names = newNames,
    }

    self:UpdateDBBlacklist(payload)
    API:FireEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, payload)
    API.broadcastBlacklistUpdate(ns.T_BLACKLIST_ADD_OR_UPDATE, payload)
    return payload
end

-----------------------------------------------------------------------------
-- RemoveFromBlacklist
-- Now requires a blType (e.g. BL_TYPE_REVIEW or BL_TYPE_ORDERS).
-- Removes the given unblacklistName from namesByType[blType].
-----------------------------------------------------------------------------
function BlacklistAPI:RemoveFromBlacklist(ownerName, blType, unblacklistName)
    if not ownerName then
        return nil, "Missing owner name"
    end
    if not blType then
        return nil, "Missing blacklist type"
    end
    if not unblacklistName then
        return nil, "Missing name to unblacklist"
    end

    local blacklist = DB.blacklists[ownerName]
    if not blacklist then
        return nil, "Owner has no blacklist"
    end

    local namesForType = blacklist.namesByType and blacklist.namesByType[blType]
    if not namesForType then
        return nil, "No names found for this blacklist type"
    end

    local found = false
    local newNames = {}

    for _, name in ipairs(namesForType) do
        if name ~= unblacklistName then
            table.insert(newNames, name)
        else
            found = true
        end
    end

    if not found then
        return nil, "Name not found in blacklist for type " .. tostring(blType)
    end

    -- Build updated payload for this player and type
    local newRev = blacklist.rev + 1
    local payload = {
        playerName = ownerName,
        rev = newRev,
        blType = blType,
        names = newNames
    }

    self:UpdateDBBlacklist(payload)
    API:FireEvent(ns.T_BLACKLIST_ADD_OR_UPDATE, payload)
    API.broadcastBlacklistUpdate(ns.T_BLACKLIST_ADD_OR_UPDATE, payload)
    return true
end

-----------------------------------------------------------------------------
-- GetBlacklist
-- Returns the entire blacklist entry for a given playerName,
-- which contains rev and namesByType sub-tables.
-----------------------------------------------------------------------------
function BlacklistAPI:GetBlacklist(playerName)
    return DB.blacklists[playerName]
end

-----------------------------------------------------------------------------
-- GetBlacklisters
-- Returns an array of player names who have blacklisted the given playerName
-- for the specified blacklist type.
-----------------------------------------------------------------------------
function BlacklistAPI:GetBlacklisters(playerName, blType)
    if not playerName or not blType then
        return {}
    end

    local blacklisters = {}

    -- Scan through all blacklists
    for ownerName, blacklist in pairs(DB.blacklists) do
        if blacklist.namesByType and blacklist.namesByType[blType] then
            -- Check if playerName exists in this owner's blacklist
            for _, name in ipairs(blacklist.namesByType[blType]) do
                if name == playerName then
                    table.insert(blacklisters, ownerName)
                    break  -- No need to check remaining names for this owner
                end
            end
        end
    end

    return blacklisters
end

-----------------------------------------------------------------------------
-- IsBlacklisted
-- Checks if a specific name is blacklisted by a player for the given type
-- Returns: boolean
-----------------------------------------------------------------------------
function BlacklistAPI:IsBlacklisted(playerName, blType, blacklistedName)
    if not playerName or not blType or not blacklistedName then
        return false
    end

    local blacklist = DB.blacklists[playerName]
    if not blacklist or not blacklist.namesByType or not blacklist.namesByType[blType] then
        return false
    end

    for _, name in ipairs(blacklist.namesByType[blType]) do
        if name == blacklistedName then
            return true
        end
    end

    return false
end

-----------------------------------------------------------------------------
-- GetAllBlacklisters
-- Returns an array of player names who have blacklisted the given playerName
-- across any blacklist type.
-----------------------------------------------------------------------------
function BlacklistAPI:GetAllBlacklisters(playerName)
    if not playerName then
        return {}
    end

    local blacklisters = {}
    local seen = {} -- To prevent duplicate entries if someone blacklisted across multiple types

    -- Scan through all blacklists
    for ownerName, blacklist in pairs(DB.blacklists) do
        if blacklist.namesByType then
            -- Check all blacklist types
            for _, names in pairs(blacklist.namesByType) do
                -- Check if playerName exists in this type's blacklist
                for _, name in ipairs(names) do
                    if name == playerName and not seen[ownerName] then
                        table.insert(blacklisters, ownerName)
                        seen[ownerName] = true
                        break -- No need to check remaining names for this owner/type
                    end
                end
            end
        end
    end

    return blacklisters
end
