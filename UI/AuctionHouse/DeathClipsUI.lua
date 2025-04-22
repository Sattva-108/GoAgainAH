local addonName, ns = ...
local L = ns.L


local NUM_CLIPS_TO_DISPLAY = 9
local NUM_CLIPS_PER_PAGE = 50
local CLIPS_BUTTON_HEIGHT = 37

local function updateSortArrows()
    OFSortButton_UpdateArrow(OFDeathClipsStreamerSort, "clips", "streamer")
    OFSortButton_UpdateArrow(OFDeathClipsRaceSort, "clips", "race")
    OFSortButton_UpdateArrow(OFDeathClipsLevelSort, "clips", "level")
    OFSortButton_UpdateArrow(OFDeathClipsClassSort, "clips", "class")
    OFSortButton_UpdateArrow(OFDeathClipsWhenSort, "clips", "when")
    OFSortButton_UpdateArrow(OFDeathClipsRatingSort, "clips", "rating")
    OFSortButton_UpdateArrow(OFDeathClipsWhereSort, "clips", "where")
    OFSortButton_UpdateArrow(OFDeathClipsClipSort, "clips", "clip")
end

function OFAuctionFrameDeathClips_OnLoad()
    OFAuctionFrameDeathClips.page = 0
    OFAuctionFrame_SetSort("clips", "when", false)
    ns.AuctionHouseAPI:RegisterEvent(ns.EV_DEATH_CLIPS_CHANGED, function()
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update()
        end
    end)
    -- Initialize the state variable to track which clip's prompt is open
    OFAuctionFrameDeathClips.openedPromptClipID = nil
    OFAuctionFrameDeathClips._highlightedClips = OFAuctionFrameDeathClips._highlightedClips or {}
end

local function formatWhen(clip)
    if clip.ts == nil then
        return L["Unknown"]
    end
    local serverTime = GetServerTime()
    local timeDiff = serverTime - clip.ts

    if timeDiff < 0 then
        --print(string.format(
        --        "Time sync issue - Server: %d, Clip: %d, Diff: %d (Clip ID: %s)",
        --        serverTime, clip.ts, timeDiff, clip.id or "nil"
        --))
        timeDiff = 0  -- Ensure we never show negative time
    end

    return ns.PrettyDuration(timeDiff)
end

function SetupClipHighlight(button)
    if not button.glow then
        -- ✨ Glow
        local glow = button:CreateTexture(nil, 'OVERLAY')
        button.glow = glow
        glow:SetPoint('CENTER', button, 'CENTER')
        glow:SetWidth(400 / 300 * button:GetWidth())
        glow:SetHeight(171 / 70 * button:GetHeight())
        glow:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\UI-Achievement-Alert-Glow")
        glow:SetBlendMode('ADD')
        glow:SetTexCoord(0, .78125, 0, .66796875)
        glow:SetAlpha(0)

        glow.animation = CreateFrame('Frame')
        glow.animation:Hide()
        glow.animation:SetScript('OnUpdate', function(self)
            local t = GetTime() - self.t0
            if t <= .2 then
                glow:SetAlpha(t * 5)
            elseif t <= .7 then
                glow:SetAlpha(1 - (t - .2) * 2)
            else
                glow:SetAlpha(0)
                self:Hide()
            end
        end)
        function glow.animation:Play()
            self.t0 = GetTime()
            self:Show()
        end
    end

    if not button.shine then
        -- ✨ Shine
        local shine = button:CreateTexture(nil, 'ARTWORK')
        button.shine = shine
        shine:SetPoint('TOPLEFT', button, 0, 8)
        shine:SetWidth(67 / 300 * button:GetWidth())
        shine:SetHeight(1.28 * button:GetHeight())
        shine:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\UI-Achievement-Alert-Glow")
        shine:SetBlendMode('ADD')
        shine:SetTexCoord(.78125, .912109375, 0, .28125)
        shine:SetAlpha(0)

        shine.animation = CreateFrame('Frame')
        shine.animation:Hide()
        shine.animation:SetScript('OnUpdate', function(self)
            local t = GetTime() - self.t0
            if t <= .3 then
                shine:SetPoint('TOPLEFT', button, 0, 8)
            elseif t <= .7 then
                shine:SetPoint('TOPLEFT', button, (t - .3) * 2.5 * self.distance, 8)
            end
            if t <= .3 then
                shine:SetAlpha(0)
            elseif t <= .5 then
                shine:SetAlpha(1)
            elseif t <= .7 then
                shine:SetAlpha(1 - (t - .5) * 5)
            else
                shine:SetAlpha(0)
                self:Hide()
            end
        end)
        function shine.animation:Play()
            self.t0 = GetTime()
            self.distance = button:GetWidth() - shine:GetWidth() + 8
            self:Show()
            button:SetAlpha(1)
        end
    end
end


local initialized = false
function OFAuctionFrameDeathClips_OnShow()
    OFAuctionFrameDeathClips_Update()
    if not initialized then
        initialized = true
        local state = ns.GetDeathClipReviewState()
        local update = function()
            if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update()
            end
        end


        state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_ADD_OR_UPDATE, update)
        state:RegisterEvent(ns.EV_DEATH_CLIP_REVIEW_STATE_SYNCED, update)
        state:RegisterEvent(ns.EV_DEATH_CLIP_OVERRIDE_UPDATED, update)

        -- Hook HideAllClipPrompts ONCE to reset our state tracker
        hooksecurefunc(ns, "HideAllClipPrompts", function()
            OFAuctionFrameDeathClips.openedPromptClipID = nil
            -- Also explicitly update the highlight state of buttons when prompts are closed externally
            if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update() -- Refresh highlights
            end
        end)
    end
    OFAuctionFrameDeathClips._whenUpdateTicker = C_Timer:NewTicker(1, function()
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            for i = 1, NUM_CLIPS_TO_DISPLAY do
                local button = _G["OFDeathClipsButton" .. i]
                local clip = button and button.clip
                if button and button:IsShown() and clip then
                    local when = _G[button:GetName() .. "WhenText"]
                    if when and clip.ts then
                        local age = GetServerTime() - clip.ts
                        when:SetText(formatWhen(clip))

                        local highlighted = OFAuctionFrameDeathClips._highlightedClips

                        if age < 3 and not highlighted[clip.id] then
                            highlighted[clip.id] = true

                            if button.glow then
                                button.glow.animation:Play()
                            end
                            if button.shine then
                                button.shine.animation:Play()
                            end
                        end

                    end
                end
            end
        end
    end)

end

local function ResizeEntry(button, numBatchAuctions, totalAuctions)
    local buttonHighlight = _G[button:GetName().."Highlight"]
    if ( numBatchAuctions < NUM_CLIPS_TO_DISPLAY ) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    elseif ( numBatchAuctions == NUM_CLIPS_TO_DISPLAY and totalAuctions <= NUM_CLIPS_TO_DISPLAY ) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    else
        button:SetWidth(769)
        buttonHighlight:SetWidth(735)
    end
end

local function UpdateClipEntry(state, i, offset, button, clip, ratings, numBatchClips, totalClips)
    if clip.streamer == nil or clip.streamer == "" then
        clip.streamer = ns.GetTwitchName(clip.characterName)
    end

    local buttonName = button:GetName()
    local overrides = state:GetClipOverrides(clip.id)
    local copy = {}
    for k, v in pairs(clip) do
        copy[k] = v
    end
    for k, v in pairs(overrides) do
        copy[k] = v
    end
    clip = copy

    ResizeEntry(button, numBatchClips, totalClips)

    local name = _G[buttonName.."Name"]
    if clip.characterName then
        -- Get the class color using the player's class
        local classColor = RAID_CLASS_COLORS[clip.class] -- 'clip.class' should be the player's class (e.g., "WARRIOR", "MAGE", etc.)

        if classColor then
            -- Set class color for the name
            name:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            -- Fallback to a default color (light gray) if the class color is not found
            name:SetTextColor(0.85, 0.85, 0.85)
        end

        name:SetText(clip.characterName)
    else
        name:SetTextColor(0.85, 0.85, 0.85)   -- Light grayish white for unknown
        name:SetText(L["Unknown"])
    end

    local race = _G[buttonName.."RaceText"]
    race:SetText(L[clip.race] or L["Unknown"])

    -- Faction-based color logic for the race text
    if clip.faction == "Horde" then
        race:SetTextColor(0.8, 0.3, 0.3)  -- Soft red for Horde
    elseif clip.faction == "Alliance" then
        race:SetTextColor(0.4, 0.6, 1)    -- Soft blue for Alliance
    else
        race:SetTextColor(0.9, 0.9, 0.4)  -- Soft yellow for Neutral or unknown faction
    end


    local iconTexture = _G[buttonName.."ItemIconTexture"]
    if clip.class and CLASS_ICON_TCOORDS[clip.class] then
        iconTexture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        iconTexture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[clip.class]))
    else
        iconTexture:SetTexture("interface/icons/inv_misc_questionmark")
        iconTexture:SetTexCoord(0, 1, 0, 1)  -- reset tex coords
    end

    local level = _G[buttonName.."Level"]
    local lvl = clip.level or 1

    -- Получаем цвет по уровню сложности
    local color = GetQuestDifficultyColor(lvl)

    -- Переводим RGB в шестнадцатеричный код
    local hex = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)

    -- Устанавливаем цветной текст
    level:SetText(hex .. lvl .. "|r")


    local class = _G[buttonName.."ClassText"]
    if clip.class then
        -- Convert to uppercase for consistent lookups
        local classKey = string.upper(clip.class)

        -- Get localized full name
        local localizedName = LOCALIZED_CLASS_NAMES_MALE[classKey] or clip.class

        -- Only shorten Warlock for Russian clients
        if GetLocale() == "ruRU" and classKey == "WARLOCK" then
            localizedName = "Чернокниж."
        end

        -- Set class color from RAID_CLASS_COLORS
        local classColor = RAID_CLASS_COLORS[classKey]
        if classColor then
            class:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            class:SetTextColor(1, 1, 1) -- Fallback to white
        end

        class:SetText(localizedName)
    else
        -- Unknown class handling
        class:SetTextColor(1, 1, 1)
        class:SetText(L["Unknown"])
    end

    local when = _G[buttonName.."WhenText"]
    when:SetText(formatWhen(clip))

    local where = _G[buttonName.."WhereText"]
    where:SetJustifyH("LEFT")  -- Align text to the left

    local whereStr
    if clip.mapId then
        whereStr = C_Map.GetMapInfo(clip.mapId).name
    end
    if not whereStr then
        whereStr = clip.where
    end
    where:SetText(whereStr or L["Unknown"])

    local clipText = _G[buttonName.."ClipText"]
    local mobLevelText = _G[buttonName.."ClipMobLevel"]

    clipText:SetText(clip.deathCause or "Неизвестно")
    mobLevelText:SetText(clip.mobLevelText or "")
    mobLevelText:SetJustifyH("CENTER")

    -- Update Rating Widget
    local ratingWidget = _G[buttonName.."Rating"].ratingWidget
    if clip.id == nil then
        ratingWidget:Show()
        ratingWidget:SetRating(0)
    else
        ratingWidget:Show()
        ratingWidget:SetRating(ns.GetRatingAverage(ratings))
    end

    local clipButton = _G[buttonName] -- Get the button itself

    -- === OPTIMIZED OnClick ===
    clipButton:SetScript("OnClick", function()
        -- Ensure we have a valid clip and ID to work with
        if not clip or not clip.id then return end

        local clickedClipId = clip.id
        local wasOpen = OFAuctionFrameDeathClips.openedPromptClipID and OFAuctionFrameDeathClips.openedPromptClipID == clickedClipId

        -- Always hide any potentially open prompt first.
        -- This simplifies logic - we hide regardless, and then decide whether to show again.
        ns.HideAllClipPrompts() -- The hook will set openedPromptClipID to nil

        -- If the clicked clip's prompt was NOT the one open, show the appropriate prompt.
        if not wasOpen then
            -- Let ShowDeathClipReviewsPrompt handle the logic:
            -- It checks if the player has rated and shows either the
            -- reviews prompt or calls ShowDeathClipRatePrompt itself.
            ns.ShowDeathClipReviewsPrompt(clip)

            -- Mark this clip's prompt as the one that is now open
            OFAuctionFrameDeathClips.openedPromptClipID = clickedClipId
        end
        -- If it *was* open, HideAllClipPrompts already closed it, and openedPromptClipID is nil,
        -- so we don't re-open it, achieving the toggle-off behavior.

        -- Update highlights immediately after click logic
        OFAuctionFrameDeathClips_Update()
    end)


    -- Update button highlight based on whether its prompt is open
    if OFAuctionFrameDeathClips.openedPromptClipID and OFAuctionFrameDeathClips.openedPromptClipID == clip.id then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

local function FilterHiddenClips(state, clips)
    local filtered = {}
    for _, clip in ipairs(clips) do
        local overrides = state:GetClipOverrides(clip.id)
        if not overrides.hidden then
            table.insert(filtered, clip)
        end
    end
    return filtered
end

function OFAuctionFrameDeathClips_Update()
    local state = ns.GetDeathClipReviewState()
    local ratingsByClip = state:GetRatingsByClip()

    local allClips = ns.GetLiveDeathClips()
    local clips = {}
    for _, clip in pairs(allClips) do
        table.insert(clips, clip)
    end

    clips = ns.SortDeathClips(clips, OFGetCurrentSortParams("clips"))
    clips = FilterHiddenClips(state, clips)

    local totalClips = #clips
    local page = OFAuctionFrameDeathClips.page or 0
    local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
    local startIdx = offset + 1 + (page * NUM_CLIPS_PER_PAGE)
    local endIdx = startIdx + NUM_CLIPS_TO_DISPLAY - 1
    local numBatchClips = min(totalClips - page * NUM_CLIPS_PER_PAGE, NUM_CLIPS_PER_PAGE)
    local isLastSlotEmpty

    updateSortArrows()

    -- Pre-fetch visible clips
    local visibleClips = {}
    for i = startIdx, endIdx do
        visibleClips[i - startIdx + 1] = clips[i]
    end

    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local button = _G["OFDeathClipsButton"..i]
        local clip = visibleClips[i]
        button.clip = clip

        -- 🔥 Add highlight support
        SetupClipHighlight(button)

        if not clip then
            button:Hide()
            isLastSlotEmpty = (i == NUM_CLIPS_TO_DISPLAY)
        else
            button:Show()
            local ratings = (clip.id and ratingsByClip[clip.id]) or {}

            ns.TryExcept(
                    function()
                        UpdateClipEntry(state, i, offset, button, clip, ratings, numBatchClips, totalClips)
                    end,
                    function(err)
                        button:Hide()
                        ns.DebugLog("Error updating clip entry: " .. err)
                    end
            )
        end
    end

    -- Pagination logic
    if totalClips > NUM_CLIPS_PER_PAGE then
        local totalPages = max(0, ceil(totalClips / NUM_CLIPS_PER_PAGE) - 1)
        OFDeathClipsPrevPageButton:SetEnabled(page > 0)
        OFDeathClipsNextPageButton:SetEnabled(page < totalPages)

        if isLastSlotEmpty then
            OFDeathClipsSearchCountText:Show()
            local itemsMin = page * NUM_CLIPS_PER_PAGE + 1
            local itemsMax = itemsMin + numBatchClips - 1
            OFDeathClipsSearchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalClips)
        else
            OFDeathClipsSearchCountText:Hide()
        end

        -- Force scrollbar to allow one more scroll row
        FauxScrollFrame_Update(OFDeathClipsScroll, numBatchClips + 1, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT)
    else
        OFDeathClipsPrevPageButton:Disable()
        OFDeathClipsNextPageButton:Disable()
        OFDeathClipsSearchCountText:Hide()
        FauxScrollFrame_Update(OFDeathClipsScroll, numBatchClips, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT)
    end
end


function OFDeathClipsRatingWidget_OnLoad(self)
    local starRating = ns.CreateStarRatingWidget({
        starSize = 12,
        panelHeight = 12,
        marginBetweenStarsX = 2,
        textWidth = 22,
        leftMargin = 1,
        disableMouse = true,
        hideText = true
    })
    self.ratingWidget = starRating
    starRating.frame:SetParent(self)
    starRating.frame:SetPoint("LEFT", self, "LEFT", -2, 0)
    starRating:SetRating(3.5)
    starRating.frame:Show()
end

function OFAuctionFrameDeathClips_OnHide()
    if OFAuctionFrameDeathClips._whenUpdateTicker then
        OFAuctionFrameDeathClips._whenUpdateTicker:Cancel()
        OFAuctionFrameDeathClips._whenUpdateTicker = nil
    end
end