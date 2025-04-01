local addonName, ns = ...
local L = ns.L

local LfgAPI = {}
ns.LfgAPI = LfgAPI

local DB = ns.AuctionHouseDB
local API = ns.AuctionHouseAPI

function LfgAPI:UpdateDBLFG(payload)
    DB.lfg[payload.lfg.name] = payload.lfg
    DB.lastLfgUpdateAt = time()
    DB.revLfg = (DB.revLfg or 0) + 1
end

function LfgAPI:GetMyEntry()
    if not DB or not DB.lfg then
        return nil
    end

    local me = UnitName("player")
    return DB.lfg[me]
end

function LfgAPI:UpsertEntry(data)
    if not data.name then
        return nil, L["No name provided"]
    end

    local currentRev = -1
    local prevEntry = DB.lfg[data.name]
    if prevEntry then
        currentRev = prevEntry.rev
    end

    data.rev = currentRev + 1

    self:UpdateDBLFG({lfg = data})
    API:FireEvent(ns.T_LFG_ADD_OR_UPDATE, {lfg = data})
    API.broadcastLFGUpdate(ns.T_LFG_ADD_OR_UPDATE, {lfg = data})

    return data
end

function LfgAPI:DeleteEntry(name, isNetworkUpdate, admin)
    if not name then
        return nil, L["No name provided"]
    end

    local me = UnitName("player")
    if name ~= me and not admin then
        return nil, L["You can only delete your own LFG entry"]
    end
    if not DB.lfg[name] then
        return nil, L["LFG entry does not exist"]
    end

    DB.lfg[name] = nil
    DB.lastLfgUpdateAt = time()
    DB.revLfg = (DB.revLfg or 0) + 1

    if not isNetworkUpdate then
        API:FireEvent(ns.T_LFG_DELETED, name)
        API.broadcastLFGUpdate(ns.T_LFG_DELETED, name)
    end

    return true
end
