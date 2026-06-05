-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local AST = LibTSMTypes:Init("CustomString.AST")
local Types = LibTSMTypes:Include("CustomString.Types")
local Optimizer = LibTSMTypes:Include("CustomString.Optimizer")
local TokenProcessor = LibTSMTypes:IncludeClassType("CustomStringTokenProcessor")
local private = {
	tokenProcessor = TokenProcessor.Create(),
	dependencyIteratorTemp = {},
}



-- ============================================================================
-- Module Methods
-- ============================================================================

---Generates an AST from a list of tokens.
---@param tokenList NamedTupleList The list of tokens
---@param tree Tree The empty tree to store the AST in
---@return boolean # Whether or not generating the AST was successful
---@return EnumValue|nil # The error type
---@return number|nil # The error token index
function AST.Generate(tokenList, tree)
	-- Generate the AST
	local success, errType, errTokenIndex = private.tokenProcessor:Execute(tokenList, tree)
	if not success then
		return false, errType, errTokenIndex
	end

	-- Optimize the AST
	success, errType, errTokenIndex = Optimizer.Execute(tree)
	if not success then
		return false, errType, errTokenIndex
	end

	return true
end

---Iterates over the variable dependencies of the custom string.
---@param tree Tree The empty tree to store the AST in
---@return fun(): number, string, string?, string? @An iterator with fields: `index`, `source`, `itemArg`, `extraArg`
function AST.DependencyIterator(tree)
	assert(not next(private.dependencyIteratorTemp))
	local context = private.dependencyIteratorTemp
	context.tree = tree
	for node in tree:DepthFirstIterator() do
		local nodeType = tree:GetData(node, "type")
		local parentNode = context.tree:GetParent(node)
		local parentNodeValue = parentNode and context.tree:GetData(parentNode, "value") or nil
		if nodeType == Types.NODE.VARIABLE and parentNodeValue ~= "convert" then
			tinsert(context, node)
		elseif nodeType == Types.NODE.FUNCTION and tree:GetData(node, "value") == "convert" then
			tinsert(context, node)
		end
	end
	return private.DependencyIteratorHelper, context, 0
end

---Dumps an AST for debugging purposes.
---@param tree Tree The empty tree to store the AST in
function AST.Dump(tree)
	for node in tree:DepthFirstIterator() do
		local value = tree:GetData(node, "value")
		value = value ~= "" and value or "?"
		local depth = tree:GetDepth(node)
		print(strrep("  ", depth)..value)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DependencyIteratorHelper(context, index)
	index = index + 1
	local node = context[index]
	if not node then
		wipe(context)
		return nil
	end
	local nodeType = context.tree:GetData(node, "type")
	local nodeValue = context.tree:GetData(node, "value")
	if nodeType == Types.NODE.FUNCTION then
		assert(nodeValue == "convert")
		local sourceNode, itemNode = context.tree:GetChildren(node)
		assert(sourceNode and context.tree:GetData(sourceNode, "type") == Types.NODE.VARIABLE)
		local itemValue = itemNode and context.tree:GetData(itemNode, "value")
		assert(not itemValue or (context.tree:GetData(itemNode, "type") == Types.NODE.VARIABLE and Types.IsItemParam(itemValue)))
		return index, nodeValue, itemValue, context.tree:GetData(sourceNode, "value")
	else
		assert(nodeType == Types.NODE.VARIABLE)
		local parentNode = context.tree:GetParent(node)
		local parentNodeValue = parentNode and context.tree:GetData(parentNode, "value") or nil
		assert(not parentNode or context.tree:GetData(parentNode, "type") == Types.NODE.FUNCTION)
		if Types.IsItemParam(nodeValue) then
			assert(parentNodeValue)
			return index, parentNodeValue, nodeValue
		else
			return index, nodeValue
		end
	end
end
