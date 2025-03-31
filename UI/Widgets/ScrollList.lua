-- namespace
local _, ns = ...;

ns.ScrollList = {
    -- class fields
    buttons,
    frame,
    numToDisplay,
    buttonHeight = 25,
    labelProvider = function(k, v) return tostring(v) end,
    contentProvider = function() return {} end,
    filter = function() return true end,
    buttonScript,
    offset = 0
}
local ScrollList = ns.ScrollList
ScrollList.__index = ScrollList

local function size(self, items)
    local count = 0
    for key, value in pairs(items) do
        if (self.filter(key, value) == true) then
            count = count + 1
        end
    end
    return count
end

local function updateScrollFrame(self)
    local scrollFrame = self.frame
    local items = self.contentProvider()
    local itemCount = size(self, items)
    local numToDisplay = self.numToDisplay
    FauxScrollFrame_Update(scrollFrame, itemCount, numToDisplay, self.buttonHeight, nil, nil, nil, nil, nil, nil, true)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    local line = 0
    for key, value in pairs(items) do
        if (self.filter(key, value) == true) then
            local lineminusoffset = line - offset
            if (lineminusoffset >= numToDisplay) then break end
            if (line >= offset and lineminusoffset <= numToDisplay) then
                local button = self.buttons[lineminusoffset + 1]
                if (button) then
                    local text, disabled = self.labelProvider(key, value, button)
                    button:SetText(tostring(text or ""))
                    if (disabled) then
                        button:SetNormalFontObject("GameFontDisableLeft")
                    else
                        button:SetNormalFontObject("GameFontHighlightLeft")
                    end
                    button:Show()
                    button.item = { key = key, value = value }
                    -- notify that the button got visible
                    local script = self.buttonScript["OnUpdate"]
                    if (script) then script(button.index, button, key, value) end
                end
            else
                if (lineminusoffset >= 0 and lineminusoffset < numToDisplay) then
                    local button = self.buttons[lineminusoffset + 1]
                    if (button) then
                        button:Hide()
                        button.item = nil
                    end
                end
            end
            line = line + 1
        end
    end

    -- hide unused items
    while (line < numToDisplay) do
        local button = self.buttons[line + 1]
        if (button) then
            button:Hide()
            button.item = nil
        end
        line = line + 1;
    end
end

function ScrollList.new(globalName, parentFrame, numToDisplay, buttonTemplate)
    local self = setmetatable({}, ScrollList)
    local list = self
    self.numToDisplay = numToDisplay
    self.buttonScript = {}

    -- create the scroll frame
    local frame = CreateFrame("ScrollFrame", globalName, parentFrame, "FauxScrollFrameTemplate")
    frame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, list.buttonHeight, function() updateScrollFrame(list) end)
    end)
    frame:SetScript("OnShow", function() updateScrollFrame(list) end)

    frame.list = self
    self.frame = frame

    -- create the buttons within the frame
    local buttons = {}
    for buttonIndex = 1, numToDisplay do
        local button = CreateFrame("Button", nil, frame, buttonTemplate)
        button:SetNormalFontObject("GameFontHighlightLeft")
        button:SetHighlightFontObject("GameFontNormal")

        -- register events
        local events = { "OnClick", "OnEnter", "OnLeave" }
        for _, event in pairs(events) do
            button:SetScript(event, function(self, mouseButton)
                local item = button.item
                if (item) then
                    local script = list.buttonScript[event]
                    if (script) then script(buttonIndex, button, item.key, item.value) end
                end
            end)
        end
        button.index = buttonIndex
        buttons[buttonIndex] = button
    end
    self.buttons = buttons

    return self
end

function ScrollList.SetPoint(self, point, relativeFrame, relativePoint, ofsx, ofsy)
    self.frame:SetPoint(point, relativeFrame, relativePoint, ofsx, ofsy)
end

function ScrollList.SetSize(self, width, height)
    self:SetWidth(width)
    self:SetHeight(height)
end

function ScrollList.SetWidth(self, width)
    self.frame:SetWidth(width)
    for i, button in pairs(self.buttons) do
        button:SetWidth(width)
    end
end

function ScrollList.SetHeight(self, height)
    self.frame:SetHeight(height)
end

function ScrollList.SetButtonHeight(self, buttonHeight)
    self.buttonHeight = buttonHeight
    local relativeFrame = self.frame
    local relativePoint = "TOPLEFT"
    local ofsx = 6
    local ofsy = -6
    for i, button in pairs(self.buttons) do
        button:SetHeight(buttonHeight)
        button:SetPoint("TOPLEFT", relativeFrame, relativePoint, ofsx, ofsy)
        relativeFrame = button
        relativePoint = "BOTTOMLEFT"
        ofsx = 0
        ofsy = 0
    end
end

function ScrollList.SetLabelProvider(self, f)
    if f then self.labelProvider = f end
end

function ScrollList.SetButtonScript(self, eventType, f)
    if f and eventType then
        self.buttonScript[eventType] = f
    end
end

function ScrollList:SetContentProvider(f)
    if f then self.contentProvider = f end
end

function ScrollList.SetFilter(self, f)
    if f then self.filter = f end
end

function ScrollList.GetFrame(self)
    return self.frame
end

function ScrollList.Update(self)
    updateScrollFrame(self)
end
