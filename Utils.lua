local addonName, ns = ...
local L = ns.L

ns.id_to_class = {
    [1] = "Warrior",
    [2] = "Paladin",
    [3] = "Hunter",
    [4] = "Rogue",
    [5] = "Priest",
    [7] = "Shaman",
    [8] = "Mage",
    [9] = "Warlock",
    [11] = "Druid",
}

ns.class_to_id = {
    ["Warrior"] = 1,
    ["Paladin"] = 2,
    ["Hunter"] = 3,
    ["Rogue"] = 4,
    ["Priest"] = 5,
    ["Shaman"] = 7,
    ["Mage"] = 8,
    ["Warlock"] = 9,
    ["Druid"] = 11,
}

ns.id_to_race = {
    [1] = "Human",
    [2] = "Orc",
    [3] = "Dwarf",
    [4] = "Night Elf",
    [5] = "Undead",
    [6] = "Tauren",
    [7] = "Gnome",
    [8] = "Troll",
}

ns.race_to_id = {
    ["Human"] = 1,
    ["Orc"] = 2,
    ["Dwarf"] = 3,
    ["Night Elf"] = 4,
    ["Undead"] = 5,
    ["Tauren"] = 6,
    ["Gnome"] = 7,
    ["Troll"] = 8,
}

ns.RACE_COLORS = {
    ["Human"]                = "#2055F0",
    ["Dwarf"]                = "#CC9933",
    ["Night Elf"]            = "#A335EE",
    ["Gnome"]                = "#F48CBA",

    ["Orc"]                  = "#53ED6C",
    ["Undead"]               = "#A296EA",
    ["Tauren"]               = "#E8A76E",
    ["Troll"]                = "#67FFF6",
}

ns.AddRaceColor = function(text, race)
    if not ns.RACE_COLORS[race] then
        return text
    end

    local color = ns.RACE_COLORS[race]
    --turn #RRGGBB into AARRGGBB
    color = "FF" .. color:sub(2)
    return "|c" .. color .. text .. "|r"
end

ns.AddClassColor = function(text, class)
    if not ns.CLASS_COLORS[class] then
        return text
    end

    local color = ns.CLASS_COLORS[class]
    return "|c" .. color.colorStr .. text .. "|r"
end

ns.CLASS_COLORS = {}
for k, _ in pairs(ns.class_to_id) do
    ns.CLASS_COLORS[k] = RAID_CLASS_COLORS[string.upper(k)]
end
ns.CLASS_COLORS["Shaman"] = CreateColor(36 / 255, 89 / 255, 255 / 255)
ns.CLASS_COLORS["Shaman"].colorStr = "ff245bff"

ns.HexToRGG = function(hex)
    -- Remove leading "#" if present
    if hex:sub(1,1) == "#" then
        hex = hex:sub(2)
    end

    -- Parse the string in pairs of two (RR, GG, BB) and convert from hex to decimal
    local r = tonumber(hex:sub(1,2), 16) / 255
    local g = tonumber(hex:sub(3,4), 16) / 255
    local b = tonumber(hex:sub(5,6), 16) / 255

    return r, g, b
end

ns.NewId = function()
    local timestamp = time() * 1000  -- *1000 to have 4 digits for randomHex
    local number = timestamp + math.random(1048576)  -- 1048576 is 2^20 -- 4 chars hex-encoded
    local hexStr = string.format("%x", number)
    -- remove the first character from the hex string (first digits from timestamp are not important)
    return string.sub(hexStr, 2)
end

ns.TryFinally = function(try, finally)
    local status, result = pcall(try)
    finally()
    if status then
        return result
    else
        error(result)
    end
end

ns.TryExcept = function(try, except)
    local status, result = pcall(try)
    if status then
        return result
    else
        except(result)
    end
end

ns.TryExceptFinally = function(try, except, finally)
    local status, result = pcall(try)
    if status then
        if finally then
            finally()
            return result
        end
    else
        local finalError = result
        if except then
            local exceptStatus, exceptResult = pcall(function() except(result) end)
            if not exceptStatus then
                finalError = {
                    message = result,
                    innerError = exceptResult
                }
            end
        end
        if finally then
            finally()
        end
        error(finalError)
    end
end

ns.GetItemInfo = function(id, quantity)
    if ns.IsSpellItem(id) then
        return ns.GetSpellItemInfo(id)
    end
    if ns.IsFakeItem(id) then
        return ns.GetFakeItemInfo(id, quantity)
    end
    return GetItemInfo(id)
end

-- it's really upsetting that even if we had GetItemInfoInstant
-- it wouldn't give us the ItemSellPrice
ns.GetItemInfoAsync = function(itemId, callback, quantity)
    if ns.IsFakeItem(itemId) then
        callback(ns.GetFakeItemInfo(itemId, quantity))
        return
    end
    if ns.IsSpellItem(itemId) then
        callback(ns.GetSpellItemInfo(itemId))
        return
    end

    local itemName = GetItemInfo(itemId)
    if itemName then
        callback(GetItemInfo(itemId))
    -- FIXME TODO 3.3.5 is this ever needed? was initially was made to fix itemSellprice to Request Item
    else
        -- Retry until item is cached
        local retries = 0
        local maxRetries = 10
        local f = CreateFrame("Frame")
        f:SetScript("OnUpdate", function(self, elapsed)
            retries = retries + 1
            local name = GetItemInfo(itemId)
            if name or retries >= maxRetries then
                self:SetScript("OnUpdate", nil)
                callback(GetItemInfo(itemId))
            end
        end)
    end
end


-- GetItemCount returns the number of times you own itemId
-- for gold it returns the amount of copper you have
ns.GetItemCount = function(itemId, includeBank)
    if itemId == ns.ITEM_ID_GOLD then
        return GetMoney()
    end
    if itemId == ns.ITEM_ID_GUILD_POINTS then
        return 0
    end
    return GetItemCount(itemId, includeBank)
end

ns.GetAuctionDurationEnum = function(auction)
    local duration = auction.expiresAt - time()
    if duration < 30 * 60 then
        return 1
    elseif duration < 2 * 60 * 60 then
        return 2
    elseif duration < 8 * 60 * 60 then
        return 3
    else
        return 4
    end
end

ns.GetTimeText = function(timeLeft)
    if timeLeft <= 0 then
        return nil
    end

    local hours = math.floor(timeLeft / 3600)
    local minutes = math.floor((timeLeft % 3600) / 60)

    if hours > 0 then
        return string.format(L["%dh left"], hours)
    else
        return string.format(L["%dm left"], minutes)
    end
end

ns.TableLength = function(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

ns.GetMoneyString = function(copper)
    local gold = floor(copper / 10000)
    local silver = floor((copper % 10000) / 100)
    local remainingCopper = copper % 100

    local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
    local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t"
    local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t"

    local moneyString = ""
    if gold > 0 then
        moneyString = moneyString .. gold .. GOLD_ICON .. " "
    end
    if silver > 0 or gold > 0 then
        moneyString = moneyString .. silver .. SILVER_ICON .. " "
    end
    moneyString = moneyString .. remainingCopper .. COPPER_ICON

    return moneyString
end

ns.DebugLog = function(...)
    if ns.TEST_USERS[UnitName("player")] then
        print(...)
    end
end

-- Local function to inspect a frame and print its information with improved styling
local function InspectFrameInfo(frame)
    if not frame then
        print("|cffff0000No frame provided.|r")
        return
    end

    -- Exclude WorldFrame
    if frame == WorldFrame then
        print("|cffff0000WorldFrame is excluded from inspection.|r")
        return
    end

    -- Print basic frame info in green, bold for titles
    print("|cff00ff00|hFrame Name:|r|cffffffff", frame:GetName())
    print("|cff00ff00|hFrame Width:|r|cffffffff", frame:GetWidth())
    print("|cff00ff00|hFrame Height:|r|cffffffff", frame:GetHeight())
    local point, relativeFrame, relativePoint, xOfs, yOfs = frame:GetPoint()
    print("|cff00ff00|hFrame Position:|r|cffffffff", point, relativeFrame and relativeFrame:GetName() or "nil", relativePoint, xOfs, yOfs)

    -- Print all textures used by the frame (if any) with extra spacing
    print("|cff00ff00====================|r")
    print("|cff00ff00Textures used by|r", frame:GetName())
    for i, texture in ipairs({frame:GetRegions()}) do
        if texture and texture.GetTexture then
            print("|cff00ff00  Texture|r", i, ":", texture:GetTexture())

            -- Check and print texcoords if present
            local texCoords = {texture:GetTexCoord()}
            if texCoords[1] then
                print("    |cff00ff00TexCoords:|r", texCoords[1], texCoords[2], texCoords[3], texCoords[4])
            end
        end
    end

    -- Add spacing before children section
    print("|cff00ff00====================|r")
    print("|cff00ff00Children of|r", frame:GetName())
    for i, child in ipairs({frame:GetChildren()}) do
        print("|cff00ff00  Child|r", i, ":", child:GetName())
    end

    -- Add spacing before script section
    print("|cff00ff00====================|r")
    print("|cff00ff00Scripts and events for|r", frame:GetName())
    for _, scriptType in ipairs({"OnClick", "OnEnter", "OnLeave", "OnShow", "OnHide"}) do
        -- Skip checking OnClick for frames without this script
        local success, scriptFunc = pcall(frame.GetScript, frame, scriptType)

        -- If successful, print the script type; otherwise, report it as not available
        if success and scriptFunc then
            print("|cff00ff00  Script type:|r", scriptType)
        elseif not success then
            print("|cffff0000Error accessing script for", scriptType, "|r")
        else
            print("|cffff0000No script for|r", scriptType)
        end
    end

    -- Check for parent frame details if the parent is a table
    if relativeFrame then
        print("|cff00ff00Parent Name:|r", relativeFrame:GetName())
    else
        print("|cffff0000No parent frame|r")
    end

    -- Print last line in red, more emphasis
    print("|cffff0000====================|r")
    print("|cffff0000End of frame info|r")
    print("|cffff0000====================|r")
end

-- Register the slash command correctly
SLASH_ATHENEGRAB1 = "/athenegrab"
SlashCmdList["ATHENEGRAB"] = function(msg)
    if msg and msg ~= "" then
        -- If an argument (frame name) is passed, get the frame info of that frame
        local frame = _G[msg]
        if frame then
            InspectFrameInfo(frame)
        else
            print("|cffff0000Frame not found: " .. msg .. "|r")
        end
    else
        -- If no argument, use the frame under the mouse (MouseFocus)
        local frame = GetMouseFocus()
        if frame then
            InspectFrameInfo(frame)
        else
            print("|cffff0000No frame under the mouse.|r")
        end
    end
end

-- =====================  GoAgainAH realm-debug slash tools  =====================
SLASH_GAHRL1 = "/gahrl"
SlashCmdList.GAHRL = function()
    local total, localOnly = 0, 0
    for _ in pairs(ns.AuctionHouseDB.auctions) do total = total + 1 end
    for _ in pairs(ns.FilterAuctionsThisRealm(ns.AuctionHouseDB.auctions)) do localOnly = localOnly + 1 end
    print(string.format("Realm %s — auctions: %d total / %d this realm",
            ns.CURRENT_REALM, total, localOnly))
end

SLASH_GAHMAKE1 = "/gahmake"
SlashCmdList.GAHMAKE = function()
    local a = ns.AuctionHouseAPI:CreateAuction(99999, 1, 1) -- dummy itemID 99999
    if a then
        print("Created test auction ID", a.id, "realm", a.realm)
    end
end

SLASH_GAHLIST1 = "/gahlistforeign"
SlashCmdList.GAHLIST = function()
    for id, a in pairs(ns.AuctionHouseDB.auctions) do
        if a.realm ~= ns.CURRENT_REALM then
            print("Foreign auction:", id, a.realm, a.owner, a.itemID)
        end
    end
end

SLASH_GAHDUMP1 = "/gahdump"
SlashCmdList.GAHDUMP = function(msg)
    local id = msg:match("%S+")
    if not id then print("Usage: /gahdump <auctionID>") return end
    dump(ns.AuctionHouseDB.auctions[id])
end
-- ==============================================================================

