# GoAgainAH Addon Map - MCP Navigation Guide

## Overview
GoAgainAH is a World of Warcraft addon for the Sirus server that provides a custom auction house system for the "Go Again" guild. The addon uses the Ace3 framework and provides features including:

- Custom auction house interface
- Death clips system (audio/video reviews)
- LFG (Looking for Group) integration
- Review/ratings system
- Blacklist management
- COD mail and loan system
- Guild points integration

## Directory Structure

### 📁 Root Directory
- `GoAgainAH.toc` - Main addon table of contents (loads all files in order)
- `dependencies.xml` - Loads all Ace3 libraries
- `Config.lua` - Configuration system and options
- `ChangeLog.lua` - Addon version history
- `codemcp.toml` - CodeMCP configuration

### 📁 Core Systems

#### 🔹 AuctionHouse/
Main auction house functionality:
- `AuctionHouseAPI.lua` - Core API for auction operations
  - Key functions: CreateAuction, GetAuctions, UpdateAuction, CancelAuction
  - Constants: AUCTION_STATUS_*, PRICE_TYPE_*, DELIVERY_TYPE_*
- `AuctionHouseDB.lua` - Database management
  - Handles auction storage, synchronization
  - Manages revisions for state sync
- `AuctionHouseUtils.lua` - Utility functions
  - Item link parsing, price formatting, time calculations
- `AuctionAlertWidget.lua` - Alert notifications for auction events
- `TradeAPI.lua` - Trade transaction management
- `BlacklistAPI.lua` - Player blacklist functionality
- `PendingTxAPI.lua` - Pending transaction tracking
- `LfgAPI.lua` - Looking for group integration
- `ItemTooltipHook.lua` - Tooltip enhancements for items

#### 🔹 ItemDB/
Item database and caching:
- `ItemDB.lua` - Main item database interface
- `ItemsVanilla.lua` - Vanilla WoW item data
- `ItemsBoP.lua` - Bind on Pickup items
- `Enchants.lua` - Enchantment data
- `SpecialItems.lua` - Special/unique items

#### 🔹 DeathClips/
Death clip review system:
- `DeathClipReviews.lua` - Review management
- `DeathClipUtils.lua` - Utility functions
- `LiveDeathClips.lua` - Live clip handling
- Parent: `DeathClipsAgain.lua` - Main death clips addon

#### 🔹 LFG/
Looking for group features:
- `LFGUtils.lua` - LFG utility functions
- `Dungeons.lua` - Dungeon definitions

#### 🔹 Chat/
Chat system integration:
- `ChatUtils.lua` - Chat utilities and commands

### 📁 UI Systems

#### 🔹 UI/
Base UI components:
- `CustomFrame.lua` - Custom frame base class
- `CustomTabGroup.lua` - Tab management
- `CustomIcon.lua` - Icon handling
- `MinimalFrame.lua` - Minimal frame template
- `MultiLineEditBoxCustom.lua` - Multi-line text input
- `MinimapIcon.lua` - Minimap button
- `ColabTable.lua` - Collaborative table widget

#### 🔹 UI/Widgets/
Reusable UI widgets:
- `PriceWidget.lua` - Price input/display
- `ItemWidget.lua` - Item display
- `StarRatingWidget.lua` - Star rating system
- `ScrollList.lua` - Scrollable list base
- `RoleWidget.lua` - Role selection (tank/healer/dps)

#### 🔹 UI/AuctionHouse/
Auction house specific UI:
- `AuctionUI.lua` - Main auction interface
- `AuctionData.lua` - UI data management
- `BrowseParams.lua` - Browse/search parameters
- `ReviewUI.lua` - Review interface
- `ReviewPopup.lua` - Review popup dialog
- `AuctionBuyConfirmPrompt.lua` - Buy confirmation
- `AuctionWishlistConfirmPrompt.lua` - Wishlist confirmation
- `AuctionSelectEnchantPrompt.lua` - Enchant selection
- `SettingsUI.lua` - Settings interface
- `LfgUI.lua` - LFG interface
- `DeathClipsUI.lua` - Death clips interface
- `DeathClipsTabs.lua` - Death clips tab management
- `AtheneUI.lua` - Athene special tab

#### 🔹 UI/LFG/
LFG specific UI:
- `DungeonScrollList.lua` - Dungeon list widget

#### 🔹 UI/Mailbox/
Mailbox integration:
- `Mailbox.lua` - COD mail handling

### 📁 Supporting Systems

#### 🔹 StreamerDB/
- `StreamerDB.lua` - Streamer database

#### 🔹 Locale/
Localization files:
- `registerLocale.lua` - Locale registration
- `enUS.lua`, `esES.lua`, `esMX.lua` - Language files
- `ItemNames.lua` - Localized item names

#### 🔹 Media/
Graphics and audio assets:
- `icons/` - UI icons
- `DeathAudioClips/` - Death sound clips
- Various `.blp` and `.tga` texture files

#### 🔹 Libs/
Third-party libraries (Ace3 framework)

### 📁 Other Important Files

- `AuctionHouse.lua` - Main addon initialization
- `GameEventHandler.lua` - Game event handling
- `Utils.lua` - General utility functions
- `MagicLinks.lua` - Special link handling
- `PlayerPrefs.lua` - Player preferences
- `VersionCheck.lua` - Version compatibility
- `GuildRegister.lua` - Guild registration
- `GuildPointUtils.lua` - Guild point calculations
- `OFCommandHandler.lua` - Slash command handler

## Key Functions and APIs

### Creating Auctions
```lua
AuctionHouseAPI:CreateAuction(itemLink, itemQuantity, price, priceType, deliveryType, auctionType)
```

### Searching Auctions
```lua
AuctionHouseAPI:GetAuctions(filters)
AuctionHouseAPI:GetAuctionsByItemLink(itemLink)
```

### Managing Transactions
```lua
TradeAPI:CreateTrade(auctionId, buyerName)
TradeAPI:CompleteTrade(tradeId)
PendingTxAPI:CreatePendingTransaction(type, data)
```

### LFG Operations
```lua
LfgAPI:CreateLfgEntry(dungeonId, role, note)
LfgAPI:GetLfgEntries(dungeonId)
```

### Review System
```lua
AuctionHouseAPI:CreateReview(targetPlayer, rating, comment, reviewType)
AuctionHouseAPI:GetPlayerRating(playerName)
```

## State Management

The addon uses a revision-based synchronization system:
- `DB.revision` - Main auction database revision
- `DB.revTrades` - Trade database revision
- `DB.revRatings` - Rating database revision
- `DB.revLfg` - LFG database revision
- `DB.revBlacklists` - Blacklist database revision
- `DB.revPendingTransactions` - Pending transaction revision

## Communication Protocol

Uses AceComm for guild-wide state synchronization:
- Channel: "AuctionHouse" (guild addon channel)
- Messages: Compressed and serialized using LibDeflate
- State sync on login/reload

## Saved Variables

- `AuctionHouseDBSaved` - Main database
- `AHConfigSaved` - Configuration settings
- `LiveDeathClips` - Death clip data
- `PlayerPrefsSaved` - Player preferences
- `DeathClipReviewsSaved` - Death clip reviews
- `CharacterPrefsSaved` - Per-character settings

## Quick Navigation Tips for MCP

1. **Core auction logic**: Start with `AuctionHouse/AuctionHouseAPI.lua`
2. **UI implementation**: Check `UI/AuctionHouse/AuctionUI.lua`
3. **Database operations**: See `AuctionHouse/AuctionHouseDB.lua`
4. **Event handling**: Look at `GameEventHandler.lua`
5. **Configuration**: Review `Config.lua`
6. **Utilities**: Check `Utils.lua` and `AuctionHouse/AuctionHouseUtils.lua`

## Common Patterns

- All major systems follow Ace3 addon structure
- UI uses custom frame inheritance from `CustomFrame.lua`
- Database operations go through API layer
- State synchronization uses revision numbers
- Localization uses `ns.L` table
