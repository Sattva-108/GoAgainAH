---@meta

---@class BrowseParams
---@field public text string
---@field public minLevel number
---@field public maxLevel number
---@field public class number
---@field public subclass number
---@field public slot number
---@field public page number
---@field public faction number
---@field public exactMatch boolean
---@field public onlineOnly boolean
---@field public auctionsOnly boolean
BrowseParams = {}

function BrowseParams.New(
        text,
        minLevel,
        maxLevel,
        class,
        subclass,
        slot,
        page,
        faction,
        exactMatch,
        onlineOnly,
        auctionsOnly
)
    ---@type BrowseParams
    local self = {}
    setmetatable(self, BrowseParams)
    self.text = text
    self.minLevel = minLevel
    self.maxLevel = maxLevel
    self.class = class
    self.subclass = subclass
    self.slot = slot
    self.page = page
    self.faction = faction
    self.exactMatch = exactMatch
    self.onlineOnly = onlineOnly
    self.auctionsOnly = auctionsOnly
    return self
end

function BrowseParams.Empty()
    return BrowseParams.New("", nil, nil, nil, nil, nil, 0, nil, false, false, false)
end
