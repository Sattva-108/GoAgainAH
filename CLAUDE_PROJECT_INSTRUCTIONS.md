# Claude Project Custom Instructions for GoAgainAH

## Project Overview
You are helping develop GoAgainAH, a World of Warcraft addon for the Sirus server (WoW 3.3.5a). This is a comprehensive auction house system for the "Go Again" guild.

## MCP Integration
When asked to work on this project, ALWAYS start by:
1. Initialize codemcp with path: `E:\World of Warcraft Sirus\Interface\AddOns\GoAgainAH`
2. Use the MCP documentation files for navigation

## Key Documentation Files
The project has comprehensive MCP documentation:
- `MCP_DOCUMENTATION_INDEX.md` - Master index of all docs
- `MCP_NAVIGATION_MAP.md` - Complete file structure and descriptions
- `MCP_QUICK_REFERENCE.md` - Fast function finder and patterns
- `MCP_DATA_STRUCTURES.md` - All data structures and schemas
- `MCP_TOOL_INTEGRATION.md` - MCP tool definitions
- `PROJECT_INSTRUCTIONS.md` - Development guidelines

## Core Features
1. **Auction System**: Custom auction house with multiple price types
2. **Trade Management**: COD mail and loan system
3. **Review System**: Player ratings for buyers/sellers
4. **LFG Integration**: Looking for group functionality
5. **Death Clips**: Audio review system
6. **Blacklist**: Player blacklist management
7. **Guild Points**: Custom currency system

## Technical Stack
- **Framework**: Ace3 (AceAddon, AceComm, AceSerializer, etc.)
- **WoW Version**: 3.3.5a (Interface: 30300)
- **State Sync**: Revision-based synchronization via guild addon channel
- **Storage**: SavedVariables (global and per-character)
- **Compression**: LibDeflate for network messages

## File Organization
- `AuctionHouse/` - Core auction logic and APIs
- `UI/AuctionHouse/` - User interface components
- `ItemDB/` - Item database and caching
- `DeathClips/` - Death clip system
- `LFG/` - Looking for group features
- `Locale/` - Localization (enUS, esES, esMX)
- `Libs/` - Ace3 and other libraries

## Key APIs and Patterns

### Creating Auctions
```lua
AuctionHouseAPI:CreateAuction(itemLink, quantity, price, priceType, deliveryType, auctionType)
```

### State Management
- Each data type has revision numbers (DB.revision, DB.revTrades, etc.)
- Changes increment revision and broadcast to guild
- On login, request state sync from guild members

### Common Constants
- `ns.AUCTION_STATUS_*` - Auction states
- `ns.PRICE_TYPE_*` - Money, Twitch raid, Custom, Guild points
- `ns.DELIVERY_TYPE_*` - Any, Mail, Trade
- `ns.REVIEW_TYPE_*` - Buyer, Seller

## Development Guidelines

### Code Style
- Use existing Ace3 patterns
- 4 spaces indentation
- Descriptive variable names
- Comment complex logic

### When Making Changes
1. Check existing patterns in similar files
2. Update relevant API files first
3. Add UI components if needed
4. Update localization strings
5. Test state synchronization
6. Update revision numbers for sync

### Testing
- Use `/goagain debug` for debug mode
- Test with multiple guild members for sync
- Check SavedVariables after `/reload`
- Verify mail functionality

### Common Tasks Reference
- **Add auction type**: Define in `AuctionHouseAPI.lua`, update UI
- **Add price type**: Update constants, `FormatPrice`, `PriceWidget.lua`
- **New UI tab**: Create in `UI/AuctionHouse/`, register in `AuctionUI.lua`
- **Database changes**: Update `AuctionHouseDB.lua`, increment revision

## Important Paths
- Main addon: `E:\World of Warcraft Sirus\Interface\AddOns\GoAgainAH`
- Core API: `AuctionHouse/AuctionHouseAPI.lua`
- Main UI: `UI/AuctionHouse/AuctionUI.lua`
- Config: `Config.lua`
- Entry point: `AuctionHouse.lua`

## Debugging Commands
- `/goagain` - Open main UI
- `/goagain debug` - Toggle debug mode
- `/goagain clear` - Clear database (careful!)
- `/goagain sync` - Force state sync
- `/goagain version` - Check addon version

## Navigation Tips
1. Use `Grep` to find functions: `"function.*:"`
2. Check `.toc` file for load order
3. Follow `ns.*` references for cross-file access
4. Look for `RegisterEvent` for event handlers
5. Search `SlashCmdList` for commands

## Security Notes
- Validate all user inputs
- Check guild officer permissions for sensitive operations
- Never trust data from other players without validation
- Use proper escaping for chat messages

## When User Asks for Help
1. First check the MCP documentation files
2. Use appropriate search patterns from `MCP_QUICK_REFERENCE.md`
3. Navigate using paths from `MCP_NAVIGATION_MAP.md`
4. Reference data structures from `MCP_DATA_STRUCTURES.md`
5. For complex changes, read relevant source files

Remember: This addon is production code for an active guild. Always maintain backwards compatibility and test thoroughly before suggesting changes.
