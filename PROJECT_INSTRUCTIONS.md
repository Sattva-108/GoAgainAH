# GoAgainAH Project Instructions

## Overview
GoAgainAH is a custom World of Warcraft addon for the Sirus server that provides an advanced auction house system for the "Go Again" guild. This addon includes features like custom auctions, death clips, LFG integration, and a comprehensive review system.

## MCP (Model Context Protocol) Documentation

For efficient navigation and development with Claude MCP, we have created comprehensive documentation maps:

### 📚 Documentation Files

1. **[MCP_NAVIGATION_MAP.md](./MCP_NAVIGATION_MAP.md)**
   - Complete directory structure overview
   - File descriptions and purposes
   - Key function locations
   - System architecture explanation

2. **[MCP_QUICK_REFERENCE.md](./MCP_QUICK_REFERENCE.md)**
   - Fast function finder with common API calls
   - Key file locations table
   - Common search patterns for grep
   - Quick task guides

3. **[MCP_DATA_STRUCTURES.md](./MCP_DATA_STRUCTURES.md)**
   - Core data structure definitions
   - Database schema
   - State management details
   - Event system documentation

4. **[MCP_TOOL_INTEGRATION.md](./MCP_TOOL_INTEGRATION.md)**
   - Complete tool definitions for MCP
   - Tool discovery patterns
   - Usage examples
   - Security and best practices

5. **[CLAUDE_PROJECT_INSTRUCTIONS.md](./CLAUDE_PROJECT_INSTRUCTIONS.md)**
   - Ready-to-use Custom Instructions for Claude Projects
   - Complete project context and guidelines
   - No need to upload files - uses MCP access

## Development Guidelines

### Code Style
- Follow existing Ace3 framework patterns
- Use descriptive function and variable names
- Comment complex logic
- Maintain consistent indentation (4 spaces)

### Adding Features
1. Check existing patterns in similar files
2. Update relevant API files
3. Add UI components if needed
4. Update localization files
5. Test thoroughly in-game

### Testing
- WoW addons require manual in-game testing
- Use `/goagain debug` for debug mode
- Check saved variables after reload
- Test state synchronization with guild members

### Common Tasks

#### Adding a new auction type:
1. Define constant in `AuctionHouseAPI.lua`
2. Update auction creation logic
3. Add UI handling
4. Update filters and search

#### Adding UI elements:
1. Create widget in `UI/Widgets/`
2. Use `CustomFrame` as base
3. Register in parent UI file
4. Add localization strings

#### Modifying database:
1. Update structure in `AuctionHouseDB.lua`
2. Increment revision number
3. Handle migration if needed
4. Update sync logic

## File Organization

- **Core Logic**: `AuctionHouse/` directory
- **UI Components**: `UI/` directory
- **Utilities**: `Utils.lua`, `*Utils.lua` files
- **Configuration**: `Config.lua`, `PlayerPrefs.lua`
- **Localization**: `Locale/` directory

## Important Constants

See `AuctionHouseAPI.lua` for all constants:
- `AUCTION_STATUS_*` - Auction states
- `PRICE_TYPE_*` - Price types
- `DELIVERY_TYPE_*` - Delivery methods
- `REVIEW_TYPE_*` - Review types

## Debugging

Enable debug mode:
```
/goagain debug
```

Common debug commands:
- `/goagain clear` - Clear database
- `/goagain sync` - Force sync
- `/goagain version` - Check version

## Support

For issues or questions:
1. Check the documentation files
2. Review similar existing code
3. Test in-game with debug mode
4. Contact addon maintainers: Athene, MottiDowerro
