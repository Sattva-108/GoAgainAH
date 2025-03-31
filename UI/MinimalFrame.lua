--[[-----------------------------------------------------------------------------
Frame Container
-------------------------------------------------------------------------------]]
local Type, Version = "MinimalFrame", 30
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Core frame methods
local methods = {
	["OnAcquire"] = function(self)
		self.frame:SetParent(UIParent)
		self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
		self:ApplyStatus()
		self:Show()
	end,

	["OnRelease"] = function(self)
		self.status = nil
		table.wipe(self.localstatus)
	end,

	["Hide"] = function(self)
		self.frame:Hide()
	end,

	["Show"] = function(self)
		self.frame:Show()
	end,

	["ApplyStatus"] = function(self)
		local status = self.status or self.localstatus
		local frame = self.frame
		self:SetWidth(status.width or 700)
		self:SetHeight(status.height or 500)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER")
	end,

	["SetPadding"] = function(self, xpad, ypad)
		local content = self.content
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", xpad or 0, -(ypad or 0))
		content:SetPoint("BOTTOMRIGHT", -(xpad or 0), ypad or 0)
	end
}

-- Constructor
local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	-- Content frame
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 0, 0)
	content:SetPoint("BOTTOMRIGHT", 0, 0)

	local widget = {
		localstatus = {},
		content     = content,
		frame       = frame,
		type        = Type
	}
	
	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
