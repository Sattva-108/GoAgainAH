local _, ns = ...

ns.GetPlayerLevel = function()
    return UnitLevel("player")
    -- return 33
end

local function IsLookingForDungeon(scroll, dungeon)
    local entry = ns.LfgAPI:GetMyEntry()
    if not entry or not entry.dungeons then
        return false
    end
    if not dungeon then
        ns.DebugLog("unexpected missing dungeon", dungeon)
        return false
    end

    for _, dungeonIndex in ipairs(entry.dungeons) do
        if dungeonIndex == dungeon.index then
            return true
        end
    end
    return false
end

local function SetLookingForDungeon(scroll, dungeon, enabled)
    -- Initialize dungeons table
    scroll.dungeons = scroll.dungeons or {}

    if enabled then
        scroll.dungeons[dungeon.name] = dungeon
    else
        scroll.dungeons[dungeon.name] = nil
    end
end

ns.SetLookingForAllDungeons = function(scroll, enabled)
    local playerLevel = ns.GetPlayerLevel()
    for _, dungeon in pairs(ns.DUNGEON_LIST) do
        if dungeon.category and playerLevel >= dungeon.requiredLevel and playerLevel <= dungeon.maximumLevel then
            SetLookingForDungeon(scroll, dungeon, enabled)
        end
    end
end

ns.CreateDungeonScrollList = function(parent)
    -- Create the dungeonInset frame
    local dungeonInset = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    dungeonInset:SetPoint("TOPLEFT", parent, "BOTTOMRIGHT", 0, 0)
    dungeonInset:SetSize(350, 415)

    -- Set higher frame strata and level to render above other UI elements
    dungeonInset:SetFrameStrata("DIALOG")
    dungeonInset:SetFrameLevel(100)

    -- Add close button in top-right corner
    local closeButton = CreateFrame("Button", nil, dungeonInset, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", dungeonInset, "TOPRIGHT", -16, 4)
    closeButton:SetScript("OnClick", function()
        dungeonInset:Hide()
    end)

    -- Create four blocker frames around the dungeonInset
    local blockers = {}
    -- Left blocker
    blockers.left = CreateFrame("Frame", nil, dungeonInset)
    blockers.left:SetFrameStrata("DIALOG")
    blockers.left:SetFrameLevel(99)
    blockers.left:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    blockers.left:SetPoint("BOTTOMRIGHT", dungeonInset, "BOTTOMLEFT")
    blockers.left:EnableMouse(true)
    blockers.left:SetScript("OnMouseDown", function() dungeonInset:Hide() end)

    -- Right blocker
    blockers.right = CreateFrame("Frame", nil, dungeonInset)
    blockers.right:SetFrameStrata("DIALOG")
    blockers.right:SetFrameLevel(99)
    blockers.right:SetPoint("TOPLEFT", dungeonInset, "TOPRIGHT")
    blockers.right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    blockers.right:EnableMouse(true)
    blockers.right:SetScript("OnMouseDown", function() dungeonInset:Hide() end)

    -- Top blocker
    blockers.top = CreateFrame("Frame", nil, dungeonInset)
    blockers.top:SetFrameStrata("DIALOG")
    blockers.top:SetFrameLevel(99)
    blockers.top:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    blockers.top:SetPoint("BOTTOMRIGHT", dungeonInset, "TOPRIGHT")
    blockers.top:EnableMouse(true)
    blockers.top:SetScript("OnMouseDown", function() dungeonInset:Hide() end)

    -- Bottom blocker
    blockers.bottom = CreateFrame("Frame", nil, dungeonInset)
    blockers.bottom:SetFrameStrata("DIALOG")
    blockers.bottom:SetFrameLevel(99)
    blockers.bottom:SetPoint("TOPLEFT", dungeonInset, "BOTTOMLEFT")
    blockers.bottom:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
    blockers.bottom:EnableMouse(true)
    blockers.bottom:SetScript("OnMouseDown", function() dungeonInset:Hide() end)

    dungeonInset.blockers = blockers

    -- Hook the show/hide functions to manage the blockers
    dungeonInset:HookScript("OnShow", function()
        for _, blocker in pairs(blockers) do
            blocker:Show()
        end
    end)
    dungeonInset:HookScript("OnHide", function()
        for _, blocker in pairs(blockers) do
            blocker:Hide()
        end
    end)


    local categoryFilters = {}
    local dungeonScrollList = ns.ScrollList.new("DungeonFinderDungeonScrollList", dungeonInset, 24,
        "LfgDungeonSpecificChoiceTemplate")
    -- Ensure the scroll list also has high strata/level
    dungeonScrollList:SetPoint("TOPLEFT", dungeonInset, "TOPLEFT", 0, -6)
    dungeonScrollList:SetPoint("BOTTOMRIGHT", dungeonInset, "BOTTOMRIGHT", -26, 6)
    dungeonScrollList:SetWidth(300)
    dungeonScrollList:SetButtonHeight(16)
    dungeonScrollList:SetContentProvider(function() return ns.DUNGEON_LIST end)
    dungeonScrollList:SetLabelProvider(function(index, dungeon, button)
        local playerLevel = ns.GetPlayerLevel()

        button.dungeon = dungeon
        button.instanceName:SetText(dungeon.name)
        if dungeon.category then
            -- a dungeon or raid
            button.expandOrCollapseButton:Hide()
            button.isCollapsed = false

            -- check the required level of the player
            if (playerLevel < dungeon.requiredLevel) then
                button.lockedIndicator:Show()
                button.enableButton:Disable()
                button.enableButton:Hide()
            else
                button.lockedIndicator:Hide()
                button.enableButton:Enable()
                button.enableButton:Show()
            end

            -- set checked status
            button.enableButton:SetChecked(IsLookingForDungeon(dungeonScrollList, dungeon))
            button.enableButton:SetScript("OnClick", function()
                if dungeon.category then
                    SetLookingForDungeon(dungeonScrollList, dungeon, button.enableButton:GetChecked())

                    -- auto apply
                    OFLFG_CheckButton:SetChecked(true)
                    OFLFG_Apply(dungeonScrollList.dungeons)
                end
                dungeonScrollList:Update()
            end)

            -- the level range
            button.level:Show()
            local levelText
            if (dungeon.minimumLevel == dungeon.maximumLevel) then
                levelText = tostring(dungeon.minimumLevel)
            else
                levelText = dungeon.minimumLevel .. " - " .. dungeon.maximumLevel
            end
            button.level:SetText("(" .. levelText .. ")")

            -- the color for the level range
            local levelCompare
            if (playerLevel < dungeon.minimumLevel) then
                levelCompare = dungeon.minimumLevel
            elseif (playerLevel > dungeon.maximumLevel) then
                levelCompare = dungeon.maximumLevel
            else
                levelCompare = playerLevel
            end

            local difficultyColor = GetQuestDifficultyColor(levelCompare)
            button.level:SetFontObject(difficultyColor.font)
            button.instanceName:SetFontObject(difficultyColor.font)
        else
            local category = dungeon.name
            -- returns 0 for no dungeons, 1 for at least 1 dungeon, 2 for all dungeons
            local function dungeonsSelected()
                local oneDungeonSelected = false
                local allDungeonsSelected = true
                for i, d in pairs(ns.DUNGEON_LIST) do
                    if (d.category and d.category == category and playerLevel >= d.requiredLevel) then
                        if IsLookingForDungeon(dungeonScrollList, d) then
                            oneDungeonSelected = true
                        else
                            allDungeonsSelected = false
                        end
                    end
                end
                if (allDungeonsSelected and oneDungeonSelected) then
                    return 2
                elseif (oneDungeonSelected) then
                    return 1
                else
                    return 0
                end
            end

            -- simply a category
            button.instanceName:SetFontObject("GameFontHighlightLeft");
            button.level:Hide()
            button.lockedIndicator:Hide()

            button.expandOrCollapseButton:Hide()

            -- enable select/deselect all
            button.enableButton:Enable()
            button.enableButton:Show()
            button.enableButton:SetScript("OnClick", function()
                if dungeonsSelected() > 0 then
                    -- Clear all dungeons in this category
                    for i, d in pairs(ns.DUNGEON_LIST) do
                        if d.category and d.category == category then
                            SetLookingForDungeon(dungeonScrollList, d, false)
                        end
                    end
                else
                    OFLFG_CheckButton:SetChecked(true)
                    -- Select all available dungeons in this category
                    for i, d in pairs(ns.DUNGEON_LIST) do
                        if d.category and d.category == category and playerLevel >= d.requiredLevel and playerLevel <= d.maximumLevel then
                            SetLookingForDungeon(dungeonScrollList, d, true)
                        end
                    end
                end
                -- auto apply
                OFLFG_Apply(dungeonScrollList.dungeons)

                dungeonScrollList:Update()
            end)
            local selection = dungeonsSelected()
            if (selection == 2) then
                button.enableButton:SetChecked(true)
                button.enableButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
                button.enableButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
            elseif (selection == 1) then
                button.enableButton:SetChecked(true)
                button.enableButton:SetCheckedTexture("Interface\\Buttons\\UI-MultiCheck-Up");
                button.enableButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-MultiCheck-Disabled");
            else
                button.enableButton:SetChecked(false)
                button.enableButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");
                button.enableButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
            end
        end
        -- show heroic icon if the dungeon's minimum level is higher than the player level
        if (dungeon.category and playerLevel < dungeon.minimumLevel and playerLevel >= dungeon.requiredLevel) then
            button.heroicIcon:Show()
        else
            button.heroicIcon:Hide()
        end
    end)
    dungeonScrollList:SetFilter(function(index, dungeon)
        if (not dungeon.category or not categoryFilters[dungeon.category]) then
            return true
        end
    end)
    dungeonScrollList:Update()

    -- Store the dungeonInset reference on the scroll list for easier access
    dungeonScrollList.dungeonInset = dungeonInset
    dungeonScrollList.dungeonInset:Hide()

    dungeonScrollList.IsShown = function()
        dungeonScrollList.dungeonInset:IsShown()
    end
    dungeonScrollList.Hide = function()
        dungeonScrollList.dungeonInset:Hide()
    end
    dungeonScrollList.Show = function()
        dungeonScrollList.dungeonInset:Show()
    end

    return dungeonScrollList
end
