-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Types = LibTSMTypes:Init("CustomString.Types")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local NamedTupleList = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("NamedTupleList")
local Tree = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("Tree")
Types.TOKEN = EnumType.New("TOKEN", {
	UNKNOWN = EnumType.NewValue(),
	NUMBER = EnumType.NewValue(),
	MONEY = EnumType.NewValue(),
	NEWLINE = EnumType.NewValue(),
	WHITESPACE = EnumType.NewValue(),
	IDENTIFIER = EnumType.NewValue(),
	FUNCTION = EnumType.NewValue(),
	COMMA = EnumType.NewValue(),
	LEFT_PAREN = EnumType.NewValue(),
	RIGHT_PAREN = EnumType.NewValue(),
	MATH_OPERATOR = EnumType.NewValue(),
	COLORCODE = EnumType.NewValue(),
	NEGATIVE_OPERATOR = EnumType.NewValue(),
})
Types.NODE = EnumType.New("NODE", {
	FUNCTION = EnumType.NewValue(),
	CONSTANT = EnumType.NewValue(),
	VARIABLE = EnumType.NewValue(),
	INVALID = EnumType.NewValue(),
})
Types.ERROR = EnumType.New("ERROR", {
	INVALID_TOKEN = EnumType.NewValue(),
	UNBALANCED_PARENS = EnumType.NewValue(),
	INVALID_NUM_ARGS = EnumType.NewValue(),
	TOO_MANY_VARS = EnumType.NewValue(),
	INVALID_ITEM_STRING = EnumType.NewValue(),
	INVALID_CONVERT_ARG = EnumType.NewValue(),
	NO_ITEM_PARAM_PARENT = EnumType.NewValue(),
	EMPTY_STRING = EnumType.NewValue(),
	INVALID_SOURCE = EnumType.NewValue(),
	NO_VALUE = EnumType.NewValue(),
	INVALID_CHARACTER = EnumType.NewValue(),
	ALREADY_EXISTS = EnumType.NewValue(),
	RESERVED_WORD = EnumType.NewValue(),
})
Types.FUNCTION_INFO = {
	["+"] = {minArgs=2, maxArgs=2},
	["-"] = {minArgs=2, maxArgs=2},
	["*"] = {minArgs=2, maxArgs=2},
	["/"] = {minArgs=2, maxArgs=2},
	["^"] = {minArgs=2, maxArgs=2},
	["%"] = {minArgs=2, maxArgs=2},
	check = {minArgs=2, maxArgs=3},
	iflte = {minArgs=3, maxArgs=4},
	iflt = {minArgs=3, maxArgs=4},
	ifgte = {minArgs=3, maxArgs=4},
	ifgt = {minArgs=3, maxArgs=4},
	ifeq = {minArgs=3, maxArgs=4},
	round = {minArgs=1, maxArgs=2},
	roundup = {minArgs=1, maxArgs=2},
	rounddown = {minArgs=1, maxArgs=2},
	min = {minArgs=1, maxArgs=math.huge},
	max = {minArgs=1, maxArgs=math.huge},
	avg = {minArgs=1, maxArgs=math.huge},
	first = {minArgs=1, maxArgs=math.huge},
	convert = {minArgs=1, maxArgs=2},
}
Types.SOURCE_TYPE = EnumType.New("SOURCE_TYPE", {
	PRICE_DB = EnumType.NewValue(), -- Changes infrequently and all at once (communicated via CustomString.InvalidateCache)
	NORMAL = EnumType.NewValue(), -- Changes are communicated via CustomString.InvalidateCache
	VOLATILE = EnumType.NewValue(), -- Changes without calling CustomString.InvalidateCache
})
local ITEM_STRING_MATCH_STR_1 = "^[ip]:[0-9:%-]+$"
local ITEM_STRING_MATCH_STR_2 = "^item:[0-9:%-]+$"



-- ============================================================================
-- Module Methods
-- ============================================================================

---Creates a new token list.
---@return NamedTupleList
function Types.CreateTokenList()
	return NamedTupleList.New("token", "str", "startPos", "endPos")
end

---Creates a new node tree.
---@return Tree
function Types.CreateNodeTree()
	return Tree.Create("type", "value", "tokenIndex")
end

---Return if a value is an item parameter.
---@param value string
---@return boolean
function Types.IsItemParam(value)
	return value == "baseitem" or Types.IsItemStringParam(value)
end

---Return if a value is an item string parameter.
---@param value string
---@return boolean
function Types.IsItemStringParam(value)
	return (strmatch(value, ITEM_STRING_MATCH_STR_1) or strmatch(value, ITEM_STRING_MATCH_STR_2)) and true or false
end
