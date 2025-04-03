function SetupLocalization(l10nTable)
    local locale = GetLocale() -- Get the current game locale
    if l10nTable[locale] and type(l10nTable[locale].localize) == "function" then
        l10nTable[locale].localize() -- Call the localize function for the current locale
    else
        -- Fallback to enUS if the locale is not supported
        if l10nTable["enUS"] and type(l10nTable["enUS"].localize) == "function" then
            l10nTable["enUS"].localize()
        else
            print("Localization not available for locale: " .. locale)
        end
    end
end

local l10nTable = {
	deDE = {
		localize = function()
		end,
	},
	enGB = {
		localize = function()
		end,
	},

	enUS = {

	},

	esES = {
        localize = function()
        end,
	},
	esMX = {
        localize = function()
        end,
	},

	frFR = {
		localize = function()
		end,
	},

	itIT = {
		localize = function()
		end,
	},

	koKR = {
		localize = function()
		end,
	},

	ptBR = {
        localize = function()
        end,
	},

	ptPT = {
        localize = function()
        end,
	},

	ruRU = {
        localize = function()
        end,
	},

	zhCN = {
		localize = function()
		end,
	},

	zhTW = {
		localize = function()
		end,
	},
};

SetupLocalization(l10nTable);