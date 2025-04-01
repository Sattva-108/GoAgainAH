local _, ns = ...
local L = ns.L

ns.ChangeLog = {
    ["1.1.15"] = {
        -- armor & weapons filtering
        L["Allow buying and selling with Guild Points!"],
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Rate & review death clips"],
        L["Stream Together Dungeon Finder"],

        L["Improved stability"],
        L["More detailed armor & weapon filters"],
    },
    ["1.1.14"] = {
        -- minor followup bugfixes for state syncing
        L["Allow buying and selling with Guild Points!"],
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Rate & review death clips"],
        L["Stream Together Dungeon Finder"],

        L["Improved stability"],
        L["More detailed armor & weapon filters"],
    },
    ["1.1.13"] = {
        -- bugfixes/optimization for state syncing
        -- bugfixes for review syncing
        -- persist checkboxes in browse menu
        -- add weapons/armor sub-categories in browse menu
        -- after submitting, 'I want my AI' and feedback now switch to the review tab
        L["Allow buying and selling with Guild Points!"],
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Rate & review death clips"],
        L["Stream Together Dungeon Finder"],

        L["Improved stability"],
        L["More detailed armor & weapon filters"],
    },
    ["1.1.12"] = {
        -- bugfixes for state syncing and deathclip syncing
        L["Allow buying and selling with Guild Points!"],
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Rate & review death clips"],
        L["Stream Together Dungeon Finder"],
        L["Added shift+left click to search"],
    },
    ["1.1.11"] = {
        -- bugfixes for deathclips. localization bugfix for nightelf icon and druid text
        L["Allow buying and selling with Guild Points!"],
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Rate & review death clips"],
        L["Stream Together Dungeon Finder"],
        L["Added shift+left click to search"],
    },
    ["1.1.10"] = {
        -- minor bugfixes
        L["Allow buying and selling with Guild Points!"],
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Rate & review death clips"],
        L["Stream Together Dungeon Finder"],
    },
    ["1.1.9"] = {
        -- support trading for points
        L["Allow buying and selling with Guild Points!"],
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Rate & review death clips"],
        L["Stream Together Dungeon Finder"],
    },
    ["1.1.8"] = {
        -- support Spanish and GoAgain!
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        -- L["Create or Request Enchants"],
        L["Rate & review death clips"],
        L["Duel Auctions: Winner of the duel gets to keep the gold & item"],
        L["Stream Together Dungeon Finder"],
    },
    ["1.1.6"] = {
        -- minor changes to paladin tab
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        -- L["Create or Request Enchants"],
        L["Rate & review death clips"],
        L["Duel Auctions: Winner of the duel gets to keep the gold & item"],
        L["Stream Together Dungeon Finder"],
    },
    ["1.1.5"] = {
        -- minor changes to paladin tab
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Create or Request Enchants"],
        L["Rate & review death clips"],
        L["Duel Auctions: Winner of the duel gets to keep the gold & item"],
        L["Stream Together Dungeon Finder"],
    },
    ["1.1.4"] = {
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Create or Request Enchants"],
        L["Rate & review death clips"],
        L["Duel Auctions: Winner of the duel gets to keep the gold & item"],
        L["Stream Together Dungeon Finder"],
        -- fix: auction data sometimes didn't load for users
        -- quality of life improvements for auctionhouse (filtering/sorting)
        -- minor changes to death clips
    },
    ["1.1.2"] = {
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Create or Request Enchants"],
        L["Rate & review death clips"],
        L["Duel Auctions: Winner of the duel gets to keep the gold & item"],
        L["Stream Together Dungeon Finder"],
        -- fix: tipping popup button
        -- user-experience improvements to Stream Together. auto-enable, tooltips, whisper/invite always usable
    },
    ["1.1.1"] = {
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Create or Request Enchants"],
        L["Rate & review death clips"],
        L["Duel Auctions: Winner of the duel gets to keep the gold & item"],
        L["Stream Together Dungeon Finder"],
    },
    ["1.1.0"] = {
        L["Gold Orders (Deathrolls, TwitchRaids, etc.)"],
        L["Create or Request Enchants"],
        L["Rate & review death clips"],
        L["Duel Auctions: Winner of the duel gets to keep the gold & item"],
    },

    -- ["1.0.7-14"] = {
    --     "Hide Athene top-left portrait in the Auction House",
    --     "Sound effect when declaring bankruptcy",
    --     "Update reel youtube url",
    --     "Various bugfixes related to duels"
    -- },
    -- ["1.0.7-13"] = {
    --     "New: Duels! Sell items for duels. The winner gets the item, or the gold"
    --     "Updated icon"
    -- },
    -- ["1.0.7-12"] = {
    --     "AddBlock option to get rid of the Athene tab"
    -- },
    ["1.0.7-11"] = {
        "Fix: show average viewers in Stream Together",
        "Fix: auctions created by a Shaman could cause the 'Guild Orders' tab to render weirdly",
        "Fix: auction row UI highlight could get stuck after clicking it",
        "Fix: layout/visual glitches in Guild Orders"
    },
    ["1.0.7-10"] = {
        "Fix: bug tracking auctions after player death"
    },
    ["1.0.7-9"] = {
        "Auctions now expire after 14 days instead of 3 days",
        "Blacklisting Athene now hides the Athene tab",
        "Automatically blacklists Athene when you first install the addon",
        "Fix: remove auctions after gkick",
        "Fix: various layout/visual glitches"
    },
    ["1.0.7"] = {
        "New: Stream Together tab to colab with other streamers",
        "Added a way to leave feedback"
    },
    ["1.0.4"] = {
        "Added a message in the chat box whenever a guild member dies to link to the death clip",
        "Various bug fixes and UI improvements"
    },
}