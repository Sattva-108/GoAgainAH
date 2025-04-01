local addonName, ns = ...
local L = ns.L

local PendingTxAPI = {}
ns.PendingTxAPI = PendingTxAPI

local DB = ns.AuctionHouseDB
local API = ns.AuctionHouseAPI

function PendingTxAPI:UpdateDBPendingTransaction(payload)
    -- Check if we already have a newer version of this transaction
    local existingTx = DB.pendingTransactions[payload.id]
    if existingTx and existingTx.rev and payload.transaction.rev and existingTx.rev > payload.transaction.rev then
        return false -- Ignore older revisions
    end

    DB.pendingTransactions[payload.id] = payload.transaction
    DB.lastPendingTransactionUpdateAt = time()
    DB.revPendingTransactions = (DB.revPendingTransactions or 0) + 1
    return true
end

function PendingTxAPI:AddPendingTransaction(transaction)
    if not transaction.id then
        return nil, L["Missing transaction ID"]
    end

    -- Initialize or increment revision
    if not transaction.rev then
        transaction.rev = 1
    else
        transaction.rev = transaction.rev + 1
    end

    local entry = {
        id = transaction.id,
        transaction = transaction,
    }

    if not self:UpdateDBPendingTransaction(entry) then
        return nil, L["Newer version exists"]
    end

    API:FireEvent(ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE, entry)
    API.broadcastPendingTransactionUpdate(ns.T_PENDING_TRANSACTION_ADD_OR_UPDATE, entry)
    return entry
end

function PendingTxAPI:RemovePendingTransaction(transactionId, fromNetwork)
    if not transactionId then
        return nil, L["Missing transaction ID"]
    end

    if not DB.pendingTransactions[transactionId] then
        return nil, L["Transaction not found"]
    end

    DB.pendingTransactions[transactionId] = nil
    DB.lastPendingTransactionUpdateAt = time()
    DB.revPendingTransactions = DB.revPendingTransactions + 1

    API:FireEvent(ns.T_PENDING_TRANSACTION_DELETED, transactionId)

    if not fromNetwork then
        API.broadcastPendingTransactionUpdate(ns.T_PENDING_TRANSACTION_DELETED, transactionId)
    end

    return true
end

function PendingTxAPI:GetPendingTransaction(transactionId)
    return DB.pendingTransactions[transactionId]
end

function PendingTxAPI:GetAllPendingTransactions()
    local result = {}
    for id, transaction in pairs(DB.pendingTransactions) do
        result[id] = transaction
    end
    return result
end

-- Add new shared function for handling transactions
function PendingTxAPI:HandlePendingTransactionChange(tx)
    local me = UnitName("player")
    ns.DebugLog("HandlePendingTransactionChange")

    -- Return early if transaction doesn't involve current player
    if tx.from ~= me and tx.to ~= me then
        ns.DebugLog("HandlePendingTransactionChange not relevant", tx.from, tx.to, me, tx.from == me, tx.to == me)
        return
    end

    if tx.type == ns.PRICE_TYPE_GUILD_POINTS then
        -- Transfer points locally only since this is a network sync
        local err = ns.TransferGuildPoints(tx.from, tx.to, tx.amount, tx.id, true)
        if err then
            print(ChatPrefixError() .. L[" Failed to transfer points:"], err)
            return
        end
        ns.DebugLog("HandlePendingTransactionChange TransferGuildPoints SUCCESS", tx.from, tx.to, tx.amount)
    else
        print(ChatPrefixError() .. " PendingTransaction unknown type, please update to the latest version of the addon.", tx.type, tx.to, tx.from)
        return
    end

    -- Mark the transaction as handled for the current user's side
    local updates = {}
    if tx.from == me then
        updates.fromHandled = true
    end
    if tx.to == me then
        updates.toHandled = true
    end

    -- Update or delete the transaction based on state
    if updates.fromHandled and tx.toHandled then
        ns.PendingTxAPI:RemovePendingTransaction(tx.id)
    elseif tx.fromHandled and updates.toHandled then
        ns.PendingTxAPI:RemovePendingTransaction(tx.id)
    else
        -- Update the transaction with the new handled state and increment revision
        local updatedTx = CopyTable(tx)
        for k,v in pairs(updates) do
            updatedTx[k] = v
        end
        ns.PendingTxAPI:AddPendingTransaction(updatedTx)
    end
end
