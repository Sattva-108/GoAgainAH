local _, ns = ...
local L = ns.L

OF_NUM_BROWSE_TO_DISPLAY = 8;
OF_NUM_AUCTION_ITEMS_PER_PAGE = 50;
OF_NUM_FILTERS_TO_DISPLAY = 15;
OF_BROWSE_FILTER_HEIGHT = 15;
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
    local name = "subClassID";
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
	if not classID and not subClassID and not inventoryType then
		return;
	end

	self.filters = self.filters or {};
	self.filters[#self.filters + 1] = { classID = classID, subClassID = subClassID, inventoryType = inventoryType, };

	if self.parent then
		self.parent:AddFilter(classID, subClassID, inventoryType);
	end
end

do
	local function GenerateSubClassesHelper(self, classID, subClasses)
		for i = 1, #subClasses do
			local subClassID = subClasses[i];
			self:CreateSubCategoryAndFilter(classID, subClassID);
		end
	end

	function OFAuctionCategoryMixin:GenerateSubCategoriesAndFiltersFromSubClass(classID)
		GenerateSubClassesHelper(self, classID, C_AuctionHouse.GetAuctionItemSubClasses(classID));
	end
end

function OFAuctionCategoryMixin:FindSubCategoryByName(name)
	if self.subCategories then
		for i, subCategory in ipairs(self.subCategories) do
			if subCategory.name == name then
				return subCategory;
			end
		end
	end
end
    
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
	weaponsCategory:SetDetailColumnString(ITEM_LEVEL_ABBR);
	weaponsCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_WEAPON);
end

do -- Armor
	local ArmorInventoryTypes = {
		Enum.InventoryType.IndexHeadType,
		Enum.InventoryType.IndexShoulderType,
		Enum.InventoryType.IndexChestType,
		Enum.InventoryType.IndexWaistType,
		Enum.InventoryType.IndexLegsType,
		Enum.InventoryType.IndexFeetType,
		Enum.InventoryType.IndexWristType,
		Enum.InventoryType.IndexHandType,
	};

	local armorCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_ARMOR);
	armorCategory:SetDetailColumnString(ITEM_LEVEL_ABBR);

	local miscCategory = armorCategory:CreateSubCategory(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC);
	miscCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC, Enum.InventoryType.IndexHeadType);
	miscCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC, Enum.InventoryType.IndexNeckType);
	miscCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC, Enum.InventoryType.IndexBodyType);
	miscCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC, Enum.InventoryType.IndexFingerType);
	miscCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC, Enum.InventoryType.IndexTrinketType);
	miscCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_GENERIC, Enum.InventoryType.IndexHoldableType);

	local clothCategory = armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH);
	clothCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH, ArmorInventoryTypes);

	clothCategory:CreateNamedSubCategoryAndFilter(INVTYPE_CLOAK, LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_CLOTH, Enum.InventoryType.IndexCloakType);

	local leatherCategory = armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LEATHER);
	leatherCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LEATHER, ArmorInventoryTypes);

	local mailCategory = armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_MAIL);
	mailCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_MAIL, ArmorInventoryTypes);

	local plateCategory = armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_PLATE);
	plateCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_PLATE, ArmorInventoryTypes);

	local cosmeticCategory = armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_COSMETIC);
	cosmeticCategory:AddBulkInventoryTypeCategories(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_COSMETIC, ArmorInventoryTypes);

	armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_SHIELD);
	armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_LIBRAM);
	armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_IDOL);
	armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_TOTEM);
	armorCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_ARMOR, LE_ITEM_ARMOR_SIGIL);
end

do -- Containers
	local containersCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_CONTAINERS);
	containersCategory:SetDetailColumnString(AUCTION_HOUSE_BROWSE_HEADER_CONTAINER_SLOTS);
	containersCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_CONTAINER);
end

do -- Consumables
	local consumablesCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_CONSUMABLES);
	consumablesCategory:SetDetailColumnString(AUCTION_HOUSE_BROWSE_HEADER_REQUIRED_LEVEL);
	consumablesCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_CONSUMABLE);
end

do -- Glyphs
	local glyphsCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_GLYPHS);
	glyphsCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_GLYPH);
end

do -- Trade Goods
	local tradeGoodsCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_TRADE_GOODS);
	tradeGoodsCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_TRADEGOODS);
end

do -- Ammo
	local ammoCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_AMMO);
	ammoCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_AMMO);
end

do -- Quiver
	local quiverCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_QUIVER);
	quiverCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_QUIVER);
end

do -- Recipes
	local recipesCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_RECIPES);
	recipesCategory:SetDetailColumnString(AUCTION_HOUSE_BROWSE_HEADER_RECIPE_SKILL);

	recipesCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_RECIPE);
end

do -- Gems
	local gemsCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_GEMS);
	gemsCategory:SetDetailColumnString(ITEM_LEVEL_ABBR);
	gemsCategory:GenerateSubCategoriesAndFiltersFromSubClass(LE_ITEM_CLASS_GEM);
end

do -- Miscellaneous
	local miscellaneousCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_MISCELLANEOUS);
	miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_JUNK);
	miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_REAGENT);
	miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_MOUNT);
	miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_PET);
	miscellaneousCategory:CreateSubCategoryAndFilter(8, 0); -- Toy
	miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_HOLIDAY);
	miscellaneousCategory:CreateSubCategoryAndFilter(LE_ITEM_CLASS_MISCELLANEOUS, LE_ITEM_MISCELLANEOUS_OTHER);
end

do -- Quest Items
	local questItemsCategory = OFAuctionFrame_CreateCategory(AUCTION_CATEGORY_QUEST_ITEMS);
	questItemsCategory:AddFilter(LE_ITEM_CLASS_QUESTITEM);
end

OFAuctionFrame_CreateCategory(L["Enchants"]):SetFlag("BLUE_HIGHLIGHT")

OFAuctionFrame_CreateCategory(L["Gold Missions"]):SetFlag("BLUE_HIGHLIGHT")

ns.CategoryIndexToID = {
    2,							-- Оружие
    4,							-- Доспехи
    1,							-- Сумки
    0,							-- Расход. предметы
    16,							-- Символы
    7,							-- Хозяйственные предметы
    6,							-- Боеприпасы
    11,							-- Амуниция
    9,							-- Рецепты
    3,							-- Самоцветы
	15,							-- Разное
	12,							-- Задания
    ns.SPELL_ITEM_CLASS_ID,		-- Enchants
    ns.GOLD_ITEM_CLASS_ID,		-- Gold Missions
}