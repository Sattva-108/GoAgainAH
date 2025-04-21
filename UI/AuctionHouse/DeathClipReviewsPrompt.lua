local _, ns = ...
local L = ns.L

local AceGUI = LibStub("AceGUI-3.0")

local function CreateDeathClipReviewsPrompt()
    local frame = AceGUI:Create("CustomFrame")
    frame:SetTitle(L["Clip Reviews"])
    frame:SetLayout("Flow")
    frame.frame:SetResizable(false)
    frame.title:EnableMouse(false)
    frame:SetWidth(410)
    frame:SetHeight(475)

    local closeButton = CreateFrame("Button", "ExitButton", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 7,7)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)

    local contentName = "OFDeathClipReviewsContent"
    local reviewsContent = CreateFrame("Frame", contentName, UIParent, "OFDeathClipReviewsContentTemplate")
    reviewsContent:SetParent(frame.frame)
    reviewsContent:SetPoint("TOPLEFT", frame.frame, "TOPLEFT", 15, -30)
    local scrollFrame = reviewsContent.scrollFrame
    scrollFrame.buttons = {}
    for i=1,4 do
        scrollFrame.buttons[i] = _G[contentName.."Entry"..i]
        local button = scrollFrame.buttons[i]
        local starRating = ns.CreateStarRatingWidget({
            starSize = 9,
            panelHeight = 9,
            marginBetweenStarsX = 2,
            textWidth = 22,
            leftMargin = 1,
        })
        button.content.ratingWidget = starRating
        starRating.frame:SetParent(button.content.ratingFrame)
        starRating.frame:SetPoint("LEFT", button.content.ratingFrame, "LEFT", 0, 0)
        starRating:SetRating(5)
        starRating.frame:Show()
    end


    local function updateEntry(button, review)
        local content = button.content
        content.name:SetText(ns.GetDisplayName(review.owner))
        content.ratingWidget:SetRating(review.rating)
        content.reviewText:SetText(review.note)
    end

    local ENTRY_HEIGHT = 80
    frame.scrollFrame = scrollFrame
    frame.reviewButton = reviewsContent.writeReviewButton
    frame.markOfflineButton = reviewsContent.markOfflineButton
    frame.noReviewsText = reviewsContent.noReviewsText
    function frame:Setup(clip)
        self.clip = clip
        local state = ns.GetDeathClipReviewState()
        self.reviews = state:GetReviewsForClip(clip.id)
        table.sort(self.reviews, function(l, r) return l.createdAt > r.createdAt end)

        FauxScrollFrame_SetOffset(self.scrollFrame, 0)
        self.scrollFrame:SetScript("OnVerticalScroll", function(scroll, offset)
            FauxScrollFrame_OnVerticalScroll(scroll, offset, ENTRY_HEIGHT, function() self:Update() end)
        end)
        if #self.reviews > 0 then
            self.noReviewsText:Hide()
        else
            self.noReviewsText:Show()
        end
        if state:IsClipOffline(clip.id) then
            self.markOfflineButton:Hide()
        else
            self.markOfflineButton:Show()
            self.markOfflineButton:SetScript("OnClick", function()
                state:MarkClipOffline(clip.id, false)
                self:Hide()
            end)
        end

        self:Update()
        self.reviewButton:SetScript("OnClick", function()
            ns.ShowDeathClipRatePrompt(clip)
            self:Hide()
        end)
    end
    function frame:Update()
        local DISPLAYED_REVIEWS = 4
        local offset = FauxScrollFrame_GetOffset(self.scrollFrame)
        for i=1,DISPLAYED_REVIEWS do
            local review = self.reviews[i + offset]
            if review then
                local button = self.scrollFrame.buttons[i]
                button:Show()
                updateEntry(button, review)
            else
                self.scrollFrame.buttons[i]:Hide()
            end
        end
        FauxScrollFrame_Update(self.scrollFrame, #self.reviews, DISPLAYED_REVIEWS, ENTRY_HEIGHT)
    end

    function frame:Show()
        self.frame:Show()
    end


    local function update()
        if not frame:IsShown() then
            return
        end
        if frame.clip == nil then
            return
        end
        frame:Setup(frame.clip)
        frame:Update()
    end
    local state = ns.GetDeathClipReviewState()
    state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE, update)
    state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_STATE_SYNCED, update)

    return frame
end

local deathClipReviewsPrompt

ns.ShowDeathClipReviewsPrompt = function(clip)
    local state = ns.GetDeathClipReviewState()
    local playerName = UnitName("player") -- Current player
    local hasRated = false

    -- Check if player already rated this clip
    for _, review in pairs(state.persisted.state) do
        if review.clipID == clip.id and review.owner == playerName then
            hasRated = true
            break
        end
    end

    -- If NOT rated, show RATE PROMPT (hide reviews frame if it exists)
    if not hasRated then
        if deathClipReviewsPrompt then
            deathClipReviewsPrompt.frame:Hide() -- Force-hide reviews frame
        end
        ns.ShowDeathClipRatePrompt(clip)       -- Show rate prompt
        return -- Exit early
    end

    -- If already rated, SHOW REVIEWS FRAME
    if not deathClipReviewsPrompt then
        deathClipReviewsPrompt = CreateDeathClipReviewsPrompt()
    end
    deathClipReviewsPrompt:Setup(clip)
    deathClipReviewsPrompt:Show()
end