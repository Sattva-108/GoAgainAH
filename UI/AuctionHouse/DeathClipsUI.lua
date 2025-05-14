local addonName, ns = ...
local L = ns.L

-- Keep track if the sort hook has been applied to avoid duplicates
local sortHookApplied = false

local NUM_CLIPS_TO_DISPLAY = 9
local NUM_CLIPS_PER_PAGE = 50
local CLIPS_BUTTON_HEIGHT = 37

-- This must match your <Binding name="GOAGAINAH_TOGGLE_CLIPS" …> in Bindings.xml
-- 1) Key-Bindings header and friendly name
_G.BINDING_HEADER_GoAgainAH = "GoAgainAH"
_G.BINDING_NAME_GOAGAINAH_TOGGLE_CLIPS = "Показать панель смертей"

-- 2) This must exactly match your <Binding name="GOAGAINAH_TOGGLE_CLIPS" …>
function GOAGAINAH_TOGGLE_CLIPS()
    local af = _G["OFAuctionFrame"]
    if not af then
        return
    end

    -- if visible, just hide and exit
    if af:IsShown() then
        af:Hide()
        return
    end

    -- otherwise show & select Death-Clips → Live
    af:Show()

    -- click main tab #6 (Death-Clips)
    local tab6 = _G["OFAuctionFrameTab6"]
    if tab6 and tab6:IsShown() then
        tab6:Click()
    end

    -- click the “Live” sub-tab
    local liveTab = _G["OFDeathClipsTabLive"]
    if liveTab and liveTab:IsShown() then
        liveTab:Click()
    end
end

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

    -- —— КЭШ КНОПОК ——
    ns.clipButtonElements = {}
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local button = _G["OFDeathClipsButton" .. i]
        local buttonName = button:GetName()

        ns.clipButtonElements[i] = {
            button = button,
            highlight = _G[buttonName .. "Highlight"],
            name = _G[buttonName .. "Name"],
            level = _G[buttonName .. "Level"],
            raceText = _G[buttonName .. "RaceText"],
            itemIconTexture = _G[buttonName .. "ItemIconTexture"],
            classText = _G[buttonName .. "ClassText"],
            whenText = _G[buttonName .. "WhenText"],
            whereText = _G[buttonName .. "WhereText"],
            clipText = _G[buttonName .. "ClipText"],
            clipMobLevel = _G[buttonName .. "ClipMobLevel"],
            rating = _G[buttonName .. "Rating"],
            clipFrame = _G[buttonName .. "Clip"],
        }

        -- Хайлайт создаём один раз
        ns.SetupClipHighlight(button)

        -- OnClick создаём один раз
        button:SetScript("OnClick", function(self)
            local c = self.clipData
            if not c or not c.id then return end

            local wasOpen = (OFAuctionFrameDeathClips.openedPromptClipID == c.id)
            ns.HideAllClipPrompts()

            if not wasOpen then
                ns.ShowDeathClipReviewsPrompt(c)
                OFAuctionFrameDeathClips.openedPromptClipID = c.id
            end

            OFAuctionFrameDeathClips_Update()
        end)

    end

    --C_Timer:After(3, function()
    --    -- Hook the “Live” tab:
    --    OFDeathClipsTabLive:HookScript("OnClick", function()
    --        -- when you switch back to Live, sort by timestamp descending:
    --        OFAuctionFrame_SetSort("clips", "when", false)
    --    end)
    --
    --    -- Hook the “Completed” tab:
    --    OFDeathClipsTabCompleted:HookScript("OnClick", function()
    --        -- when you switch to Completed, sort by playedTime ascending:
    --        OFAuctionFrame_SetSort("clips", "clip", true)
    --    end)
    --end)

    ns.AuctionHouseAPI:RegisterEvent(ns.EV_DEATH_CLIPS_CHANGED, function()
        if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
            OFAuctionFrameDeathClips_Update()
        end
    end)
    -- Initialize the state variable to track which clip's prompt is open
    OFAuctionFrameDeathClips.openedPromptClipID = nil
    OFAuctionFrameDeathClips._highlightedClips = OFAuctionFrameDeathClips._highlightedClips or {}

    -- Hook the sort function ONCE to reset page and scroll on sort change
    if not sortHookApplied then
        -- Ensure the function exists before hooking
        if type(OFAuctionFrame_SetSort) == "function" then
            hooksecurefunc("OFAuctionFrame_SetSort", function(type, key, ascending)
                -- Reset the page number
                OFAuctionFrameDeathClips.page = 0
                -- Always reset the scroll frame offset (important for data loading)
                FauxScrollFrame_SetOffset(OFDeathClipsScroll, 0)
                if OFDeathClipsScrollScrollBar then
                    OFDeathClipsScrollScrollBar:SetValue(0)
                end

            end)
            sortHookApplied = true -- Mark as applied
        else
            -- Log an error or warning if the function can't be found
            ns.DebugLog(addonName .. ": Error - Could not find OFAuctionFrame_SetSort to hook for clip sorting.")
        end
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

function ns.SetupClipHighlight(button)
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
        --state:RegisterEvent(ns.EV_DEATH_CLIP_OVERRIDE_UPDATED, update)

        -- Hook HideAllClipPrompts ONCE to reset our state tracker
        hooksecurefunc(ns, "HideAllClipPrompts", function()
            OFAuctionFrameDeathClips.openedPromptClipID = nil
            -- Also explicitly update the highlight state of buttons when prompts are closed externally
            if OFAuctionFrame:IsShown() and OFAuctionFrameDeathClips:IsShown() then
                OFAuctionFrameDeathClips_Update() -- Refresh highlights
            end
        end)
    end
    -- —— When-Ticker: обновляет «Когда» и триггерит подсветку новых строк ——
    do
        local frame = OFAuctionFrameDeathClips
        frame._highlightedClips = frame._highlightedClips or {}

        -- остановить прежний тикер, если был
        if frame._whenUpdateTicker then
            frame._whenUpdateTicker:Cancel()
        end

        frame._whenUpdateTicker = C_Timer:NewTicker(1, function()
            -- панель аукциона или под-фрейм скрыты → пропуск
            if not (OFAuctionFrame:IsShown() and frame:IsShown()) then return end

            for i = 1, NUM_CLIPS_TO_DISPLAY do                -- всегда 9 строк
                local el     = ns.clipButtonElements[i]        -- кэш (Шаг 1)
                local button = el and el.button
                local clip   = button and button.clipData      -- актуальные данные

                if button and button:IsShown() and clip and clip.ts then
                    ------------------------------------------------------
                    -- 1) «Когда»
                    ------------------------------------------------------
                    local whenFS = el.whenText
                    whenFS:SetText(formatWhen(clip))

                    if clip.playedTime and clip.level then
                        local r,g,b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
                        whenFS:SetTextColor(r,g,b,.7)
                    else
                        whenFS:SetTextColor(.6,.6,.6,.5)
                    end

                    ------------------------------------------------------
                    -- 2) Подсветка новых клипов (меньше 60 с)
                    ------------------------------------------------------
                    local age = GetServerTime() - clip.ts
                    if age < 60 and not frame._highlightedClips[clip.id] then
                        frame._highlightedClips[clip.id] = true

                        if button.glow  then button.glow.animation:Play()  end
                        if button.shine then button.shine.animation:Play() end
                    end
                end
            end
        end)
    end

end

local function ResizeEntry(button, numBatchAuctions, totalAuctions)
    local buttonHighlight = _G[button:GetName() .. "Highlight"]
    if (numBatchAuctions < NUM_CLIPS_TO_DISPLAY) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    elseif (numBatchAuctions == NUM_CLIPS_TO_DISPLAY and totalAuctions <= NUM_CLIPS_TO_DISPLAY) then
        button:SetWidth(793)
        buttonHighlight:SetWidth(758)
    else
        button:SetWidth(769)
        buttonHighlight:SetWidth(735)
    end
end

local function UpdateLayout(buttonName)
    -- Fetch elements for Name, Level, Clip, ClassText, WhereText, and RaceText
    local name = _G[buttonName .. "Name"]
    local level = _G[buttonName .. "Level"]
    local clipFrame = _G[buttonName .. "Clip"]
    local classText = _G[buttonName .. "ClassText"]
    local whereText = _G[buttonName .. "WhereText"]
    local raceText = _G[buttonName .. "RaceText"]
    -- Re-anchor WhenText to the right of RaceText
    local whenText = _G[buttonName .. "WhenText"]
    -- Re-anchor Rating frame to the right of WhenText
    local rating = _G[buttonName .. "Rating"]

    if ns.isCompletedTabActive then
        -- When completed tab is active, hide the level and expand the name
        level:Hide()
        name:SetWidth(name:GetWidth() + level:GetWidth())  -- Expand name to take up the space of level

        -- Re-anchor the clip to the right of name
        clipFrame:ClearAllPoints()
        clipFrame:SetPoint("LEFT", name, "RIGHT", -8, 0)  -- Position Clip immediately to the right of Name

        -- Hide WhereText and adjust ClassText and RaceText
        whereText:Hide()

        -- Get half the width of WhereText to distribute between ClassText and RaceText
        local whereWidth = whereText:GetWidth()
        local halfWhereWidth = whereWidth / 2

        -- Increase the width of ClassText and RaceText by half of WhereText's width
        classText:SetWidth(classText:GetWidth() + halfWhereWidth - 20)
        raceText:SetWidth(raceText:GetWidth() + halfWhereWidth - 20)

        -- Re-anchor the ClassText and RaceText to slide them to the right of Clip
        classText:ClearAllPoints()
        raceText:ClearAllPoints()

        -- Anchor ClassText immediately to the right of Clip
        classText:SetPoint("LEFT", clipFrame, "RIGHT", 15, 0)

        -- Anchor RaceText immediately to the right of ClassText
        raceText:SetPoint("LEFT", classText, "RIGHT", 2, 0)

        -- Set font for ClassText and RaceText in the live tab (fallback font)
        classText:SetFontObject("GameFontNormal")  -- Fallback font for live tab
        raceText:SetFontObject("GameFontNormal")   -- Fallback font for live tab
        classText:SetJustifyH("CENTER")
        raceText:SetJustifyH("CENTER")

        whenText:ClearAllPoints()
        whenText:SetPoint("LEFT", raceText, "RIGHT", 0, 0)
    else
        -- If live tab is active, show the level again and reset the name width
        level:Show()
        name:SetWidth(100)  -- Reset to original width (adjust if needed)

        -- Re-anchor the whereText to the right of level (was clipFrame before)
        whereText:ClearAllPoints()
        whereText:SetPoint("LEFT", level, "RIGHT", 2, 0)
        whereText:Show()

        -- Move the clipFrame where whereText was
        clipFrame:ClearAllPoints()
        clipFrame:SetPoint("LEFT", whereText, "RIGHT", 2, 0)

        -- Reset the width of ClassText and RaceText to original sizes (adjust as needed)
        classText:SetWidth(84)  -- Adjust to original width as needed
        raceText:SetWidth(84)   -- Adjust to original width as needed

        -- Re-anchor the ClassText and RaceText to the right of clipFrame
        classText:ClearAllPoints()
        raceText:ClearAllPoints()

        -- Anchor ClassText immediately to the right of Clip (was WhereText before)
        classText:SetPoint("LEFT", clipFrame, "RIGHT", -15, 0)

        -- Anchor RaceText immediately to the right of ClassText
        raceText:SetPoint("LEFT", classText, "RIGHT", 2, 0)

        -- Set font and alignment for ClassText and RaceText in the live tab
        classText:SetFontObject("GameFontHighlightSmall")  -- Example font for live tab
        raceText:SetFontObject("GameFontHighlightSmall")   -- Example font for live tab
        classText:SetJustifyH("RIGHT")
        raceText:SetJustifyH("LEFT")

        whenText:ClearAllPoints()
        whenText:SetPoint("LEFT", raceText, "RIGHT", -10, 0)

        rating:ClearAllPoints()
        rating:SetPoint("LEFT", whenText, "RIGHT", 5, 0)

    end
end
ns.ApplyClipLayout = UpdateLayout

local function UpdateClipEntry(state, i, offset, button, clip, ratings, numBatchClips, totalClips)

    local elements = ns.clipButtonElements[i]          -- кэш
    if not elements then
        return
    end                    -- защита

    --local overrides = state:GetClipOverrides(clip.id)
    --local merged = {}
    --for k, v in pairs(clip) do
    --    merged[k] = v
    --end
    --for k, v in pairs(overrides) do
    --    merged[k] = v
    --end
    --clip = merged

    ResizeEntry(button, numBatchClips, totalClips)

    --------------------------------------------------
    --  ЧТЕНИЕ UI-ЭЛЕМЕНТОВ ЧЕРЕЗ КЭШ
    --------------------------------------------------
    local name = elements.name
    local race = elements.raceText
    local levelFS = elements.level
    local classFS = elements.classText
    local whenFS = elements.whenText
    local whereFS = elements.whereText
    local clipTextFS = elements.clipText
    local mobLevelFS = elements.clipMobLevel
    local iconTexture = elements.itemIconTexture
    local ratingFrame = elements.rating
    local clipFrame = elements.clipFrame
    local clipButton = elements.button
    --------------------------------------------------

    -- ===== NAME =====
    if clip.characterName then
        local clr = RAID_CLASS_COLORS[clip.class] or { r = .85, g = .85, b = .85 }
        name:SetTextColor(clr.r, clr.g, clr.b)
        name:SetText(clip.characterName)
    else
        name:SetTextColor(.85, .85, .85)
        name:SetText(L["Unknown"])
    end

    -- ===== RACE =====
    if GetLocale() == "ruRU" and ns.isCompletedTabActive then
        if clip.race == "Ночноро\nждённый" then
            clip.race = "Ночнорождённый"
        elseif clip.race == "Озар. дреней" then
            clip.race = "Озарённый дреней"
        elseif clip.race == "Дворф Ч. Железа" then
            clip.race = "Дворф Чёрного Железа"
        end
    end
    race:SetText(clip.race or L["Unknown"])
    if clip.faction == "Horde" then
        race:SetTextColor(.8, .3, .3)
    elseif clip.faction == "Alliance" then
        race:SetTextColor(.4, .6, 1)
    else
        race:SetTextColor(.9, .9, .4)
    end

    -- ===== CLASS ICON =====
    if clip.class and CLASS_ICON_TCOORDS[clip.class] then
        iconTexture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        iconTexture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[clip.class]))
    else
        iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        iconTexture:SetTexCoord(0, 1, 0, 1)
    end

    -- ===== LEVEL =====
    local lvl = clip.level or 1
    local q = GetQuestDifficultyColor(lvl)
    levelFS:SetFormattedText("|cff%02x%02x%02x%d|r", q.r * 255, q.g * 255, q.b * 255, lvl)

    -- ===== CLASS TEXT =====
    if clip.class then
        local key = string.upper(clip.class)
        local txt = LOCALIZED_CLASS_NAMES_MALE[key] or clip.class
        if GetLocale() == "ruRU" and not ns.isCompletedTabActive then
            if key == "WARLOCK" then
                txt = "Варлок"
            elseif key == "ROGUE" then
                txt = "Разбойник"
            end
        end
        local cc = RAID_CLASS_COLORS[key] or { r = 1, g = 1, b = 1 }
        classFS:SetTextColor(cc.r, cc.g, cc.b)
        classFS:SetText(txt)
    else
        classFS:SetTextColor(1, 1, 1);
        classFS:SetText(L["Unknown"])
    end

    -- ===== WHEN =====
    whenFS:SetText(formatWhen(clip))
    if clip.playedTime and clip.level then
        local r, g, b = ns.GetPlayedTimeColor(clip.playedTime, clip.level)
        whenFS:SetTextColor(r, g, b, .7)
    else
        whenFS:SetTextColor(.6, .6, .6, .5)
    end

    -- ===== WHERE =====
    whereFS:SetJustifyH("LEFT")
    local zone = clip.mapId and C_Map.GetMapInfo(clip.mapId).name or clip.where
    if zone == "Полуостров Адского Пламени" then
        zone = "Полуостров\nАдского Пламени"
    end
    whereFS:SetText(zone or L["Unknown"])

    -- ===== CAUSE / MOB LEVEL =====
    local causeId = clip.causeCode or 0
    if causeId == 7 and clip.deathCause ~= "" then
        local diff = (clip.mobLevel or 0) - lvl
        local r, g, b = 0, 1, 0
        if diff >= 4 then
            r, g, b = 1, 0, 0
        elseif diff >= 2 then
            r, g, b = 1, .5, 0
        elseif diff >= -1 then
            r, g, b = 1, 1, 0
        elseif diff >= -4 then
            r, g, b = 0, 1, 0
        else
            r, g, b = .5, .5, .5
        end
        clipTextFS:SetText(string.format("|cFF%02X%02X%02X%s|r", r * 255, g * 255, b * 255, clip.deathCause))
        mobLevelFS:SetText(clip.mobLevel);
        mobLevelFS:SetTextColor(r, g, b, 200 / 255)
    else
        clipTextFS:SetText("|cFFFFFFFF" .. (ns.DeathCauseByID[causeId] or "Неизвестно") .. "|r")
        mobLevelFS:SetText("")
    end
    mobLevelFS:SetJustifyH("CENTER")

    -- ===== COMPLETED TIMER =====
    if clip.completed and clip.playedTime then
        clipTextFS:SetFontObject("GameFontNormalLarge")
        local s = clip.playedTime
        clipTextFS:SetFormattedText("%dд %dч %dм %dс",
                math.floor(s / 86400), math.floor(s % 86400 / 3600),
                math.floor(s % 3600 / 60), s % 60)
    elseif clip.completed then
        clipTextFS:SetFontObject("GameFontNormalLarge")
        clipTextFS:SetText("Грузится")
    else
        clipTextFS:SetFontObject("GameFontNormal")
    end

    -- ===== RATING WIDGET =====
    if ratingFrame and ratingFrame.SetReactions then
        if clip.id then
            ratingFrame:SetReactions(ns.GetTopReactions(clip.id, 1))
        else
            ratingFrame.label:SetText("")
        end
    end
    clipButton.clipData = clip     -- актуальные данные в кнопке

    -- ===== ХАЙЛАЙТ =====
    if OFAuctionFrameDeathClips.openedPromptClipID == clip.id then
        button:LockHighlight()
    else
        button:UnlockHighlight()
    end
end

local function FilterHiddenClips(state, clips)
    return clips   -- overrides больше нет → ничего не скрываем
end


-- Updates clip entries based on which tab is active
function OFAuctionFrameDeathClips_Update()
    local frame = OFAuctionFrameDeathClips
    local state = ns.GetDeathClipReviewState()
    local ratingsByClip = state:GetRatingsByClip()

    --------------------------------------------------------------
    --  Build the list that feeds FauxScrollFrame  (Approach A)
    --------------------------------------------------------------
    local rawPool = ns.GetLiveDeathClips()             -- every clip in DB
    local pool = ns.FilterClipsThisRealm(rawPool)   -- realm-filtered once
    local clips = {}                                 -- final list for this tab

    if frame.currentSubTab == "completed" then
        -- Completed tab → keep only completed clips
        for _, clip in ipairs(pool) do
            if clip.completed then
                table.insert(clips, clip)
            end
        end
    else
        -- Live tab → keep non-completed clips
        for _, clip in ipairs(pool) do
            if not clip.completed then
                table.insert(clips, clip)
            end
        end
    end

    clips = ns.SortDeathClips(clips, OFGetCurrentSortParams("clips"))
    clips = FilterHiddenClips(state, clips)

    -- Proceed with pagination and displaying the clips
    local totalClips = #clips
    local page = OFAuctionFrameDeathClips.page or 0
    local offset = FauxScrollFrame_GetOffset(OFDeathClipsScroll)
    local startIdx = offset + 1 + (page * NUM_CLIPS_PER_PAGE)
    local endIdx = startIdx + NUM_CLIPS_TO_DISPLAY - 1
    local numBatchClips = math.min(totalClips - page * NUM_CLIPS_PER_PAGE, NUM_CLIPS_PER_PAGE)
    local isLastSlotEmpty

    updateSortArrows()
    -- Pre-fetch visible clips
    local visibleClips = {}
    for i = startIdx, endIdx do
        visibleClips[i - startIdx + 1] = clips[i]
    end

    -- Update the displayed buttons for each clip
    for i = 1, NUM_CLIPS_TO_DISPLAY do
        local button = _G["OFDeathClipsButton" .. i]
        local clip = visibleClips[i]
        button.clip = clip

        -- 🔥 Add highlight support
        ns.SetupClipHighlight(button)

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
    -- Create single large icon texture
    local icon = self:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 26) -- fill most of the rating column
    icon:SetPoint("LEFT", self, "LEFT", 0, 0)
    icon:Hide()

    -- Общая обрезка
    icon:SetTexCoord(0.1, 0.9, 0.34, 0.74)
    icon:SetVertexColor(0.5, 0.5, 0.5) -- slightly dimmed, full color


    -- Create count text overlaid on icon
    local count = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    count:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    count:SetTextColor(1, 1, 1, 0.6)
    count:SetPoint("TOPLEFT", icon, "BOTTOMRIGHT", -12, 6)
    count:Hide()

    -- Store references
    self.reactionIcon = icon
    self.reactionCount = count

    -- Assign SetReactions function
    function self:SetReactions(data)
        local paths = {
            [1] = "Interface\\AddOns\\GoAgainAH\\Media\\laugh_64x64.tga",
            [2] = "Interface\\AddOns\\GoAgainAH\\Media\\frozen_64x64.tga",
            [3] = "Interface\\AddOns\\GoAgainAH\\Media\\clown_64x64.tga",
            [4] = "Interface\\AddOns\\GoAgainAH\\Media\\fire_64x64.tga",
        }

        if data and data[1] then
            local id = data[1].id

            -- Спецпозиции и обрезки
            if id == 3 then
                -- 🤡 Клоун: немного вверх
                icon:SetTexCoord(0.1, 0.9, 0.30, 0.72)

            elseif id == 4 then
                -- 🔥 Огонь: обрезать до самого верха
                icon:SetTexCoord(0.1, 0.9, 0.12, 0.66)

            else
                -- Остальные по центру
                icon:SetTexCoord(0.1, 0.9, 0.24, 0.78)
            end

            local countValue = data[1].count
            local path = paths[id]

            self.reactionIcon:SetTexture(path)
            self.reactionIcon:Show()

            self.reactionCount:SetText(countValue)
            self.reactionCount:Show()
        else
            self.reactionIcon:Hide()
            self.reactionCount:Hide()
        end
    end
end

function OFAuctionFrameDeathClips_OnHide()
    if OFAuctionFrameDeathClips._whenUpdateTicker then
        OFAuctionFrameDeathClips._whenUpdateTicker:Cancel()
        OFAuctionFrameDeathClips._whenUpdateTicker = nil
    end
end