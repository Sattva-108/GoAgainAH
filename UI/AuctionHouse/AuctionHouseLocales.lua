local addonName, ns = ...
local L = ns.L


L_GUILD_ORDERS = L["Guild Orders"]
L_CREATE_ORDER = L["Create Order"]
L_PENDING_ORDERS = L["Pending Orders"]
L_REVIEWS_N = L["Reviews (%d)"]
L_REVIEWS = L["Reviews"]
L_STREAM_TOGETHER = L["Stream Together"]
L_DEATH_CLIPS = L["Death Clips"]
L_DEATH_ROLL = L["Death Roll"]
L_WHATS_NEW = L["What's new"]
L_WHATS_NEW_COLON = L["What's new:"]
L_YOU_RE_UP_TO_DATE = L["You're up to date"]
L_UPDATE_AVAILABLE = L["Update available"]
L_BUGS_AND_FEEDBACK = L["Bugs & Feedback"]
L_I_WANT_MY_OWN_AI = L["I want my own AI"]
L_TWITCH_RAID = L["Twitch Raid"]
L_REQUEST_ITEM = L["Request Item"]
L_TIP = L["Tip"]
L_SELECT = L["Select"]
L_COMING_SOON = L["Coming soon"]
L_TYPE = L["Type"]
L_MISC = L["Misc"]
L_BUYER_SELLER = L["Buyer/Seller"]
L_RATING = L["Rating"]
L_PRICE = L["Price"]
L_ONLINE_ONLY = L["Online Only"]
L_AUCTIONS_ONLY = L["Auctions Only"]
L_FULFILL = L["Fulfill"]
L_LOAN = L["Loan"]
L_MARK_LOAN_COMPLETE = L["Mark Loan Complete"]
L_STREAMER = L["Streamer"]
L_WHEN = L["When"]
L_WHERE = L["Where"]
L_CLIP_LINK = L["Clip Link"]
L_RATE_CLIP = L["Rate Clip"]
L_DELIVERY = L["Delivery"]
L_MIN_TWITCH_VIEWERS = L["Min Twitch viewers:"]
L_LOAN_TOOLTIP = L["Allow players to buy the item on a loan. They have 7 days to pay or declare bankruptcy."]
L_BUYOUT_WITH_LOAN = L["Buyout with loan"]
L_ALLOW_LOAN = L["Allow loan"]
L_ROLEPLAY = L["Roleplay"]
L_DUEL_NORMAL = L["Duel (Normal)"]
L_NO_REVIEWS_YET = L["There are no reviews for this clip yet."]
L_WRITE_REVIEW = L["Изменить оценку"]
L_ORDERS = L["Orders"]
L_BLACKLIST_PLAYER = L["Blacklist Player"]
L_COLAB = L["Colab"]
L_VIEWERS = L["Viewers"]
L_LIVESTREAM = L["Livestream"]
L_RAID = L["Raid"]
L_RAID_TWITCH = L["Twitch Raid"]
L_ENABLE_COLAB = L["Enable GoAgain Collab"]
L_RP_TOGETHER = L["RP Together"]
L_DUNGEON = L["Dungeon"]
L_SELECT_DUNGEONS = L["Select Dungeons"]
L_MIN_VIEWERS = L["Min Viewers"]
L_MAX_VIEWERS = L["Max Viewers"]
L_NO_MIN = L["No Min"]
L_NO_MAX = L["No Max"]
L_APPLY_VIEWERS_FILTER = L["Apply Viewers Filter"]
L_BLOCK_USERS = L["Block Users"]
L_COLAB_SET_REQUIREMENTS = L["Set your requirements for who can collab with you through Twitch's Stream Together feature"]

local goAgainAH = L["GoAgain AH"]
L_GO_AGAIN_BROWSE_AUCTIONS = goAgainAH .. " - " .. L["Browse Auctions"]
L_GO_AGAIN_PENDING_ORDERS = goAgainAH .. " - " .. L["Pending Orders"]

local _ = L["warrior"]
local _ = L["priest"]
local _ = L["shaman"]
local _ = L["paladin"]
local _ = L["rogue"]
local _ = L["mage"]
local _ = L["warlock"]
local _ = L["druid"]

local _ = L["dwarf"]
local _ = L["gnome"]
local _ = L["human"]
local _ = L["nightelf"]
local _ = L["night elf"]

local _ = L["orc"]
local _ = L["tauren"]
local _ = L["troll"]
local _ = L["undead"]

ns.LocalizeEnum = function(value)
    return L[string.lower(value)] or value
end
