-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Optimizer = LibTSMTypes:Init("CustomString.Optimizer")
local Types = LibTSMTypes:Include("CustomString.Types")
local Math = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Math")
local Hash = LibTSMTypes:From("LibTSMUtil"):Include("Util.Hash")
local private = {
	optimizeTemp = {},
	nodeStack = {},
	errType = nil,
	errNode = nil,
}
local REPEATED_OPERATOR = {
	["+"] = "*",
	["*"] = "^",
}
local IS_NEGATING_OPERATOR = {
	["-"] = 0,
	["/"] = 1,
}
local IS_OPERATOR_COMMUTATIVE = {
	["+"] = true,
	["*"] = true,
}
local INVERSE_OPERATOR = {
	["+"] = "-",
	["-"] = "+",
	["*"] = "/",
	["/"] = "*",
}
local IS_REGULAR_MATH_OPERATOR = {
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["/"] = true,
	["^"] = true,
}
local IDENTITY_VALUE = {
	["+"] = 0,
	["-"] = 0,
	["*"] = 1,
	["/"] = 1,
	["^"] = 1,
}
local IS_COMPARISON_FUNCTION = {
	iflte = true,
	iflt = true,
	ifgte = true,
	ifgt = true,
	ifeq = true,
}



-- ============================================================================
-- Module Methods
-- ============================================================================

---Run the optimizer.
---@param tree Tree The node tree to optimize
---@return boolean
---@return EnumValue|nil # The error type
---@return number|nil # The error token index
function Optimizer.Execute(tree)
	assert(not private.errType and not private.errNode)
	if not private.ExecuteHelper(tree) then
		assert(private.errType and private.errNode)
		local errType = private.errType
		local errNode = private.errNode
		private.errType = nil
		private.errNode = nil
		return false, errType, errNode
	end
	return true
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ExecuteHelper(tree)
	private.ReplaceCheck(tree, tree:GetRoot())
	private.ReplacePercent(tree, tree:GetRoot())
	assert(#private.nodeStack == 0)
	if not private.OptimizeNode(tree, tree:GetRoot()) then
		wipe(private.nodeStack)
		return false
	end
	assert(#private.nodeStack == 0)
	private.FlattenChainComparisons(tree, tree:GetRoot())
	return true
end

function private.ReplaceCheck(tree, node)
	if tree:GetData(node, "type") ~= Types.NODE.FUNCTION then
		return
	end

	for child in tree:ChildrenIterator(node) do
		private.ReplaceCheck(tree, child)
	end

	local value = tree:GetData(node, "value")
	if value ~= "check" then
		return
	end

	-- Switch this out for ifgt and add a constant 0 as the right node in the comparison
	local child1, child2, child3 = tree:GetChildren(node)
	local numChildren = tree:GetNumChildren(node)
	tree:SetData(node, "value", "ifgt")
	local rightNode = tree:Insert(node, Types.NODE.CONSTANT, 0, -1)
	if numChildren == 3 then
		tree:SetChildren(node, child1, rightNode, child2, child3)
	else
		assert(numChildren == 2)
		tree:SetChildren(node, child1, rightNode, child2)
	end
end

function private.ReplacePercent(tree, node)
	if tree:GetData(node, "type") ~= Types.NODE.FUNCTION then
		return
	end

	for child in tree:ChildrenIterator(node) do
		private.ReplacePercent(tree, child)
	end

	local value = tree:GetData(node, "value")
	if value ~= "%" then
		return
	end

	-- Switch "<?> % <?>" out for "(<?> / 100) * <?>"
	assert(tree:GetNumChildren(node) == 2)
	local child1, child2 = tree:GetChildren(node)
	tree:SetData(node, "value", "*")
	local leftNode = tree:Insert(node, Types.NODE.FUNCTION, "/", -1)
	local constantNode = tree:Insert(node, Types.NODE.CONSTANT, 100, -1)
	tree:SetChildren(leftNode, child1, constantNode)
	tree:SetChildren(node, leftNode, child2)
end

function private.OptimizeNode(tree, node)
	-- Pre-calculate any constant expressions / functions we can
	local nodeType = tree:GetData(node, "type")
	if nodeType ~= Types.NODE.FUNCTION then
		-- Can't optimize this any further
		return true
	end

	-- Optimize the children
	-- Cache them on the stack cause they might change as a result of the optimization
	local startStackLen = #private.nodeStack
	for child in tree:ChildrenIterator(node) do
		tinsert(private.nodeStack, child)
	end
	while #private.nodeStack > startStackLen do
		local child = tremove(private.nodeStack, startStackLen + 1)
		if not private.OptimizeNode(tree, child) then
			return false
		end
	end

	local allConstant, allConstantOrInvalid, anyInvalid = true, true, false
	local numChildren = 0
	local child1, child2, child3, child4 = nil, nil, nil, nil
	for child in tree:ChildrenIterator(node) do
		if tree:GetData(child, "type") == Types.NODE.CONSTANT then
			-- pass
		elseif tree:GetData(child, "type") == Types.NODE.INVALID then
			anyInvalid = true
			allConstant = false
		else
			allConstant = false
			allConstantOrInvalid = false
		end
		if not child1 then
			child1 = child
		elseif not child2 then
			child2 = child
		elseif not child3 then
			child3 = child
		elseif not child4 then
			child4 = child
		end
		numChildren = numChildren + 1
	end
	assert(numChildren > 0)

	local value = tree:GetData(node, "value")
	local constantValue, isInvalid = nil, false
	if IS_REGULAR_MATH_OPERATOR[value] then
		assert(numChildren == 2)
		if anyInvalid then
			isInvalid = true
		elseif allConstant then
			constantValue = private.PerformMathOperator(value, tree:GetData(child1, "value"), tree:GetData(child2, "value"))
		else
			return private.OptimizeRegularMathExpression(tree, node)
		end
	elseif value == "min" or value == "max" then
		local func = nil
		if value == "min" then
			func = min
		elseif value == "max" then
			func = max
		end
		assert(func)
		if allConstantOrInvalid then
			-- All children are constant or invalid so can calculate the result of the function
			for child in tree:ChildrenIterator(node) do
				local childValue = tree:GetData(child, "value")
				if tree:GetData(child, "type") ~= Types.NODE.INVALID then
					constantValue = constantValue and func(constantValue, childValue) or childValue
				end
			end
			if not constantValue then
				isInvalid = true
			end
		else
			-- Iterate through the children removing invalid arguments, combining constant arguments, and deduplicating arguments
			assert(not next(private.optimizeTemp))
			local newChildren = private.optimizeTemp
			local firstConstantChild = nil
			for child in tree:ChildrenIterator(node) do
				local childType = tree:GetData(child, "type")
				if childType == Types.NODE.CONSTANT then
					if firstConstantChild then
						tree:SetData(firstConstantChild, "value", func(tree:GetData(firstConstantChild, "value"), tree:GetData(child, "value")))
					else
						firstConstantChild = child
						tinsert(newChildren, child)
					end
				elseif childType ~= Types.NODE.INVALID then
					-- Deduplicate children by hash
					local childHash = private.GetHash(tree, child)
					if not newChildren[childHash] then
						newChildren[childHash] = true
						tinsert(newChildren, child)
					end
				end
			end
			if #newChildren == 0 then
				isInvalid = true
			elseif #newChildren == 1 then
				tree:MoveUp(newChildren[1])
			else
				tree:SetChildren(node, unpack(newChildren))
			end
			wipe(newChildren)
		end
	elseif value == "avg" then
		if allConstantOrInvalid then
			-- All children are constant so can calculate the result of the function
			local total, num = 0, 0
			for child in tree:ChildrenIterator(node) do
				if tree:GetData(child, "type") ~= Types.NODE.INVALID then
					total = total + tree:GetData(child, "value")
					num = num + 1
				end
			end
			if num == 0 then
				isInvalid = true
			else
				constantValue = total / num
			end
		else
			-- Iterate through the children removing invalid arguments
			assert(not next(private.optimizeTemp))
			local newChildren = private.optimizeTemp
			for child in tree:ChildrenIterator(node) do
				if tree:GetData(child, "type") ~= Types.NODE.INVALID then
					tinsert(newChildren, child)
				end
			end
			if #newChildren == 0 then
				isInvalid = true
			elseif #newChildren == 1 then
				tree:MoveUp(newChildren[1])
			else
				tree:SetChildren(node, unpack(newChildren))
			end
			wipe(newChildren)
		end
	elseif value == "round" or value == "rounddown" or value == "roundup" then
		-- All children are constant so can calculate the result of the function
		if numChildren < 1 or numChildren > 2 then
			private.HandleError(Types.ERROR.INVALID_NUM_ARGS, node)
			return false
		end
		if anyInvalid then
			isInvalid = true
		elseif allConstant then
			local child1Value = tree:GetData(child1, "value")
			local child2Value = child2 and tree:GetData(child2, "value") or nil
			if value == "round" then
				constantValue = Math.Round(child1Value, child2Value)
			elseif value == "rounddown" then
				constantValue = Math.Floor(child1Value, child2Value)
			elseif value == "roundup" then
				constantValue = Math.Ceil(child1Value, child2Value)
			else
				-- Should never get here
				error("Unhandled case")
			end
		end
	elseif value == "first" then
		-- Iterate through the children looking for a leading constant value that first() will always evaluate to, removing invalid arguments, and deduplicating arguments
		assert(not next(private.optimizeTemp))
		local newChildren = private.optimizeTemp
		local foundValidNonConstant, foundConstant, replacementNode = false, false, nil
		for child in tree:ChildrenIterator(node) do
			local childType = tree:GetData(child, "type")
			if childType == Types.NODE.CONSTANT then
				if not foundValidNonConstant then
					replacementNode = child
					break
				elseif not foundConstant then
					foundConstant = true
					tinsert(newChildren, child)
				end
			elseif childType ~= Types.NODE.INVALID then
				if not foundConstant then
					-- Deduplicate children by hash
					local childHash = private.GetHash(tree, child)
					if not newChildren[childHash] then
						newChildren[childHash] = true
						tinsert(newChildren, child)
					end
				end
				foundValidNonConstant = true
			end
		end
		if replacementNode then
			tree:MoveUp(replacementNode)
		elseif #newChildren == 0 then
			isInvalid = true
		elseif #newChildren == 1 then
			tree:MoveUp(newChildren[1])
		else
			tree:SetChildren(node, unpack(newChildren))
		end
		wipe(newChildren)
	elseif IS_COMPARISON_FUNCTION[value] then
		if numChildren < 3 or numChildren > 4 then
			private.HandleError(Types.ERROR.INVALID_NUM_ARGS, node)
			return false
		end
		local child1Type = tree:GetData(child1, "type")
		local child2Type = tree:GetData(child2, "type")
		if child1Type == Types.NODE.INVALID or child2Type == Types.NODE.INVALID then
			isInvalid = true
		elseif child1Type == Types.NODE.CONSTANT and child2Type == Types.NODE.CONSTANT then
			-- Replace the function with just the resulting child node
			local resultChild = private.PerformComparison(value, tree:GetData(child1, "value"), tree:GetData(child2, "value")) and child3 or child4
			if resultChild then
				tree:MoveUp(resultChild)
			else
				isInvalid = true
			end
		end
	else
		-- This is likely a source with an item parameter which can't be optimized further
		return true
	end

	assert(not constantValue or type(constantValue) == "number")
	assert(not isInvalid or not constantValue)
	if isInvalid or constantValue then
		tree:RemoveAllChildren(node)
		if constantValue then
			private.SetConstantValue(tree, node, constantValue)
		else
			tree:SetData(node, "type", Types.NODE.INVALID)
			tree:SetData(node, "value", "")
		end
	end
	return true
end

function private.OptimizeRegularMathExpression(tree, node)
	local value = tree:GetData(node, "value")
	local numChildren = tree:GetNumChildren(node)
	assert(numChildren == 2)
	local leftNode, rightNode = tree:GetChildren(node)
	local leftType = tree:GetData(leftNode, "type")
	local leftValue = tree:GetData(leftNode, "value")
	local rightType = tree:GetData(rightNode, "type")
	local rightValue = tree:GetData(rightNode, "value")
	local constantNode = (leftType == Types.NODE.CONSTANT and leftNode) or (rightType == Types.NODE.CONSTANT and rightNode) or nil
	local constantValue = (leftType == Types.NODE.CONSTANT and leftValue) or (rightType == Types.NODE.CONSTANT and rightValue) or nil

	if leftType == Types.NODE.INVALID or rightType == Types.NODE.INVALID then
		-- Result of any expression with an INVALID node is always INVALID
		local invalidNode = leftType == Types.NODE.INVALID and leftNode or rightNode
		tree:MoveUp(invalidNode)
		node = invalidNode
	elseif leftType == Types.NODE.CONSTANT and rightType == Types.NODE.CONSTANT then
		-- Both children are constants - should never get here as this should be optimized already
		error("Invalid math operation")
	elseif value == "*" and constantNode and constantValue == 0 then
		-- Multiplying anything with zero always equals 0
		tree:MoveUp(constantNode)
		node = constantNode
	elseif value == "/" and constantNode == leftNode and constantValue == 0 then
		-- Dividing 0 by anything always equals 0
		tree:MoveUp(constantNode)
		node = constantNode
	elseif value == "^" and constantNode == rightNode and constantValue == 0 then
		-- Raising anything to the power of 0 always equals 1
		tree:SetData(constantNode, "value", 1)
		tree:MoveUp(constantNode)
		node = constantNode
	elseif leftType == Types.NODE.VARIABLE and rightType == Types.NODE.VARIABLE then
		-- Both children are variables
		if leftValue ~= rightValue then
			-- Operating on two different variable, so can't optimize
			return true
		end
		-- Both sides of the expression are the same variable
		if REPEATED_OPERATOR[value] then
			-- Refactor an expression such as "x + x" to be "x * 2" for better further optimization
			tree:SetData(rightNode, "type", Types.NODE.CONSTANT)
			tree:SetData(rightNode, "value", 2)
			tree:SetData(node, "value", REPEATED_OPERATOR[value])
		elseif IS_NEGATING_OPERATOR[value] then
			-- Optimize an expression such as "x - x" to be "0"
			tree:SetData(node, "type", Types.NODE.CONSTANT)
			tree:SetData(node, "value", IDENTITY_VALUE[value])
			tree:RemoveAllChildren(node)
		elseif value == "^" then
			-- Can't optimize "x ^ x" any further
			return true
		else
			error("Invalid operator: "..tostring(value))
		end
	elseif leftType == Types.NODE.FUNCTION and rightType == Types.NODE.FUNCTION then
		-- Both children are functions
		if value == "^" then
			-- Can't optimize exponentiation expressions of this form
			return true
		end
		local leftFunctionLeftNode, leftFunctionRightNode = tree:GetChildren(leftNode)
		local rightFunctionLeftNode, rightFunctionRightNode = tree:GetChildren(rightNode)
		if not leftFunctionRightNode or not rightFunctionRightNode then
			-- Can't optimize this any further
			return true
		end
		local leftFunctionLeftType = tree:GetData(leftFunctionLeftNode, "type")
		local leftFunctionRightType = tree:GetData(leftFunctionRightNode, "type")
		local leftFunctionLeftValue = tree:GetData(leftFunctionLeftNode, "value")
		local leftFunctionRightValue = tree:GetData(leftFunctionRightNode, "value")
		local rightFunctionLeftType = tree:GetData(rightFunctionLeftNode, "type")
		local rightFunctionRightType = tree:GetData(rightFunctionRightNode, "type")
		local rightFunctionLeftValue = tree:GetData(rightFunctionLeftNode, "value")
		local rightFunctionRightValue = tree:GetData(rightFunctionRightNode, "value")
		if private.GetHash(tree, leftNode) == private.GetHash(tree, rightNode) then
			if REPEATED_OPERATOR[value] then
				-- This is an expression in the form "<?> <+*> <?>" where the operands are equal
				-- Optimize to "<var> <repeatedOp> 2"
				tree:SetData(node, "value", REPEATED_OPERATOR[value])
				tree:RemoveAllChildren(rightNode)
				tree:SetData(rightNode, "type", Types.NODE.CONSTANT)
				tree:SetData(rightNode, "value", 2)
			elseif IS_NEGATING_OPERATOR[value] then
				-- This is an expression in the form "<?> <-/> <?>" where the operands are equal
				-- Optimize to "<identityValue>"
				tree:RemoveAllChildren(node)
				tree:SetData(node, "type", Types.NODE.CONSTANT)
				tree:SetData(node, "value", IDENTITY_VALUE[value])
			else
				-- Should never get here
				error("Unhandled case")
			end
		elseif value == leftValue and value == rightValue then
			if (leftFunctionLeftType == Types.NODE.CONSTANT or leftFunctionRightType == Types.NODE.CONSTANT) and (rightFunctionLeftType == Types.NODE.CONSTANT or rightFunctionRightType == Types.NODE.CONSTANT) then
				local leftFunctionConstantNode = leftFunctionLeftType == Types.NODE.CONSTANT and leftFunctionLeftNode or leftFunctionRightNode
				local leftFunctionNonConstantNode = leftFunctionLeftType == Types.NODE.CONSTANT and leftFunctionRightNode or leftFunctionLeftNode
				local leftFunctionConstantValue = leftFunctionLeftType == Types.NODE.CONSTANT and leftFunctionLeftValue or leftFunctionRightValue
				local rightFunctionNonConstantNode = rightFunctionLeftType == Types.NODE.CONSTANT and rightFunctionRightNode or rightFunctionLeftNode
				local rightFunctionConstantValue = rightFunctionLeftType == Types.NODE.CONSTANT and rightFunctionLeftValue or rightFunctionRightValue
				if leftFunctionNonConstantNode == leftFunctionLeftNode and rightFunctionNonConstantNode == rightFunctionLeftNode then
					-- This is an expression in the form "(<?> <op> <const>) <op> (<?> <op> <const>)" or "(<?> <op> <const>) <op> (<const> <op> <?>)" or "(<const> <op> <?>) <op> (<?> <op> <const>)" or "(<const> <op> <?>) <op> (<const> <op> <?>)"
					-- Optimize to "(<?> <op> <?>) <op> <const>"
					tree:SetChildren(leftNode, leftFunctionNonConstantNode, rightFunctionNonConstantNode)
					private.SetConstantValue(tree, leftFunctionConstantNode, private.PerformMathOperator(value, leftFunctionConstantValue, rightFunctionConstantValue))
					tree:SetChildren(node, leftNode, leftFunctionConstantNode)
				elseif leftFunctionNonConstantNode == leftFunctionLeftNode and rightFunctionNonConstantNode == rightFunctionRightNode then
					-- This is an expression in the form "(<?> <op> <const>) <op> (<const> <op> <?>)"
					-- Optimize to "(<?> <nonNegatingOp> <?>) <op> <const>"
					local nonNegatingOp = IS_OPERATOR_COMMUTATIVE[value] and value or INVERSE_OPERATOR[value]
					tree:SetData(leftNode, "value", nonNegatingOp)
					tree:SetChildren(leftNode, leftFunctionNonConstantNode, rightFunctionNonConstantNode)
					private.SetConstantValue(tree, leftFunctionConstantNode, private.PerformMathOperator(nonNegatingOp, leftFunctionConstantValue, rightFunctionConstantValue))
					tree:SetChildren(node, leftNode, leftFunctionConstantNode)
				elseif leftFunctionNonConstantNode == leftFunctionRightNode and rightFunctionNonConstantNode == rightFunctionLeftNode then
					-- This is an expression in the form "(<const> <op> <?>) <op> (<?> <op> <const>)"
					-- Optimize to "<const> <op> (<?> <nonNegatingOp> <?>)"
					local nonNegatingOp = IS_OPERATOR_COMMUTATIVE[value] and value or INVERSE_OPERATOR[value]
					tree:SetData(rightNode, "value", nonNegatingOp)
					tree:SetChildren(rightNode, leftFunctionNonConstantNode, rightFunctionNonConstantNode)
					private.SetConstantValue(tree, leftFunctionConstantNode, private.PerformMathOperator(nonNegatingOp, leftFunctionConstantValue, rightFunctionConstantValue))
					tree:SetChildren(node, leftFunctionConstantNode, rightNode)
				elseif leftFunctionNonConstantNode == leftFunctionRightNode and rightFunctionNonConstantNode == rightFunctionRightNode then
					-- This is an expression in the form "(<const> <op> <?>) <op> (<const> <op> <?>)"
					-- Optimize to "<const> <op> (<?> <op> <?>)"
					tree:SetChildren(rightNode, leftFunctionNonConstantNode, rightFunctionNonConstantNode)
					private.SetConstantValue(tree, leftFunctionConstantNode, private.PerformMathOperator(value, leftFunctionConstantValue, rightFunctionConstantValue))
					tree:SetChildren(node, leftFunctionConstantNode, rightNode)
				else
					-- Should never get here
					error("Unhandled case")
				end
			elseif private.GetHash(tree, leftNode) == private.GetHash(tree, rightFunctionLeftNode) then
				-- This is an expression in the form "<func> <op> (<func> <op> <?>)"
				-- Refactor to "(<func> <op> <func>) <op> <?>"
				tree:SetChildren(rightNode, leftNode, rightFunctionLeftNode)
				tree:SetChildren(node, rightNode, rightFunctionRightNode)
			elseif private.GetHash(tree, leftNode) == private.GetHash(tree, rightFunctionRightNode) then
				-- This is an expression in the form "<func> <op> (<?> <op> <func>)"
				-- Refactor to "(<func> <nonNegatingOp> <func>) <op> <?>"
				tree:SetData(rightNode, "value", IS_OPERATOR_COMMUTATIVE[value] and value or INVERSE_OPERATOR[value])
				tree:SetChildren(rightNode, leftNode, rightFunctionRightNode)
				tree:SetChildren(node, rightNode, rightFunctionLeftNode)
			else
				-- TODO: Optimize expressions such as "(x + 2) + (x + y)"
				return true
			end
		else
			-- TODO: Optimize expressions such as "(x + 2) - (x + 5)"
			return true
		end
	elseif leftType == Types.NODE.FUNCTION or rightType == Types.NODE.FUNCTION then
		-- Exactly one of the children is a function
		local functionNode, nonFunctionNode = nil, nil
		if leftType == Types.NODE.FUNCTION then
			functionNode = leftNode
			nonFunctionNode = rightNode
		else
			functionNode = rightNode
			nonFunctionNode = leftNode
		end
		local nonFunctionType = tree:GetData(nonFunctionNode, "type")
		local nonFunctionValue = tree:GetData(nonFunctionNode, "value")
		local functionValue = tree:GetData(functionNode, "value")
		if nonFunctionType == Types.NODE.CONSTANT and nonFunctionValue == IDENTITY_VALUE[value] and (IS_OPERATOR_COMMUTATIVE[value] or rightType == Types.NODE.CONSTANT) then
			-- Optimize this to just the function node
			tree:MoveUp(functionNode)
			node = functionNode
		elseif not IS_REGULAR_MATH_OPERATOR[functionValue] then
			-- It's a non-math function, so we can't optimize this expression
			return true
		else
			assert(tree:GetNumChildren(functionNode) == 2)
			local functionLeftNode, functionRightNode = tree:GetChildren(functionNode)
			local functionLeftType = tree:GetData(functionLeftNode, "type")
			local functionRightType = tree:GetData(functionRightNode, "type")
			local functionLeftValue = tree:GetData(functionLeftNode, "value")
			local functionRightValue = tree:GetData(functionRightNode, "value")
			if nonFunctionType == Types.NODE.CONSTANT then
				if value == "^" then
					-- Can't optimize exponentiation expressions of this form
					return true
				elseif functionLeftType ~= Types.NODE.CONSTANT and functionRightType ~= Types.NODE.CONSTANT then
					-- Can't optimize this expression further since neither function argument is a constant
					return true
				end
				if functionValue == value then
					-- This is an expression in the form "<const> <op> (<?> <op> <?>)" or "(<?> <op> <?>) <op> <const>"
					-- One of the function's children is a constant (exactly one or else it would have already been optimized)
					local functionConstantValue = functionLeftType == Types.NODE.CONSTANT and functionLeftValue or functionRightValue
					local functionNonConstantNode = functionLeftType == Types.NODE.CONSTANT and functionRightNode or functionLeftNode
					if nonFunctionNode == leftNode and functionLeftType == Types.NODE.CONSTANT then
						-- This is an expression in the form "<const> <op> (<const2> <op> <?>)"
						-- Optimize to "<const3> <op> <?>"
						if not IS_OPERATOR_COMMUTATIVE[value] then
							-- The operator is not commutative, which means it gets optimized to the opposite operator (i.e. "5 - (1 - x)" becomes "4 + x")
							tree:SetData(node, "value", INVERSE_OPERATOR[value])
						end
						private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(value, nonFunctionValue, functionConstantValue))
						tree:SetChildren(node, nonFunctionNode, functionNonConstantNode)
					elseif nonFunctionNode == leftNode and functionRightType == Types.NODE.CONSTANT then
						-- This is an expression in the form "<const> <op> (<?> <op> <const2>)"
						-- Optimize to "<const3> <op> <?>"
						if IS_OPERATOR_COMMUTATIVE[value] then
							private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(value, nonFunctionValue, functionConstantValue))
						else
							-- The operator is not commutative, which means we perform the opposite operator (i.e. "5 - (x - 1)" becomes "6 - x")
							private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(INVERSE_OPERATOR[value], nonFunctionValue, functionConstantValue))
						end
						tree:SetChildren(node, nonFunctionNode, functionNonConstantNode)
					elseif nonFunctionNode == rightNode and functionLeftType == Types.NODE.CONSTANT then
						-- This is an expression in the form "(<const2> <op> <?>) <op> <const>"
						-- Optimize to "<const3> <op> <?>"
						private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(value, functionConstantValue, nonFunctionValue))
						tree:SetChildren(node, nonFunctionNode, functionNonConstantNode)
					elseif nonFunctionNode == rightNode and functionRightType == Types.NODE.CONSTANT then
						-- This is an expression in the form "(<?> <op> <const2>) <op> <const>"
						-- Optimize to "<?> <op> <const3>"
						if IS_OPERATOR_COMMUTATIVE[value] then
							private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(value, functionConstantValue, nonFunctionValue))
						else
							-- The operator is not commutative, which means we perform the opposite operator (i.e. "(x - 1) - 5" becomes "x - 6")
							private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(INVERSE_OPERATOR[value], functionConstantValue, nonFunctionValue))
						end
						tree:SetChildren(node, functionNonConstantNode, nonFunctionNode)
					else
						-- Should never get here
						error("Unhandled case")
					end
				elseif functionValue == INVERSE_OPERATOR[value] then
					-- This is an expression in the form "<const> <op> (<?> <inverseOp> <?>)" or "(<?> <inverseOp> <?>) <op> <const>"
					local negatingOperator = IS_NEGATING_OPERATOR[value] and value or functionValue
					local operator = functionLeftType == Types.NODE.CONSTANT and value or negatingOperator
					if functionLeftType == Types.NODE.CONSTANT and functionNode == rightNode then
						-- This is an expression in the form "<const> <op> (<const2> <inverseOp> <?>)"
						-- Optimize to "<const3> <negatingOp> <?>"
						tree:SetData(node, "value", negatingOperator)
						private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(operator, nonFunctionValue, functionLeftValue))
						tree:MoveUp(functionRightNode)
					elseif functionLeftType == Types.NODE.CONSTANT and functionNode == leftNode then
						-- This is an expression in the form "(<const2> <inverseOp> <?>) <op> <const>"
						-- Optimize to "<const3> <inverseOp> <?>"
						tree:SetData(node, "value", functionValue)
						private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(operator, functionLeftValue, nonFunctionValue))
						tree:SetChildren(node, nonFunctionNode, functionRightNode)
					elseif functionRightType == Types.NODE.CONSTANT and functionNode == rightNode then
						-- This is an expression in the form "<const> <op> (<?> <inverseOp> <const2>)"
						-- Optimize to "<const3> <op> <?>"
						private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(negatingOperator, nonFunctionValue, functionRightValue))
						tree:MoveUp(functionLeftNode)
					elseif functionRightType == Types.NODE.CONSTANT and functionNode == leftNode then
						-- This is an expression in the form "(<?> <inverseOp> <const2>) <op> <const>"
						-- Optimize to "<?> <inverseOp> <const3>"
						tree:SetData(node, "value", functionValue)
						private.SetConstantValue(tree, nonFunctionNode, private.PerformMathOperator(operator, functionRightValue, nonFunctionValue))
						tree:MoveUp(functionLeftNode)
					else
						-- Should never get here
						error("Unhandled case")
					end
				else
					-- Can't optimize this combination of functions
					return true
				end
			elseif nonFunctionType == Types.NODE.VARIABLE then
				if value == "^" then
					-- Can't optimize exponentiation expressions of this form
					return true
				end
				if functionValue == value then
					-- This is an expression in the form "<var> <op> (<?> <op> <?>)" or "(<?> <op> <?>) <op> <var>"
					if (functionLeftType == Types.NODE.VARIABLE and functionLeftValue == nonFunctionValue) or (functionRightType == Types.NODE.VARIABLE and functionRightValue == nonFunctionValue) then
						local functionVariableNode = (functionLeftType == Types.NODE.VARIABLE and functionLeftValue == nonFunctionValue) and functionLeftNode or functionRightNode
						local functionNonVariableNode = (functionLeftType == Types.NODE.VARIABLE and functionLeftValue == nonFunctionValue) and functionRightNode or functionLeftNode
						if IS_NEGATING_OPERATOR[value] then
							-- This is an expression in the form "<var> <negatingOp> (<var> <negatingOp> <?>)" or "(<var> <negatingOp> <?>) <negatingOp> <var>" or "<var> <negatingOp> (<?> <negatingOp> <var>)" or "(<?> <negatingOp> <var>) <negatingOp> <var>"
							-- Refactor the variable into a common expression and then re-run optimizations
							if functionVariableNode == functionLeftNode and functionNode == rightNode then
								-- This is an expression in the form "<var> <negatingOp> (<var> <negatingOp> <?>)" which requires us to invert the resulting operator
								tree:SetData(node, "value", INVERSE_OPERATOR[value])
							elseif functionVariableNode == functionRightNode then
								-- This is an expression in the form "<var> <negatingOp> (<?> <negatingOp> <var>)" or "(<?> <negatingOp> <var>) <negatingOp> <var>" which requires us to invert the function operator
								tree:SetData(functionNode, "value", INVERSE_OPERATOR[value])
							end
							if functionVariableNode == functionLeftNode then
								tree:SetChildren(functionNode, functionLeftNode, nonFunctionNode)
								tree:SetChildren(node, functionNode, functionNonVariableNode)
							else
								tree:SetChildren(functionNode, nonFunctionNode, functionVariableNode)
								if functionNode == rightNode then
									tree:SetChildren(node, functionNode, functionNonVariableNode)
								else
									tree:SetChildren(node, functionNonVariableNode, functionNode)
								end
							end
						elseif IS_OPERATOR_COMMUTATIVE[value] then
							-- This is an expression in the form "<var> <op> (<var> <op> <?>)" or "(<var> <op> <?>) <op> <var>" or "<var> <op> (<?> <op> <var>)" or "(<?> <op> <var>) <op> <var>"
							-- Refactor to "(<var> <op> <var>) <op> <?>"
							tree:SetChildren(functionNode, nonFunctionNode, functionVariableNode)
							tree:SetChildren(node, functionNode, functionNonVariableNode)
						else
							-- Should never get here
							error("Unhandled case")
						end
					else
						if functionLeftType ~= Types.NODE.CONSTANT and functionRightType ~= Types.NODE.CONSTANT then
							-- Can't optimize this further
							return true
						end
						local functionConstantNode = functionLeftType == Types.NODE.CONSTANT and functionLeftNode or functionRightNode
						local functionConstantValue = functionLeftType == Types.NODE.CONSTANT and functionLeftValue or functionRightValue
						local functionNonConstantNode = functionLeftType == Types.NODE.CONSTANT and functionRightNode or functionLeftNode
						if functionConstantValue == IDENTITY_VALUE[value] then
							assert(IS_NEGATING_OPERATOR[value] and functionConstantNode == functionLeftNode)
							if functionNode == rightNode then
								-- This is an expression in the form "<var> <negatingOp> (<identityValue> <negatingOp> <?>)"
								-- Optimize to "<var> <inverseOp> <?>"
								tree:SetData(node, "value", INVERSE_OPERATOR[value])
								tree:SetChildren(node, nonFunctionNode, functionNonConstantNode)
							else
								-- This is an expression in the form "(<identityValue> <negatingOp> <?>) <negatingOp> <var>"
								-- Refactor to "<identityValue> <negatingOp> (<?> <inverseOp> <var>)"
								tree:SetData(functionNode, "value", INVERSE_OPERATOR[value])
								tree:SetChildren(functionNode, functionRightNode, nonFunctionNode)
								tree:SetChildren(node, functionConstantNode, functionNode)
							end
						else
							if IS_OPERATOR_COMMUTATIVE[value] then
								-- This is an expression in the form "(<const> <op> <?>) <op> <var>" or "(<?> <op> <const>) <op> <var>" or "<var> <op> (<const> <op> <?>)" or "<var> <op> (<?> <op> <const>)"
								-- Refactor to "<const> <op> (<var> <op> <?>)"
								tree:SetChildren(functionNode, functionNonConstantNode, nonFunctionNode)
								tree:SetChildren(node, functionConstantNode, functionNode)
							else
								assert(IS_NEGATING_OPERATOR[value])
								if functionNode == leftNode then
									if functionConstantNode == functionLeftNode then
										-- This is an expression in the form "(<const> <op> <?>) <op> <var>"
										-- Refactor to "<const> <op> (<?> <inverseOp> <var>)"
										tree:SetData(functionNode, "value", INVERSE_OPERATOR[value])
										tree:SetChildren(functionNode, functionNonConstantNode, nonFunctionNode)
										tree:SetChildren(node, functionConstantNode, functionNode)
									else
										-- This is an expression in the form "(<?> <op> <const>) <op> <var>"
										-- Refactor to "(<?> <op> <var>) <op> <const>"
										tree:SetChildren(functionNode, functionNonConstantNode, nonFunctionNode)
										tree:SetChildren(node, functionNode, functionConstantNode)
									end
								else
									-- This is an expression in the form "<var> <op> (<const> <op> <?>)" or "<var> <op> (<?> <op> <const>)"
									-- Refactor to "(<var> <inverseOp> <?>) <op> <const>" or "(<var> <op> <?>) <inverseOp> <const>" respectively
									if functionConstantNode == functionLeftNode then
										tree:SetData(functionNode, "value", INVERSE_OPERATOR[value])
									else
										tree:SetData(node, "value", INVERSE_OPERATOR[value])
									end
									tree:SetChildren(functionNode, nonFunctionNode, functionNonConstantNode)
									tree:SetChildren(node, functionNode, functionConstantNode)
								end
							end
						end
					end
				else
					-- This is an expression in the form "<var> <op> (<?> <op2> <?>)" or "(<?> <op2> <?>) <op> <var>"
					if functionLeftType == Types.NODE.CONSTANT or functionRightType == Types.NODE.CONSTANT then
						local functionConstantNode = functionLeftType == Types.NODE.CONSTANT and functionLeftNode or functionRightNode
						local functionConstantValue = functionLeftType == Types.NODE.CONSTANT and functionLeftValue or functionRightValue
						local functionNonConstantNode = functionLeftType == Types.NODE.CONSTANT and functionRightNode or functionLeftNode
						local functionNonConstantType = functionLeftType == Types.NODE.CONSTANT and functionRightType or functionLeftType
						local functionNonConstantValue = functionLeftType == Types.NODE.CONSTANT and functionRightValue or functionLeftValue
						if functionValue == INVERSE_OPERATOR[value] then
							-- This is an expression in the form "(<?> <inverseOp> <const>) <op> <?>" or "(<const> <inverseOp> <?>) <op> <?>" or "<?> <op> (<?> <inverseOp> <const>)" or "<?> <op> (<const> <inverseOp> <?>)"
							-- Refactor the constant out from the inner expression
							if functionNode == leftNode or (functionRightType == Types.NODE.CONSTANT and not IS_NEGATING_OPERATOR[value]) then
								tree:SetData(node, "value", functionValue)
							end
							if functionRightType == Types.NODE.CONSTANT or not IS_NEGATING_OPERATOR[functionValue] then
								tree:SetData(functionNode, "value", value)
							end
							if functionNode == leftNode then
								tree:SetChildren(functionNode, functionNonConstantNode, nonFunctionNode)
							else
								tree:SetChildren(functionNode, nonFunctionNode, functionNonConstantNode)
							end
							if functionRightType == Types.NODE.CONSTANT or functionNode == rightNode then
								tree:SetChildren(node, functionNode, functionConstantNode)
							else
								tree:SetChildren(node, functionConstantNode, functionNode)
							end
						elseif functionNonConstantType == Types.NODE.VARIABLE and nonFunctionType == Types.NODE.VARIABLE and functionNonConstantValue == nonFunctionValue then
							if (functionValue == "/" and functionNonConstantNode == functionLeftNode) or functionValue == "*" then
								assert(value == "-" or value == "+")
								-- This is an expression in the form "(<var> <*/> <const>) <-+> <var>" or "(<const> * <var>) <-+> <var>" or "<var> <-+> (<var> <*/> <const>)" or "<var> <-+> (<const> * <var>)"
								-- Refactor into "<var> * <const2>"
								local newConstantValue = private.PerformMathOperator(functionValue, IDENTITY_VALUE[functionValue], functionConstantValue)
								if functionNode == leftNode then
									newConstantValue = private.PerformMathOperator(value, newConstantValue, 1)
								else
									newConstantValue = private.PerformMathOperator(value, 1, newConstantValue)
								end
								tree:SetData(functionNode, "value", "*")
								private.SetConstantValue(tree, functionConstantNode, newConstantValue)
								tree:MoveUp(functionNode)
								node = functionNode
							elseif functionNonConstantNode == functionLeftNode and functionValue == "^" and (value == "*" or value == "/") then
								-- This is an expression in the form "(<var> ^ <const>) <*/> <var>" or "<var> <*/> (<var> ^ <const>)"
								-- Refactor into "<var> ^ <const2>"
								if functionNode == leftNode then
									private.SetConstantValue(tree, functionConstantNode, private.PerformMathOperator(value == "*" and "+" or "-", functionConstantValue, 1))
								else
									private.SetConstantValue(tree, functionConstantNode, private.PerformMathOperator(value == "*" and "+" or "-", 1, functionConstantValue))
								end
								tree:MoveUp(functionNode)
								node = functionNode
							elseif functionNode == leftNode and value == "/" then
								-- This is an expression in the form "(<var> <+-> <const>) / <var>" or "(<const> <+-> <var>) / <var>"
								-- Refactor into "1 <+-> (<const> / <var>)" or "(<const> / <var>) <+-> 1" respectively
								tree:SetData(node, "value", functionValue)
								tree:SetData(functionNode, "value", value)
								tree:SetData(nonFunctionNode, "type", Types.NODE.CONSTANT)
								tree:SetData(nonFunctionNode, "value", IDENTITY_VALUE[value])
								tree:SetChildren(functionNode, functionConstantNode, functionNonConstantNode)
								if functionConstantNode == functionLeftNode then
									tree:SetChildren(node, functionNode, nonFunctionNode)
								else
									tree:SetChildren(node, nonFunctionNode, functionNode)
								end
							else
								-- Can't optimize this any further
								return true
							end
						else
							-- Can't optimize this any further
							return true
						end
					elseif functionValue == INVERSE_OPERATOR[value] and functionLeftType == Types.NODE.VARIABLE and nonFunctionType == Types.NODE.VARIABLE and functionLeftValue == nonFunctionValue then
						-- This is an expression in the form "<var> <op> (<var> <inverseOp> <?>)" or "(<var> <inverseOp> <?>) <op> <var>"
						-- Refactor to "(<var> <op> <var>) <op2> <?>"
						if not IS_NEGATING_OPERATOR[value] or functionNode == leftNode then
							tree:SetData(node, "value", functionValue)
						end
						tree:SetData(functionNode, "value", value)
						tree:SetChildren(functionNode, nonFunctionNode, functionLeftNode)
						tree:SetChildren(node, functionNode, functionRightNode)
					elseif functionValue == INVERSE_OPERATOR[value] and functionRightType == Types.NODE.VARIABLE and nonFunctionType == Types.NODE.VARIABLE and functionRightValue == nonFunctionValue then
						-- This is an expression in the form "<var> <op> (<?> <inverseOp> <var>)" or "(<?> <inverseOp> <var>) <op> <var>"
						-- Refactor to "(<var> <negatingOp> <var>) <op> <?>" or "<?> <op> (<var> <negatingOp> <var>)" respectively
						if not IS_NEGATING_OPERATOR[functionValue] then
							tree:SetData(functionNode, "value", INVERSE_OPERATOR[functionValue])
						end
						tree:SetChildren(functionNode, nonFunctionNode, functionRightNode)
						if functionNode == leftNode then
							tree:SetChildren(node, functionLeftNode, functionNode)
						else
							tree:SetChildren(node, functionNode, functionLeftNode)
						end
					else
						-- Can't optimize this any further
						return true
					end
				end
			else
				-- Should never get here
				error("Unhandled case")
			end
		end
	elseif leftType == Types.NODE.VARIABLE or rightType == Types.NODE.VARIABLE then
		-- One of the children is a variable and the other is a constant
		assert(constantNode)
		if constantValue ~= IDENTITY_VALUE[value] then
			-- Can't optimize this further
			return true
		elseif not IS_OPERATOR_COMMUTATIVE[value] and leftType == Types.NODE.CONSTANT then
			-- Can't optimize this further
			return true
		end
		node = leftType == Types.NODE.CONSTANT and rightNode or leftNode
		tree:MoveUp(node)
	else
		-- Should never get here
		error("Unhandled case")
	end

	-- Rerun optimization on this node
	return private.OptimizeNode(tree, node)
end

function private.SetConstantValue(tree, node, value)
	local isInvalid = private.IsInvalidConstantValue(value)
	tree:SetData(node, "type", isInvalid and Types.NODE.INVALID or Types.NODE.CONSTANT)
	tree:SetData(node, "value", isInvalid and "" or value)
end

function private.FlattenChainComparisons(tree, node)
	if tree:GetData(node, "type") ~= Types.NODE.FUNCTION then
		return
	end

	for child in tree:ChildrenIterator(node) do
		private.FlattenChainComparisons(tree, child)
	end

	local value = tree:GetData(node, "value")
	if not IS_COMPARISON_FUNCTION[value] then
		return
	end

	local leftNode, rightNode, trueNode, falseNode, extraNode = tree:GetChildren(node)
	if extraNode then
		return
	elseif not falseNode then
		return
	elseif tree:GetData(leftNode, "type") ~= Types.NODE.VARIABLE then
		return
	elseif tree:GetData(falseNode, "type") ~= Types.NODE.FUNCTION or tree:GetData(falseNode, "value") ~= value then
		return
	elseif tree:GetData(rightNode, "type") ~= Types.NODE.CONSTANT or tree:GetData(trueNode, "type") ~= Types.NODE.CONSTANT then
		return
	end

	if tree:GetNumChildren(falseNode) < 4 then
		return
	end
	local falseLeftNode, falseRightNode, falseTrueNode = tree:GetChildren(falseNode)
	if tree:GetData(falseLeftNode, "type") ~= Types.NODE.VARIABLE or tree:GetData(leftNode, "value") ~= tree:GetData(falseLeftNode, "value") then
		return
	elseif tree:GetData(falseRightNode, "type") ~= Types.NODE.CONSTANT or tree:GetData(falseTrueNode, "type") ~= Types.NODE.CONSTANT then
		return
	end

	tree:SetChildren(node, leftNode, rightNode, trueNode, select(2, tree:GetChildren(falseNode)))
	tree:SetData(node, "value", value)
end

function private.PerformMathOperator(operator, left, right)
	if operator == "+" then
		return left + right
	elseif operator == "-" then
		return left - right
	elseif operator == "*" then
		return left * right
	elseif operator == "/" then
		return left / right
	elseif operator == "^" then
		return left ^ right
	else
		error("Invalid operator: "..operator)
	end
end

function private.PerformComparison(comparison, left, right)
	if comparison == "iflte" then
		return left <= right
	elseif comparison == "iflt" then
		return left < right
	elseif comparison == "ifgte" then
		return left >= right
	elseif comparison == "ifgt" then
		return left > right
	elseif comparison == "ifeq" then
		return left == right
	else
		error("Invalid comparison: "..tostring(comparison))
	end
end

function private.GetHash(tree, node)
	local nodeType = tree:GetData(node, "type")
	local value = tree:GetData(node, "value")
	local hash = Hash.Calculate(tostring(nodeType))
	hash = Hash.Calculate(tostring(value), hash)
	if nodeType == Types.NODE.FUNCTION then
		if IS_OPERATOR_COMMUTATIVE[value] then
			-- Hash in a way that's stable regardless of the order of the operands
			assert(tree:GetNumChildren(node) == 2)
			local leftNode, rightNode = tree:GetChildren(node)
			local leftHash = private.GetHash(tree, leftNode)
			local rightHash = private.GetHash(tree, rightNode)
			if leftHash < rightHash then
				hash = Hash.Calculate(leftHash, hash)
				hash = Hash.Calculate(rightHash, hash)
			else
				hash = Hash.Calculate(rightHash, hash)
				hash = Hash.Calculate(leftHash, hash)
			end
		else
			for child in tree:ChildrenIterator(node) do
				hash = Hash.Calculate(private.GetHash(tree, child), hash)
			end
		end
	end
	return hash
end

function private.HandleError(errType, node)
	assert(not private.errType)
	private.errType = errType
	private.errNode = node
end

function private.IsInvalidConstantValue(value)
	assert(type(value) == "number")
	return value == math.huge or value == -math.huge or Math.IsNan(value)
end
