local _, ns = ...
local L = ns.L

OF_NUM_BROWSE_TO_DISPLAY = 8;
OF_NUM_AUCTION_ITEMS_PER_PAGE = 50;
OF_NUM_FILTERS_TO_DISPLAY = 15;
OF_BROWSE_FILTER_HEIGHT = 20;
OF_NUM_BIDS_TO_DISPLAY = 9;
OF_NUM_AUCTIONS_TO_DISPLAY = 9;
OF_AUCTIONS_BUTTON_HEIGHT = 37;
OF_OPEN_FILTER_LIST = {};
OF_MAXIMUM_BID_PRICE = 2000000000;
OFAuctionSort = { };

-- owner sorts
OFAuctionSort["owner_status"] = {
	{ column = "quantity",	reverse = true	},
	{ column = "bid",		reverse = false	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = false	},
	{ column = "duration",	reverse = false	},
	{ column = "status",	reverse = false	},
};

OFAuctionSort["owner_level"] = {
    { column =  "status",	reverse = true	},
    { column =  "bid",		reverse = true	},
    { column =  "duration",	reverse = true	},
    { column =  "quantity",	reverse = false	},
    { column =  "name",		reverse = true	},
    { column =  "quality",	reverse = true	},
    { column =  "level",	reverse = false	},
};

OFAuctionSort["owner_bid"] = {
	{ column = "quantity",	reverse = true	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = false	},
	{ column = "duration",	reverse = false	},
	{ column = "status",	reverse = false	},
	{ column = "bid",		reverse = false	},
};

OFAuctionSort["owner_quality"] = {
	{ column = "bid",		reverse = false	},
	{ column = "quantity",	reverse = true	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = false	},
};

OFAuctionSort["owner_duration"] = {
	{ column = "quantity",	reverse = true	},
	{ column = "bid",		reverse = false	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = false	},
	{ column = "status",	reverse = false	},
	{ column = "duration",	reverse = false	},
};

OFAuctionSort["owner_type"] = {
    { column = "quantity",	reverse = true	},
    { column = "bid",		reverse = false	},
    { column = "name",		reverse = false	},
    { column = "level",		reverse = true	},
    { column = "quality",	reverse = false	},
    { column = "status",	reverse = false	},
    { column = "type",	    reverse = false	},
};

OFAuctionSort["owner_delivery"] = {
    { column = "quantity",	reverse = true	},
    { column = "bid",		reverse = false	},
    { column = "name",		reverse = false	},
    { column = "level",		reverse = true	},
    { column = "quality",	reverse = false	},
    { column = "status",	reverse = false	},
    { column = "delivery",	reverse = false	},
};

-- bidder sorts
OFAuctionSort["bidder_quality"] = {
	{ column =  "bid",		reverse = false	},
	{ column =  "quantity",	reverse = true	},
	{ column =  "name",		reverse = false	},
	{ column =  "level",	reverse = true	},
	{ column =  "quality",	reverse = false	},
};

OFAuctionSort["bidder_type"] = {
    { column =  "bid",		reverse = false	},
    { column =  "quantity",	reverse = true	},
    { column =  "name",		reverse = false	},
    { column =  "level",	reverse = true	},
    { column =  "type",	    reverse = false	},
};

OFAuctionSort["bidder_delivery"] = {
    { column =  "bid",		reverse = false	},
    { column =  "quantity",	reverse = true	},
    { column =  "name",		reverse = false	},
    { column =  "level",	reverse = true	},
    { column =  "delivery",	reverse = false	},
};

OFAuctionSort["bidder_status"] = {
	{ column =  "quantity",	reverse = true	},
	{ column =  "name",		reverse = false	},
	{ column =  "level",	reverse = true	},
	{ column =  "quality",	reverse = false	},
	{ column =  "bid",		reverse = false	},
	{ column =  "duration", reverse = false	},
	{ column =  "status",	reverse = false	},
};

OFAuctionSort["bidder_bid"] = {
	{ column =  "quantity",	reverse = true	},
	{ column =  "name",		reverse = false	},
	{ column =  "level",	reverse = true	},
	{ column =  "quality",	reverse = false	},
	{ column =  "status",	reverse = false	},
	{ column =  "duration",	reverse = false	},
	{ column =  "bid",		reverse = false	},
};

OFAuctionSort["bidder_buyer"] = {
    { column = "duration",	reverse = false	},
    { column = "bid",		reverse = false },
    { column = "quantity",	reverse = true	},
    { column = "name",		reverse = false	},
    { column = "level",		reverse = true	},
    { column = "quality",	reverse = false	},
    { column = "buyer",	    reverse = false	},
};

OFAuctionSort["bidder_rating"] = {
    { column = "buyer",		reverse = false	},
    { column = "rating",	reverse = true	},
};

-- list sorts
OFAuctionSort["list_level"] = {
	{ column = "duration",	reverse = true	},
	{ column = "bid",		reverse = true	},
	{ column = "quantity",	reverse = false	},
	{ column = "name",		reverse = true	},
	{ column = "quality",	reverse = true	},
	{ column = "level",		reverse = false	},
};
OFAuctionSort["list_duration"] = {
	{ column = "bid",		reverse = false	},
	{ column = "quantity",	reverse = true	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = false	},
	{ column = "duration",	reverse = false	},
};
OFAuctionSort["list_seller"] = {
	{ column = "duration",	reverse = false	},
	{ column = "bid",		reverse = false },
	{ column = "quantity",	reverse = true	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = false	},
	{ column = "seller",	reverse = false	},
};
OFAuctionSort["list_bid"] = {
	{ column = "duration",	reverse = false	},
	{ column = "quantity",	reverse = true	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = false	},
	{ column = "bid",		reverse = false	},
};

OFAuctionSort["list_quality"] = {
	{ column = "duration",	reverse = false	},
	{ column = "bid",		reverse = false	},
	{ column = "quantity",	reverse = true	},
	{ column = "name",		reverse = false	},
	{ column = "level",		reverse = true	},
	{ column = "quality",	reverse = true	},
};

OFAuctionSort["list_type"] = {
    { column = "duration",	reverse = false	},
    { column = "bid",		reverse = false	},
    { column = "quantity",	reverse = true	},
    { column = "name",		reverse = false	},
    { column = "level",		reverse = true	},
    { column = "quality",	reverse = false	},
    { column = "type",	    reverse = false	},
};

OFAuctionSort["list_delivery"] = {
    { column = "duration",	reverse = false	},
    { column = "bid",		reverse = false	},
    { column = "quantity",	reverse = true	},
    { column = "name",		reverse = false	},
    { column = "level",		reverse = true	},
    { column = "delivery",	reverse = false	},
};

OFAuctionSort["list_rating"] = {
    { column = "seller",	reverse = false	},
    { column = "rating",	reverse = true	},
};

OFAuctionSort["clips_streamer"] = {
    { column = "when",		reverse = true	},
    { column = "streamer",	reverse = false	},
}

OFAuctionSort["clips_race"] = {
    { column = "when",	reverse = true  },
    { column = "race",	reverse = false	},
}

OFAuctionSort["clips_level"] = {
    { column = "when",	reverse = true  },
    { column = "level",	reverse = false	},
}

OFAuctionSort["clips_class"] = {
    { column = "when",	reverse = true  },
    { column = "class",	reverse = false	},
}

OFAuctionSort["clips_when"] = {
    { column = "streamer",	reverse = false	},
    { column = "when",	reverse = true  },
}

OFAuctionSort["clips_where"] = {
    { column = "when",	reverse = true  },
    { column = "where",	reverse = false	},
}

OFAuctionSort["clips_clip"] = {
    { column = "when",	reverse = true  },
    { column = "clip",	reverse = false	},
}

OFAuctionSort["clips_rating"] = {
    { column = "when",	reverse = true  },
    { column = "rating",reverse = true	},
}

OFAuctionSort["clips_rate"] = {
    { column = "when",	reverse = true  },
    { column = "rate",	reverse = false	},
}


OFAuctionSort["lfg_name"] = {
    { column = "viewers",		reverse = true	},
    { column = "name",	reverse = false	},
    { column = "meetsRequirements",	reverse = true	},
    { column = "isOnline",	reverse = true	},
}

OFAuctionSort["lfg_level"] = {
    { column = "viewers",	reverse = true  },
    { column = "level",	reverse = false	},
    { column = "meetsRequirements",	reverse = true	},
    { column = "isOnline",	reverse = true	},
}

OFAuctionSort["lfg_colab"] = {
    { column = "viewers",	reverse = true  },
    { column = "level",	reverse = false	},
    { column = "isDungeon",	reverse = true },
    { column = "meetsRequirements",	reverse = true	},
    { column = "isOnline",	reverse = true },
}

OFAuctionSort["lfg_viewers"] = {
    { column = "meetsRequirements",	reverse = true	},
    { column = "isOnline",	reverse = true },
    { column = "viewers",	reverse = true  },
}

OFAuctionSort["lfg_livestream"] = {
    { column = "meetsRequirements",	reverse = true	},
    { column = "livestream",	reverse = false	},
    { column = "isOnline",	reverse = true	},
}

OFAuctionSort["lfg_raid"] = {
    { column = "meetsRequirements",	reverse = true	},
    { column = "raid",	reverse = false	},
    { column = "isOnline",	reverse = true	},
}



OFAuctionCategories = {};

local function FindDeepestCategory(categoryIndex, ...)
	local categoryInfo = OFAuctionCategories[categoryIndex];
	for i = 1, select("#", ...) do
		local subCategoryIndex = select(i, ...);
		if categoryInfo and categoryInfo.subCategories and categoryInfo.subCategories[subCategoryIndex] then
			categoryInfo = categoryInfo.subCategories[subCategoryIndex];
		else
			break;
		end
	end
	return categoryInfo;
end

function OFAuctionFrame_FindDeepestCategory(categoryIndex, subCategoryIndex, subSubCategoryIndex)
    return FindDeepestCategory(categoryIndex, subCategoryIndex, subSubCategoryIndex)
end

function OFAuctionFrame_GetDetailColumnString(categoryIndex, subCategoryIndex)
	local categoryInfo = FindDeepestCategory(categoryIndex, subCategoryIndex);
	return categoryInfo and categoryInfo:GetDetailColumnString() or REQ_LEVEL_ABBR;
end

function OFAuctionFrame_DoesCategoryHaveFlag(flag, categoryIndex, subCategoryIndex, subSubCategoryIndex)
	local categoryInfo = FindDeepestCategory(categoryIndex, subCategoryIndex, subSubCategoryIndex);
	if categoryInfo then
		return categoryInfo:HasFlag(flag);
	end
	return false;
end

function OFAuctionFrame_CreateCategory(name)
	local category = CreateFromMixins(OFAuctionCategoryMixin);
	category.name = name;
	OFAuctionCategories[#OFAuctionCategories + 1] = category;
	return category;
end

OFAuctionCategoryMixin = {};

function OFAuctionCategoryMixin:SetDetailColumnString(detailColumnString)
	self.detailColumnString = detailColumnString;
end

function OFAuctionCategoryMixin:GetDetailColumnString()
	if self.detailColumnString then
		return self.detailColumnString;
	end
	if self.parent then
		return self.parent:GetDetailColumnString();
	end
	return REQ_LEVEL_ABBR;
end

function OFAuctionCategoryMixin:CreateSubCategory(classID, subClassID, inventoryType)
    local name = "";
    if inventoryType then
        name = GetItemInventorySlotInfo(inventoryType);
    elseif classID and subClassID then
        name = GetItemSubClassInfo(classID, subClassID);
    elseif classID then
        name = GetItemClassInfo(classID);
    end
    return self:CreateNamedSubCategory(name);
end

function OFAuctionCategoryMixin:CreateNamedSubCategory(name)
	self.subCategories = self.subCategories or {};

	local subCategory = CreateFromMixins(OFAuctionCategoryMixin);
	self.subCategories[#self.subCategories + 1] = subCategory;
	assert(name and #name > 0);
	subCategory.name = name;
	subCategory.parent = self;
	subCategory.sortIndex = #self.subCategories;
	return subCategory;
end

function OFAuctionCategoryMixin:CreateNamedSubCategoryAndFilter(name, classID, subClassID, inventoryType)
	local category = self:CreateNamedSubCategory(name);
	category:AddFilter(classID, subClassID, inventoryType);

	return category;
end

function OFAuctionCategoryMixin:CreateSubCategoryAndFilter(classID, subClassID, inventoryType)
	local category = self:CreateSubCategory(classID, subClassID, inventoryType);
	category:AddFilter(classID, subClassID, inventoryType);

	return category;
end

function OFAuctionCategoryMixin:AddBulkInventoryTypeCategories(classID, subClassID, inventoryTypes)
	for i, inventoryType in ipairs(inventoryTypes) do
		self:CreateSubCategoryAndFilter(classID, subClassID, inventoryType);
	end
end

function OFAuctionCategoryMixin:AddFilter(classID, subClassID, inventoryType)
	self.filters = self.filters or {};
	self.filters[#self.filters + 1] = { classID = classID, subClassID = subClassID, inventoryType = inventoryType, };

	if self.parent then
		self.parent:AddFilter(classID, subClassID, inventoryType);
	end
end

do
	local function GenerateSubClassesHelper(self, classID, ...)
		self:CreateSubCategory(classID);
	end

	function OFAuctionCategoryMixin:GenerateSubCategoriesAndFiltersFromSubClass(classID)
		GenerateSubClassesHelper(self, classID, GetAuctionItemSubClasses(classID));
	end
end

--function OFAuctionCategoryMixin:FindSubCategoryByName(name)
--	if self.subCategories then
--		for i, subCategory in ipairs(self.subCategories) do
--			if subCategory.name == name then
--				return subCategory;
--			end
--		end
--	end
--end
    
function OFAuctionCategoryMixin:SortSubCategories()
	if self.subCategories then
		table.sort(self.subCategories, function(left, right)
			return left.sortIndex < right.sortIndex;
		end)
	end
end

function OFAuctionCategoryMixin:SetSortIndex(sortIndex)
	self.sortIndex = sortIndex
end

function OFAuctionCategoryMixin:SetFlag(flag)
	self.flags = self.flags or {};
	self.flags[flag] = true;
end

function OFAuctionCategoryMixin:ClearFlag(flag)
	if self.flags then
		self.flags[flag] = nil;
	end
end

function OFAuctionCategoryMixin:HasFlag(flag)
	return not not (self.flags and self.flags[flag]);
end

do -- Weapons
    local weaponsCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_WEAPONS);
    
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_AXE1H, Enum.InventoryType.IndexWeaponmainhandType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_AXE2H, Enum.InventoryType.Index2HweaponType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_BOWS, Enum.InventoryType.IndexRangedType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_GUNS, Enum.InventoryType.IndexRangedType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_MACE1H, Enum.InventoryType.IndexWeaponmainhandType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_MACE2H, Enum.InventoryType.Index2HweaponType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_POLEARM, Enum.InventoryType.Index2HweaponType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_SWORD1H, Enum.InventoryType.IndexWeaponmainhandType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_SWORD2H, Enum.InventoryType.Index2HweaponType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_STAFF, Enum.InventoryType.Index2HweaponType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_UNARMED, Enum.InventoryType.IndexHandType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_GENERIC, Enum.InventoryType.IndexWeaponType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_DAGGER, Enum.InventoryType.IndexWeaponType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_THROWN, Enum.InventoryType.IndexThrownType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_CROSSBOW, Enum.InventoryType.IndexRangedType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_WAND, Enum.InventoryType.IndexThrownType);
    weaponsCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_WEAPON, LE_ITEM_WEAPON_FISHINGPOLE, Enum.InventoryType.Index2HweaponType);
end

do -- Armor
    local MiscArmorInventoryTypes = {
        IndexHeadType,
        IndexNeckType,
        IndexBodyType,
        IndexFingerType,
        IndexTrinketType,
        IndexHoldableType,
    };

    local ClothArmorInventoryTypes = {
        IndexHeadType,
        IndexShoulderType,
        IndexChestType,
        IndexWaistType,
        IndexLegsType,
        IndexFeetType,
        IndexWristType,
        IndexHandType,
        IndexCloakType, -- Only for Cloth.
    };

    local ArmorInventoryTypes = {
        IndexHeadType,
        IndexShoulderType,
        IndexChestType,
        IndexWaistType,
        IndexLegsType,
        IndexFeetType,
        IndexWristType,
        IndexHandType,
    };

    local armorCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_ARMOR);

    local miscCategory = armorCategory:CreateSubCategory(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC);
    miscCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC, MiscArmorInventoryTypes);

    local clothCategory = armorCategory:CreateSubCategory(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH);
    clothCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH, ClothArmorInventoryTypes);

   -- local clothChestCategory = clothCategory:FindSubCategoryByName(GetItemInventorySlotInfo(Enum.InventoryType.IndexChestType));
   -- clothChestCategory:AddFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH, Enum.InventoryType.IndexRobeType);

    local leatherCategory = armorCategory:CreateSubCategory(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LEATHER);
    leatherCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LEATHER, ArmorInventoryTypes);

  --  local leatherChestCategory = leatherCategory:FindSubCategoryByName(GetItemInventorySlotInfo(Enum.InventoryType.IndexChestType));
  --  leatherChestCategory:AddFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LEATHER, Enum.InventoryType.IndexRobeType);

    local mailCategory = armorCategory:CreateSubCategory(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_MAIL);
    mailCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_MAIL, ArmorInventoryTypes);

   -- local mailChestCategory = mailCategory:FindSubCategoryByName(GetItemInventorySlotInfo(Enum.InventoryType.IndexChestType));
   -- mailChestCategory:AddFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_MAIL, Enum.InventoryType.IndexRobeType);

    local plateCategory = armorCategory:CreateSubCategory(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_PLATE);
    plateCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_PLATE, ArmorInventoryTypes);

   -- local plateChestCategory = plateCategory:FindSubCategoryByName(GetItemInventorySlotInfo(Enum.InventoryType.IndexChestType));
  --  plateChestCategory:AddFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_PLATE, Enum.InventoryType.IndexRobeType);

    armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_SHIELD, Enum.InventoryType.IndexShieldType);
    armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LIBRAM, Enum.InventoryType.IndexWeaponoffhandType);
    armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_IDOL, Enum.InventoryType.IndexRelicType);
    armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_TOTEM, Enum.InventoryType.IndexRelicType);
end

do -- Containers
    local containersCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_CONTAINERS);
    --containersCategory:SetDetailColumnString(SLOT_ABBR);
    containersCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_CONTAINER);
end

do -- Consumables (SubClasses Added in TBC)
    local consumablesCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_CONSUMABLES);
    consumablesCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_CONSUMABLE);
end

do -- Trade Goods (SubClasses Added in TBC)
    local tradeGoodsCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_TRADE_GOODS);
    tradeGoodsCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_TRADEGOODS);
end

do -- Recipes
    local recipesCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_RECIPES);
    recipesCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_RECIPE);
end

--do -- Reagent (Changed to a ItemClass.Miscellaneous and other ClassIDs in TBC)
 --   if GetClassicExpansionLevel() == LE_EXPANSION_CLASSIC then
  --      local reagentCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_REAGENT);
   --     reagentCategory:AddFilter(LE_ITEM_CLASS_MISCELLANEOUS);
  --  end
--end

do -- Miscellaneous (SubClasses Added in TBC)
    local miscellaneousCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_MISCELLANEOUS);
    miscellaneousCategory:AddFilter(LE_ITEM_CLASS_MISCELLANEOUS);
    miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_JUNK);
    miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_REAGENT);
    miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_PET);
    miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_HOLIDAY);
    miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_OTHER);
    miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_MOUNT);
end

OFAuctionFrame_CreateCategory(L["Enchants"]):SetFlag("BLUE_HIGHLIGHT")

OFAuctionFrame_CreateCategory(L["Gold Missions"]):SetFlag("BLUE_HIGHLIGHT")

ns.CategoryIndexToID = {
    2,
    4,
    1,
    0,
    7,
    6,
    11,
    9,
    5,
    15,
    ns.SPELL_ITEM_CLASS_ID,
    ns.GOLD_ITEM_CLASS_ID,
}

ns.SubCategoryIndexToID = {
    -- [classID] = { [subCategoryIndex] = subClassID }
    
    -- Оружие (classID 2)
    [2] = {
        [1] = 0,  -- Одноручное
        [2] = 1,  -- Двуручное
        [3] = 2,  -- Дальний бой
        [4] = 3,  -- Метательное
        [5] = 4,  -- Кистевое
        [6] = 5,  -- Разное
        [7] = 6,  -- Артефакты
        [8] = 7,  -- Жезлы
        [9] = 8,  -- Рыбная ловля
    },
    
    -- Броня (classID 4)
    [4] = {
        [1] = 1,  -- Ткань
        [2] = 2,  -- Кожа
        [3] = 3,  -- Кольчуга
        [4] = 4,  -- Латы
        [5] = 5,  -- Косметические
        [6] = 6,  -- Аксессуары
        [7] = 7,  -- Ткань (роба)
        [8] = 8,  -- Реликвии
    },
    
    -- Расходные материалы (classID 0)
    [0] = {
        [1] = 0,  -- Зелья
        [2] = 1,  -- Эликсиры
        [3] = 2,  -- Свитки
        [4] = 3,  -- Драгоценности
        [5] = 4,  -- Сумки
        [6] = 5,  -- Идолы
        [7] = 6,  -- Тотемы
        [8] = 7,  -- Амулеты
        [9] = 8,  -- Сигилы
    },
    
    -- Наложение чар (classID 1)
    [1] = {
        [1] = 0,  -- Металлы
        [2] = 1,  -- Оружие
        [3] = 2,  -- Ткань
        [4] = 3,  -- Кожа
        [5] = 4,  -- Камни
        [6] = 5,  -- Алхимия
        [7] = 6,  -- Элементалы
        [8] = 7,  -- Травы
        [9] = 8,  -- Рецепты
    },
    
    -- Задания (classID 3)
    [3] = {
        [1] = 0,  -- Задания
        [2] = 1,  -- Спецпредметы
    },
    
    -- Рецепты (classID 9)
    [9] = {
        [1] = 0,  -- Книги
        [2] = 1,  -- Кожевничество
        [3] = 2,  -- Портняжное дело
        [4] = 3,  -- Кузница
        [5] = 4,  -- Инженерное дело
        [6] = 5,  -- Ювелирное дело
        [7] = 6,  -- Алхимия
        [8] = 7,  -- Наложение чар
        [9] = 8,  -- Гербовые печати
    },
    
    -- Контейнеры (classID 11)
    [11] = {
        [1] = 0,  -- Сумки
        [2] = 1,  -- Драгоценности
        [3] = 2,  -- Уберские
        [4] = 3,  -- Хладодышащие
    },
    
    -- Разное (classID 15)
    [15] = {
        [1] = 0,  -- Мусор
        [2] = 1,  -- Ремесленные материалы
        [3] = 2,  -- Части
        [4] = 3,  -- Сезонные
    },
}