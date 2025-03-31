local addonName, ns = ...

local function UpdateItemIcon(buttonName, texture, count, canUse)
    local iconTexture = _G[buttonName.."IconTexture"]
    iconTexture:SetTexture(texture)
    if not canUse then
        iconTexture:SetVertexColor(1.0, 0.1, 0.1)
    else
        iconTexture:SetVertexColor(1.0, 1.0, 1.0)
    end

    local itemCount = _G[buttonName.."Count"]
    if count > 1 then
        itemCount:SetText(count)
        itemCount:Show()
    else
        itemCount:Hide()
    end
end

local function CreateItemWidget(parent, name, config)
    local widget = CreateFrame("Button", name, parent, "ItemButtonTemplate")

    local nameLabel = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("LEFT", widget, "RIGHT", 5, 0)
    nameLabel:SetJustifyH("LEFT")

    if config and config.labelWidth then
        nameLabel:SetWidth(config.labelWidth)
    end
    nameLabel:SetWordWrap(false)
    nameLabel:SetNonSpaceWrap(false)

    -- Add tooltip behavior
    widget:SetScript("OnEnter", function(self)
        if ns.IsFakeItem(widget.itemID) and not ns.IsSupportedFakeItem(widget.itemID) then
            local title, description = ns.GetFakeItemTooltip(widget.itemID)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip_SetTitle(GameTooltip, title)
            GameTooltip_AddNormalLine(GameTooltip, description, true)
            GameTooltip:Show()

        elseif widget.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if ns.IsSpellItem(widget.itemID) then
                GameTooltip:SetSpellByID(ns.ItemIDToSpellID(widget.itemID))
            else
                GameTooltip:SetItemByID(widget.itemID)
                GameTooltip_ShowCompareItem()
            end

            if IsModifiedClick("DRESSUP") then
                ShowInspectCursor()
            else
                ResetCursor()
            end
        end
    end)

    widget:SetScript("OnLeave", function(self)
        GameTooltip_Hide()
        ResetCursor()
    end)

    widget:SetScript("OnClick", function(self, button)
        if widget.itemID and ns.IsFakeItem(widget.itemID) then
            return  -- not supported (yet)
        end

        if widget.itemID then
            local _, link = ns.GetItemInfo(widget.itemID)
            if link then
                HandleModifiedItemClick(link)
            end
        end
    end)

    function widget:SetItem(itemID, count)
        self.itemID = itemID

        if not itemID then
            UpdateItemIcon(self:GetName(), nil, 0, true)
            nameLabel:SetText("")
            return
        end

        ns.GetItemInfoAsync(itemID, function(...)
            local name, _, quality, _, _, _, _, _, _, texture = ...
            local renderCount = count or 1
            if itemID == ns.ITEM_ID_GOLD then
                renderCount = 0
            end

            UpdateItemIcon(self:GetName(), texture, renderCount, true)

            nameLabel:SetText(name)
            local color = ITEM_QUALITY_COLORS[quality]
            if color then
                nameLabel:SetVertexColor(color.r, color.g, color.b)
            else
                nameLabel:SetVertexColor(1, 1, 1)
            end
        end, count)
    end

    return widget, nameLabel
end

ns.CreateItemWidget = CreateItemWidget
