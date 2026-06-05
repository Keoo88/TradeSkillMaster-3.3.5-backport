-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local TokenProcessor = LibTSMTypes:DefineClassType("CustomStringTokenProcessor")
local Types = LibTSMTypes:Include("CustomString.Types")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local MoneyFormatter = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("MoneyFormatter")
local private = {
	expressionStackTemp = {},
	expressionResultTemp = {},
	expressionsTemp = {},
}
local AST_ACTION = EnumType.New("AST_ACTION", {
	START_EXPRESSION = EnumType.NewValue(),
	END_EXPRESSION = EnumType.NewValue(),
	START_FUNCTION = EnumType.NewValue(),
	END_FUNCTION = EnumType.NewValue(),
	ADD_NODE = EnumType.NewValue(),
	NEGATE_NEXT = EnumType.NewValue(),
})
local AST_IGNORE_TOKEN = {
	[Types.TOKEN.WHITESPACE] = true,
	[Types.TOKEN.NEWLINE] = true,
	[Types.TOKEN.COLORCODE] = true,
}
local INTERNAL_AST_NODE = EnumType.New("INTERNAL_AST_NODE", {
	ROOT_EXPRESSION = EnumType.NewValue(),
	EXPRESSION = EnumType.NewValue(),
	OPERATOR = EnumType.NewValue(),
})



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a token processor.
---@return CustomStringTokenProcessor
function TokenProcessor.__static.Create()
	return TokenProcessor()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function TokenProcessor.__private:__init()
	self._tokenList = nil
	self._tree = nil
	self._index = 0
	self._errType = nil
	self._errTokenIndex = nil
	self._stack = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Executes the processor.
---@param tokenList NamedTupleList The list of tokens
---@param tree Tree The empty tree to store the AST in
---@return boolean
---@return CustomString.Types.ERROR?
---@return number?
function TokenProcessor:Execute(tokenList, tree)
	assert(not self._tokenList and not self._tree and not self._errType and not self._errTokenIndex and not next(self._stack))
	self._tokenList = tokenList
	self._tree = tree
	self._index = 0

	-- Generate the initial AST from the tokens
	if not self:_ProcessAction() then
		local errType, errTokenIndex = self._errType, self._errTokenIndex
		assert(errType and errTokenIndex)
		self._errType = nil
		self._errTokenIndex = nil
		self._tree = nil
		self._tokenList = nil
		wipe(self._stack)
		return false, errType, errTokenIndex
	end
	local nextActionResult, nextAction = self:_GetNextAction()
	assert(nextActionResult and nextAction == nil)

	-- Remove all expressions and turn operators into functions
	self:_RemoveExpressions()

	-- Validate that there are no internal nodes left in the tree and that the number of arguments for functions is correct
	local isValid = true
	for node in tree:DepthFirstIterator() do
		local nodeType = tree:GetData(node, "type")
		assert(nodeType == Types.NODE.CONSTANT or nodeType == Types.NODE.FUNCTION or nodeType == Types.NODE.VARIABLE)
		if isValid and nodeType == Types.NODE.FUNCTION then
			local value = tree:GetData(node, "value")
			local numChildren = tree:GetNumChildren(node)
			local info = Types.FUNCTION_INFO[value]
			if not info and numChildren ~= 1 then
				-- This is a price source being used as a function which must have exactly 1 argument
				self:_HandleErrorForNode(Types.ERROR.INVALID_NUM_ARGS, node)
				isValid = false
			elseif info and (numChildren < info.minArgs or numChildren > info.maxArgs) then
				self:_HandleErrorForNode(Types.ERROR.INVALID_NUM_ARGS, node)
				isValid = false
			elseif value == "convert" then
				-- Extra validation for convert()
				local child1Node, child2Node = tree:GetChildren(node)
				if tree:GetData(child1Node, "type") ~= Types.NODE.VARIABLE then
					self:_HandleErrorForNode(Types.ERROR.INVALID_CONVERT_ARG, child1Node)
					-- First argument is not a variable
					isValid = false
				elseif Types.IsItemParam(tree:GetData(child1Node, "value")) then
					-- First argument is an item
					self:_HandleErrorForNode(Types.ERROR.INVALID_CONVERT_ARG, child1Node)
					isValid = false
				elseif tree:GetData(child1Node, "value") == "matprice" then
					-- Can't use "matprice" as a source for convert()
					self:_HandleErrorForNode(Types.ERROR.INVALID_CONVERT_ARG, child1Node)
					isValid = false
				elseif child2Node and tree:GetData(child2Node, "type") ~= Types.NODE.VARIABLE then
					-- Second argument is not a variable
					self:_HandleErrorForNode(Types.ERROR.INVALID_CONVERT_ARG, child2Node)
					isValid = false
				elseif child2Node and not Types.IsItemParam(tree:GetData(child2Node, "value")) then
					-- Second argument is not an item
					self:_HandleErrorForNode(Types.ERROR.INVALID_CONVERT_ARG, child2Node)
					isValid = false
				end
			end
		elseif isValid and nodeType == Types.NODE.VARIABLE and Types.IsItemParam(tree:GetData(node, "value")) and not self._tree:GetParent(node) then
			-- Item parameter without a parent
			self:_HandleErrorForNode(Types.ERROR.NO_ITEM_PARAM_PARENT, node)
			isValid = false
		elseif isValid and nodeType == Types.NODE.VARIABLE and tree:GetData(node, "value") == "convert" then
			self:_HandleErrorForNode(Types.ERROR.INVALID_NUM_ARGS, node)
			isValid = false
		end
	end

	self._tree = nil
	self._tokenList = nil
	assert(not next(self._stack))
	if isValid then
		assert(not self._errType)
		return true
	else
		local errType, errTokenIndex = self._errType, self._errTokenIndex
		assert(errType and errTokenIndex)
		self._errType = nil
		self._errTokenIndex = nil
		return false, errType, errTokenIndex
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function TokenProcessor.__private:_ProcessAction(parent, action, tokenIndex)
	if not action then
		local success
		success, action, tokenIndex = self:_GetNextAction()
		if not success then
			return false
		end
	end
	assert(action == AST_ACTION.START_EXPRESSION or action == AST_ACTION.START_FUNCTION)
	local isExpression = action == AST_ACTION.START_EXPRESSION
	local nodeType = isExpression and INTERNAL_AST_NODE.EXPRESSION or Types.NODE.FUNCTION
	local nodeValue = tokenIndex ~= -1 and self._tokenList:GetRowField(tokenIndex, "str") or ""
	local node = self._tree:Insert(parent, nodeType, nodeValue, tokenIndex)
	local negateExpressionNode = nil
	while true do
		local success
		success, action, tokenIndex = self:_GetNextAction()
		if not success then
			return false
		end
		if (isExpression and action == AST_ACTION.END_EXPRESSION) or (not isExpression and action == AST_ACTION.END_FUNCTION) then
			assert(not negateExpressionNode)
			break
		elseif action == AST_ACTION.ADD_NODE then
			local tokenType, tokenStr = self._tokenList:GetRow(tokenIndex)
			local childType, childValue = nil, nil
			if tokenType == Types.TOKEN.MATH_OPERATOR then
				childType = INTERNAL_AST_NODE.OPERATOR
				childValue = tokenStr
			elseif tokenType == Types.TOKEN.MONEY then
				childType = Types.NODE.CONSTANT
				local value = MoneyFormatter.FromString(tokenStr)
				assert(value)
				childValue = value
			elseif tokenType == Types.TOKEN.NUMBER then
				childType = Types.NODE.CONSTANT
				local value = tonumber(tokenStr)
				assert(value)
				childValue = value
			elseif tokenType == Types.TOKEN.IDENTIFIER then
				childType = Types.NODE.VARIABLE
				childValue = tokenStr
			else
				error("Invalid token type: "..tostring(tokenType))
			end
			self._tree:Insert(negateExpressionNode or node, childType, childValue, tokenIndex)
			if negateExpressionNode then
				if not self:_ProcessExpression(negateExpressionNode) then
					return false
				end
				negateExpressionNode = nil
			end
		elseif action == AST_ACTION.NEGATE_NEXT then
			negateExpressionNode = self._tree:Insert(node, INTERNAL_AST_NODE.EXPRESSION, "", -1)
			self._tree:Insert(negateExpressionNode, Types.NODE.CONSTANT, 0, -1)
			self._tree:Insert(negateExpressionNode, INTERNAL_AST_NODE.OPERATOR, "-", -1)
		elseif action == AST_ACTION.START_FUNCTION or action == AST_ACTION.START_EXPRESSION then
			if not self:_ProcessAction(negateExpressionNode or node, action, tokenIndex) then
				return false
			end
			if negateExpressionNode then
				if not self:_ProcessExpression(negateExpressionNode) then
					return false
				end
				negateExpressionNode = nil
			end
		else
			error("Invalid action: "..tostring(action))
		end
	end
	if isExpression then
		return self:_ProcessExpression(node)
	else
		return true
	end
end

function TokenProcessor.__private:_GetNextAction()
	while true do
		if self._index == 0 then
			-- Start our wrapping expression
			self._index = self._index + 1
			assert(self:_StackLen() == 0)
			self:_StackPush(-1, INTERNAL_AST_NODE.ROOT_EXPRESSION)
			return true, AST_ACTION.START_EXPRESSION, -1
		elseif self._stack.queuedAction then
			-- We have an extra action queued from the current token, so return that
			local index = self._index
			self._index = self._index + 1
			local action = self._stack.queuedAction
			self._stack.queuedAction = nil
			return true, action, index
		elseif self._index <= self._tokenList:GetNumRows() then
			-- Get the next action based on the token
			local index = self._index
			local token = self._tokenList:GetRowField(self._index, "token")
			local isValid, action, queueAction = self:_GetTokenAction(token)
			if not isValid then
				return false
			end
			if queueAction then
				self._stack.queuedAction = queueAction
			else
				self._index = self._index + 1
			end
			if action then
				return true, action, index
			end
		elseif self._index == self._tokenList:GetNumRows() + 1 then
			-- End our wrapping expression
			self._index = self._index + 1
			if self:_StackLen() > 1 then
				local tokenIndex = self:_StackPop()
				self:_HandleErrorForToken(Types.ERROR.UNBALANCED_PARENS, tokenIndex)
				return false
			end
			assert(select(2, self:_StackPop()) == INTERNAL_AST_NODE.ROOT_EXPRESSION)
			assert(self:_StackLen() == 0)
			return true, AST_ACTION.END_EXPRESSION, -1
		else
			-- We're done
			assert(self:_StackLen() == 0)
			return true, nil, nil, nil
		end
	end
end

function TokenProcessor.__private:_StackPush(tokenIndex, node)
	tinsert(self._stack, tokenIndex)
	tinsert(self._stack, node)
end

function TokenProcessor.__private:_StackPeekLastTwoNodes()
	local len = #self._stack
	return self._stack[len], self._stack[len-2]
end

function TokenProcessor.__private:_StackPop()
	assert(#self._stack > 0)
	local node = tremove(self._stack)
	local tokenIndex = tremove(self._stack)
	return tokenIndex, node
end

function TokenProcessor.__private:_StackLen()
	return #self._stack / 2
end

function TokenProcessor.__private:_GetTokenAction(token)
	local parentNode, parentParentNode = self:_StackPeekLastTwoNodes()
	if token == Types.TOKEN.NUMBER or token == Types.TOKEN.MONEY or token == Types.TOKEN.IDENTIFIER or token == Types.TOKEN.MATH_OPERATOR then
		return true, AST_ACTION.ADD_NODE
	elseif token == Types.TOKEN.FUNCTION then
		assert(parentNode == INTERNAL_AST_NODE.EXPRESSION or parentNode == INTERNAL_AST_NODE.ROOT_EXPRESSION)
		self:_StackPush(self._index, Types.NODE.FUNCTION)
		return true, AST_ACTION.START_FUNCTION
	elseif token == Types.TOKEN.LEFT_PAREN then
		self:_StackPush(self._index, INTERNAL_AST_NODE.EXPRESSION)
		return true, AST_ACTION.START_EXPRESSION
	elseif token == Types.TOKEN.COMMA then
		if parentNode ~= INTERNAL_AST_NODE.EXPRESSION or parentParentNode ~= Types.NODE.FUNCTION then
			self:_HandleErrorForToken(Types.ERROR.INVALID_TOKEN, self._index)
			return false
		end
		return true, AST_ACTION.END_EXPRESSION, AST_ACTION.START_EXPRESSION
	elseif token == Types.TOKEN.RIGHT_PAREN then
		local _, stackNode = self:_StackPop()
		if stackNode == INTERNAL_AST_NODE.ROOT_EXPRESSION then
			self:_HandleErrorForToken(Types.ERROR.UNBALANCED_PARENS, self._index)
			return false
		end
		assert(stackNode == INTERNAL_AST_NODE.EXPRESSION)
		if parentParentNode == Types.NODE.FUNCTION then
			self:_StackPop()
			return true, AST_ACTION.END_EXPRESSION, AST_ACTION.END_FUNCTION
		else
			return true, AST_ACTION.END_EXPRESSION
		end
	elseif token == Types.TOKEN.NEGATIVE_OPERATOR then
		return true, AST_ACTION.NEGATE_NEXT
	elseif token == Types.TOKEN.UNKNOWN then
		self:_HandleErrorForToken(Types.ERROR.INVALID_TOKEN, self._index)
		return false
	else
		assert(AST_IGNORE_TOKEN[token])
		return true
	end
end

function TokenProcessor.__private:_ProcessExpression(parent)
	-- Get the children
	assert(not next(private.expressionResultTemp))
	local result = private.expressionResultTemp
	for child in self._tree:ChildrenIterator(parent) do
		tinsert(result, child)
	end
	if #result == 1 then
		-- Expression with a single child, so nothing to process
		wipe(result)
		return true
	elseif #result == 0 then
		-- Empty expression
		local parentParent = self._tree:GetParent(parent)
		if parentParent and self._tree:GetData(parentParent, "type") == Types.NODE.FUNCTION then
			self:_HandleErrorForNode(Types.ERROR.INVALID_NUM_ARGS, parentParent)
		else
			self:_HandleErrorForNode(Types.ERROR.INVALID_TOKEN, parent)
		end
		return false
	end

	-- Convert the list of children from infix notation to postfix
	assert(not next(private.expressionStackTemp))
	local stack = private.expressionStackTemp
	local numNodes = #result
	for i = numNodes, 1, -1 do
		local child = result[i]
		local childType = self._tree:GetData(child, "type")
		if childType == Types.NODE.FUNCTION or childType == INTERNAL_AST_NODE.EXPRESSION or childType == Types.NODE.CONSTANT or childType == Types.NODE.VARIABLE then
			tinsert(result, child)
		elseif childType == INTERNAL_AST_NODE.OPERATOR then
			local childPriority = self:_GetOperatorPriority(child, "value")
			while #stack > 0 and childPriority < self:_GetOperatorPriority(stack[#stack]) do
				tinsert(result, tremove(stack))
			end
			tinsert(stack, child)
		else
			error("Unknown type: "..tostring(childType))
		end
	end
	while #stack > 0 do
		tinsert(result, tremove(stack))
	end

	-- We use the end of the `result` list to store the result - shift the result down
	assert(#result == numNodes * 2)
	for i = numNodes, 1, -1 do
		result[i] = tremove(result)
	end
	assert(#result == numNodes)

	-- Convert operators into functions and convert them into a tree
	if not self:_ProcessOperator(result, parent, tremove(result)) then
		wipe(result)
		return false
	end
	if #result > 0 then
		self:_HandleErrorForNode(Types.ERROR.INVALID_TOKEN, result[1])
		wipe(result)
		return false
	end
	return true
end

function TokenProcessor.__private:_GetOperatorPriority(node)
	local str = self._tree:GetData(node, "value")
	if str == "-" or str == "+" then
		return 1
	elseif str == "*" or str == "/" or str == "%" then
		return 2
	elseif str == "^" then
		return 3
	else
		error("Invalid operator: "..tostring(str))
	end
end

function TokenProcessor.__private:_ProcessOperator(nodes, parent, opNode)
	if self._tree:GetData(opNode, "type") ~= INTERNAL_AST_NODE.OPERATOR then
		self:_HandleErrorForNode(Types.ERROR.INVALID_TOKEN, opNode)
		return false
	end
	self._tree:SetData(opNode, "type", Types.NODE.FUNCTION)
	self._tree:SetChildren(parent, opNode)

	if self._tree:GetData(opNode, "value") == "-" and #nodes == 1 then
		tinsert(nodes, self._tree:Insert(opNode, Types.NODE.CONSTANT, 0, -1))
	end

	local leftNode = tremove(nodes)
	if self._tree:GetData(leftNode, "type") == INTERNAL_AST_NODE.OPERATOR then
		if not self:_ProcessOperator(nodes, opNode, leftNode) then
			return false
		end
	end

	local rightNode = tremove(nodes)
	if not rightNode then
		self:_HandleErrorForNode(Types.ERROR.INVALID_TOKEN, opNode)
		return false
	end
	if self._tree:GetData(rightNode, "type") == INTERNAL_AST_NODE.OPERATOR then
		if not self:_ProcessOperator(nodes, opNode, rightNode) then
			return false
		end
	end

	self._tree:SetChildren(opNode, leftNode, rightNode)
	return true
end

function TokenProcessor.__private:_RemoveExpressions()
	local root = self._tree:GetRoot()
	assert(self._tree:GetData(root, "type") == INTERNAL_AST_NODE.EXPRESSION)
	-- Get the single child of the root node and promote it to be the new root
	assert(self._tree:GetNumChildren(root) == 1)
	local newRoot = self._tree:GetChildren(root)
	self._tree:MoveUp(newRoot)

	assert(not next(private.expressionsTemp))
	local expressions = private.expressionsTemp
	for node in self._tree:DepthFirstIterator() do
		if self._tree:GetData(node, "type") == INTERNAL_AST_NODE.EXPRESSION then
			assert(self._tree:GetNumChildren(node) == 1)
			tinsert(expressions, self._tree:GetChildren(node))
		end
	end

	for _, child in ipairs(expressions) do
		self._tree:MoveUp(child)
	end
	wipe(expressions)
end

function TokenProcessor.__private:_HandleErrorForNode(errType, node)
	self:_HandleErrorForToken(errType, self._tree:GetData(node, "tokenIndex"))
end

function TokenProcessor.__private:_HandleErrorForToken(errType, tokenIndex)
	assert(tokenIndex and tokenIndex ~= -1)
	assert(errType)
	assert(not self._errType and not self._errTokenIndex)
	self._errType = errType
	self._errTokenIndex = tokenIndex
end
