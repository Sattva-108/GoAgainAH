local _, ns = ...
local L = ns.L

local seenTransactions = {}

ns.TransferGuildPoints = function(fromPlayer, toPlayer, points, txId, localOnly)
    local fromPlayerPoints = ns.GetGuildPoints(fromPlayer)
    local toPlayerPoints = ns.GetGuildPoints(toPlayer)
    if fromPlayerPoints == nil then
        return string.format(L["Could not find points for %s"], fromPlayer)
    end
    if toPlayerPoints == nil then
        return string.format(L["Could not find points for %s"], toPlayer)
    end

    local errFromPlayer = ns.OffsetGuildPoints(fromPlayer, -points, txId, localOnly)
    if errFromPlayer ~= nil then
        return string.format(L["Could not update points for %s: %s"], fromPlayer, errFromPlayer)
    end

    local errToPlayer = ns.OffsetGuildPoints(toPlayer, points, txId, localOnly)
    if errToPlayer ~= nil then
        return string.format(L["Could not update points for %s: %s"], toPlayer, errToPlayer)
    end

    ns.DebugLog("TransferGuildPoints", fromPlayer, toPlayer, points, txId, localOnly)
    return nil
end

ns.GetGuildPoints = function(playerName)
    if SixtyProjectLoader ~= nil then
        ---@type SixtyProjectFunctions
        local SixtyProjectFunctions = SixtyProjectLoader:ImportModule("SixtyProjectFunctions")
        if playerName == UnitName("player") then
            return SixtyProjectFunctions.GetPlayerPoints()
        end
        local guildData = SixtyProjectFunctions.GetGuildData()
        if guildData and guildData[playerName] then
            return guildData[playerName].Points
        end
    end
    return nil
end

---@param SixtyProjectCommunication SixtyProjectCommunication
---@param SixtyProjectFunctions SixtyProjectFunctions
---@param points number
local function OffsetMyGuildPointsCore(SixtyProjectCommunication, SixtyProjectFunctions, offset, txId)
    if seenTransactions[txId] then
        return
    end
    seenTransactions[txId] = true

    SixtyProjectFunctions.AddPoints(offset)
    SixtyProjectCommunication.PlayerInformationMessage()
end

ns.OffsetMyGuildPoints = function(offset, txId)
    if SixtyProjectLoader == nil then
        return L["SixtyProject addon is not loaded"]
    end
    ---@type SixtyProjectCommunication
    local SixtyProjectCommunication = SixtyProjectLoader:ImportModule("SixtyProjectCommunication")
    ---@type SixtyProjectFunctions
    local SixtyProjectFunctions = SixtyProjectLoader:ImportModule("SixtyProjectFunctions")
    OffsetMyGuildPointsCore(SixtyProjectCommunication, SixtyProjectFunctions, offset, txId)
    return nil
end

ns.OffsetGuildPoints = function(playerName, offset, txId, localOnly)
    if SixtyProjectLoader == nil then
        return L["SixtyProject addon is not loaded"]
    end
    ---@type SixtyProjectCommunication
    local SixtyProjectCommunication = SixtyProjectLoader:ImportModule("SixtyProjectCommunication")
    ---@type SixtyProjectFunctions
    local SixtyProjectFunctions = SixtyProjectLoader:ImportModule("SixtyProjectFunctions")

    if playerName == UnitName("player") then
        OffsetMyGuildPointsCore(SixtyProjectCommunication, SixtyProjectFunctions, offset, txId)
    elseif not localOnly then
        ns.AuctionHouse:RequestOffsetGuildPoints(playerName, offset, txId)
    end

    return nil
end

