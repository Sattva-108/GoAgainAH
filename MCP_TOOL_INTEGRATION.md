# GoAgainAH MCP Tool Integration Guide

## MCP Tool Definitions

This document defines the primary tools and resources available in the GoAgainAH addon for MCP integration. Each tool represents a specific capability that can be invoked through the MCP interface.

## 🛠️ Available Tools

### Auction Management Tools

#### `auction.create`
Create a new auction listing.
```lua
-- Parameters:
{
  itemLink: string,      -- WoW item link
  itemQuantity: number,  -- Stack size
  price: number,         -- Price in copper
  priceType: number,     -- PRICE_TYPE_* constant
  deliveryType: number,  -- DELIVERY_TYPE_* constant
  auctionType: number    -- AUCTION_TYPE_* constant
}
-- Returns: { auctionId: string, success: boolean }
```

#### `auction.search`
Search for auctions with filters.
```lua
-- Parameters:
{
  searchText?: string,
  category?: string,
  minLevel?: number,
  maxLevel?: number,
  priceType?: number,
  auctionType?: number
}
-- Returns: { auctions: Auction[], count: number }
```

#### `auction.cancel`
Cancel an active auction.
```lua
-- Parameters: { auctionId: string }
-- Returns: { success: boolean }
```

#### `auction.buy`
Buy an auction.
```lua
-- Parameters: { auctionId: string }
-- Returns: { success: boolean, tradeId?: string }
```

### Trade Management Tools

#### `trade.create`
Initiate a trade transaction.
```lua
-- Parameters: { auctionId: string, buyerName: string }
-- Returns: { tradeId: string, success: boolean }
```

#### `trade.complete`
Complete a pending trade.
```lua
-- Parameters: { tradeId: string }
-- Returns: { success: boolean }
```

#### `trade.list`
List active trades.
```lua
-- Parameters: { filter?: "pending" | "completed" }
-- Returns: { trades: Trade[] }
```

### Review System Tools

#### `review.create`
Create a player review.
```lua
-- Parameters:
{
  targetPlayer: string,
  rating: number,        -- 1-5
  comment: string,
  reviewType: string     -- "buyer" | "seller"
}
-- Returns: { reviewId: string, success: boolean }
```

#### `review.getPlayerRating`
Get a player's rating summary.
```lua
-- Parameters: { playerName: string }
-- Returns: { average: number, total: number, count: number }
```

### LFG Tools

#### `lfg.create`
Create an LFG listing.
```lua
-- Parameters:
{
  dungeonId: number,
  role: string,          -- "tank" | "healer" | "dps"
  note?: string
}
-- Returns: { lfgId: string, success: boolean }
```

#### `lfg.search`
Search LFG listings.
```lua
-- Parameters: { dungeonId?: number, role?: string }
-- Returns: { entries: LfgEntry[] }
```

### Blacklist Tools

#### `blacklist.add`
Add player to blacklist.
```lua
-- Parameters: { playerName: string, reason: string }
-- Returns: { success: boolean }
```

#### `blacklist.check`
Check if player is blacklisted.
```lua
-- Parameters: { playerName: string }
-- Returns: { isBlacklisted: boolean, reason?: string }
```

### Database Tools

#### `db.sync`
Force database synchronization.
```lua
-- Parameters: {}
-- Returns: { success: boolean, revision: number }
```

#### `db.getRevisions`
Get current database revisions.
```lua
-- Parameters: {}
-- Returns: {
  auctions: number,
  trades: number,
  ratings: number,
  lfg: number,
  blacklists: number
}
```

## 📚 Available Resources

### Item Database
```lua
-- Resource: items
-- Provides access to item information
{
  path: "items/{itemId}",
  description: "Get item details by ID",
  returns: {
    name: string,
    link: string,
    level: number,
    quality: number,
    icon: string
  }
}
```

### Player Profiles
```lua
-- Resource: players
-- Provides player information
{
  path: "players/{playerName}",
  description: "Get player profile",
  returns: {
    name: string,
    realm: string,
    rating: number,
    totalTrades: number,
    guildPoints: number
  }
}
```

### Configuration
```lua
-- Resource: config
-- Access configuration settings
{
  path: "config",
  description: "Get/set configuration",
  returns: AHConfig
}
```

## 🔧 MCP Configuration

### Tool Registration Pattern
```lua
-- Example tool registration in MCP format
{
  "name": "auction.create",
  "description": "Create a new auction listing",
  "inputSchema": {
    "type": "object",
    "properties": {
      "itemLink": { "type": "string" },
      "itemQuantity": { "type": "number" },
      "price": { "type": "number" },
      "priceType": { "type": "number" },
      "deliveryType": { "type": "number" },
      "auctionType": { "type": "number" }
    },
    "required": ["itemLink", "itemQuantity", "price"]
  }
}
```

### Tool Discovery
Tools are discovered through:
1. Static analysis of API files
2. Function naming conventions (`API:functionName`)
3. JSDoc-style comments for parameters

## 🚀 Usage Examples

### Creating an Auction via MCP
```
User: "Create an auction for [Thunderfury] at 5000 gold"

MCP Tool Call:
{
  tool: "auction.create",
  arguments: {
    itemLink: "[Thunderfury, Blessed Blade of the Windseeker]",
    itemQuantity: 1,
    price: 50000000,  // 5000 gold in copper
    priceType: 0,     // PRICE_TYPE_MONEY
    deliveryType: 0,  // DELIVERY_TYPE_ANY
    auctionType: 0    // AUCTION_TYPE_SELL
  }
}
```

### Searching Auctions
```
User: "Find all epic weapons under 1000 gold"

MCP Tool Call:
{
  tool: "auction.search",
  arguments: {
    category: "weapons",
    minLevel: 60,
    maxLevel: 80,
    priceType: 0
  }
}
```

## 📋 Tool Categories

### Core Operations
- `auction.*` - Auction house operations
- `trade.*` - Trade management
- `review.*` - Rating system

### Social Features
- `lfg.*` - Looking for group
- `blacklist.*` - Blacklist management

### System Operations
- `db.*` - Database operations
- `config.*` - Configuration management

### Utility Tools
- `utils.formatPrice` - Price formatting
- `utils.parseItemLink` - Item link parsing
- `utils.calculatePoints` - Guild point calculation

## 🔐 Security Considerations

1. **Input Validation**: All tool inputs are validated before execution
2. **Permission Checks**: Some tools require guild officer permissions
3. **Rate Limiting**: Database sync operations are throttled
4. **Sandboxing**: Tools cannot access system files or execute arbitrary code

## 🔄 State Management

Tools maintain state through:
- Database persistence (SavedVariables)
- In-memory caching
- Event-driven updates
- Revision-based synchronization

## 📝 Best Practices

1. **Use specific tools** rather than generic ones when possible
2. **Batch operations** to reduce database writes
3. **Check permissions** before sensitive operations
4. **Handle errors** gracefully with meaningful messages
5. **Validate inputs** to prevent malformed data

## 🎯 Quick Tool Reference

| Tool | Purpose | Common Use |
|------|---------|------------|
| `auction.create` | Create auction | Listing items |
| `auction.search` | Find auctions | Browsing items |
| `trade.create` | Start trade | Buying items |
| `review.create` | Rate player | After trade |
| `lfg.create` | LFG listing | Finding groups |
| `db.sync` | Sync data | Troubleshooting |
