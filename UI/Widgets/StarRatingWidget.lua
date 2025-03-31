local addonName, ns = ...
local AceGUI = LibStub("AceGUI-3.0")

local STAR_EMPTY = "Interface/AddOns/" .. addonName .. "/Media/Icons/Icn_StarEmpty.png"
local STAR_GREY = "Interface/AddOns/" .. addonName .. "/Media/Icons/Icn_StarGrey.png"
local STAR_FULL = "Interface/AddOns/" .. addonName .. "/Media/Icons/Icn_StarFull.png"

local function CalculateOffset(i, config)
    local starSize = config.starSize or 18
    local spaceBetweenStars = config.marginBetweenStarsX or 8
    local leftMargin = config.leftMargin or 6
    local textWidth = config.textWidth or 18

    return leftMargin + textWidth + (i - 1) * (starSize + spaceBetweenStars)
end

local function ShouldShowFullStar(starIndex, rating)
    return starIndex <= math.floor(rating + 0.499)
end

local function CreateStarRatingWidget(config)
    local starGroup = AceGUI:Create("MinimalFrame")
    starGroup:SetWidth(CalculateOffset(6, config) - (config.marginBetweenStarsX or 8))
    starGroup:SetHeight(config.panelHeight or 40)
    starGroup.rating = config.initialRating or 0

    local empty = STAR_EMPTY
    if config.useGreyStars then
        empty = STAR_GREY
    end

    local starSize = config.starSize or 18

    local stars = {}
    for i = 1, 5 do
        local starButton = CreateFrame("Button", nil, starGroup.frame)
        starButton:SetSize(starSize + (config.hitboxPadX or 0), starSize + (config.hitboxPadY or 0))
        starButton:SetPoint("LEFT", CalculateOffset(i, config), 0)

        -- Add a transparent background to increase hit area
        local background = starButton:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0)  -- Completely transparent

        local starTexture = starButton:CreateTexture(nil, "OVERLAY")
        starTexture:SetSize(starSize, starSize)
        starTexture:SetPoint("CENTER")
        starTexture:SetTexture(empty)

        starButton.texture = starTexture
        stars[i] = starButton

        if config.interactive then
            starButton:SetScript("OnClick", function()
                starGroup:SetRating(i)

                if config.onChange then
                    config.onChange(i)
                end
            end)
        end
    end

    -- Add method to update rating
    function starGroup:SetRating(rating)
        self.rating = rating
        for i = 1, 5 do
            stars[i].texture:SetTexture(ShouldShowFullStar(i, rating) and STAR_FULL or empty)
        end

        local ratingText = string.format("%.1f", self.rating)
        self.label:SetText(ratingText)

        -- Set text color based on rating
        if not self.rating or self.rating == 0 then
            self.label:SetTextColor(0.5, 0.5, 0.5, 1) -- Grey
        else
            self.label:SetTextColor(1, 0.82, 0, 1) -- Gold
        end
    end

    -- Add text label
    local label = starGroup.frame:CreateFontString(nil, "OVERLAY", config.labelFont or "GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(string.format("%d", starGroup.rating))
    starGroup.label = label

    -- Set initial state
    starGroup:SetRating(config.initialRating or 0)

    return starGroup
end

ns.CreateStarRatingWidget = CreateStarRatingWidget
