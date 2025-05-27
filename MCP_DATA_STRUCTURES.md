# GoAgainAH Data Structures - MCP Reference

## 📊 Core Data Structures

### Auction Object
```lua
auction = {
    id = "unique_auction_id",
    itemLink = "[Item Link]",
    itemQuantity = 1,
    price = 10000,  -- in copper
    priceType = 0,  -- PRICE_TYPE_MONEY
    deliveryType = 0,  -- DELIVERY_TYPE_ANY
    auctionType = 0,  -- AUCTION_TYPE_SELL
    owner = "PlayerName",
    ownerRealm = "RealmName",
    realm = "RealmName",
    createdAt = timestamp,
    status = "active",  -- AUCTION_STATUS_*
    buyer = "BuyerName",  -- when sold
    buyerRealm = "RealmName",
    completedAt = timestamp,  -- when completed
    enchantId = nil,  -- optional enchant
}
```

### Trade Object
```lua
trade = {
    id = "unique_trade_id",
    auctionId = "auction_id",
    seller = "SellerName",
    sellerRealm = "RealmName",
    buyer = "BuyerName",
    buyerRealm = "RealmName",
    status = "pending",  -- pending/completed/cancelled
    createdAt = timestamp,
    completedAt = timestamp,
}
```

### Review/Rating Object
```lua
review = {
    id = "unique_review_id",
    reviewer = "ReviewerName",
    reviewerRealm = "RealmName",
    target = "TargetName",
    targetRealm = "RealmName",
    rating = 5,  -- 1-5 stars
    comment = "Great seller!",
    reviewType = "seller",  -- buyer/seller
    createdAt = timestamp,
}
```

### LFG Entry
```lua
lfgEntry = {
    id = "unique_lfg_id",
    player = "PlayerName",
    realm = "RealmName",
    dungeonId = 1,
    role = "tank",  -- tank/healer/dps
    note = "Optional note",
    createdAt = timestamp,
    expiresAt = timestamp,
}
```

### Pending Transaction
```lua
pendingTx = {
    id = "unique_tx_id",
    type = "mail_cod",  -- mail_cod/mail_loan/trade
    auctionId = "auction_id",
    from = "SenderName",
    to = "ReceiverName",
    amount = 10000,
    status = "pending",
    createdAt = timestamp,
}
```

### Blacklist Entry
```lua
blacklist = {
    player = "PlayerName",
    realm = "RealmName",
    reason = "Reason for blacklist",
    addedBy = "ModeratorName",
    addedAt = timestamp,
}
```

## 🗄️ Database Structure

### Main Database Tables
```lua
AuctionHouseDB = {
    -- Core auction data
    auctions = { [auctionId] = auction },

    -- Trade tracking
    trades = { [tradeId] = trade },
    tradesArchive = { [tradeId] = trade },  -- completed trades

    -- Player ratings
    ratings = { [playerId] = { total = 100, count = 20, average = 5.0 } },
    reviews = { [reviewId] = review },

    -- LFG system
    lfg = { [lfgId] = lfgEntry },

    -- Blacklist
    blacklists = { [playerId] = blacklist },

    -- Pending transactions
    pendingTransactions = { [txId] = pendingTx },

    -- Revision tracking for sync
    revision = 0,
    revTrades = 0,
    revRatings = 0,
    revLfg = 0,
    revBlacklists = 0,
    revPendingTransactions = 0,

    -- Last update timestamps
    lastUpdateAt = timestamp,
    lastRatingUpdateAt = timestamp,
    lastLfgUpdateAt = timestamp,
    lastBlacklistUpdateAt = timestamp,
    lastPendingTransactionUpdateAt = timestamp,
}
```

## 🔄 State Management

### Revision System
Each data type has its own revision number that increments on changes:
- Auctions: `DB.revision`
- Trades: `DB.revTrades`
- Ratings: `DB.revRatings`
- LFG: `DB.revLfg`
- Blacklists: `DB.revBlacklists`
- Pending Transactions: `DB.revPendingTransactions`

### State Synchronization Flow
```
1. Player logs in → Request state from guild
2. Guild members → Send their revision numbers
3. Compare revisions → Request updates for outdated data
4. Receive updates → Merge into local database
5. Broadcast own updates → Keep guild in sync
```

### Message Format
```lua
message = {
    type = "auction_update",  -- update type
    revision = 123,  -- current revision
    data = { ... },  -- actual data
    timestamp = time(),
}
```

## 🎨 UI State

### Browse Parameters
```lua
browseParams = {
    searchText = "",
    category = "all",  -- all/weapons/armor/etc
    minLevel = 1,
    maxLevel = 80,
    usableOnly = false,
    priceType = nil,  -- filter by price type
    auctionType = nil,  -- buy/sell
    sortBy = "time",  -- time/price/name
    sortOrder = "desc",  -- asc/desc
}
```

### Configuration
```lua
AHConfig = {
    -- UI Settings
    showMinimapIcon = true,
    minimapIconPosition = 45,

    -- Notifications
    enableAlerts = true,
    alertSound = true,

    -- Auction Settings
    defaultPriceType = 0,  -- PRICE_TYPE_MONEY
    defaultDeliveryType = 0,  -- DELIVERY_TYPE_ANY

    -- Display Settings
    itemsPerPage = 20,
    showTooltipPrices = true,

    -- Death Clips
    deathClipsEnabled = true,
    deathClipVolume = 0.5,
}
```

## 🔌 Event System

### Custom Events
```lua
-- Auction events
"AUCTION_CREATED"
"AUCTION_UPDATED"
"AUCTION_CANCELLED"
"AUCTION_BOUGHT"

-- Trade events
"TRADE_INITIATED"
"TRADE_COMPLETED"
"TRADE_CANCELLED"

-- System events
"DATABASE_SYNCED"
"REVISION_UPDATED"
"BLACKLIST_UPDATED"
```

### Event Data
```lua
eventData = {
    event = "AUCTION_CREATED",
    data = {
        auctionId = "id",
        itemLink = "[Item]",
        owner = "Player",
    },
    timestamp = time(),
}
```

## 💾 Saved Variables

### Global (Account-wide)
- `AuctionHouseDBSaved` - Main database
- `AHConfigSaved` - Configuration
- `LiveDeathClips` - Death clip settings
- `PlayerPrefsSaved` - Player preferences
- `DeathClipReviewsSaved` - Death clip reviews

### Per-Character
- `CharacterPrefsSaved` - Character-specific settings

## 🔑 Common Lookup Patterns

### Find auctions by item
```lua
local auctions = {}
for id, auction in pairs(DB.auctions) do
    if auction.itemLink == itemLink and auction.status == "active" then
        table.insert(auctions, auction)
    end
end
```

### Get player rating
```lua
local rating = DB.ratings[playerName] or { total = 0, count = 0, average = 0 }
```

### Check blacklist
```lua
local isBlacklisted = DB.blacklists[playerName] ~= nil
```

### Find pending transactions
```lua
local pending = {}
for id, tx in pairs(DB.pendingTransactions) do
    if tx.to == playerName and tx.status == "pending" then
        table.insert(pending, tx)
    end
end
```
