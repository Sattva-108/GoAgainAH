local addonName, ns = ...

-- AuctionHouseDB should only contain data, no functions. it's a saved variable!

local AuctionHouseDB = {
    auctions = {},
    -- trades are completed auctions that can have reviews
    -- after a trade has been made, the buyer can review the seller and vice versa
    -- when the character of the reviewer died, the review does not count towards the total score of the reviewed party
    trades = {},
    lastUpdateAt = 0,
    revision = 0,
    listeners = { },
    showDebugUIOnLoad = false,
}
ns.AuctionHouseDB = AuctionHouseDB

