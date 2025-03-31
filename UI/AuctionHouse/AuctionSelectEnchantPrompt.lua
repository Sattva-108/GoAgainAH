local _, ns = ...
local AceGUI = LibStub("AceGUI-3.0")

local function CreateSpellScroll()
    -- Create the main frame
    local frame = AceGUI:Create("CustomFrame")
    frame:SetTitle("Select Enchant")
    frame:SetLayout("Flow")
    frame:SetWidth(400)
    frame:SetHeight(450)

	frame.content:SetPoint("BOTTOMRIGHT", -17, 20)
    local closeButton = CreateFrame("Button", "ExitButton", frame.frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame.frame, "TOPRIGHT", 7,7)
    closeButton:SetScript("OnClick", function()
        frame.frame:Hide()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
    end)

    -- Create the search box
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("Search:")
    searchBox:SetWidth(300)
    searchBox:DisableButton(true)
    frame:AddChild(searchBox)

    -- Create a scrollable container
    local padding = AceGUI:Create("MinimalFrame")
    padding:SetFullWidth(true)
    padding:SetHeight(10)

    frame:AddChild(padding)

    -- Create a scrollable container
    local scroll = AceGUI:Create("ScrollFrame")
    -- "Fill", "Flow", or "List" can be used as needed. "List" is usually convenient
    -- for a straightforward vertical layout.
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)

    -- Add the scroll to the frame
    frame:AddChild(scroll)

    ----------------------------------------------------------------------------
    -- Function: Update the scroll list based on a filter
    ----------------------------------------------------------------------------
    local function UpdateSpellList(filter)
        scroll:ReleaseChildren()  -- Clear out old rows

        -- Convert filter to lowercase for case-insensitive matching
        local searchTerm = filter:lower()
        searchTerm = searchTerm and searchTerm:gsub("([^%w])", "%%%1")

        -- First pass to count matches
        local matches = {}
        for itemID, name in pairs(ns.ENCHANT_ITEMS) do
            if searchTerm == "" or name:lower():find(searchTerm, 1, true) then
                table.insert(matches, {itemID = itemID, name = name})
            end
        end

        local totalMatches = #matches
        local displayCount = math.min(50, totalMatches)

        -- Show total entries message if we're limiting results
        if totalMatches > 50 then
            local countLabel = AceGUI:Create("Label")
            countLabel:SetText(string.format("Displaying 50 out of %d entries", totalMatches))
            countLabel:SetFullWidth(true)
            scroll:AddChild(countLabel)
        end

        -- Display up to 50 items
        for i = 1, displayCount do
            local itemID = matches[i].itemID
            local name = matches[i].name
            local spellID = ns.ItemIDToSpellID(itemID)

            -- Create a horizontal group (row) for this spell
            local row = AceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")

            -- Spell icon
            local icon = AceGUI:Create("Icon")
            icon:SetImage(GetSpellTexture(spellID) or "Interface\\ICONS\\INV_Misc_QuestionMark")
            icon:SetImageSize(32, 32)
            icon:SetWidth(40)  -- Enough room for the icon

            -- Setup tooltip on hover
            icon:SetCallback("OnEnter", function(widget)
                GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end)
            icon:SetCallback("OnLeave", function()
                GameTooltip:Hide()
            end)

            row:AddChild(icon)

            -- Spell name label
            local spellLabel = AceGUI:Create("Label")
            spellLabel:SetText(name)
            spellLabel:SetWidth(220) -- Adjust to fit your layout
            row:AddChild(spellLabel)

            -- "Select" button
            local selectButton = AceGUI:Create("Button")
            selectButton:SetText("Select")
            selectButton:SetWidth(80)
            selectButton:SetCallback("OnClick", function()
                OFSelectEnchantForAuction(itemID)
                frame:Hide()
            end)

            row:AddChild(selectButton)

            -- Finally, add the row to the scroll container
            scroll:AddChild(row)
        end
    end

    ----------------------------------------------------------------------------
    -- Event: OnTextChanged for the search box
    ----------------------------------------------------------------------------
    searchBox:SetCallback("OnTextChanged", function(widget, event, text)
        UpdateSpellList(text)
    end)

    -- Initialize with an empty filter (shows all)
    UpdateSpellList("")
    return frame
end


local auctionSelectEnchantPrompt
ns.ShowAuctionSelectEnchantPrompt = function()
    if not auctionSelectEnchantPrompt then
        auctionSelectEnchantPrompt = CreateSpellScroll()
    end
    auctionSelectEnchantPrompt:Show()
end

ns.HideAuctionSelectEnchantPrompt = function()
    if auctionSelectEnchantPrompt then
        auctionSelectEnchantPrompt:Hide()
    end
end

