local addonName, ns = ...
--[[-----------------------------------------------------------------------------
Frame Container
-------------------------------------------------------------------------------]]
local Type, Version = "CustomFrame", 30
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local pairs, assert, type = pairs, assert, type
local wipe = table.wipe

-- WoW APIs
local PlaySound = PlaySound
local CreateFrame, UIParent = CreateFrame, UIParent

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Button_OnClick(frame)
	PlaySound(799) -- SOUNDKIT.GS_TITLE_OPTION_EXIT
	frame.obj:Hide()
end

local function Frame_OnShow(frame)
	frame.obj:Fire("OnShow")
end

local function Frame_OnClose(frame)
	frame.obj:Fire("OnClose")
end

local function Frame_OnMouseDown(frame)
	AceGUI:ClearFocus()
end

local function Title_OnMouseDown(frame)
	frame:GetParent():StartMoving()
	AceGUI:ClearFocus()
end

local function MoverSizer_OnMouseUp(mover)
	local frame = mover:GetParent()
	frame:StopMovingOrSizing()
	local self = frame.obj
	local status = self.status or self.localstatus
	status.width = frame:GetWidth()
	status.height = frame:GetHeight()
	status.top = frame:GetTop()
	status.left = frame:GetLeft()
end

local function SizerSE_OnMouseDown(frame)
	frame:GetParent():StartSizing("BOTTOMRIGHT")
	AceGUI:ClearFocus()
end

local function SizerS_OnMouseDown(frame)
	frame:GetParent():StartSizing("BOTTOM")
	AceGUI:ClearFocus()
end

local function SizerE_OnMouseDown(frame)
	frame:GetParent():StartSizing("RIGHT")
	AceGUI:ClearFocus()
end

local function StatusBar_OnEnter(frame)
	frame.obj:Fire("OnEnterStatusBar")
end

local function StatusBar_OnLeave(frame)
	frame.obj:Fire("OnLeaveStatusBar")
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.frame:SetParent(UIParent)
		self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
		self.frame:SetFrameLevel(100) -- Lots of room to draw under it
		self:SetTitle()
		self:ApplyStatus()
		self:Show()
        self:EnableResize(true)
	end,

	["OnRelease"] = function(self)
		self.status = nil
		wipe(self.localstatus)
	end,

	["OnWidthSet"] = function(self, width, useCustomPadding)
		local content = self.content
		local contentwidth = useCustomPadding and (width - 34) or width
		if contentwidth < 0 then
			contentwidth = 0
		end
		content:SetWidth(contentwidth)
		content.width = contentwidth
	end,

	["OnHeightSet"] = function(self, height, useCustomPadding)
		local content = self.content
		local contentheight = useCustomPadding and (height - 57) or height
		if contentheight < 0 then
			contentheight = 0
		end
		content:SetHeight(contentheight)
		content.height = contentheight
	end,

	["SetTitle"] = function(self, title)
		self.titletext:SetText(title)
		self.titlebg:SetWidth((self.titletext:GetWidth() or 0) + 10)
	end,

	["Hide"] = function(self)
		self.frame:Hide()
	end,

	["Show"] = function(self)
		self.frame:Show()
	end,

	["EnableResize"] = function(self, state)
		--local func = state and "Show" or "Hide"
		--self.sizer_se[func](self.sizer_se)
		--self.sizer_s[func](self.sizer_s)
		--self.sizer_e[func](self.sizer_e)
	end,

	-- called to set an external table to store status in
	["SetStatusTable"] = function(self, status)
		assert(type(status) == "table")
		self.status = status
		self:ApplyStatus()
	end,

	["ApplyStatus"] = function(self)
		local status = self.status or self.localstatus
		local frame = self.frame
		self:SetWidth(status.width or 700)
		self:SetHeight(status.height or 500)
		frame:ClearAllPoints()

		local anchor = _G["OFAuctionFrame"]
		if anchor and anchor:IsVisible() then
			frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 5, -14)
		elseif status.top and status.left then
			frame:SetPoint("TOP", UIParent, "BOTTOM", 0, status.top)
			frame:SetPoint("LEFT", UIParent, "LEFT", status.left, 0)
		else
			frame:SetPoint("CENTER")
		end
	end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local FrameBackdrop = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	edgeSize = 24,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local PaneBackdrop  = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 5, bottom = 3 }
}

local function Constructor()
    local name = "AceGUI30CustomFrame" .. AceGUI:GetNextWidgetNum(Type)
	local frame = CreateFrame("Frame", name, UIParent)

    _G[name] = frame
    tinsert(UISpecialFrames, name)


    frame:Hide()

	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(100) -- Lots of room to draw under it
	frame:SetBackdrop(FrameBackdrop)
	frame:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

	if frame.SetResizeBounds then -- WoW 10.0
		frame:SetResizeBounds(400, 200)
	else
		frame:SetMinResize(400, 200)
	end
	frame:SetToplevel(true)
	frame:SetScript("OnShow", Frame_OnShow)
	frame:SetScript("OnHide", Frame_OnClose)
	frame:SetScript("OnMouseDown", Frame_OnMouseDown)

	local titlebg = frame:CreateTexture(nil, "OVERLAY")
	titlebg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg:SetTexCoord(0.31, 0.67, 0, 0.63)
	titlebg:SetPoint("TOP", 0, 12)
	titlebg:SetWidth(100)
	titlebg:SetHeight(40)

	local title = CreateFrame("Frame", nil, frame)
	title:EnableMouse(true)
	title:SetScript("OnMouseDown", Title_OnMouseDown)
	title:SetScript("OnMouseUp", MoverSizer_OnMouseUp)
	title:SetAllPoints(titlebg)

	local titletext = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titletext:SetPoint("TOP", titlebg, "TOP", 0, -14)

	local titlebg_l = frame:CreateTexture(nil, "OVERLAY")
	titlebg_l:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg_l:SetTexCoord(0.21, 0.31, 0, 0.63)
	titlebg_l:SetPoint("RIGHT", titlebg, "LEFT")
	titlebg_l:SetWidth(30)
	titlebg_l:SetHeight(40)

	local titlebg_r = frame:CreateTexture(nil, "OVERLAY")
	titlebg_r:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg_r:SetTexCoord(0.67, 0.77, 0, 0.63)
	titlebg_r:SetPoint("LEFT", titlebg, "RIGHT")
	titlebg_r:SetWidth(30)
	titlebg_r:SetHeight(40)

	--local sizer_se = CreateFrame("Frame", nil, frame)
	--sizer_se:SetPoint("BOTTOMRIGHT")
	--sizer_se:SetWidth(25)
	--sizer_se:SetHeight(25)
	--sizer_se:EnableMouse()
	--sizer_se:SetScript("OnMouseDown",SizerSE_OnMouseDown)
	--sizer_se:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

	--local line1 = sizer_se:CreateTexture(nil, "BACKGROUND")
	--line1:SetWidth(14)
	--line1:SetHeight(14)
	--line1:SetPoint("BOTTOMRIGHT", -8, 8)
	--line1:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	--local x = 0.1 * 14/17
	--line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)
    --
	--local line2 = sizer_se:CreateTexture(nil, "BACKGROUND")
	--line2:SetWidth(8)
	--line2:SetHeight(8)
	--line2:SetPoint("BOTTOMRIGHT", -8, 8)
	--line2:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	--x = 0.1 * 8/17
	--line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

	--local sizer_s = CreateFrame("Frame", nil, frame)
	--sizer_s:SetPoint("BOTTOMRIGHT", -25, 0)
	--sizer_s:SetPoint("BOTTOMLEFT")
	--sizer_s:SetHeight(25)
	--sizer_s:EnableMouse(true)
	--sizer_s:SetScript("OnMouseDown", SizerS_OnMouseDown)
	--sizer_s:SetScript("OnMouseUp", MoverSizer_OnMouseUp)
    --
	--local sizer_e = CreateFrame("Frame", nil, frame)
	--sizer_e:SetPoint("BOTTOMRIGHT", 0, 25)
	--sizer_e:SetPoint("TOPRIGHT")
	--sizer_e:SetWidth(25)
	--sizer_e:EnableMouse(true)
	--sizer_e:SetScript("OnMouseDown", SizerE_OnMouseDown)
	--sizer_e:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

	--Container Support
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 17, -27)
	content:SetPoint("BOTTOMRIGHT", -17, 40)

	function ns.CustomFrameSetAllPoints()
		content:SetAllPoints(frame)
	end
	function ns.CustomFrameHideBackDrop()
		frame:SetBackdrop(nil)
	end

	local widget = {
		localstatus = {},
        title = title,
		titletext   = titletext,
		titlebg     = titlebg,
		titlebg_l     = titlebg_l,
		titlebg_r     = titlebg_r,
		--sizer_se    = sizer_se,
		--sizer_s     = sizer_s,
		--sizer_e     = sizer_e,
		content     = content,
		frame       = frame,
		type        = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsContainer(widget)
end

do
	local AceGUI = LibStub("AceGUI-3.0")
	local function Constructor()
		local num   = AceGUI:GetNextWidgetNum("PKBTRedButton")
		local frame = CreateFrame("Button",
				"AceGUI30PKBTRedButton"..num,
				UIParent,
				"PKBT_RedButtonTemplate"
		)
		local widget = {
			frame    = frame,
			type     = "PKBTRedButton",
			OnAcquire = function(self)
				frame:Show()
				frame:SetScript("OnClick", nil)
				frame:SetEnabled(true)
			end
		}
		-- mix in the standard widget API
		AceGUI:RegisterAsWidget(widget)
		-- text handling
		function widget:SetText(text) frame:SetText(text) end
		function widget:SetDisabled(disabled)
			if disabled then frame:Disable() else frame:Enable() end
		end
		function widget:SetCallback(_, callback)
			frame:SetScript("OnClick", function() callback(self) end)
		end
		return widget
	end
	AceGUI:RegisterWidgetType("PKBTRedButton", Constructor, 1)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
