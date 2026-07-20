-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local MarketValue = LibTSMService:Init("AuctionScan.MarketValue")
local Util = LibTSMService:Include("AuctionScan.Util")

-- Thin alias: implementation lives in AuctionScan.Util (loaded first in LibTSMService.xml).
MarketValue.Calc = Util.CalcMarketValue
