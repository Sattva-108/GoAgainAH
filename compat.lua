local addonName, ns = ...

---------------------------------------------------------------------------
-- C_Timer polyfill (backported from WoD 6.0, not in standard 3.3.5)
---------------------------------------------------------------------------
if not C_Timer then
    C_Timer = {}

    local tickers = {}
    local tickerID = 0

    function C_Timer:After(delay, callback)
        local frame = CreateFrame("Frame")
        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                callback()
            end
        end)
        return frame
    end

    function C_Timer:NewTicker(interval, callback, iterations)
        iterations = iterations or 0 -- 0 = infinite
        tickerID = tickerID + 1
        local id = tickerID
        local remaining = iterations
        local elapsed = 0

        local ticker = {
            _cancelled = false,
            Cancel = function(self)
                self._cancelled = true
                tickers[id] = nil
            end,
        }
        tickers[id] = ticker

        local frame = CreateFrame("Frame")
        ticker._frame = frame

        frame:SetScript("OnUpdate", function(_, dt)
            if ticker._cancelled then
                frame:SetScript("OnUpdate", nil)
                return
            end
            elapsed = elapsed + dt
            if elapsed >= interval then
                elapsed = elapsed - interval
                callback(ticker)
                if ticker._cancelled then
                    frame:SetScript("OnUpdate", nil)
                    return
                end
                if iterations > 0 then
                    remaining = remaining - 1
                    if remaining <= 0 then
                        frame:SetScript("OnUpdate", nil)
                        tickers[id] = nil
                    end
                end
            end
        end)

        return ticker
    end
end

---------------------------------------------------------------------------
-- GameTooltip_SetTitle (retail helper, not in 3.3.5)
---------------------------------------------------------------------------
if not GameTooltip_SetTitle then
    function GameTooltip_SetTitle(tooltip, title, manualOrder)
        if not tooltip or not title then return end
        tooltip:AddLine(title, 1, 1, 1)
    end
end

---------------------------------------------------------------------------
-- CreateColor (retail helper, not in 3.3.5)
---------------------------------------------------------------------------
if not CreateColor then
    function CreateColor(r, g, b, a)
        local color = CreateFrame("Frame")
        color.r = r or 1
        color.g = g or 1
        color.b = b or 1
        color.a = a or 1
        color.colorStr = ("ff%02x%02x%02x"):format(
            math.floor(color.r * 255),
            math.floor(color.g * 255),
            math.floor(color.b * 255)
        )
        return color
    end
end

---------------------------------------------------------------------------
-- CreateFromMixins / Mixin (retail helpers, not in 3.3.5)
---------------------------------------------------------------------------
if not CreateFromMixins then
    function CreateFromMixins(...)
        local result = {}
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            if mixin then
                for k, v in pairs(mixin) do
                    result[k] = v
                end
            end
        end
        return result
    end
end

if not Mixin then
    function Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            if mixin then
                for k, v in pairs(mixin) do
                    object[k] = v
                end
            end
        end
        return object
    end
end

---------------------------------------------------------------------------
-- Enum polyfill (retail namespace, not in standard 3.3.5)
-- Values match Sirus client Constants.lua exactly
---------------------------------------------------------------------------
if not Enum then
    Enum = {
        ItemQuality = {
            Poor = 0,
            Common = 1,
            Uncommon = 2,
            Rare = 3,
            Epic = 4,
            Legendary = 5,
            Artifact = 6,
            Heirloom = 7,
        },
        InventoryType = {
            IndexNonEquipType = 0,
            IndexHeadType = 1,
            IndexNeckType = 2,
            IndexShoulderType = 3,
            IndexBodyType = 4,
            IndexChestType = 5,
            IndexWaistType = 6,
            IndexLegsType = 7,
            IndexFeetType = 8,
            IndexWristType = 9,
            IndexHandType = 10,
            IndexFingerType = 11,
            IndexTrinketType = 12,
            IndexWeaponType = 13,
            IndexShieldType = 14,
            IndexRangedType = 15,
            IndexCloakType = 16,
            Index2HweaponType = 17,
            IndexBagType = 18,
            IndexTabardType = 19,
            IndexRobeType = 20,
            IndexWeaponmainhandType = 21,
            IndexWeaponoffhandType = 22,
            IndexHoldableType = 23,
            IndexAmmoType = 24,
            IndexThrownType = 25,
            IndexRangedrightType = 26,
            IndexQuiverType = 27,
            IndexRelicType = 28,
        },
        PlayerInteractionType = {
            MailInfo = 20,
        },
        Hardcore = {
            Status = {
                None = 0,
                Failed = 1,
                Completed = 2,
            },
        },
    }
end

---------------------------------------------------------------------------
-- LE_ITEM_* constants (match Sirus Constants.lua exactly)
---------------------------------------------------------------------------
LE_ITEM_CLASS_CONSUMABLE   = LE_ITEM_CLASS_CONSUMABLE   or 0
LE_ITEM_CLASS_CONTAINER    = LE_ITEM_CLASS_CONTAINER    or 1
LE_ITEM_CLASS_WEAPON       = LE_ITEM_CLASS_WEAPON       or 2
LE_ITEM_CLASS_GEM          = LE_ITEM_CLASS_GEM          or 3
LE_ITEM_CLASS_ARMOR        = LE_ITEM_CLASS_ARMOR        or 4
LE_ITEM_CLASS_AMMO         = LE_ITEM_CLASS_AMMO         or 6
LE_ITEM_CLASS_TRADEGOODS   = LE_ITEM_CLASS_TRADEGOODS   or 7
LE_ITEM_CLASS_RECIPE       = LE_ITEM_CLASS_RECIPE       or 9
LE_ITEM_CLASS_QUIVER       = LE_ITEM_CLASS_QUIVER       or 11
LE_ITEM_CLASS_QUESTITEM    = LE_ITEM_CLASS_QUESTITEM    or 12
LE_ITEM_CLASS_MISCELLANEOUS = LE_ITEM_CLASS_MISCELLANEOUS or 15
LE_ITEM_CLASS_GLYPH        = LE_ITEM_CLASS_GLYPH        or 16

LE_ITEM_ARMOR_GENERIC      = LE_ITEM_ARMOR_GENERIC      or 0
LE_ITEM_ARMOR_CLOTH        = LE_ITEM_ARMOR_CLOTH        or 1
LE_ITEM_ARMOR_LEATHER      = LE_ITEM_ARMOR_LEATHER      or 2
LE_ITEM_ARMOR_MAIL         = LE_ITEM_ARMOR_MAIL         or 3
LE_ITEM_ARMOR_PLATE        = LE_ITEM_ARMOR_PLATE        or 4
LE_ITEM_ARMOR_COSMETIC     = LE_ITEM_ARMOR_COSMETIC     or 5
LE_ITEM_ARMOR_SHIELD       = LE_ITEM_ARMOR_SHIELD       or 6
LE_ITEM_ARMOR_LIBRAM       = LE_ITEM_ARMOR_LIBRAM       or 7
LE_ITEM_ARMOR_IDOL         = LE_ITEM_ARMOR_IDOL         or 8
LE_ITEM_ARMOR_TOTEM        = LE_ITEM_ARMOR_TOTEM        or 9
LE_ITEM_ARMOR_SIGIL        = LE_ITEM_ARMOR_SIGIL        or 10

LE_ITEM_MISCELLANEOUS_JUNK      = LE_ITEM_MISCELLANEOUS_JUNK      or 0
LE_ITEM_MISCELLANEOUS_REAGENT   = LE_ITEM_MISCELLANEOUS_REAGENT   or 1
LE_ITEM_MISCELLANEOUS_PET       = LE_ITEM_MISCELLANEOUS_PET       or 2
LE_ITEM_MISCELLANEOUS_HOLIDAY   = LE_ITEM_MISCELLANEOUS_HOLIDAY   or 3
LE_ITEM_MISCELLANEOUS_OTHER     = LE_ITEM_MISCELLANEOUS_OTHER     or 4
LE_ITEM_MISCELLANEOUS_MOUNT     = LE_ITEM_MISCELLANEOUS_MOUNT     or 5

LE_ITEM_RECIPE_BOOK = LE_ITEM_RECIPE_BOOK or 0

---------------------------------------------------------------------------
-- GetItemClassInfo / GetItemSubClassInfo (Sirus Constants, not in 3.3.5)
---------------------------------------------------------------------------
if not GetItemClassInfo then
    function GetItemClassInfo(classID)
        if tonumber(classID) then
            return _G[string.format("ITEM_CLASS_%d", classID)]
                or string.format("Class %d", classID)
        end
    end
end

if not GetItemSubClassInfo then
    function GetItemSubClassInfo(classID, subClassID)
        if tonumber(classID) and tonumber(subClassID) then
            return _G[string.format("ITEM_SUB_CLASS_%d_%d", classID, subClassID)]
                or string.format("Sub %d/%d", classID, subClassID)
        end
    end
end

---------------------------------------------------------------------------
-- GetItemInventorySlotInfo (Sirus Constants, not in 3.3.5)
---------------------------------------------------------------------------
if not GetItemInventorySlotInfo then
    local inventorySlots = {
        [1]  = INVTYPE_HEAD,
        [2]  = INVTYPE_NECK,
        [3]  = INVTYPE_SHOULDER,
        [4]  = INVTYPE_BODY,
        [5]  = INVTYPE_CHEST,
        [6]  = INVTYPE_WAIST,
        [7]  = INVTYPE_LEGS,
        [8]  = INVTYPE_FEET,
        [9]  = INVTYPE_WRIST,
        [10] = INVTYPE_HAND,
        [11] = INVTYPE_FINGER,
        [12] = INVTYPE_TRINKET,
        [13] = INVTYPE_WEAPON,
        [14] = INVTYPE_WEAPONOFFHAND,
        [15] = INVTYPE_RANGED,
        [16] = INVTYPE_CLOAK,
        [17] = INVTYPE_2HWEAPON,
        [18] = INVTYPE_BAG,
        [19] = INVTYPE_TABARD,
        [20] = INVTYPE_ROBE,
        [21] = INVTYPE_WEAPONMAINHAND,
        [22] = INVTYPE_SHIELD,
        [23] = INVTYPE_HOLDABLE,
        [24] = INVTYPE_AMMO,
        [25] = INVTYPE_THROWN,
        [26] = INVTYPE_RANGEDRIGHT,
        [27] = INVTYPE_QUIVER,
        [28] = INVTYPE_RELIC,
    }
    function GetItemInventorySlotInfo(inventoryType)
        if tonumber(inventoryType) then
            return inventorySlots[inventoryType]
        end
    end
end

---------------------------------------------------------------------------
-- MoneyFrame polyfills (not in some 3.3.5 clients)
---------------------------------------------------------------------------
if not MoneyFrame_SetMaxDisplayWidth then
    function MoneyFrame_SetMaxDisplayWidth() end
end

---------------------------------------------------------------------------
-- C_AuctionHouse stub (retail namespace, not in 3.3.5)
---------------------------------------------------------------------------
if not C_AuctionHouse then
    C_AuctionHouse = {}
    function C_AuctionHouse.GetAuctionItemSubClasses()
        return {}
    end
end

---------------------------------------------------------------------------
-- SetNormalAtlas / SetHighlightAtlas / SetPushedAtlas polyfills
-- Retail texture atlas API, not in 3.3.5
---------------------------------------------------------------------------
do
    local function AtlasNoop() end

    local function PatchMT(mt)
        if not mt then return end
        local idx = mt.__index
        -- WoW widget metatables use a function __index; wrap it
        if type(idx) == "function" then
            local realIndex = idx
            mt.__index = function(self, key)
                if key == "SetNormalAtlas" or key == "SetHighlightAtlas"
                    or key == "SetPushedAtlas" or key == "SetDisabledAtlas"
                    or key == "SetAtlas" then
                    return AtlasNoop
                end
                return realIndex(self, key)
            end
        elseif type(idx) == "table" then
            idx.SetNormalAtlas = idx.SetNormalAtlas or AtlasNoop
            idx.SetHighlightAtlas = idx.SetHighlightAtlas or AtlasNoop
            idx.SetPushedAtlas = idx.SetPushedAtlas or AtlasNoop
            idx.SetDisabledAtlas = idx.SetDisabledAtlas or AtlasNoop
            idx.SetAtlas = idx.SetAtlas or AtlasNoop
        end
    end

    PatchMT(getmetatable(CreateFrame("Frame")))
    PatchMT(getmetatable(CreateFrame("Button")))
    PatchMT(getmetatable(CreateFrame("Frame"):CreateTexture()))
end

---------------------------------------------------------------------------
-- SOUNDKIT (retail table, not in 3.3.5 — PlaySound takes numeric IDs)
---------------------------------------------------------------------------
if not SOUNDKIT then
    SOUNDKIT = {
        IG_MAINMENU_OPTION_CHECKBOX_ON = 856,
        IG_CHARACTER_INFO_TAB = 841,
        IG_MAINMENU_OPEN = 839,
        IG_MAINMENU_CLOSE = 840,
        AUCTION_WINDOW_OPEN = 866,
        AUCTION_WINDOW_CLOSE = 867,
        LOOT_WINDOW_COIN_SOUND = 894,
        GS_TITLE_OPTION_EXIT = 799,
    }
end

---------------------------------------------------------------------------
-- GetServerTime (retail API, not in 3.3.5)
---------------------------------------------------------------------------
if not GetServerTime then
    function GetServerTime()
        return time()
    end
end
-- PKBT_RedButtonTemplate: not available on 3.3.5
-- CustomFrame.lua uses pcall to fall back to plain Button

---------------------------------------------------------------------------
-- PKBT_Font_16 fallback
---------------------------------------------------------------------------
if not _G["PKBT_Font_16"] then
    _G["PKBT_Font_16"] = CreateFont("PKBT_Font_16")
    PKBT_Font_16:SetFont("Fonts\\FRIZQT__.TTF", 16)
end
