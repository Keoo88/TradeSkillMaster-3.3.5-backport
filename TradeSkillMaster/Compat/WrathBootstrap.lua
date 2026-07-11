-- ------------------------------------------------------------------------------ --
--                       TradeSkillMaster — WoW 3.3.5a backport                   --
--   Loaded BEFORE everything else. Polyfills retail globals that LibTSMCore     --
--   and LibTSMWoW assume exist (WOW_PROJECT_*, C_AddOns, C_CVar, some Enums).   --
-- ------------------------------------------------------------------------------ --

local _G = _G

-- ============================================================================
-- WOW_PROJECT_* constants
-- ============================================================================

_G.WOW_PROJECT_MAINLINE                = _G.WOW_PROJECT_MAINLINE                or 1
_G.WOW_PROJECT_CLASSIC                 = _G.WOW_PROJECT_CLASSIC                 or 2
_G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5
_G.WOW_PROJECT_WRATH_CLASSIC           = _G.WOW_PROJECT_WRATH_CLASSIC           or 11
_G.WOW_PROJECT_CATACLYSM_CLASSIC       = _G.WOW_PROJECT_CATACLYSM_CLASSIC       or 14
_G.WOW_PROJECT_MISTS_CLASSIC           = _G.WOW_PROJECT_MISTS_CLASSIC           or 15

if not _G.WOW_PROJECT_ID then
	_G.WOW_PROJECT_ID = _G.WOW_PROJECT_WRATH_CLASSIC
end

-- ============================================================================
-- C_AddOns
-- ============================================================================

if not _G.C_AddOns then
	_G.C_AddOns = {}
end
local C_AddOns = _G.C_AddOns

C_AddOns.IsAddOnLoaded                = C_AddOns.IsAddOnLoaded                or _G.IsAddOnLoaded
C_AddOns.LoadAddOn                    = C_AddOns.LoadAddOn                    or _G.LoadAddOn
C_AddOns.EnableAddOn                  = C_AddOns.EnableAddOn                  or _G.EnableAddOn
C_AddOns.DisableAddOn                 = C_AddOns.DisableAddOn                 or _G.DisableAddOn
C_AddOns.GetAddOnInfo                 = C_AddOns.GetAddOnInfo                 or _G.GetAddOnInfo
C_AddOns.GetAddOnMetadata             = C_AddOns.GetAddOnMetadata             or _G.GetAddOnMetadata
C_AddOns.GetAddOnDependencies         = C_AddOns.GetAddOnDependencies         or _G.GetAddOnDependencies
C_AddOns.GetAddOnOptionalDependencies = C_AddOns.GetAddOnOptionalDependencies or _G.GetAddOnOptionalDependencies
C_AddOns.IsAddOnLoadOnDemand          = C_AddOns.IsAddOnLoadOnDemand          or _G.IsAddOnLoadOnDemand
C_AddOns.GetNumAddOns                 = C_AddOns.GetNumAddOns                 or _G.GetNumAddOns
C_AddOns.IsAddonVersionCheckEnabled   = C_AddOns.IsAddonVersionCheckEnabled   or _G.IsAddonVersionCheckEnabled or function() return false end

-- ============================================================================
-- C_CVar
-- ============================================================================

if not _G.C_CVar then
	_G.C_CVar = {}
end
local C_CVar = _G.C_CVar

C_CVar.GetCVar        = C_CVar.GetCVar        or _G.GetCVar
C_CVar.SetCVar        = C_CVar.SetCVar        or _G.SetCVar
C_CVar.GetCVarBool    = C_CVar.GetCVarBool    or _G.GetCVarBool or function(name)
	local v = _G.GetCVar and _G.GetCVar(name)
	return v == "1" or v == true
end
C_CVar.GetCVarDefault = C_CVar.GetCVarDefault or _G.GetCVarDefault
C_CVar.RegisterCVar   = C_CVar.RegisterCVar   or _G.RegisterCVar or function() end

-- ============================================================================
-- Enum stubs — fields must exist so retail-AH branches parse, even if unused
-- ============================================================================

_G.Enum = _G.Enum or {}
local Enum = _G.Enum

Enum.AuctionHouseSortOrder = Enum.AuctionHouseSortOrder or {
	Price    = 0,
	Name     = 1,
	Level    = 2,
	Bid      = 3,
	Buyout   = 4,
	Quantity = 5,
	TimeLeft = 6,
	Owner    = 7,
}

Enum.AuctionHouseNotification = Enum.AuctionHouseNotification or {
	AuctionWon     = 0,
	AuctionSold    = 1,
	AuctionOutbid  = 2,
	AuctionExpired = 3,
	BidPlaced      = 4,
	AuctionRemoved = 5,
}

Enum.AuctionHouseFilter = Enum.AuctionHouseFilter or {
	UncollectedOnly  = 0,
	UsableOnly       = 1,
	UpgradesOnly     = 2,
	ExactMatch       = 3,
	PoorQuality      = 4,
	CommonQuality    = 5,
	UncommonQuality  = 6,
	RareQuality      = 7,
	EpicQuality      = 8,
	LegendaryQuality = 9,
	ArtifactQuality  = 10,
}

Enum.ItemQuality = Enum.ItemQuality or {
	Poor      = 0,
	Common    = 1,
	Uncommon  = 2,
	Rare      = 3,
	Epic      = 4,
	Legendary = 5,
	Artifact  = 6,
	Heirloom  = 7,
	WoWToken  = 8,
}

Enum.Profession = Enum.Profession or {
	None           = 0,
	Alchemy        = 1,
	Blacksmithing  = 2,
	Enchanting     = 3,
	Engineering    = 4,
	Herbalism      = 5,
	Inscription    = 6,
	Jewelcrafting  = 7,
	Leatherworking = 8,
	Mining         = 9,
	Skinning       = 10,
	Tailoring      = 11,
	Cooking        = 12,
	FirstAid       = 13,
	Fishing        = 14,
}

Enum.BagIndex = Enum.BagIndex or {
	Backpack  = 0,
	Bag_1     = 1,
	Bag_2     = 2,
	Bag_3     = 3,
	Bag_4     = 4,
	Keyring   = -2,
	Bank      = -1,
	BankBag_1 = 5,
	BankBag_2 = 6,
	BankBag_3 = 7,
	BankBag_4 = 8,
	BankBag_5 = 9,
	BankBag_6 = 10,
	BankBag_7 = 11,
}

-- ============================================================================
-- Misc globals
-- ============================================================================

if not _G.tInvert then
	function _G.tInvert(tbl)
		local out = {}
		for k, v in pairs(tbl) do
			out[v] = k
		end
		return out
	end
end

if not _G.Round then
	function _G.Round(n)
		if n >= 0 then
			return math.floor(n + 0.5)
		end
		return math.ceil(n - 0.5)
	end
end

if not _G.Clamp then
	function _G.Clamp(value, lo, hi)
		if value < lo then return lo end
		if value > hi then return hi end
		return value
	end
end

if not _G.Saturate then
	function _G.Saturate(value)
		return _G.Clamp(value, 0, 1)
	end
end

if not _G.FrameDeltaLerp then
	function _G.FrameDeltaLerp(start, target, amount)
		return start + (target - start) * _G.Clamp(amount, 0, 1)
	end
end

if not _G.IsMacClient then
	function _G.IsMacClient() return false end
end

-- ============================================================================
-- Retail-only C_ namespace stubs
-- These tables must exist so Lua can read fields like C_AuctionHouse.GetCancelCost
-- without error, even though the retail branches are never executed on Wrath.
-- ============================================================================

_G.C_AuctionHouse  = _G.C_AuctionHouse  or {}
_G.C_TradeSkillUI  = _G.C_TradeSkillUI  or {}
_G.C_Garrison      = _G.C_Garrison      or {}
_G.C_TooltipInfo   = _G.C_TooltipInfo   or {}
_G.C_Bank          = _G.C_Bank          or {}
_G.C_Seasons       = _G.C_Seasons       or {}

-- ----------------------------------------------------------------------------
-- Shared no-op factories
-- ----------------------------------------------------------------------------
local _noop  = function() end
local _nil   = function() return nil end
local _false = function() return false end
local _zero  = function() return 0 end
local _empty = function() return {} end

-- ----------------------------------------------------------------------------
-- C_AuctionHouse stub methods
-- TSM never executes these on Wrath (every retail path is behind
-- HasFeature(C_AUCTION_HOUSE)), but Lua still reads method references when
-- modules wire callbacks like :MapNonNilWithFunction(C_AuctionHouse.GetCancelCost).
-- Keep ordering and names aligned with vault/20_API_Compat/c-auctionhouse.md.
-- ----------------------------------------------------------------------------
do
	local CAH = _G.C_AuctionHouse
	CAH.GetCancelCost                 = CAH.GetCancelCost                 or _nil
	CAH.PostCommodity                 = CAH.PostCommodity                 or _noop
	CAH.PostItem                      = CAH.PostItem                      or _noop
	CAH.PlaceBid                      = CAH.PlaceBid                      or _noop
	CAH.ConfirmCommoditiesPurchase    = CAH.ConfirmCommoditiesPurchase    or _noop
	CAH.CloseAuctionHouse             = CAH.CloseAuctionHouse             or _noop
	CAH.GetItemCommodityStatus        = CAH.GetItemCommodityStatus        or _nil
	CAH.CalculateItemDeposit          = CAH.CalculateItemDeposit          or _nil
	CAH.CalculateCommodityDeposit     = CAH.CalculateCommodityDeposit     or _nil
	CAH.IsSellItemValid               = CAH.IsSellItemValid               or _false
	CAH.HasFullOwnedAuctionResults    = CAH.HasFullOwnedAuctionResults    or _false
	CAH.GetNumOwnedAuctions           = CAH.GetNumOwnedAuctions           or _zero
	CAH.GetOwnedAuctionInfo           = CAH.GetOwnedAuctionInfo           or _nil
	CAH.ReplicateItems                = CAH.ReplicateItems                or _noop
	CAH.MakeItemKey                   = CAH.MakeItemKey                   or _nil
	CAH.HasFullBrowseResults          = CAH.HasFullBrowseResults          or _false
	CAH.HasFullItemSearchResults      = CAH.HasFullItemSearchResults      or _false
	CAH.HasFullCommoditySearchResults = CAH.HasFullCommoditySearchResults or _false
	CAH.GetNumItemSearchResults       = CAH.GetNumItemSearchResults       or _zero
	CAH.GetNumCommoditySearchResults  = CAH.GetNumCommoditySearchResults  or _zero
	CAH.GetNumReplicateItems          = CAH.GetNumReplicateItems          or _zero
	CAH.GetBrowseResults              = CAH.GetBrowseResults              or _empty
	CAH.GetReplicateItemLink          = CAH.GetReplicateItemLink          or _nil
	CAH.GetReplicateItemInfo          = CAH.GetReplicateItemInfo          or _nil
	CAH.GetItemSearchResultInfo       = CAH.GetItemSearchResultInfo       or _nil
	CAH.GetCommoditySearchResultInfo  = CAH.GetCommoditySearchResultInfo  or _nil
	CAH.GetItemKeyInfo                = CAH.GetItemKeyInfo                or _nil
	CAH.GetExtraBrowseInfo            = CAH.GetExtraBrowseInfo            or _nil
	CAH.GetQuoteDurationRemaining     = CAH.GetQuoteDurationRemaining     or _zero
	CAH.GetAuctionItemSubClasses      = CAH.GetAuctionItemSubClasses      or _empty
end

-- ----------------------------------------------------------------------------
-- C_TradeSkillUI stub methods
-- 60 call sites in LibTSMWoW/Source/API/TradeSkill.lua. All gated behind
-- HasFeature(C_TRADE_SKILL_UI) at runtime — these no-ops only protect the
-- module-load reads (default values for filters, etc).
-- Keep in sync with vault/20_API_Compat/c-tradeskillui.md.
-- ----------------------------------------------------------------------------
do
	local CTSU = _G.C_TradeSkillUI
	CTSU.OpenTradeSkill                  = CTSU.OpenTradeSkill                  or _noop
	CTSU.CloseTradeSkill                 = CTSU.CloseTradeSkill                 or _noop
	CTSU.IsNPCCrafting                   = CTSU.IsNPCCrafting                   or _false
	CTSU.IsTradeSkillGuild               = CTSU.IsTradeSkillGuild               or _false
	CTSU.IsTradeSkillLinked              = CTSU.IsTradeSkillLinked              or _false
	CTSU.IsTradeSkillReady               = CTSU.IsTradeSkillReady               or _false
	CTSU.IsDataSourceChanging            = CTSU.IsDataSourceChanging            or _false
	CTSU.GetTradeSkillListLink           = CTSU.GetTradeSkillListLink           or _nil
	CTSU.GetBaseProfessionInfo           = CTSU.GetBaseProfessionInfo           or _nil
	CTSU.GetQualitiesForRecipe           = CTSU.GetQualitiesForRecipe           or _empty
	CTSU.GetShowUnlearned                = CTSU.GetShowUnlearned                or _false
	CTSU.SetShowLearned                  = CTSU.SetShowLearned                  or _noop
	CTSU.SetShowUnlearned                = CTSU.SetShowUnlearned                or _noop
	CTSU.GetOnlyShowMakeableRecipes      = CTSU.GetOnlyShowMakeableRecipes      or _false
	CTSU.SetOnlyShowMakeableRecipes      = CTSU.SetOnlyShowMakeableRecipes      or _noop
	CTSU.GetOnlyShowSkillUpRecipes       = CTSU.GetOnlyShowSkillUpRecipes       or _false
	CTSU.SetOnlyShowSkillUpRecipes       = CTSU.SetOnlyShowSkillUpRecipes       or _noop
	CTSU.AnyRecipeCategoriesFiltered     = CTSU.AnyRecipeCategoriesFiltered     or _false
	CTSU.ClearRecipeCategoryFilter       = CTSU.ClearRecipeCategoryFilter       or _noop
	CTSU.AreAnyInventorySlotsFiltered    = CTSU.AreAnyInventorySlotsFiltered    or _false
	CTSU.ClearInventorySlotFilter        = CTSU.ClearInventorySlotFilter        or _noop
	CTSU.IsAnyRecipeFromSource           = CTSU.IsAnyRecipeFromSource           or _false
	CTSU.IsRecipeSourceTypeFiltered      = CTSU.IsRecipeSourceTypeFiltered      or _false
	CTSU.ClearRecipeSourceTypeFilter     = CTSU.ClearRecipeSourceTypeFilter     or _noop
	CTSU.GetRecipeItemNameFilter         = CTSU.GetRecipeItemNameFilter         or _nil
	CTSU.SetRecipeItemNameFilter         = CTSU.SetRecipeItemNameFilter         or _noop
	CTSU.GetRecipeItemLevelFilter        = CTSU.GetRecipeItemLevelFilter        or function() return 0, 0 end
	CTSU.SetRecipeItemLevelFilter        = CTSU.SetRecipeItemLevelFilter        or _noop
	CTSU.GetRecipeQualityItemIDs         = CTSU.GetRecipeQualityItemIDs         or _empty
	CTSU.GetRecipeItemLink               = CTSU.GetRecipeItemLink               or _nil
	CTSU.GetRecipeInfo                   = CTSU.GetRecipeInfo                   or _nil
	CTSU.GetRecipeCooldown               = CTSU.GetRecipeCooldown               or _nil
	CTSU.GetItemCraftedQualityByItemInfo = CTSU.GetItemCraftedQualityByItemInfo or _nil
	CTSU.GetRecipeSchematic              = CTSU.GetRecipeSchematic              or _empty
	CTSU.GetFilteredRecipeIDs            = CTSU.GetFilteredRecipeIDs            or _empty
	CTSU.GetRecipeDescription            = CTSU.GetRecipeDescription            or _nil
	CTSU.GetCraftingOperationInfo        = CTSU.GetCraftingOperationInfo        or _nil
	CTSU.GetSalvagableItemIDs            = CTSU.GetSalvagableItemIDs            or _empty
	CTSU.GetCategoryInfo                 = CTSU.GetCategoryInfo                 or _nil
	CTSU.GetRecipeRequirements           = CTSU.GetRecipeRequirements           or _empty
	CTSU.GetRecipeQualityReagentLink     = CTSU.GetRecipeQualityReagentLink     or _nil
	CTSU.CraftEnchant                    = CTSU.CraftEnchant                    or _noop
	CTSU.CraftSalvage                    = CTSU.CraftSalvage                    or _noop
end

-- ============================================================================
-- C_EncodingUtil (retail-only base64/CBOR — used by External/LibBonusId/Data.lua)
-- Bonus IDs don't exist on 3.3.5 (introduced in WoD 6.0), but the lib still
-- has to load. Return a structurally-correct empty BonusIdData from DeserializeCBOR
-- so Lib.LoadData stores empty tables instead of crashing. All Filter*/Calculate
-- entry points then short-circuit harmlessly through the empty data.
-- ============================================================================

if not _G.C_EncodingUtil then
	_G.C_EncodingUtil = {}
end
do
	local CEU = _G.C_EncodingUtil
	CEU.DecodeBase64       = CEU.DecodeBase64       or function() return "" end
	CEU.DecompressString   = CEU.DecompressString   or function() return "" end
	CEU.EncodeBase64       = CEU.EncodeBase64       or function() return "" end
	CEU.CompressString     = CEU.CompressString     or function() return "" end
	CEU.SerializeCBOR      = CEU.SerializeCBOR      or function() return "" end
	if not CEU.DeserializeCBOR then
		CEU.DeserializeCBOR = function()
			local patch, buildNum = GetBuildInfo()
			return {
				version            = 2,
				build              = tostring(patch).."."..tostring(buildNum),
				squishMax          = 0,
				squishCurve        = {},
				bonuses            = {},
				curves             = {},
				contentTuning      = {},
				itemRangeStarts    = {},
				itemRangeLevels    = {},
				midnightItems      = {},
				tooltipBonuses     = {},
				treeBonusLists     = {},
				itemTreeBonuses    = {},
				levelToBonusString = {},
			}
		end
	end
end

-- ============================================================================
-- C_Item.GetItemClassInfo (ClassicAPI provides GetItemSubClassInfo but not this)
-- Bridges to the global 3.3.5 GetItemClassInfo if present, otherwise static map.
-- ============================================================================

if not _G.C_Item then _G.C_Item = {} end
if not _G.C_Item.GetItemClassInfo then
	if type(_G.GetItemClassInfo) == "function" then
		_G.C_Item.GetItemClassInfo = _G.GetItemClassInfo
	else
		local CLASS_NAMES = {
			[0]  = "Consumable",
			[1]  = "Container",
			[2]  = "Weapon",
			[3]  = "Gem",
			[4]  = "Armor",
			[5]  = "Reagent",
			[6]  = "Projectile",
			[7]  = "Trade Goods",
			[8]  = "Recipe",
			[9]  = "Quest",
			[11] = "Quiver",
			[12] = "Quest",
			[13] = "Key",
			[15] = "Miscellaneous",
			[16] = "Glyph",
		}
		_G.C_Item.GetItemClassInfo = function(classID) return CLASS_NAMES[classID] end
	end
end

-- ============================================================================
-- Profession skill-rank constants (Cataclysm/MoP names missing on 3.3.5)
-- TradeSkill.lua builds a CLASSIC_SUB_NAMES table keyed by these globals; any
-- nil key crashes the table literal with "table index is nil".
-- ============================================================================

_G.APPRENTICE   = _G.APPRENTICE   or "Apprentice"
_G.JOURNEYMAN   = _G.JOURNEYMAN   or "Journeyman"
_G.EXPERT       = _G.EXPERT       or "Expert"
_G.ARTISAN      = _G.ARTISAN      or "Artisan"
_G.MASTER       = _G.MASTER       or "Master"
_G.GRAND_MASTER = _G.GRAND_MASTER or "Grand Master"
_G.ILLUSTRIOUS  = _G.ILLUSTRIOUS  or "Illustrious Grand Master" -- Cata
_G.ZEN_MASTER   = _G.ZEN_MASTER   or "Zen Master"               -- MoP

-- ============================================================================
-- LE_GAME_ERR_AUCTION_* constants (post-WotLK enums; ERR_* strings exist on 3.3.5)
-- AuctionHouseWrapper concatenates these into event keys like "UI_ERROR_MESSAGE/<id>".
-- On 3.3.5 the UI_ERROR_MESSAGE event payload is the localized string itself,
-- so mapping LE_GAME_ERR_X → ERR_X keeps the keys consistent.
-- ============================================================================

_G.LE_GAME_ERR_AUCTION_DATABASE_ERROR = _G.LE_GAME_ERR_AUCTION_DATABASE_ERROR or _G.ERR_AUCTION_DATABASE_ERROR or "ERR_AUCTION_DATABASE_ERROR"
_G.LE_GAME_ERR_AUCTION_HIGHER_BID     = _G.LE_GAME_ERR_AUCTION_HIGHER_BID     or _G.ERR_AUCTION_HIGHER_BID     or "ERR_AUCTION_HIGHER_BID"
_G.LE_GAME_ERR_ITEM_NOT_FOUND         = _G.LE_GAME_ERR_ITEM_NOT_FOUND         or _G.ERR_ITEM_NOT_FOUND         or "ERR_ITEM_NOT_FOUND"
_G.LE_GAME_ERR_AUCTION_BID_OWN        = _G.LE_GAME_ERR_AUCTION_BID_OWN        or _G.ERR_AUCTION_BID_OWN        or "ERR_AUCTION_BID_OWN"
_G.LE_GAME_ERR_NOT_ENOUGH_MONEY       = _G.LE_GAME_ERR_NOT_ENOUGH_MONEY       or _G.ERR_NOT_ENOUGH_MONEY       or "ERR_NOT_ENOUGH_MONEY"
_G.LE_GAME_ERR_ITEM_MAX_COUNT         = _G.LE_GAME_ERR_ITEM_MAX_COUNT         or _G.ERR_ITEM_MAX_COUNT         or "ERR_ITEM_MAX_COUNT"
_G.LE_GAME_ERR_AUCTION_BID_INCREMENT  = _G.LE_GAME_ERR_AUCTION_BID_INCREMENT  or _G.ERR_AUCTION_BID_INCREMENT  or "ERR_AUCTION_BID_INCREMENT"
_G.LE_GAME_ERR_AUCTION_HOUSE_DISABLED = _G.LE_GAME_ERR_AUCTION_HOUSE_DISABLED or _G.ERR_AUCTION_HOUSE_DISABLED or "ERR_AUCTION_HOUSE_DISABLED"
_G.LE_GAME_ERR_AUCTION_REPAIR_ITEM    = _G.LE_GAME_ERR_AUCTION_REPAIR_ITEM    or _G.ERR_AUCTION_REPAIR_ITEM    or "ERR_AUCTION_REPAIR_ITEM"
_G.LE_GAME_ERR_AUCTION_LIMITED_DURATION_ITEM = _G.LE_GAME_ERR_AUCTION_LIMITED_DURATION_ITEM or _G.ERR_AUCTION_LIMITED_DURATION_ITEM or "ERR_AUCTION_LIMITED_DURATION_ITEM"
_G.LE_GAME_ERR_AUCTION_USED_CHARGES   = _G.LE_GAME_ERR_AUCTION_USED_CHARGES   or _G.ERR_AUCTION_USED_CHARGES   or "ERR_AUCTION_USED_CHARGES"
_G.LE_GAME_ERR_AUCTION_WRAPPED_ITEM   = _G.LE_GAME_ERR_AUCTION_WRAPPED_ITEM   or _G.ERR_AUCTION_WRAPPED_ITEM   or "ERR_AUCTION_WRAPPED_ITEM"
_G.LE_GAME_ERR_AUCTION_BOUND_ITEM     = _G.LE_GAME_ERR_AUCTION_BOUND_ITEM     or _G.ERR_AUCTION_BOUND_ITEM     or "ERR_AUCTION_BOUND_ITEM"
_G.LE_GAME_ERR_AUCTION_CONJURED_ITEM  = _G.LE_GAME_ERR_AUCTION_CONJURED_ITEM  or _G.ERR_AUCTION_CONJURED_ITEM  or "ERR_AUCTION_CONJURED_ITEM"
_G.LE_GAME_ERR_AUCTION_QUEST_ITEM     = _G.LE_GAME_ERR_AUCTION_QUEST_ITEM     or _G.ERR_AUCTION_QUEST_ITEM     or "ERR_AUCTION_QUEST_ITEM"
_G.LE_GAME_ERR_NOT_IN_AUCTION_HOUSE   = _G.LE_GAME_ERR_NOT_IN_AUCTION_HOUSE   or _G.ERR_NOT_IN_AUCTION_HOUSE   or "ERR_NOT_IN_AUCTION_HOUSE"
_G.LE_GAME_ERR_AUCTION_ENOUGH_ITEMS   = _G.LE_GAME_ERR_AUCTION_ENOUGH_ITEMS   or _G.ERR_AUCTION_ENOUGH_ITEMS   or "ERR_AUCTION_ENOUGH_ITEMS"

-- ============================================================================
-- GetAutoCompleteRealms — retail API, used by External/EmbeddedLibs/LibRealmInfo.
-- ============================================================================

if type(_G.GetAutoCompleteRealms) ~= "function" then
	_G.GetAutoCompleteRealms = function() return {} end
end

-- ============================================================================
-- C_Item.GetItemSubClassInfo override — ClassicAPI's implementation does
-- `subClassID >= 0` which crashes when 3.3.5's GetAuctionItemSubClasses returns
-- localized strings instead of numeric IDs. Wrap to short-circuit non-number
-- subClassID by returning it as the name.
-- ============================================================================

do
	local orig = _G.C_Item and _G.C_Item.GetItemSubClassInfo
	if orig then
		_G.C_Item.GetItemSubClassInfo = function(classID, subClassID)
			if type(subClassID) ~= "number" then
				return subClassID, false
			end
			return orig(classID, subClassID)
		end
	end
end

-- ============================================================================
-- GetAddOnEnableState — retail (introduced post-WotLK). On 3.3.5, IsAddOnLoaded
-- + GetAddOnInfo cover what TSM needs. Returns retail's tri-state (0/1/2).
-- Also expose under C_AddOns for code paths that reach for the namespaced form.
-- ============================================================================

if type(_G.GetAddOnEnableState) ~= "function" then
	_G.GetAddOnEnableState = function(name_or_character, maybe_name)
		-- Retail signature: GetAddOnEnableState(character, name). Some callers
		-- pass (name, character). Accept either.
		local n1, n2 = name_or_character, maybe_name
		local name = (type(n2) == "string" and n2 ~= "" and n2) or (type(n1) == "string" and n1) or nil
		if not name then return 0 end
		-- Loaded implies enabled.
		if _G.IsAddOnLoaded(name) then return 2 end
		-- Enabled-but-not-yet-loaded (load-on-demand, or an addon that loads AFTER
		-- this one alphabetically — the backport loads Accounting/Crafting after the
		-- core) must still report "All" (2), not "Some" (1), or Addon.IsEnabled()
		-- would wrongly treat it as disabled. Use GetAddOnInfo's enabled flag.
		-- pcall: GetAddOnInfo errors on unknown addon names on 3.3.5.
		local ok, _, _, _, enabled = pcall(_G.GetAddOnInfo, name)
		if not ok then return 0 end
		return enabled and 2 or 0
	end
end
if _G.C_AddOns then
	_G.C_AddOns.GetAddOnEnableState = _G.C_AddOns.GetAddOnEnableState or _G.GetAddOnEnableState
end
-- Enum.AddOnEnableState.All — used by Addon.IsEnabled() comparison
_G.Enum = _G.Enum or {}
_G.Enum.AddOnEnableState = _G.Enum.AddOnEnableState or { None = 0, Some = 1, All = 2 }

-- ============================================================================
-- CancelEmote — retail (added in Cataclysm 4.0). No-op on 3.3.5.
-- ============================================================================

if type(_G.CancelEmote) ~= "function" then
	_G.CancelEmote = function() end
end

-- ============================================================================
-- CalculateTotalNumberOfFreeBagSlots — retail (post-WotLK). Sum over backpack + 4 bags.
-- ============================================================================

if type(_G.CalculateTotalNumberOfFreeBagSlots) ~= "function" then
	_G.CalculateTotalNumberOfFreeBagSlots = function()
		local total = 0
		local maxBag = _G.NUM_BAG_SLOTS or 4
		for bag = 0, maxBag do
			total = total + ((_G.GetContainerNumFreeSlots and _G.GetContainerNumFreeSlots(bag)) or 0)
		end
		return total
	end
end

-- ============================================================================
-- session 10 / Этап А — extra C_* polyfills for paths the audit found
-- ClassicAPI already covers C_Item.GetItemInfo/Instant/Count/SubClassInfo/Link/ID
-- and C_Spell.GetSpellInfo/Texture/Link. Here we patch the gaps that audit
-- session 9 turned up (handoff.md §P0 #1–20, #70).
-- ============================================================================

do
	local CI = _G.C_Item or {}
	_G.C_Item = CI
	-- C_Item.GetItemFamily(itemInfo) -> int (bag type bitmask)
	if not CI.GetItemFamily and type(_G.GetItemFamily) == "function" then
		CI.GetItemFamily = _G.GetItemFamily
	end
	-- C_Item.GetDetailedItemLevelInfo(itemLink) -> effectiveLevel, isPreview, baseLevel
	if not CI.GetDetailedItemLevelInfo then
		CI.GetDetailedItemLevelInfo = function(itemInfo)
			local _, _, _, ilvl = _G.GetItemInfo(itemInfo)
			return ilvl or 0, false, ilvl or 0
		end
	end
	-- Some callers reach through C_Item.GetItemQualityByID etc. — ClassicAPI provides them.
end

-- C_PlayerInfo: only one TSM call site (Container.lua:123)
_G.C_PlayerInfo = _G.C_PlayerInfo or {}
_G.C_PlayerInfo.HasAccountInventoryLock = _G.C_PlayerInfo.HasAccountInventoryLock or _false
_G.C_PlayerInfo.IsPlayerInChromieTime   = _G.C_PlayerInfo.IsPlayerInChromieTime   or _false
_G.C_PlayerInfo.CanPlayerEnterChromieTime = _G.C_PlayerInfo.CanPlayerEnterChromieTime or _false

-- C_Mail: TSM reads .GetCraftingOrderMailInfo / .IsCommandPending
_G.C_Mail = _G.C_Mail or {}
_G.C_Mail.IsCommandPending          = _G.C_Mail.IsCommandPending          or _false
_G.C_Mail.GetCraftingOrderMailInfo  = _G.C_Mail.GetCraftingOrderMailInfo  or _nil
_G.C_Mail.HasInboxMoney             = _G.C_Mail.HasInboxMoney             or _zero
_G.C_Mail.GetSendMailCurrentPrice   = _G.C_Mail.GetSendMailCurrentPrice   or _zero

-- C_PetJournal: 3 TSM call sites in Item.lua, 1 in TradeSkill.lua
_G.C_PetJournal = _G.C_PetJournal or {}
_G.C_PetJournal.GetNumPetSources    = _G.C_PetJournal.GetNumPetSources    or _zero
_G.C_PetJournal.GetPetInfoBySpeciesID = _G.C_PetJournal.GetPetInfoBySpeciesID or _nil
_G.C_PetJournal.GetPetInfoByPetID   = _G.C_PetJournal.GetPetInfoByPetID   or _nil
_G.C_PetJournal.GetPetInfoByItemID  = _G.C_PetJournal.GetPetInfoByItemID  or _nil
_G.C_PetJournal.FindPetIDByName     = _G.C_PetJournal.FindPetIDByName     or _nil

-- C_CurrencyInfo: replaces global GetCurrencyInfo (1 TSM call site)
_G.C_CurrencyInfo = _G.C_CurrencyInfo or {}
if not _G.C_CurrencyInfo.GetCurrencyInfo then
	_G.C_CurrencyInfo.GetCurrencyInfo = function(id)
		if type(_G.GetCurrencyInfo) == "function" then
			local name, amount, texture, _, _, totalMax, isDiscovered = _G.GetCurrencyInfo(id)
			if not name then return nil end
			return {
				name = name,
				quantity = amount or 0,
				iconFileID = texture,
				maxQuantity = totalMax or 0,
				discovered = isDiscovered and true or false,
			}
		end
		return nil
	end
end
_G.C_CurrencyInfo.GetCurrencyLink = _G.C_CurrencyInfo.GetCurrencyLink or _G.GetCurrencyLink or _nil

-- C_Bank: namespace exists as empty stub from earlier block. Add methods so
-- read-through doesn't crash (every retail path is HasFeature-gated anyway).
do
	local CB = _G.C_Bank
	CB.IsItemAllowedInBankType    = CB.IsItemAllowedInBankType    or _false
	CB.FetchDepositedMoney        = CB.FetchDepositedMoney        or _zero
	CB.AutoDepositItemsIntoBank   = CB.AutoDepositItemsIntoBank   or _noop
	CB.HasMaxBankTabs             = CB.HasMaxBankTabs             or _false
	CB.PurchaseBankTab            = CB.PurchaseBankTab            or _noop
	CB.CanPurchaseBankTab         = CB.CanPurchaseBankTab         or _false
	CB.CloseBankFrame             = CB.CloseBankFrame             or _noop
	CB.FetchPurchasedBankTabData  = CB.FetchPurchasedBankTabData  or _empty
end

-- TooltipDataProcessor — retail-only (10.x). Used by some retail UI hooks.
_G.TooltipDataProcessor = _G.TooltipDataProcessor or {}
_G.TooltipDataProcessor.AddTooltipPostCall = _G.TooltipDataProcessor.AddTooltipPostCall or _noop

-- Enum.BankType — retail constants for Warband bank flow. Guards exist around
-- the actual calls (Container.CanAccessWarbank()) but the constants are still
-- read at module-load when building call tables.
_G.Enum.BankType = _G.Enum.BankType or { Character = 0, Account = 1 }

-- Enum.ItemCommodityStatus — read at AuctionHouseWrapper module load.
_G.Enum.ItemCommodityStatus = _G.Enum.ItemCommodityStatus or { Unknown = 0, Item = 1, Commodity = 2 }

-- Enum.PlayerInteractionType subset used by tooltip/AH wrappers
_G.Enum.PlayerInteractionType = _G.Enum.PlayerInteractionType or {
	None         = 0,
	TradePartner = 1,
	Item         = 2,
	Gossip       = 3,
	QuestGiver   = 4,
	Merchant     = 5,
	Auctioneer   = 8,
	Banker       = 9,
	GuildBanker  = 10,
	MailInfo     = 17,
}

-- ============================================================================
-- AnimationGroup:SetToFinalAlpha — retail-only method used by LibDBIcon-1.0:270.
-- Patch the AnimationGroup metatable with a no-op so the call is harmless.
-- ============================================================================

do
	local ok, animGroup = pcall(function()
		return CreateFrame("Frame"):CreateAnimationGroup()
	end)
	if ok and animGroup then
		local meta = getmetatable(animGroup)
		local idx = meta and meta.__index
		if type(idx) == "table" and not idx.SetToFinalAlpha then
			idx.SetToFinalAlpha = function() end
		end
	end
end

-- ============================================================================
-- date() — global date function (retail API, wraps os.date)
-- ============================================================================

if not _G.date then
	_G.date = function(...)
		return os and os.date and os.date(...) or "??:??:??"
	end
end

-- ============================================================================
-- SetLanguageForAllChatTabs — missing on 3.3.5 (added later in retail).
-- WeakAuras auras and other scripts call this global. Polyfill it so they
-- don't error out when it's nil.
-- ============================================================================

do
	local function SetLanguageForAllChatTabs_Impl(lang)
		if not lang or lang == "" then return end
		if not GetNumLanguages or not GetLanguageByIndex or not NUM_CHAT_WINDOWS then return end
		local targetLang, targetID
		for i = 1, GetNumLanguages() do
			local name, id = GetLanguageByIndex(i)
			if name == lang then targetLang, targetID = name, id break end
		end
		if not targetLang then return end
		for i = 1, NUM_CHAT_WINDOWS do
			local cf = _G["ChatFrame" .. i]
			if cf and cf.editBox then
				cf.editBox.language = targetLang
				if targetID then cf.editBox.languageID = targetID end
			end
		end
	end

	if type(_G.SetLanguageForAllChatTabs) ~= "function" then
		_G.SetLanguageForAllChatTabs = SetLanguageForAllChatTabs_Impl
	end
end

-- ============================================================================
-- Blizzard_DebugTools ScriptErrorsFrame guard.
-- On 3.3.5a the stock error display is buggy: ScriptErrorsFrame_Update (line ~432)
-- can call format() with a nil argument and throw, which cascades into a crash
-- *while displaying another addon's error* (e.g. DBM-Core enabling via CombatLog).
-- The visible "bad argument #6 to 'format'" is this secondary crash, not the root.
-- Wrap the frame's entry points in pcall so a broken native error frame can never
-- crash the client. Errors are still captured by TSM's debug log (TSMDebugDB) and
-- the default chat error output. Blizzard_DebugTools is LoadOnDemand (loads on the
-- first script error), so guard now (if already loaded) and again on ADDON_LOADED.
-- ============================================================================

do
	local function guardScriptErrorsFrame()
		if type(_G.ScriptErrorsFrame_OnError) == "function" and not _G.__tsmGuardedOnError then
			local orig = _G.ScriptErrorsFrame_OnError
			_G.ScriptErrorsFrame_OnError = function(...)
				local ok, err = pcall(orig, ...)
				if not ok and _G.TSMDBG and _G.TSMDBG.LogErr then
					_G.TSMDBG.LogErr("ScriptErrorsFrame_OnError", err)
				end
			end
			_G.__tsmGuardedOnError = true
		end
		if type(_G.ScriptErrorsFrame_Update) == "function" and not _G.__tsmGuardedUpdate then
			local orig = _G.ScriptErrorsFrame_Update
			_G.ScriptErrorsFrame_Update = function(...)
				local ok = pcall(orig, ...)
				return ok
			end
			_G.__tsmGuardedUpdate = true
		end
	end

	guardScriptErrorsFrame()
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(_, _, addon)
		if addon == "Blizzard_DebugTools" then
			guardScriptErrorsFrame()
		end
	end)
end

-- ============================================================================
-- SOUNDKIT: fill in keys TSM uses that the shared !!!ClassicAPI polyfill misses
-- ============================================================================
-- On 3.3.5a PlaySound() expects a string sound name. TSM references SOUNDKIT.ITEM_REPAIR
-- (e.g. Vendoring repair button), which the shared polyfill doesn't define, so the value was
-- nil and PlaySound(nil) raised 'Usage: PlaySound("sound")', aborting the repair handler.
do
	_G.SOUNDKIT = _G.SOUNDKIT or {}
	_G.SOUNDKIT.ITEM_REPAIR = _G.SOUNDKIT.ITEM_REPAIR or "ITEM_REPAIR"
	-- Guard PlaySound so a nil/!-found sound key can never abort a handler on this client
	if not _G.__tsmPlaySoundGuarded and type(_G.PlaySound) == "function" then
		local origPlaySound = _G.PlaySound
		_G.PlaySound = function(sound, ...)
			if sound == nil then
				return
			end
			return pcall(origPlaySound, sound, ...)
		end
		_G.__tsmPlaySoundGuarded = true
	end
end

-- ============================================================================
-- ColorPickerFrame retail-API polyfills (GetColorAlpha / SetColorAlpha) +
-- OpacitySliderFrame:SetValue nil guard.
--
-- Modern Ace3 (AceGUIWidget-ColorPicker, bundled in ElvUI) and helpers such as
-- UltimateMouseCursor's SetupColorPickerAndShow assume the retail color-picker
-- contract. On 3.3.5a ColorPickerFrame has no GetColorAlpha/SetColorAlpha, so
-- their swatch/opacity callbacks throw:
--   AceGUIWidget-ColorPicker.lua: attempt to call method 'GetColorAlpha' (a nil value)
-- Separately, the stock OpacitySliderFrame:OnShow runs
--   OpacitySliderFrame:SetValue(ColorPickerFrame.opacity)
-- and when a retail-style caller opens the picker without seeding .opacity,
-- SetValue(nil) raises "Usage: OpacitySliderFrame:SetValue(value)".
--
-- ColorPickerFrame / OpacitySliderFrame are global Blizzard frames created in
-- FrameXML before any addon loads, so define-if-missing shims here fix every
-- addon that relies on the retail contract. On 3.3.5a the opacity slider value
-- equals the alpha that was set (OnShow assigns the slider directly from
-- .opacity, no inversion), which matches what retail GetColorAlpha returns.
-- ============================================================================

do
	local cpf = _G.ColorPickerFrame
	if type(cpf) == "table" then
		if not cpf.GetColorAlpha then
			function cpf:GetColorAlpha()
				if not self.hasOpacity then
					return 1
				end
				local slider = _G.OpacitySliderFrame
				local v = slider and slider.GetValue and slider:GetValue()
				if type(v) ~= "number" then
					v = self.opacity
				end
				if type(v) ~= "number" then
					return 1
				end
				return v
			end
		end

		if not cpf.SetColorAlpha then
			function cpf:SetColorAlpha(alpha)
				if type(alpha) ~= "number" then
					return
				end
				self.hasOpacity = true
				self.opacity = alpha
				local slider = _G.OpacitySliderFrame
				if slider and slider.SetValue then
					slider:SetValue(alpha)
				end
			end
		end
	end

	local slider = _G.OpacitySliderFrame
	if slider and slider.SetValue and not slider.__tsmSetValueGuarded then
		local baseSetValue = slider.SetValue
		slider.SetValue = function(self, value, ...)
			if type(value) ~= "number" then
				value = 1
			end
			return baseSetValue(self, value, ...)
		end
		slider.__tsmSetValueGuarded = true
	end
end
