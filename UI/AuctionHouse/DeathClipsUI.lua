local _, ns = ...
local L = ns.L


local NUM_CLIPS_TO_DISPLAY = 9
local NUM_CLIPS_PER_PAGE = 50
local CLIPS_BUTTON_HEIGHT = 37
local selectedClip

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
    end
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
    race:SetText(L[clip.race:lower()] or L["Unknown"])
    if clip.race and ns.RACE_COLORS[clip.race] then
        race:SetTextColor(ns.HexToRGG(ns.RACE_COLORS[clip.race]))
    else
        race:SetTextColor(1, 1, 1)
    end

    local iconTexture = _G[buttonName.."ItemIconTexture"]
    if clip.class and CLASS_ICON_TCOORDS[clip.class] then
        iconTexture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        iconTexture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[clip.class]))
    else
        iconTexture:SetTexture("interface/icons/inv_misc_questionmark")
        iconTexture:SetTexCoord(0, 1, 0, 1)  -- reset tex coords
    end


    local glow = _G[buttonName.."ItemGlowBorder"]

    if glow then
        -- Get the class color using RAID_CLASS_COLORS
        local classColor = RAID_CLASS_COLORS[clip.class]

        -- If the class color is valid, apply it to the glow
        if classColor then
            glow:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.75)  -- Using class color with a soft alpha
        else
            -- Fallback for when the class is not found (default to yellow for unknown)
            glow:SetVertexColor(0.9, 0.9, 0.2, 0.75)  -- Soft yellow glow for unknown
        end
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

    local ratingWidget = _G[buttonName.."Rating"].ratingWidget
    local clipButton = _G[buttonName]
    if clip.id == nil then
        ratingWidget:Show()
        ratingWidget:SetRating(0)
    else
        ratingWidget:Show()
        ratingWidget:SetRating(ns.GetRatingAverage(ratings))
    end

    clipButton:SetScript("OnClick", function()
        ns.DebugLog("clip id:", clip.id)
        ns.HideDeathClipRatePrompt()
        ns.ShowDeathClipReviewsPrompt(clip)
    end)

    if ( selectedClip and selectedClip == offset + i) then
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
    local clips = {}
    for _, clip in pairs(ns.GetLiveDeathClips()) do
        table.insert(clips, clip)
    end
    local state = ns.GetDeathClipReviewState()

    clips = ns.SortDeathClips(clips, OFGetCurrentSortParams("clips"))
    clips = FilterHiddenClips(state, clips)
    local ratingsByClip = state:GetRatingsByClip()
    local totalClips = #clips
    local numBatchClips = min(totalClips, NUM_CLIPS_PER_PAGE)
    local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
    local page = OFAuctionFrameDeathClips.page or 0
    local index, isLastSlotEmpty

    updateSortArrows()

    for i=1, NUM_CLIPS_TO_DISPLAY do
        index = offset + i + (page * NUM_CLIPS_PER_PAGE)
        local button = _G["OFDeathClipsButton"..i]
        local clip = clips[index]
        button.clip = clip
        if ( clip == nil or index > (numBatchClips + page * NUM_CLIPS_PER_PAGE)) then
            button:Hide()
            isLastSlotEmpty = (i == NUM_CLIPS_TO_DISPLAY)
        else
            button:Show()
            ns.TryExcept(
                function()
                    local ratings
                    if clip.id == nil then
                        ratings = {}
                    else
                        ratings = ratingsByClip[clip.id] or {}
                    end
                    UpdateClipEntry(state, i, offset, button, clip, ratings, numBatchClips, totalClips)
                end,
                function(err)
                    button:Hide()
                    ns.DebugLog("Error updating clip entry: " .. err)
                end)
        end
    end


    if ( totalClips > NUM_CLIPS_PER_PAGE ) then

        local totalPages = (ceil(totalClips / NUM_CLIPS_PER_PAGE) - 1)
        totalPages = max(0, totalPages)
        if ( page <= 0) then
            OFDeathClipsPrevPageButton:Disable()
        else
            OFDeathClipsPrevPageButton:Enable()
        end
        if page >= totalPages then
            OFDeathClipsNextPageButton:Disable()
        else
            OFDeathClipsNextPageButton:Enable()
        end
        if ( isLastSlotEmpty ) then
            OFDeathClipsSearchCountText:Show()
            local itemsMin = page * NUM_CLIPS_PER_PAGE + 1;
            local itemsMax = itemsMin + numBatchClips - 1;
            OFDeathClipsSearchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalClips)
        else
            OFDeathClipsSearchCountText:Hide()
        end

        -- Artifically inflate the number of results so the scrollbar scrolls one extra row
        numBatchClips = numBatchClips + 1
    else
        OFDeathClipsPrevPageButton.isEnabled = false
        OFDeathClipsNextPageButton.isEnabled = false
        OFDeathClipsSearchCountText:Hide()
    end


    -- Update scrollFrame
    FauxScrollFrame_Update(OFDeathClipsScroll, numBatchClips, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT)
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