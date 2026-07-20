-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local Schema = LibTSMSystem:Init("AddonSettings.Schema")
local Settings = LibTSMSystem:From("LibTSMTypes"):Include("Settings")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the settings schema.
---@return SettingsSchema
function Schema.Get()
	-- Changelog:
	-- [10] first TSM4 version - combined all module settings into a single DB
	-- [11] added profile.internalData.createdDefaultOperations
	-- [12] added global.shoppingOptions.pctSource
	-- [13] added profile.internalData.{managementGroupTreeContext,auctioningGroupTreeContext,shoppingGroupTreeContext}
	-- [14] added global.userData.savedAuctioningSearches
	-- [15] added global.coreOptions.bankUITab, profile.coreOptions.{bankUIBankFramePosition,bankUIGBankFramePosition}
	-- [16] moved profile.coreOptions.{bankUIBankFramePosition,bankUIGBankFramePosition} to profile.internalData.{bankUIBankFramePosition,bankUIGBankFramePosition}
	-- [17] added global.internalData.{mainUIFrameContext,auctionUIFrameContext,craftingUIFrameContext}
	-- [18] removed global.internalData.itemStringLookup
	-- [19] added sync scope (initially with internalData.{classKey,bagQuantity,bankQuantity,reagentBankQuantity,auctionQuantity,mailQuantity}), removed factionrealm.internalData.{syncMetadata,accountKey,inventory,characters} and factionrealm.coreOptions.syncAccounts, added global.debug.chatLoggingEnabled
	-- [20] added global.tooltipOptions.enabled
	-- [21] added global.craftingOptions.{profitPercent,questSmartCrafting,queueSort}
	-- [22] added global.coreOptions.cleanGuildBank
	-- [23] changed global.shoppingOptions.maxDeSearchPercent default to 100
	-- [24] added global.auctioningOptions.{showAuctionDBTab,openAllBags,ahRowDisplay}
	-- [25] split realm.internalData.goldLog into sync.internalData.goldLog and factionrealm.internalData.guildGoldLog
	-- [26] added profile.internalData.{shoppingTabGroupContext,auctioningTabGroupContext}
	-- [27] added char.internalData.craftingCooldowns
	-- [28] added global.internalData.mailingUIFrameContext
	-- [29] added global.internalData.vendoringUIFrameContext
	-- [30] added global.internalData.bankingUIFrameContext
	-- [31] changed global.internalData.bankingUIFrameContext default (isOpen = true), added profile.internalData.{bankingWarehousingGroupTreeContext,bankingAuctioningGroupTreeContext,bankingMailingGroupTreeContext}
	-- [32] removed factionrealm.internalData.gathering, added factionrealm.internalData.gatheringContext.{crafter,professions}, added profile.gatheringOptions.sources
	-- [33] added global.internalData.taskListUIFrameContext
	-- [34] removed realm.internalData.{lastAuctionDBCompleteScan,lastAuctionDBSaveTime,auctionDBScanData}
	-- [35] added factionrealm.userData.craftingCooldownIgnore
	-- [36] removed factionrealm.internalData.playerProfessions and added sync.internalData.playerProfessions
	-- [37] removed global.auctioningOptions.showAuctionDBTab
	-- [38] removed global.mailingOptions.{defaultMailTab,autoCheck,displayMoneyCollected,deleteEmptyNPCMail,showReloadBtn,sendDelay,defaultPage}, added global.mailingOptions.recentlyMailedList
	-- [39] added profile.internalData.{craftingGroupTreeContext,mailingGroupTreeContext,vendoringGroupTreeContext,importGroupTreeContext}
	-- [40] removed global.accountingOptions.{timeFormat,mvSource}
	-- [41] removed global.coreOptions.groupPriceSource
	-- [42] removed global.vendoringOptions.defaultMerchantTab
	-- [43] removed global.coreOptions.{moveDelay,bankUITab}, removed global.auctioningOptions.{openAllBags,ahRowDisplay}, removed global.craftingOptions.{profitPercent,questSmartCrafting,queueSort}, removed global.destroyingOptions.{logDays,timeFormat}, removed global.vendoringOptions.{autoSellTrash,qsHideGrouped,qsHideSoulbound,qsBatchSize,defaultPage,qsMaxMarketValue,qsDestroyValue}, removed profile.coreOptions.{cleanBags,cleanBank,cleanReagentBank,cleanGuildBank}
	-- [44] changed global.internalData.{mainUIFrameContext,auctionUIFrameContext,craftingUIFrameContext,destroyingUIFrameContext,mailingUIFrameContext,vendoringUIFrameContext,bankingUIFrameContext} default (added "scale = 1")
	-- [45] added char.internalData.auctionSaleHints
	-- [46] added global.shoppingOptions.{buyoutConfirm,buyoutAlertSource}
	-- [47] added factionrealm.internalData.expiringMail and factionrealm.internalData.expiringAuction
	-- [48] added profile.internalData.exportGroupTreeContext
	-- [49] added factionrealm.internalData.{mailDisenchantablesChar,mailExcessGoldChar,mailExcessGoldLimit}
	-- [50] added factionrealm.internalData.{csvAuctionDBScan,auctionDBScanTime,auctionDBScanHash}
	-- [51-53] resetting factionrealm.internalData.crafts
	-- [54] removed global.coreOptions.{tsmItemTweetEnabled,auctionSaleEnabled,auctionBuyEnabled}
	-- [55] added global.auctionUIContext.{auctioningSelectionDividedContainer,auctioningBagScrollingTable,auctioningLogScrollingTable,auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingSelectionDividedContainer,shoppingAuctionScrollingTable,sniperScrollingTable,frame,showDefault,shoppingSearchesTabGroup}
	--  added global.bankingUIContext.{frame,isOpen,tab}
	--  added global.craftingUIContext.{craftsScrollingTable,matsScrollingTable,gatheringDividedContainer,gatheringScrollingTable,professionScrollingTable,frame,showDefault,professionDividedContainer}
	--  added global.destroyingUIContext.itemsScrollingTable
	--  added global.mailingUIContext.{mailsScrollingTable,frame,showDefault}
	--  added global.mainUIContext.{ledgerDetailScrollingTable,ledgerInventoryScrollingTable,ledgerAuctionsScrollingTable,ledgerOtherScrollingTable,ledgerTransactionsScrollingTable,ledgerResaleScrollingTable,frame,dashboardDividedContainer,groupsDividedContainer,operationsDividedContainer,importExportDividedContainer}
	--  added global.taskListUIContext.{frame,isOpen}
	--  added global.vendoringUIContext.{buyScrollingTable,buybackScrollingTable,sellScrollingTable,frame,showDefault}
	--  added profile.mainUIContext.{groupsManagementGroupTree,importGroupTree,exportGroupTree}
	--  added profile.auctionUIContext.{auctioningTabGroup,auctioningGroupTree,shoppingGroupTree}
	--  added profile.bankingUIContext.{warehousingGroupTree,auctioningGroupTree,mailingGroupTree}
	--  added profile.craftingUIContext.groupTree
	--  added profile.mailingUIContext.groupTree
	--  added profile.vendoringUIContext.groupTree
	--  removed profile.internalData.{auctioningTabGroupContext,auctioningGroupTreeContext,managementGroupTreeContext,shoppingGroupTreeContext,importGroupTreeContext,exportGroupTreeContext,bankingUIFrameContext,craftingUIFrameContext,auctionUIFrameContext,mailingUIFrameContext,vendoringUIFrameContext,destroyingUIFrameContext,mainUIFrameContext,taskListUIFrameContext}
	-- [56] added factionrealm.internalData.isCraftFavorite
	-- [57] updated global.auctionUIContext.auctioningAuctionScrollingTable
	-- [58] updated global.auctionUIContext.sniperScrollingTable
	-- [59] updated global.mainUIContext.{frame,dashboardDividedContainer,ledgerDetailScrollingTable,ledgerInventoryScrollingTable,ledgerAuctionsScrollingTable,ledgerOtherScrollingTable,ledgerTransactionsScrollingTable,ledgerResaleScrollingTable}
	-- [60] updated global.auctionUIContext.{auctioningAuctionScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}, global.craftingUIContext.professionScrollingTable
	-- [61] updated global.auctionUIContext.sniperScrollingTable
	-- [62] updated global.mainUIContext.{ledgerTransactionsScrollingTable,ledgerResaleScrollingTable}
	-- [63] removed global.auctioningOptions.roundNormalPrice
	-- [64] removed global.accountingOptions.smartBuyPrice
	-- [65] added global.appearanceOptions.colorSet
	-- [66] added global.auctionUIContext.auctioningSelectionVerticalDividedContainer
	-- [67] updated global.mailingUIContext.mailsScrollingTable
	-- [68] removed profile.internalData.{bankUIBankFramePosition,bankUIGBankFramePosition,shoppingTabGroupContext,bankingWarehousingGroupTreeContext,bankingAuctioningGroupTreeContext,bankingMailingGroupTreeContext,craftingGroupTreeContext,mailingGroupTreeContext,vendoringGroupTreeContext}
	-- [69] updated global.mainUIContext.ledgerInventoryScrollingTable
	-- [70] updated global.auctionUIContext.{auctioningAuctionScrollingTable,shoppingAuctionScrollingTable}
	-- [71] moved profile.auctionUIContext.{auctioningGroupTree,shoppingGroupTree},profile.bankingUIContext.{warehousingGroupTree,auctioningGroupTree,mailingGroupTree},profile.craftingUIContext.groupTree,profile.mailingUIContext.groupTree,profile.mainUIContext.{groupsManagementGroupTree,importGroupTree,exportGroupTree} to char.*
	-- [72] updated global.auctionUIContext.sniperScrollingTable
	-- [73] added profile.vendoringUIContext.groupTree
	-- [74] added sync.internalData.money
	-- [75] updated global.appearanceOptions.colorSet
	-- [76] updated global.mainUIContext.operationsSummaryScrollingTable
	-- [77] added global.coreOptions.protectAuctionHouse
	-- [78] added global.mainUIContext.{dashboardUnselectedCharacters,dashboardTimeRange}
	-- [79] updated global.shoppingOptions.maxDeSearchLvl
	-- [80] updated char.auctionUIContext.{auctioningGroupTree,shoppingGroupTree},char.bankingUIContext.{warehousingGroupTree,auctioningGroupTree,mailingGroupTree},char.craftingUIContext.groupTree,char.mailingUIContext.groupTree,char.vendoringUIContext.groupTree,char.mainUIContext.{importGroupTree,exportGroupTree}
	-- [81] updated global.mailingUIContext.mailsScrollingTable
	-- [82] updated global.craftingUIContext.professionScrollingTable
	-- [83] added sync.internalData.goldLogLastUpdate, factionrealm.internalData.guildGoldLogLastUpdate
	-- [84] added global.auctionUIContext.myAuctionsScrollingTable
	-- [85] removed global.craftingOptions.ignoreCDCraftCost
	-- [86] updated global.craftingUIContext.craftsScrollingTable
	-- [87] added global.craftingUIContext.craftsScrollingTable
	-- [88] added global.shoppingOptions.searchAutoFocus
	-- [89] updated global.craftingOptions.defaultCraftPriceMethod
	-- [90] added global.internalData.lastCharacter
	-- [91] updated global.craftingUIContext.professionScrollingTable
	-- [92] updated global.vendoringUIContext.buyScrollingTable
	-- [93] moved profile.auctionUIContext.auctioningTabGroup to global.auctionUIContext.auctioningTabGroup
	-- [94] added global.internalData.whatsNewVersion
	-- [95] added global.appearanceOptions.showTotalMoney
	-- [96] updated global.userData.{savedShoppingSearches,savedAuctioningSearches}
	-- [97] added global.internalData.{optionalMatBonusIdLookup,optionalMatTextLookup}
	-- [98] added global.appearanceOptions.customColorSet
	-- [99] updated factionrealm.internalData.crafts, factionrealm.userData.craftingCooldownIgnore, char.internalData.craftingCooldowns
	-- [100] added factionrealm.internalData.craftingQueue
	-- [101] updated factionrealm.internalData.craftingQueue
	-- [102] removed global.internalData.optionalMatBonusIdLookup
	-- [103] updated global.auctionUIContext.auctioningAuctionScrollingTable, global.auctionUIContext.myAuctionsScrollingTable, global.auctionUIContext.shoppingAuctionScrollingTable, global.auctionUIContext.sniperScrollingTable, global.auctionUIContext.professionScrollingTable
	-- [104] removed factionrealm.internalData.{csvAuctionDBScan,auctionDBScanTime,auctionDBScanHash}
	-- [105] updated factionrealm.internalData.crafts, factionrealm.userData.craftingCooldownIgnore, char.internalData.craftingCooldowns
	-- [106] added global.userData.ungroupedItemMode
	-- [107] added global.tooltipOptions.{destroyTooltipFormat,convertTooltipFormat}, removed global.tooltipOptions.{deTooltip,millTooltip,prospectTooltip,transformTooltip,detailedDestroyTooltip}
	-- [108] updated global.tooltipOptions.moduleTooltips
	-- [109] updated global.craftingUIContext.professionScrollingTable
	-- [110] remove factionrealm.auctioningOptions.whitelist on retail
	-- [111] updated global.craftingUIContext.{professionScrollingTable,professionDividedContainer}
	-- [112] updated global.craftingUIContext.professionScrollingTable
	-- [113] updated global.craftingUIContext.professionDividedContainerBottom
	-- [114] updated factionrealm.internalData.crafts
	-- [115] removed global.internalData.optionalMatTextLookup
	-- [116] updated global.internalData.destroyingHistory
	-- [117] added global.storyBoardUIContext, updated global.craftingUIContext.{craftsScrollingTable,matsScrollingTable,gatheringScrollingTable}
	-- [118] updated factionrealm.internalData.crafts
	-- [119] added global.coreOptions.regionWide
	-- [120] updated factionrealm.internalData.crafts
	-- [121] rename global.userData.operations to global.userData.sharedOperations
	-- [122] updated global.auctionUIContext.{myAuctionsScrollingTable,auctioningBagScrollingTable,auctioningLogScrollingTable,auctioningAuctionScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}
	--  updated global.craftingUIContext.{craftsScrollingTable,matsScrollingTable,gatheringScrollingTable,professionScrollingTable}
	--  updated global.destroyingUIContext.itemsScrollingTable
	-- 	updated global.mailingUIContext.mailsScrollingTable
	--  updated global.mainUIContext.{operationsSummaryScrollingTable,ledgerDetailScrollingTable,ledgerTransactionsScrollingTable,ledgerResaleScrollingTable,ledgerInventoryScrollingTable,ledgerOtherScrollingTable}
	--  updated global.vendoringUIContext.buyScrollingTable,buybackScrollingTable,sellScrollingTable
	-- [123] added global.userData.customPriceSourceFormat
	-- [124] updated auctionUIContext.auctioningBagScrollingTable
	-- [125] updated global.shoppingOptions.maxDeSearchLvl
	-- [126] added realm.coreOptions.auctionDBAltRealm
	-- [127] added global.internalData.warbankQuantity
	-- [128] added global.internalData.{warbankMoney,warbankGoldLog,warbankGoldLogLastUpdate}
	-- [129] updated factionrealm.internalData.crafts
	-- [130/131] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable}, factionrealm.auctioningOptions.whitelist
	-- [132] removed internalData.reagentBankQuantity
	-- [133] updated global.auctionUIContext.{auctioningAuctionScrollingTable,myAuctionsScrollingTable,shoppingAuctionScrollingTable,sniperScrollingTable}, factionrealm.auctioningOptions.whitelist
	-- [134] added global.appearanceOptions.{fontFace,fontScale,itemIconSize}
	return Settings.NewSchema(134, 10)
		:EnterScope("global")
			:EnterNamespace("debug")
				:AddBoolean("chatLoggingEnabled", false, 19)
			:LeaveNamespace()
			:EnterNamespace("internalData")
				:AddString("lastCharacter", "???", 90)
				:AddTable("vendorItems", {}, 10)
				:AddNumber("appMessageId", 0, 10)
				:AddTable("destroyingHistory", {}, 116)
				:AddNumber("whatsNewVersion", 0, 94)
				:AddTable("warbankQuantity", {}, 127)
				:AddNumber("warbankMoney", 0, 128)
				:AddString("warbankGoldLog", "", 128)
				:AddNumber("warbankGoldLogLastUpdate", 0, 128)
			:LeaveNamespace()
			:EnterNamespace("appearanceOptions")
				:AddBoolean("taskListBackgroundLock", false, 87)
				:AddBoolean("showTotalMoney", false, 95)
				:AddString("colorSet", "midnight", 75)
				:AddTable("customColorSet", {}, 98)
				:AddString("fontFace", "", 134)
				:AddNumber("fontScale", 1, 134)
				:AddNumber("itemIconSize", 12, 134)
			:LeaveNamespace()
			:EnterNamespace("auctionUIContext")
				:AddTable("frame", { width = 830, height = 587, centerX = -300, centerY = 100, scale = 1, page = 1 }, 55)
				:AddBoolean("showDefault", false, 55)
				:AddTable("auctioningSelectionDividedContainer", { leftWidth = 272 }, 55)
				:AddTable("auctioningSelectionVerticalDividedContainer", { leftWidth = 220 }, 66)
				:AddTable("auctioningBagScrollingTable", { cols = { { id = "selected", width = 16, hidden = nil }, { id = "item", width = 274, hidden = nil }, { id = "operation", width = 206, hidden = nil }, { id = "group", width = 160, hidden = true } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 124)
				:AddTable("auctioningLogScrollingTable", { cols = { { id = "index", width = 14, hidden = nil }, { id = "item", width = 190, hidden = nil }, { id = "buyout", width = 110, hidden = nil }, { id = "operation", width = 108, hidden = nil }, { id = "seller", width = 90, hidden = nil }, { id = "info", width = 234, hidden = nil } }, colWidthLocked = nil, sortCol = "index", sortAscending = false }, 122)
				:AddTable("auctioningAuctionScrollingTable", { cols = (LibTSMSystem.IsVanillaClassic() or LibTSMSystem.IsBCClassic() or LibTSMSystem.IsWrathClassic()) and { { id = "item", width = 226, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "posts", width = 40, hidden = nil }, { id = "stack", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 80, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, } or { { id = "item", width = 226, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "qty", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 136, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, }, sortCol = "pct", sortAscending = true }, 133)
				:AddTable("myAuctionsScrollingTable", { cols = (LibTSMSystem.IsVanillaClassic() or LibTSMSystem.IsBCClassic() or LibTSMSystem.IsWrathClassic()) and { { id = "item", width = 248, hidden = nil }, { id = "stackSize", width = 30, hidden = nil }, { id = "timeLeft", width = 40, hidden = nil }, { id = "highBidder", width = 110, hidden = nil }, { id = "group", width = 110, hidden = nil }, { id = "currentBid", width = 100, hidden = nil }, { id = "buyout", width = 100, hidden = nil } } or { { id = "item", width = 248, hidden = nil }, { id = "stackSize", width = 30, hidden = nil }, { id = "timeLeft", width = 40, hidden = nil }, { id = "group", width = 228, hidden = nil }, { id = "currentBid", width = 100, hidden = nil }, { id = "buyout", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic() and not LibTSMSystem.IsWrathClassic()) and "item" or nil, sortAscending = (not LibTSMSystem.IsVanillaClassic() and not LibTSMSystem.IsBCClassic() and not LibTSMSystem.IsWrathClassic()) and true or nil }, 133)
				:AddTable("shoppingSelectionDividedContainer", { leftWidth = 272 }, 55)
				:AddTable("shoppingAuctionScrollingTable", { cols = (LibTSMSystem.IsVanillaClassic() or LibTSMSystem.IsBCClassic() or LibTSMSystem.IsWrathClassic()) and { { id = "item", width = 226, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "posts", width = 40, hidden = nil }, { id = "stack", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 80, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, } or { { id = "item", width = 226, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "qty", width = 40, hidden = nil }, { id = "timeLeft", width = 26, hidden = nil }, { id = "seller", width = 136, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, }, sortCol = "pct", sortAscending = true }, 133)
				:AddTable("sniperScrollingTable", { cols = (LibTSMSystem.IsVanillaClassic() or LibTSMSystem.IsBCClassic() or LibTSMSystem.IsWrathClassic()) and { { id = "icon", width = 24, hidden = nil }, { id = "item", width = 230, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "posts", width = 40, hidden = nil }, { id = "stack", width = 40, hidden = nil }, { id = "seller", width = 86, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, } or { { id = "icon", width = 24, hidden = nil }, { id = "item", width = 230, hidden = nil }, { id = "ilvl", width = 32, hidden = nil }, { id = "qty", width = 40, hidden = nil }, { id = "seller", width = 134, hidden = nil }, { id = "itemBid", width = 115, hidden = nil }, { id = "bid", width = 115, hidden = true }, { id = "itemBuyout", width = 115, hidden = nil }, { id = "buyout", width = 115, hidden = true }, { id = "bidPct", width = 40, hidden = true }, { id = "pct", width = 40, hidden = nil }, }, sortCol = "pct", sortAscending = true }, 133)
				:AddTable("shoppingSearchesTabGroup", { pathIndex = 1 }, 55)
				:AddTable("auctioningTabGroup", { pathIndex = 1 }, 93)
			:LeaveNamespace()
			:EnterNamespace("bankingUIContext")
				:AddTable("frame", { width = 325, height = 600, centerX = 500, centerY = 0, scale = 1 }, 55)
				:AddBoolean("isOpen", true, 55)
				:AddString("tab", "Warehousing", 55)
			:LeaveNamespace()
			:EnterNamespace("craftingUIContext")
				:AddTable("frame", { width = 820, height = 587, centerX = -200, centerY = 0, scale = 1, page = 1 }, 55)
				:AddBoolean("showDefault", false, 55)
				:AddTable("craftsScrollingTable", { cols = { { id = "queued", width = 30, hidden = nil }, { id = "craftName", width = 222, hidden = nil }, { id = "operation", width = 80, hidden = nil }, { id = "bags", width = 28, hidden = nil }, { id = "ah", width = 24, hidden = nil }, { id = "craftingCost", width = 100, hidden = nil }, { id = "itemValue", width = 100, hidden = nil }, { id = "profit", width = 100, hidden = nil } , { id = "profitPct", width = 50, hidden = true }, { id = "saleRate", width = 32, hidden = nil } }, colWidthLocked = nil, sortCol = "craftName", sortAscending = true }, 122)
				:AddTable("matsScrollingTable", { cols = { { id = "name", width = 246, hidden = nil }, { id = "price", width = 100, hidden = nil }, { id = "professions", width = 310, hidden = nil }, { id = "num", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = "name", sortAscending = true }, 122)
				:AddTable("gatheringDividedContainer", { leftWidth = 284 }, 55)
				:AddTable("gatheringScrollingTable", { cols = { { id = "name", width = 210, hidden = nil }, { id = "sources", width = 160, hidden = nil }, { id = "have", width = 50, hidden = nil }, { id = "need", width = 50, hidden = nil } }, colWidthLocked = nil, sortCol = "name", sortAscending = true }, 122)
				:AddTable("professionScrollingTable", { cols = { { id = "name", width = 310, hidden = nil }, { id = "qty", width = 54, hidden = nil }, { id = "craftingCost", width = 100, hidden = true }, { id = "itemValue", width = 100, hidden = true }, { id = "profit", width = 100, hidden = nil }, { id = "profitPct", width = 50, hidden = true }, { id = "saleRate", width = 42, hidden = nil } }, colWidthLocked = nil, collapsed = {} }, 122)
				:AddTable("professionDividedContainer", { leftWidth = 556 }, 111)
				:AddTable("professionDividedContainerBottom", { leftWidth = LibTSMSystem.IsRetail() and 348 or 390 }, 113)
			:LeaveNamespace()
			:EnterNamespace("destroyingUIContext")
				:AddTable("frame", { width = 296, height = 442, centerX = 0, centerY = 0, scale = 1 }, 55)
				:AddTable("itemsScrollingTable", { cols = { { id = "item", width = 214, hidden = nil }, { id = "num", width = 30, hidden = nil } }, colWidthLocked = nil }, 122)
			:LeaveNamespace()
			:EnterNamespace("storyBoardUIContext")
				:AddTable("frame", { width = 800, height = 600, centerX = 0, centerY = 0, scale = 1 }, 117)
			:LeaveNamespace()
			:EnterNamespace("mailingUIContext")
				:AddTable("frame", { width = 620, height = 516, centerX = -200, centerY = 0, scale = 1, page = 1 }, 55)
				:AddBoolean("showDefault", false, 55)
				:AddTable("mailsScrollingTable", { cols = { { id = "items", width = 380, hidden = nil }, { id = "sender", width = 100, hidden = true }, { id = "expires", width = 65, hidden = nil }, { id = "money", width = 115, hidden = nil } }, colWidthLocked = nil }, 122)
			:LeaveNamespace()
			:EnterNamespace("mainUIContext")
				:AddTable("frame", { width = 900, height = 700, centerX = 0, centerY = 0, scale = 1, page = 1 }, 59)
				:AddTable("ledgerDetailScrollingTable", { cols = { { id = "activityType", width = 91, hidden = nil }, { id = "source", width = 60, hidden = nil }, { id = "buyerSeller", width = 100, hidden = nil }, { id = "qty", width = 45, hidden = nil }, { id = "perItem", width = 120, hidden = nil }, { id = "totalPrice", width = 120, hidden = nil }, { id = "time", width = 110, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerInventoryScrollingTable", { cols = { { id = "item", width = 160, hidden = nil }, { id = "totalItems", width = 50, hidden = nil }, { id = "bags", width = 50, hidden = nil }, { id = "banks", width = 50, hidden = nil }, { id = "mail", width = 50, hidden = nil }, { id = "alts", width = 50, hidden = nil }, { id = "guildVault", width = 50, hidden = nil }, { id = "auctionHouse", width = 50, hidden = nil }, { id = "totalValue", width = 120, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 122)
				:AddTable("ledgerAuctionsScrollingTable", { cols = { { id = "item", width = 305, hidden = nil }, { id = "player", width = 110, hidden = nil }, { id = "stackSize", width = 55, hidden = nil }, { id = "quantity", width = 72, hidden = nil }, { id = "time", width = 120, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerOtherScrollingTable", { cols = { { id = "type", width = 200, hidden = nil }, { id = "character", width = 110, hidden = nil }, { id = "otherCharacter", width = 122, hidden = nil }, { id = "amount", width = 120, hidden = nil }, { id = "time", width = 110, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerTransactionsScrollingTable", { cols = { { id = "item", width = 156, hidden = nil }, { id = "player", width = 95, hidden = nil }, { id = "type", width = 50, hidden = nil }, { id = "stack", width = 55, hidden = nil }, { id = "auctions", width = 60, hidden = nil }, { id = "perItem", width = 120, hidden = nil }, { id = "total", width = 120, hidden = true }, { id = "time", width = 110, hidden = nil } }, colWidthLocked = nil, sortCol = "time", sortAscending = false }, 122)
				:AddTable("ledgerResaleScrollingTable", { cols = { { id = "item", width = 194, hidden = nil }, { id = "bought", width = 50, hidden = nil }, { id = "avgBuyPrice", width = 120, hidden = nil }, { id = "sold", width = 50, hidden = nil }, { id = "avgSellPrice", width = 120, hidden = nil }, { id = "avgProfit", width = 120, hidden = nil }, { id = "totalProfit", width = 120, hidden = true }, { id = "profitPct", width = 80, hidden = true } }, colWidthLocked = nil, sortCol = "item", sortAscending = true } , 122)
				:AddTable("dashboardDividedContainer", { leftWidth = 300 }, 59)
				:AddTable("dashboardUnselectedCharacters", {}, 78)
				:AddNumber("dashboardTimeRange", -1, 78)
				:AddTable("groupsDividedContainer", { leftWidth = 300 }, 55)
				:AddTable("operationsDividedContainer", { leftWidth = 306 }, 55)
				:AddTable("importExportDividedContainer", { leftWidth = 300 }, 55)
				:AddTable("operationsSummaryScrollingTable", { cols = { { id = "selected", width = 16, hidden = nil }, { id = "name", width = 248, hidden = nil }, { id = "groups", width = 130, hidden = nil }, { id = "items", width = 130, hidden = nil } }, colWidthLocked = nil, sortCol = "name", sortAscending = true }, 122)
			:LeaveNamespace()
			:EnterNamespace("taskListUIContext")
				:AddTable("frame", { topRightX = -220, topRightY = -10, minimized = false, isOpen = true }, 55)
				:AddBoolean("isOpen", true, 55)
			:LeaveNamespace()
			:EnterNamespace("vendoringUIContext")
				:AddTable("frame", { width = 560, height = 500, centerX = -200, centerY = 0, scale = 1, page = 1 }, 55)
				:AddBoolean("showDefault", false, 55)
				:AddTable("buyScrollingTable", { cols = { { id = "qty", width = 40, hidden = nil }, { id = "item", width = 310, hidden = nil }, { id = "ilvl", width = 32, hidden = true }, { id = "cost", width = 150, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 122)
				:AddTable("buybackScrollingTable", { cols = { { id = "qty", width = 40, hidden = nil }, { id = "item", width = 360, hidden = nil }, { id = "cost", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 122)
				:AddTable("sellScrollingTable", { cols = { { id = "item", width = 300, hidden = nil }, { id = "vendorSell", width = 100, hidden = nil }, { id = "potential", width = 100, hidden = nil } }, colWidthLocked = nil, sortCol = "item", sortAscending = true }, 122)
			:LeaveNamespace()
			:EnterNamespace("coreOptions")
				:AddBoolean("globalOperations", false, 10)
				:AddBoolean("protectAuctionHouse", false, 77)
				:AddString("chatFrame", "", 10)
				:AddString("auctionSaleSound", "TSM_NO_SOUND", 10)
				:AddTable("minimapIcon", { hide = false, minimapPos = 220, radius = 80 }, 10)
				:AddString("destroyValueSource", "dbmarket", 10)
				:AddString("groupPriceSource", "dbmarket", 41)
				:AddBoolean("regionWide", false, 119)
			:LeaveNamespace()
			:EnterNamespace("accountingOptions")
				:AddBoolean("trackTrades", true, 10)
				:AddBoolean("autoTrackTrades", false, 10)
			:LeaveNamespace()
			:EnterNamespace("auctioningOptions")
				:AddBoolean("cancelWithBid", false, 10)
				:AddBoolean("disableInvalidMsg", false, 10)
				:AddBoolean("matchWhitelist", true, 10)
				:AddString("scanCompleteSound", "TSM_NO_SOUND", 10)
				:AddString("confirmCompleteSound", "TSM_NO_SOUND", 10)
			:LeaveNamespace()
			:EnterNamespace("craftingOptions")
				:AddString("defaultMatCostMethod", "min(dbmarket, crafting, vendorbuy, convert(dbmarket))", 10)
				:AddString("defaultCraftPriceMethod", "first(dbminbuyout, dbmarket)*0.95", 89)
				:AddTable("ignoreCharacters", {}, 10)
				:AddTable("ignoreGuilds", {}, 10)
			:LeaveNamespace()
			:EnterNamespace("destroyingOptions")
				:AddBoolean("autoStack", true, 10)
				:AddBoolean("includeSoulbound", false, 10)
				:AddBoolean("autoShow", true, 10)
				:AddNumber("deMaxQuality", 3, 10)
				:AddString("deAbovePrice", "0c", 10)
			:LeaveNamespace()
			:EnterNamespace("mailingOptions")
				:AddBoolean("sendItemsIndividually", false, 10)
				:AddBoolean("inboxMessages", true, 10)
				:AddBoolean("sendMessages", true, 10)
				:AddNumber("resendDelay", 1, 10)
				:AddNumber("keepMailSpace", 0, 10)
				:AddNumber("deMaxQuality", 2, 10)
				:AddString("openMailSound", "TSM_NO_SOUND", 10)
				:AddTable("recentlyMailedList", {}, 38)
			:LeaveNamespace()
			:EnterNamespace("shoppingOptions")
				:AddNumber("minDeSearchLvl", 1, 10)
				:AddNumber("maxDeSearchLvl", 600, 125)
				:AddNumber("maxDeSearchPercent", 100, 23)
				:AddString("pctSource", "dbmarket", 12)
				:AddBoolean("buyoutConfirm", false, 46)
				:AddString("buyoutAlertSource", "min(100000g, 200% dbmarket)", 46)
				:AddBoolean("searchAutoFocus", true, 88)
			:LeaveNamespace()
			:EnterNamespace("sniperOptions")
				:AddString("sniperSound", "TSM_NO_SOUND", 10)
			:LeaveNamespace()
			:EnterNamespace("vendoringOptions")
				:AddBoolean("displayMoneyCollected", false, 10)
				:AddString("qsMarketValue", "dbmarket", 10)
			:LeaveNamespace()
			:EnterNamespace("tooltipOptions")
				:AddBoolean("enabled", true, 20)
				:AddBoolean("embeddedTooltip", true, 10)
				:AddTable("customPriceTooltips", {}, 10)
				:AddTable("moduleTooltips", {}, 108)
				:AddBoolean("vendorBuyTooltip", true, 10)
				:AddBoolean("vendorSellTooltip", true, 10)
				:AddBoolean("groupNameTooltip", true, 10)
				:AddString("destroyTooltipFormat", "simple", 107)
				:AddString("convertTooltipFormat", "simple", 107)
				:AddTable("operationTooltips", {}, 10)
				:AddString("tooltipShowModifier", "none", 10)
				:AddString("inventoryTooltipFormat", "full", 10)
				:AddString("tooltipPriceFormat", "text", 10)
			:LeaveNamespace()
			:EnterNamespace("userData")
				:AddTable("sharedOperations", {}, 121)
				:AddTable("customPriceSources", {}, 10)
				:AddTable("customPriceSourceFormat", {}, 123)
				:AddTable("destroyingIgnore", {}, 10)
				:AddTable("savedShoppingSearches", { filters = {}, name = {}, isFavorite = {} }, 96)
				:AddTable("vendoringIgnore", {}, 10)
				:AddTable("savedAuctioningSearches", { filters = {}, searchTypes = {}, name = {}, isFavorite = {} }, 96)
				:AddString("ungroupedItemMode", "specific", 106)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("profile")
			:EnterNamespace("internalData")
				:AddBoolean("createdDefaultOperations", false, 11)
			:LeaveNamespace()
			:EnterNamespace("userData")
				:AddTable("groups", {}, 10)
				:AddTable("items", {}, 10)
				:AddTable("operations", {}, 10)
			:LeaveNamespace()
			:EnterNamespace("gatheringOptions")
				:AddTable("sources", { "vendor", "guildBank", "alt", "altGuildBank", "craftProfit", "auction", "craftNoProfit" }, 32)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("factionrealm")
			:EnterNamespace("internalData")
				:AddTable("characterGuilds", {}, 10)
				:AddTable("guildVaults", {}, 10)
				:AddTable("pendingMail", {}, 10)
				:AddTable("expiringMail", {}, 47)
				:AddTable("expiringAuction", {}, 47)
				:AddString("mailDisenchantablesChar", "", 49)
				:AddString("mailExcessGoldChar", "", 49)
				:AddNumber("mailExcessGoldLimit", 10000000000, 49)
				:AddTable("crafts", {}, 129)
				:AddTable("craftingQueue", {}, 101)
				:AddTable("mats", {}, 10)
				:AddTable("guildGoldLog", {}, 25)
				:AddTable("guildGoldLogLastUpdate", {}, 83)
				:AddTable("isCraftFavorite", {}, 56)
			:LeaveNamespace()
			:EnterNamespace("coreOptions")
				:AddTable("ignoreGuilds", {}, 10)
			:LeaveNamespace()
			:EnterNamespace("auctioningOptions")
				:If(LibTSMSystem.IsVanillaClassic() or LibTSMSystem.IsBCClassic() or LibTSMSystem.IsWrathClassic())
					:AddTable("whitelist", {}, 133)
				:EndIf()
			:LeaveNamespace()
			:EnterNamespace("gatheringContext")
				:AddString("crafter", "", 32)
				:AddTable("professions", {}, 32)
			:LeaveNamespace()
			:EnterNamespace("userData")
				:AddTable("craftingCooldownIgnore", {}, 105)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("realm")
			:EnterNamespace("internalData")
				:AddString("csvSales", "", 10)
				:AddString("csvBuys", "", 10)
				:AddString("csvIncome", "", 10)
				:AddString("csvExpense", "", 10)
				:AddString("csvExpired", "", 10)
				:AddString("csvCancelled", "", 10)
				:AddString("saveTimeSales", "", 10)
				:AddString("saveTimeBuys", "", 10)
				:AddString("saveTimeExpires", "", 10)
				:AddString("saveTimeCancels", "", 10)
				:AddTable("accountingTrimmed", {}, 10)
			:LeaveNamespace()
			:EnterNamespace("coreOptions")
				:AddString("auctionDBAltRealm", "", 126)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("char")
			:EnterNamespace("internalData")
				:AddTable("auctionPrices", {}, 10)
				:AddTable("auctionMessages", {}, 10)
				:AddTable("craftingCooldowns", {}, 105)
				:AddTable("auctionSaleHints", {}, 45)
			:LeaveNamespace()
			:EnterNamespace("auctionUIContext")
				:AddTable("auctioningGroupTree", { collapsed = {}, unselected = {} }, 80)
				:AddTable("shoppingGroupTree", { collapsed = {}, unselected = {} }, 80)
			:LeaveNamespace()
			:EnterNamespace("bankingUIContext")
				:AddTable("warehousingGroupTree", { collapsed = {}, unselected = {} }, 80)
				:AddTable("auctioningGroupTree", { collapsed = {}, unselected = {} }, 80)
				:AddTable("mailingGroupTree", { collapsed = {}, unselected = {} }, 80)
			:LeaveNamespace()
			:EnterNamespace("craftingUIContext")
				:AddTable("groupTree", { collapsed = {}, unselected = {} }, 80)
			:LeaveNamespace()
			:EnterNamespace("mailingUIContext")
				:AddTable("groupTree", { collapsed = {}, unselected = {} }, 80)
			:LeaveNamespace()
			:EnterNamespace("vendoringUIContext")
				:AddTable("groupTree", { collapsed = {}, unselected = {} }, 80)
			:LeaveNamespace()
			:EnterNamespace("mainUIContext")
				:AddTable("groupsManagementGroupTree", { collapsed = {} }, 71)
				:AddTable("importGroupTree", { collapsed = {}, selected = {} }, 80)
				:AddTable("exportGroupTree", { collapsed = {}, unselected = {} }, 80)
			:LeaveNamespace()
		:LeaveScope()
		:EnterScope("sync")
			-- NOTE: whenever these are changed, the sync version needs to be increased in LibTSMService/Source/Sync/Classes/Constants.lua
			:EnterNamespace("internalData")
				:AddNumber("money", 0, 74)
				:AddString("classKey", "", 19)
				:AddTable("bagQuantity", {}, 19)
				:AddTable("bankQuantity", {}, 19)
				:AddTable("auctionQuantity", {}, 19)
				:AddTable("mailQuantity", {}, 19)
				:AddString("goldLog", "", 25)
				:AddNumber("goldLogLastUpdate", 0, 83)
				:AddTable("playerProfessions", {}, 36)
			:LeaveNamespace()
		:LeaveScope()
		:Commit()
end
