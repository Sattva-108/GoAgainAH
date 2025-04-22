local addonName, ns = ...
local L = ns.L

-- Assuming LiveDeathClips is defined somewhere accessible within the ns scope
-- For example, it might be initialized like this elsewhere:
-- ns.LiveDeathClips = ns.LiveDeathClips or {}
-- ns.GetLiveDeathClips = function()
--     return ns.LiveDeathClips
-- end
-- If not, you'll need to ensure ns.LiveDeathClips is the actual table reference.


---
-- Finds all clips for a specific character name, removes them from the
-- main LiveDeathClips table, and returns the removed clips.
-- @param targetName (string) The character name to search for (e.g., "Grommash").
-- @return (table) A table containing the clips that were found and removed.
--
function ns.shash(targetName)
    if not targetName then
        print(addonName .. ": ns.shash requires a targetName.")
        return {}
    end

    -- Use the existing function to get the reference to the live table
    -- Assuming ns.GetLiveDeathClips() returns the actual table reference
    local allClips = ns.GetLiveDeathClips()

    -- Check if the table exists
    if not allClips or type(allClips) ~= "table" then
        print(addonName .. ": LiveDeathClips table not found or not a table.")
        return {}
    end

    local removedClips = {}
    local keysToRemove = {}

    -- First pass: Identify clips to remove and collect their keys
    -- Use pairs as we don't know if keys are numeric indices or string IDs
    for key, clip in pairs(allClips) do
        -- Ensure clip is valid and has a characterName property
        if clip and type(clip) == "table" and clip.characterName and clip.characterName == targetName then
            -- Store a copy of the clip to return later
            -- (Simple shallow copy, adjust if deep copy needed)
            local clipCopy = {}
            for k, v in pairs(clip) do clipCopy[k] = v end
            table.insert(removedClips, clipCopy)

            -- Store the key for removal in the second pass
            table.insert(keysToRemove, key)
        end
    end

    -- Second pass: Remove the identified clips using the collected keys
    if #keysToRemove > 0 then
        print(string.format("%s: Found %d clips for '%s'. Removing them.", addonName, #keysToRemove, targetName))
        for _, key in ipairs(keysToRemove) do
            allClips[key] = nil -- Remove the entry by setting its value to nil
        end
    else
        print(string.format("%s: No clips found for '%s'.", addonName, targetName))
    end

    -- Optional: Trigger an update if the UI is currently shown
    -- This ensures the UI reflects the removal immediately if needed.
    -- if OFAuctionFrame and OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips and OFAuctionFrameDeathClips:IsShown() then
    --    OFAuctionFrameDeathClips_Update()
    -- end

    return removedClips
end

-- Example of how to call it (e.g., via a slash command or test script)
-- /run local removed = ns.shash("Grommash"); print("Removed", #removed, "clips for Grommash")


-- TODO FIXME before release 3.3.5
-- a little hack to not get warning when running testing script:
-- /run SendAddonMessage("ASMSG_HARDCORE_DEATH", "Grommash:15:0:1:16:Цитадель Ледяной Короны:7:Ворг:12", "WHISPER", UnitName("player"))

hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2, data)
    if which == "DANGEROUS_SCRIPTS_WARNING" then
        C_Timer:After(0.01, function()
            local dialog = StaticPopup_Visible(which)
            if dialog then
                local frame = _G[dialog]
                if frame and frame.data then
                    RunScript(frame.data)
                    StaticPopup_Hide(which)
                end
            end
        end)
    end
end)



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
    clip = copy -- Use the merged clip data

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

    -- Get difficulty color based on level
    local color = GetQuestDifficultyColor(lvl)
    -- Format level text with color
    local hex = string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
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
        local mapInfo = C_Map.GetMapInfo(clip.mapId)
        whereStr = mapInfo and mapInfo.name
    end
    if not whereStr then
        whereStr = clip.where
    end
    where:SetText(whereStr or L["Unknown"])

    local clipText = _G[buttonName.."ClipText"]
    local mobLevelText = _G[buttonName.."ClipMobLevel"]

    clipText:SetText(clip.deathCause or L["Unknown"]) -- Use L["Unknown"] if deathCause is nil
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
        ns.HideAllClipPrompts() -- The hook will set openedPromptClipID to nil

        -- If the clicked clip's prompt was NOT the one open, show the appropriate prompt.
        if not wasOpen then
            -- ShowDeathClipReviewsPrompt handles showing reviews or rate prompt
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
        -- Ensure clip and clip.id are valid before checking overrides
        if clip and clip.id then
            local overrides = state:GetClipOverrides(clip.id)
            if not overrides.hidden then
                table.insert(filtered, clip)
            end
        elseif clip then -- Keep clips without an ID if they shouldn't be hidden by default
            table.insert(filtered, clip)
        end
    end
    return filtered
end

function OFAuctionFrameDeathClips_Update()
    local state = ns.GetDeathClipReviewState()
    local ratingsByClip = state:GetRatingsByClip()

    -- Get the potentially modified clips table
    local allClipsData = ns.GetLiveDeathClips()
    local clips = {}
    -- Ensure allClipsData is a table before iterating
    if type(allClipsData) == "table" then
        for _, clip in pairs(allClipsData) do
            -- Add to list only if it's not nil (might have been removed by ns.shash)
            if clip then
                table.insert(clips, clip)
            end
        end
    else
        -- Handle case where GetLiveDeathClips didn't return a table (error or initialization issue)
        ns.DebugLog("OFAuctionFrameDeathClips_Update: GetLiveDeathClips() did not return a table.")
        -- Optionally clear clips or return early
        clips = {}
    end

    clips = ns.SortDeathClips(clips, OFGetCurrentSortParams("clips"))
    clips = FilterHiddenClips(state, clips) -- Filter hidden clips *after* converting to array

    local totalClips = #clips
    local page = OFAuctionFrameDeathClips.page or 0
    local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
    local startIdx = offset + 1 -- Adjusted for 0-based offset
    -- Calculate the actual number of items on the current page in the source data
    local numTotalItemsOnPageAndBefore = min(totalClips, (page + 1) * NUM_CLIPS_PER_PAGE)
    local numItemsOnCurrentPage = max(0, numTotalItemsOnPageAndBefore - (page * NUM_CLIPS_PER_PAGE))

    updateSortArrows()

    -- Pre-fetch visible clips based on scroll offset within the current page's data
    local visibleClips = {}
    local pageStartIndex_in_clips = page * NUM_CLIPS_PER_PAGE + 1
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local indexInCurrentPageData = offset + i
        local indexInFullClipsArray = pageStartIndex_in_clips + indexInCurrentPageData - 1
        if indexInCurrentPageData > 0 and indexInFullClipsArray <= totalClips then
            visibleClips[i] = clips[indexInFullClipsArray]
        end
    end


    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local button = _G["OFDeathClipsButton"..i]
        local clip = visibleClips[i]
        button.clip = clip -- Store the clip data on the button

        -- 🔥 Add highlight support
        SetupClipHighlight(button)

        if not clip then
            button:Hide()
        else
            button:Show()
            local ratings = (clip.id and ratingsByClip[clip.id]) or {}
            local currentNumItemsOnPage = min(numItemsOnCurrentPage - offset, NUM_CLIPS_TO_DISPLAY)

            ns.TryExcept(
                    function()
                        -- Pass the count of items *actually available* for the current scroll view on this page
                        UpdateClipEntry(state, i, offset, button, clip, ratings, currentNumItemsOnPage, totalClips)
                    end,
                    function(err)
                        button:Hide()
                        ns.DebugLog("Error updating clip entry: " .. err .. "\n" .. debugstack())
                    end
            )
        end
    end

    -- Adjust Pagination and Scrollbar logic
    local totalPages = max(0, ceil(totalClips / NUM_CLIPS_PER_PAGE) - 1)

    if totalClips > NUM_CLIPS_PER_PAGE then
        OFDeathClipsPrevPageButton:SetEnabled(page > 0)
        OFDeathClipsNextPageButton:SetEnabled(page < totalPages)

        -- Show count text only if pagination is active
        OFDeathClipsSearchCountText:Show()
        local itemsMin = page * NUM_CLIPS_PER_PAGE + 1
        local itemsMax = numTotalItemsOnPageAndBefore -- Correctly shows the max item index on this page or earlier
        OFDeathClipsSearchCountText:SetFormattedText(NUMBER_OF_RESULTS_TEMPLATE, itemsMin, itemsMax, totalClips)

        -- Update the scroll frame based on the number of items *on the current page*
        FauxScrollFrame_Update(OFDeathClipsScroll, numItemsOnCurrentPage, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT)

    else
        -- Hide pagination buttons and text if only one page worth of items
        OFDeathClipsPrevPageButton:Disable()
        OFDeathClipsNextPageButton:Disable()
        OFDeathClipsSearchCountText:Hide()

        -- Update scroll frame based on the total number of clips (since it's <= NUM_CLIPS_PER_PAGE)
        FauxScrollFrame_Update(OFDeathClipsScroll, totalClips, NUM_CLIPS_TO_DISPLAY, CLIPS_BUTTON_HEIGHT)
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
    -- starRating:SetRating(3.5) -- Initial rating removed, set dynamically in UpdateClipEntry
    starRating.frame:Show()
end

function OFAuctionFrameDeathClips_OnHide()
    if OFAuctionFrameDeathClips._whenUpdateTicker then
        OFAuctionFrameDeathClips._whenUpdateTicker:Cancel()
        OFAuctionFrameDeathClips._whenUpdateTicker = nil
    end
    -- Hide prompts when the main frame hides
    ns.HideAllClipPrompts()
end

-- Need functions for page changes
function OFDeathClipsPrevPageButton_OnClick()
    local page = OFAuctionFrameDeathClips.page or 0
    if page > 0 then
        OFAuctionFrameDeathClips.page = page - 1
        FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0) -- Reset scroll offset when changing page
        OFAuctionFrameDeathClips_Update()
    end
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
end

function OFDeathClipsNextPageButton_OnClick()
    local page = OFAuctionFrameDeathClips.page or 0
    -- Calculate total pages correctly
    local allClipsData = ns.GetLiveDeathClips()
    local clips = {}
    if type(allClipsData) == "table" then
        for _, clip in pairs(allClipsData) do if clip then table.insert(clips, clip) end end
    end
    local state = ns.GetDeathClipReviewState()
    clips = FilterHiddenClips(state, clips) -- Filter before counting for pagination
    local totalClips = #clips
    local totalPages = max(0, ceil(totalClips / NUM_CLIPS_PER_PAGE) - 1)

    if page < totalPages then
        OFAuctionFrameDeathClips.page = page + 1
        FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0) -- Reset scroll offset
        OFAuctionFrameDeathClips_Update()
    end
    PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
end

-- Need sorting functions to reset page and offset
local original_OFAuctionFrame_SetSort = OFAuctionFrame_SetSort
function OFAuctionFrame_SetSort(list, field, reverse)
    original_OFAuctionFrame_SetSort(list, field, reverse)
    if list == "clips" then
        OFAuctionFrameDeathClips.page = 0
        FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0)
        -- Update immediately after sort changes
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update()
        end
    end
end