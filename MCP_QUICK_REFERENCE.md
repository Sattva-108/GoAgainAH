# GoAgainAH Quick Reference - MCP

## 🔍 Fast Function Finder

### Auction Operations
```lua
-- Create auction
AuctionHouseAPI:CreateAuction(itemLink, itemQuantity, price, priceType, deliveryType, auctionType)

-- Search auctions
AuctionHouseAPI:GetAuctions(filters)
AuctionHouseAPI:GetAuctionsByItemLink(itemLink)
AuctionHouseAPI:GetActiveAuctions()

-- Modify auction
AuctionHouseAPI:UpdateAuction(auctionId, updates)
AuctionHouseAPI:CancelAuction(auctionId)
AuctionHouseAPI:BuyAuction(auctionId)
```

### Trade & Transaction
```lua
-- Trade management
TradeAPI:CreateTrade(auctionId, buyerName)
TradeAPI:CompleteTrade(tradeId)
TradeAPI:GetActiveTrades()

-- Pending transactions
PendingTxAPI:CreatePendingTransaction(type, data)
PendingTxAPI:GetPendingTransactions()
PendingTxAPI:CompletePendingTransaction(txId)
```

### Player & Guild
```lua
-- Ratings
AuctionHouseAPI:CreateReview(targetPlayer, rating, comment, reviewType)
AuctionHouseAPI:GetPlayerRating(playerName)

-- Blacklist
BlacklistAPI:AddToBlacklist(playerName, reason)
BlacklistAPI:RemoveFromBlacklist(playerName)
BlacklistAPI:IsBlacklisted(playerName)

-- Guild points
GuildPointUtils:GetPlayerPoints(playerName)
GuildPointUtils:CalculatePoints(itemValue)
```

### UI & Display
```lua
-- Item tooltips
AuctionHouseUtils:GetItemInfo(itemLink)
AuctionHouseUtils:FormatPrice(price, priceType)

-- Alerts
AuctionAlertWidget:ShowAlert(message, type)

-- Frame management
AuctionUI:Show()
AuctionUI:Hide()
AuctionUI:Refresh()
```

## 📂 Key File Locations

| Feature | Primary File | Supporting Files |
|---------|-------------|------------------|
| Auction Core | `AuctionHouse/AuctionHouseAPI.lua` | `AuctionHouseDB.lua`, `AuctionHouseUtils.lua` |
| UI Main | `UI/AuctionHouse/AuctionUI.lua` | `AuctionData.lua`, `BrowseParams.lua` |
| Trading | `AuctionHouse/TradeAPI.lua` | `PendingTxAPI.lua` |
| Reviews | `UI/AuctionHouse/ReviewUI.lua` | `ReviewPopup.lua` |
| LFG | `AuctionHouse/LfgAPI.lua` | `UI/AuctionHouse/LfgUI.lua` |
| Death Clips | `DeathClips/LiveDeathClips.lua` | `DeathClipReviews.lua` |
| Config | `Config.lua` | `PlayerPrefs.lua` |

## 🎯 Common Search Patterns

### Find all functions in a module:
```
Grep: "function.*:" <module_name>.lua
```

### Find event handlers:
```
Grep: "RegisterEvent\|CHAT_MSG\|PLAYER_"
```

### Find slash commands:
```
Grep: "SlashCmdList\|SLASH_"
```

### Find saved variables usage:
```
Grep: "AuctionHouseDBSaved\|AHConfigSaved"
```

### Find API calls:
```
Grep: "AuctionHouseAPI:\|TradeAPI:\|LfgAPI:"
```

## 🔧 Common Tasks

### Add new auction type:
1. Define constant in `AuctionHouseAPI.lua` (ns.AUCTION_TYPE_*)
2. Update `CreateAuction` in `AuctionHouseAPI.lua`
3. Add UI handling in `AuctionUI.lua`

### Add new price type:
1. Define constant in `AuctionHouseAPI.lua` (ns.PRICE_TYPE_*)
2. Update `FormatPrice` in `AuctionHouseUtils.lua`
3. Update `PriceWidget.lua` for UI

### Add new UI tab:
1. Create tab content in `UI/AuctionHouse/`
2. Register in `AuctionUI.lua` tab system
3. Add localization in `Locale/`

### Debug state sync:
1. Check `GameEventHandler.lua` for sync events
2. Review revision numbers in `AuctionHouseDB.lua`
3. Monitor comm messages in chat with debug enabled

## 🚀 Performance Tips

- Item data is cached in `ItemDB/`
- Use `GetAuctionsByItemLink` for single item queries
- Batch database updates to minimize broadcasts
- UI updates throttled via `AuctionUI:ScheduleRefresh()`

## 🐛 Common Issues

| Issue | Check These Files |
|-------|-------------------|
| Auction not showing | `AuctionHouseAPI:GetAuctions`, `BrowseParams.lua` |
| Sync problems | `GameEventHandler.lua`, revision numbers |
| UI not updating | `AuctionUI:Refresh()`, event handlers |
| Mail issues | `UI/Mailbox/Mailbox.lua`, `PendingTxAPI.lua` |
