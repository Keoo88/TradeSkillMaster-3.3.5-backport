-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local CodeGen = LibTSMTypes:DefineClassType("CustomStringCodeGen")
local Types = LibTSMTypes:Include("CustomString.Types")
local Hash = LibTSMTypes:From("LibTSMUtil"):Include("Util.Hash")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local StringBuilder = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("StringBuilder")
local private = {
	instance = nil,
	stringBuilder = nil,
}



-- ============================================================================
-- Code Templates
-- ============================================================================

local BASE_TEMPLATE =
[[return function(itemString, helpers)
	local INVALID = helpers.INVALID

	-- Locals
%(locals)s

	-- Code
	local res = INVALID
	repeat
%(code)s

		res = %(expression)s
	until true

	return res
end]]
local COMPARISON_FUNCTION_TEMPLATE =
[[if not %(res)s then repeat
	%(res)s = INVALID
%(childrenCode)s
	if %(leftRes)s %(operator)s %(rightRes)s then
%(trueCode)s
		%(res)s = %(trueRes)s
	else
%(falseCode)s
		%(res)s = %(falseRes)s
	end
until true end]]
local COMPARISON_COLLAPSED_FUNCTION_TEMPLATE =
[[if not %(res)s then repeat
	%(res)s = INVALID
%(childrenCode)s
	if %(leftRes)s %(operator)s %(rightRes)s then
%(trueCode)s
		%(res)s = %(trueRes)s
%(childCode)s
	else
%(falseCode)s
		%(res)s = %(falseRes)s
	end
until true end]]
local COMPARISON_COLLAPSED_CHILD_TEMPLATE =
[[	elseif %(leftRes)s %(operator)s %(rightRes)s then
%(trueCode)s
		%(res)s = %(trueRes)s]]
local FIRST_FUNCTION_TEMPLATE =
[[if not %(res)s then repeat
	%(res)s = INVALID
%(code)s
until true end]]
local FIRST_FUNCTION_ARG_TEMPLATE =
[[%(res)s = %(arg)s
break]]
local FIRST_FUNCTION_ARG_SUFFIX_TEMPLATE =
[[if %(res)s ~= INVALID then break end]]
local MIN_MAX_FUNCTION_ARG_TEMPLATE =
[[if %(res)s == INVALID or (%(arg)s ~= INVALID and %(arg)s %(operator)s %(res)s) then
	%(res)s = %(arg)s
end]]
local MIN_MAX_FUNCTION_TEMPLATE =
[[if not %(res)s then
	%(res)s = INVALID
%(code)s
end]]
local AVG_FUNCTION_ARG_TEMPLATE =
[[%(total)s = %(total)s + %(arg)s
%(num)s = %(num)s + 1]]
local AVG_FUNCTION_TEMPLATE =
[[if not %(res)s then
	local %(total)s, %(num)s = 0, 0
%(code)s

	%(res)s = %(num)s > 0 and %(total)s / %(num)s or INVALID
end]]
local ROUND_FUNCTION_TEMPLATE =
[[if not %(res)s then repeat
	%(res)s = INVALID
%(childrenCode)s
	%(res)s = %(func)s(%(value)s / %(sig)s%(extraAdd)s) * %(sig)s
until true end]]
local CONVERT_FUNCTION_TEMPLATE =
[[%(res)s = %(res)s or helpers.GetPrice(%(item)s, "%(value)s", "%(source)s")]]
local SOURCE_WITH_ITEM_ARG_TEMPLATE =
[[%(res)s = %(res)s or helpers.GetPrice(%(item)s, "%(value)s")]]



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Generates code for a given AST.
---@param tree Tree The AST
---@return string|nil # The generated code or nil if there was an error
---@return EnumValue|nil # The error type
---@return number|nil # The error token index
function CodeGen.__static.Execute(tree)
	if not private.instance then
		private.instance = CodeGen()
		private.stringBuilder = StringBuilder.Create()
	end
	return private.instance:_Generate(tree)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CodeGen.__private:__init()
	self._tree = nil
	self._errType = nil
	self._errTokenIndex = nil
	self._hash = {}
	self._statement = {}
	self._expression = {}
	self._localVar = {}
	self._locals = {}
end

function CodeGen.__private:_Generate(tree)
	assert(not self._tree and not self._errType and not self._errTokenIndex)
	self._tree = tree
	local code = self:_GenerateHelper()

	wipe(self._hash)
	wipe(self._statement)
	wipe(self._expression)
	wipe(self._localVar)
	wipe(self._locals)
	self._tree = nil
	local errType, errTokenIndex = self._errType, self._errTokenIndex
	self._errType = nil
	self._errTokenIndex = nil

	if code then
		assert(not errType and not errTokenIndex)
	else
		assert(errType and errTokenIndex)
	end

	return code, errType, errTokenIndex
end

function CodeGen.__private:_GenerateHelper()
	local root = self._tree:GetRoot()
	if not self:_GenerateCode(root) then
		return nil
	end

	-- Sort the locals
	for _, varName in pairs(self._localVar) do
		if not self._locals[varName] then
			tinsert(self._locals, varName)
			self._locals[varName] = true
		end
	end
	if #self._locals > 190 then
		self._errType = Types.ERROR.TOO_MANY_VARS
		self._errTokenIndex = -1
		return nil
	end
	sort(self._locals)
	for i = 1, #self._locals do
		self._locals[i] = format("local %s = nil", self._locals[i])
	end

	-- Some final formatting to make the code cleaner
	local statement = self._statement[root] or ""
	statement = gsub(statement, "\n%s+\n", "\n\n")
	statement = gsub(statement, " then\n\n", " then\n")
	statement = gsub(statement, "\telse\n\n", "\telse\n")
	statement = gsub(statement, "\trepeat\n\n", "\trepeat\n")
	statement = gsub(statement, "\n(\n\t+elseif)", "%1")
	statement = gsub(statement, "^\n+", "")

	return private.stringBuilder:SetTemplate(BASE_TEMPLATE)
		:SetParam("locals", private.IndentCode(table.concat(self._locals, "\n")))
		:SetParam("code", private.IndentCode(statement, 2))
		:SetParam("expression", self._expression[root])
		:Commit()
end

function CodeGen.__private:_GetHash(node)
	if not self._hash[node] then
		local nodeType = self._tree:GetData(node, "type")
		local nodeValue = self._tree:GetData(node, "value")
		local hash = Hash.Calculate(tostring(nodeType))
		hash = Hash.Calculate(tostring(nodeValue), hash)
		for child in self._tree:ChildrenIterator(node) do
			assert(nodeType == Types.NODE.FUNCTION)
			hash = Hash.Calculate(self:_GetHash(child), hash)
		end
		self._hash[node] = hash
	end
	return self._hash[node]
end

function CodeGen.__private:_GenerateCode(node)
	local nodeType = self._tree:GetData(node, "type")
	local nodeValue = self._tree:GetData(node, "value")
	if nodeType == Types.NODE.CONSTANT then
		self._statement[node] = nil
		self._expression[node] = nodeValue
		self._localVar[node] = nil
	elseif nodeType == Types.NODE.INVALID then
		self._statement[node] = nil
		self._expression[node] = "INVALID"
		self._localVar[node] = nil
	elseif nodeType == Types.NODE.VARIABLE then
		if nodeValue == "baseitem" then
			local varName = "baseItemString"
			self._statement[node] = private.stringBuilder:SetTemplate("%(res)s = %(res)s or helpers.GetBaseItemString(itemString)")
				:SetParam("res", varName)
				:Commit()
			self._expression[node] = varName
			self._localVar[node] = varName
		elseif Types.IsItemStringParam(nodeValue) then
			local itemString = ItemString.Get(nodeValue)
			if not itemString then
				self:_HandleError(Types.ERROR.INVALID_ITEM_STRING, node)
				return false
			end
			self._statement[node] = nil
			self._expression[node] = "\""..itemString.."\""
			self._localVar[node] = nil
		else
			local varName = "var_"..nodeValue
			self._statement[node] = private.stringBuilder:SetTemplate("%(res)s = %(res)s or helpers.GetPrice(itemString, \"%(value)s\")")
				:SetParam("res", varName)
				:SetParam("value", nodeValue)
				:Commit()
			self._expression[node] = varName
			self._localVar[node] = varName
		end
	elseif nodeType == Types.NODE.FUNCTION then
		for child in self._tree:ChildrenIterator(node) do
			if not self:_GenerateCode(child) then
				return false
			end
		end
		if nodeValue == "+" or nodeValue == "-" or nodeValue == "*" or nodeValue == "/" or nodeValue == "^" or nodeValue == "%" then
			local statement, expression = self:_GenerateMathOperation(node, nodeValue)
			self._statement[node] = statement
			self._expression[node] = expression
			self._localVar[node] = nil
		else
			local resLocal = "res_"..nodeValue.."_"..self:_GetHash(node)
			self._expression[node] = resLocal
			self._localVar[node] = resLocal
			local statement = nil
			if nodeValue == "iflte" or nodeValue == "iflt" or nodeValue == "ifgte" or nodeValue == "ifgt" or nodeValue == "ifeq" then
				statement = self:_GenerateComparisonStatement(node, nodeValue, resLocal)
			elseif nodeValue == "first" or nodeValue == "min" or nodeValue == "max" or nodeValue == "avg" then
				statement = self:_GenerateVaragFunctionStatement(node, nodeValue, resLocal)
			elseif nodeValue == "round" or nodeValue == "roundup" or nodeValue == "rounddown" then
				statement = self:_GenerateRoundFunctionStatement(node, nodeValue, resLocal)
			elseif nodeValue == "convert" then
				statement = self:_GenerateConvertFunctionStatement(node, nodeValue, resLocal)
			else
				-- Assume this is a source with an item argument
				statement = self:_GenerateSourceWithItemArgStatement(node, nodeValue, resLocal)
			end
			if not statement then
				return false
			end
			self._statement[node] = statement
		end
	else
		error("Invalid node type: "..tostring(nodeType))
	end
	return true
end

function CodeGen.__private:_GenerateMathOperation(node, nodeValue)
	assert(self._tree:GetNumChildren(node) == 2)
	local leftNode, rightNode = self._tree:GetChildren(node)
	assert(self._expression[leftNode] and self._expression[rightNode])
	local statement = ""
	if self._statement[leftNode] then
		statement = statement.."\n\n"
		if self._localVar[leftNode] then
			statement = statement..self:_StatementHelper(leftNode)
		else
			statement = statement..self._statement[leftNode]
		end
	end
	if self._statement[rightNode] then
		statement = statement.."\n\n"
		if self._localVar[rightNode] then
			statement = statement..self:_StatementHelper(rightNode)
		else
			statement = statement..self._statement[rightNode]
		end
	end

	local expression = private.stringBuilder:SetTemplate("(%(left)s %(operator)s %(right)s)")
		:SetParam("operator", nodeValue == "%" and "/ 100 *" or nodeValue)
		:SetParam("left", self._expression[leftNode])
		:SetParam("right", self._expression[rightNode])
		:Commit()

	return statement, expression
end

function CodeGen.__private:_GenerateComparisonStatement(node, nodeValue, resLocal)
	local numChildren = self._tree:GetNumChildren(node)
	if numChildren < 3 then
		self:_HandleError(Types.ERROR.INVALID_NUM_ARGS, node)
		return nil
	end
	assert(numChildren >= 3)
	local leftNode, rightNode, trueNode, falseNode = self._tree:GetChildren(node)

	local leftCode, leftRes = self:_StatementHelper(leftNode, resLocal.."_leftArg")
	local rightCode, rightRes = self:_StatementHelper(rightNode, resLocal.."_rightArg")

	-- Optimize cases where the true / false value is equal to one of the comparison values
	local trueCode, trueRes = "", nil
	if self:_GetHash(leftNode) == self:_GetHash(trueNode) then
		trueCode = "-- Optimized to leftArg"
		trueRes = leftRes
	elseif self:_GetHash(rightNode) == self:_GetHash(trueNode) then
		trueCode = "-- Optimized to rightArg"
		trueRes = rightRes
	else
		trueCode, trueRes = self:_StatementHelper(trueNode, resLocal.."_trueArg")
	end
	local falseCode, falseRes = "", nil
	if falseNode then
		if self:_GetHash(leftNode) == self:_GetHash(falseNode) then
			falseCode = "-- Optimized to leftArg"
			falseRes = leftRes
		elseif self:_GetHash(rightNode) == self:_GetHash(falseNode) then
			falseCode = "-- Optimized to rightArg"
			falseRes = rightRes
		else
			falseCode, falseRes = self:_StatementHelper(falseNode, resLocal.."_falseArg")
		end
	else
		falseCode = "-- Not specified"
		falseRes = "INVALID"
	end

	local operator = nil
	if nodeValue == "iflt" then
		operator = "<"
	elseif nodeValue == "iflte" then
		operator = "<="
	elseif nodeValue == "ifgt" then
		operator = ">"
	elseif nodeValue == "ifgte" then
		operator = ">="
	elseif nodeValue == "ifeq" then
		operator = "=="
	else
		error("Invalid node value: "..tostring(nodeValue))
	end

	local comparisonChildrenCode = private.JoinLines("", leftCode, "", rightCode, "")

	local template, childCode = nil, nil
	if numChildren > 4 then
		childCode = ""
		local i = 4
		while true do
			if numChildren < i + 2 then
				self:_HandleError(Types.ERROR.INVALID_NUM_ARGS, node)
				return nil
			end
			local childRightNode, childTrueNode, childFalseNode = select(i, self._tree:GetChildren(node))
			local childRightCode, childRightRes = self:_StatementHelper(childRightNode, resLocal.."_childRightArg")
			assert(childRightCode == "")
			local childTrueCode, childTrueRes = self:_StatementHelper(childTrueNode, resLocal.."_trueArg")

			childCode = childCode.."\n"..private.stringBuilder:SetTemplate(COMPARISON_COLLAPSED_CHILD_TEMPLATE)
				:SetParam("res", resLocal)
				:SetParam("operator", operator)
				:SetParam("leftRes", leftRes)
				:SetParam("rightRes", childRightRes)
				:SetParam("trueCode", private.IndentCode(childTrueCode))
				:SetParam("trueRes", childTrueRes)
				:Commit()

			i = i + 2
			if not childFalseNode then
				falseCode = "-- Not specified"
				falseRes = "INVALID"
				break
			elseif i >= numChildren then
				falseCode, falseRes = self:_StatementHelper(childFalseNode, resLocal.."_falseArg")
				break
			end
		end
		template = COMPARISON_COLLAPSED_FUNCTION_TEMPLATE
	else
		template = COMPARISON_FUNCTION_TEMPLATE
	end

	local builder = private.stringBuilder:SetTemplate(template)
		:SetParam("res", resLocal)
		:SetParam("operator", operator)
		:SetParam("childrenCode", private.IndentCode(comparisonChildrenCode))
		:SetParam("leftRes", leftRes)
		:SetParam("rightRes", rightRes)
		:SetParam("trueCode", private.IndentCode(trueCode, 2))
		:SetParam("trueRes", trueRes)
		:SetParam("falseCode", private.IndentCode(falseCode, 2))
		:SetParam("falseRes", falseRes)
	if childCode then
		builder:SetParam("childCode", childCode)
	end
	return builder:Commit()
end

function CodeGen.__private:_GenerateVaragFunctionStatement(node, functionName, resLocal)
	assert(self._tree:GetNumChildren(node) > 0)
	local baseArgTemplate, functionTemplate, checkArg = nil, nil, nil
	local operator = nil
	local totalLocal, numLocal = nil, nil
	if functionName == "min" then
		baseArgTemplate = MIN_MAX_FUNCTION_ARG_TEMPLATE
		functionTemplate = MIN_MAX_FUNCTION_TEMPLATE
		operator = "<"
		checkArg = false
	elseif functionName == "max" then
		baseArgTemplate = MIN_MAX_FUNCTION_ARG_TEMPLATE
		functionTemplate = MIN_MAX_FUNCTION_TEMPLATE
		operator = ">"
		checkArg = false
	elseif functionName == "avg" then
		baseArgTemplate = AVG_FUNCTION_ARG_TEMPLATE
		functionTemplate = AVG_FUNCTION_TEMPLATE
		totalLocal = resLocal.."_total"
		numLocal = resLocal.."_num"
		checkArg = true
	elseif functionName == "first" then
		baseArgTemplate = FIRST_FUNCTION_ARG_TEMPLATE
		functionTemplate = FIRST_FUNCTION_TEMPLATE
		checkArg = true
	else
		error("Invalid function name: "..tostring(functionName))
	end

	local childrenCode = ""
	local argNum = 1
	for child in self._tree:ChildrenIterator(node) do
		local argTemplate, argLocal, didWrap = self:_HandleFunctionArgument(child, baseArgTemplate, resLocal.."_arg_"..argNum, checkArg)
		if functionName == "first" and didWrap then
			argTemplate = private.JoinLines(argTemplate, FIRST_FUNCTION_ARG_SUFFIX_TEMPLATE)
		end
		local builder = private.stringBuilder:SetTemplate(argTemplate)
			:SetParam("res", resLocal)
			:SetParam("arg", argLocal)
		if functionName == "min" or functionName == "max" then
			builder:SetParam("operator", operator)
		elseif functionName == "avg" then
			builder:SetParam("total", totalLocal)
			builder:SetParam("num", numLocal)
		end
		childrenCode = private.JoinLines(childrenCode, "", builder:Commit())
		argNum = argNum + 1
	end

	local builder = private.stringBuilder:SetTemplate(functionTemplate)
		:SetParam("res", resLocal)
		:SetParam("code", private.IndentCode(childrenCode))
	if functionName == "avg" then
		builder:SetParam("total", totalLocal)
		builder:SetParam("num", numLocal)
	end
	return builder:Commit()
end

function CodeGen.__private:_GenerateRoundFunctionStatement(node, nodeValue, resLocal)
	local numChildren = self._tree:GetNumChildren(node)
	if numChildren == 0 or numChildren > 2 then
		self:_HandleError(Types.ERROR.INVALID_NUM_ARGS, node)
		return nil
	end
	local valueNode, sigNode = self._tree:GetChildren(node)

	local valueCode, valueRes = self:_StatementHelper(valueNode, resLocal.."_value")
	local sigCode, sigRes = nil, nil
	if sigNode then
		sigCode, sigRes = self:_StatementHelper(sigNode, resLocal.."_sig")
	else
		sigCode = ""
		sigRes = "1"
	end

	local func, extraAdd = nil, nil
	if nodeValue == "round" then
		func = "floor"
		extraAdd = " + 0.5"
	elseif nodeValue == "rounddown" then
		func = "floor"
		-- Add a bit in order to account for floating point inaccuracies
		extraAdd = " + 0.001 / "..sigRes
	elseif nodeValue == "roundup" then
		-- Subtract a bit in order to account for floating point inaccuracies
		func = "ceil"
		extraAdd = " - 0.001 / "..sigRes
	else
		error("Invalid node value: "..tostring(nodeValue))
	end

	local childrenCode = private.JoinLines("", valueCode, "", sigCode, "")
	return private.stringBuilder:SetTemplate(ROUND_FUNCTION_TEMPLATE)
		:SetParam("res", resLocal)
		:SetParam("childrenCode", private.IndentCode(childrenCode))
		:SetParam("func", func)
		:SetParam("value", valueRes)
		:SetParam("sig", sigRes)
		:SetParam("extraAdd", extraAdd)
		:Commit()
end

function CodeGen.__private:_GenerateConvertFunctionStatement(node, nodeValue, resLocal)
	-- Convert must have a source argument and may optionally have a "baseitem" or itemString parameter
	local numChildren = self._tree:GetNumChildren(node)
	if numChildren == 0 or numChildren > 2 then
		self:_HandleError(Types.ERROR.INVALID_NUM_ARGS, node)
		return nil
	end
	local sourceNode, itemNode = self._tree:GetChildren(node)
	assert(self._tree:GetData(sourceNode, "type") == Types.NODE.VARIABLE)
	local sourceValue = self._tree:GetData(sourceNode, "value")
	local code, item = nil, nil
	if itemNode then
		code = self:_ItemArgStatementHelper(itemNode)
		item = self._expression[itemNode]
	else
		code = ""
		item = "itemString"
	end

	return code..private.stringBuilder:SetTemplate(CONVERT_FUNCTION_TEMPLATE)
		:SetParam("res", resLocal)
		:SetParam("item", item)
		:SetParam("source", sourceValue)
		:SetParam("value", nodeValue)
		:Commit()
end

function CodeGen.__private:_GenerateSourceWithItemArgStatement(node, nodeValue, resLocal)
	local numChildren = self._tree:GetNumChildren(node)
	if numChildren ~= 1 then
		self:_HandleError(Types.ERROR.INVALID_NUM_ARGS, node)
		return nil
	end
	local itemNode = self._tree:GetChildren(node)
	local code = self:_ItemArgStatementHelper(itemNode)
	if not code then
		return nil
	end
	return code..private.stringBuilder:SetTemplate(SOURCE_WITH_ITEM_ARG_TEMPLATE)
		:SetParam("res", resLocal)
		:SetParam("item", self._expression[itemNode])
		:SetParam("value", nodeValue)
		:Commit()
end

function CodeGen.__private:_ItemArgStatementHelper(node)
	if self._tree:GetData(node, "type") ~= Types.NODE.VARIABLE then
		self:_HandleError(Types.ERROR.INVALID_TOKEN, node)
		return nil
	end
	local itemValue = self._tree:GetData(node, "value")
	if not Types.IsItemParam(itemValue) then
		self:_HandleError(Types.ERROR.INVALID_TOKEN, node)
		return nil
	end
	if self._statement[node] then
		return self._statement[node].."\n"
	else
		return ""
	end
end

function CodeGen.__private:_StatementHelper(node, argLocal, isOptional)
	local code, res = "", nil
	local nodeType = self._tree:GetData(node, "type")
	if nodeType == Types.NODE.CONSTANT then
		-- Always valid
		res = self._expression[node]
	elseif self._localVar[node] then
		if self._statement[node] then
			code = code..self._statement[node]
		end
		if not isOptional then
			code = code.."\n"..private.stringBuilder:SetTemplate("if %(arg)s == INVALID then break end")
				:SetParam("arg", self._localVar[node])
				:Commit()
		end
		res = self._localVar[node]
	else
		if self._statement[node] then
			code = code..self._statement[node].."\n"
		end
		code = code.."\n"..private.stringBuilder:SetTemplate("local %(arg)s = %(expression)s")
			:SetParam("arg", argLocal)
			:SetParam("expression", self._expression[node])
			:Commit()
		res = argLocal
	end
	return code, res
end

function CodeGen.__private:_HandleFunctionArgument(node, template, argLocal, checkArg)
	local didWrap = false
	if self._tree:GetData(node, "type") == Types.NODE.CONSTANT then
		argLocal = self._expression[node]
	else
		if checkArg then
			-- Need to make sure the argument is valid
			template = private.JoinLines(
				"if %(arg)s ~= INVALID then",
				private.IndentCode(template),
				"end"
			)
		end
		local argCode = nil
		argCode, argLocal = self:_StatementHelper(node, argLocal, true)
		template = private.JoinLines(argCode, template)
		if private.CodeCanBreak(argCode) then
			-- Need to wrap in a "repeat ... until true" since the argument code can break
			template = private.JoinLines(
				"repeat",
				private.IndentCode(template),
				"until true"
			)
			didWrap = true
		end
	end
	return template, argLocal, didWrap
end

function CodeGen.__private:_HandleError(errType, node)
	self._errType = errType
	self._errTokenIndex = self._tree:GetData(node, "tokenIndex")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.JoinLines(...)
	return strjoin("\n", ...)
end

function private.IndentCode(code, num)
	local indent = strrep("\t", num or 1)
	return indent..gsub(code, "\n", "\n"..indent)
end

function private.CodeCanBreak(code)
	if not strfind(code, "%sbreak%s") then
		-- No break in code at all
		return false
	elseif strmatch(code, "^%s*repeat\n.+\n%s*until true$") or strmatch(code, "^%s*if [^\n]+ then repeat\n.+\n%s*until true end$") then
		-- Code is wrapped in its own "repeat ... until true"
		return false
	end
	return true
end
