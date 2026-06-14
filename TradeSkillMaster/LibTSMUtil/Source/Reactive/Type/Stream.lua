-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ReactiveStream = LibTSMUtil:DefineClassType("ReactiveStream")
local ReactivePublisher = LibTSMUtil:IncludeClassType("ReactivePublisher")
local Table = LibTSMUtil:Include("Lua.Table")
local NO_INITIAL_VALUE = newproxy()
local NIL_INITIAL_VALUE = newproxy()



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new stream object.
---@return ReactiveStream
function ReactiveStream.__static.Create()
	return ReactiveStream()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function ReactiveStream.__private:__init()
	self._publishers = {}
	self._scripts = {}
	self._sending = false
	self._sendQueue = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Creates a new publisher for the stream.
---@return ReactivePublisher
function ReactiveStream:Publisher()
	local publisher = ReactivePublisher.Get(self)
	tinsert(self._publishers, publisher)
	self._publishers[publisher] = NO_INITIAL_VALUE
	return publisher
end

---Creates a new publisher for the stream.
---@param sendInitialValue any An initial value to send to the new publisher once it's committed
---@return ReactivePublisher
function ReactiveStream:PublisherWithInitialValue(initialValue)
	local publisher = ReactivePublisher.Get(self)
	tinsert(self._publishers, publisher)
	if initialValue == nil then
		self._publishers[publisher] = NIL_INITIAL_VALUE
	else
		self._publishers[publisher] = initialValue
	end
	return publisher
end

-- Dispatches the queued publishers. Kept as a separate local so Send can run it under pcall
-- and always restore its _sending/_sendQueue state afterwards, even if a subscriber errors.
local function DispatchSendQueue(self, sendQueue, data)
	for i = 1, #sendQueue do
		local publisher = sendQueue[i]
		if self._publishers[publisher] ~= nil then
			publisher:_HandleData(data)
		end
	end
end

---Sends a new data value the stream's publishers.
---@param data table The data to send
function ReactiveStream:Send(data)
	local sendQueue = self._sendQueue
	assert(not self._sending and #sendQueue == 0)
	self._sending = true
	local publishers = self._publishers
	for i = 1, #publishers do
		sendQueue[i] = publishers[i]
	end
	-- Dispatch under pcall so an error inside a subscriber's _HandleData (e.g. an assert raised
	-- while a List/ScrollTable redraws) can't leave this stream stuck with _sending=true and a
	-- populated _sendQueue. Previously that permanently bricked the stream object (which is
	-- reused across DBs), so every later Send tripped the assert above. Always clean up, then
	-- re-raise the original error.
	local ok, err = pcall(DispatchSendQueue, self, sendQueue, data)
	wipe(sendQueue)
	self._sending = false
	if not ok then
		error(err, 0)
	end
end

---Registers a script handler on the stream.
---@param script '"OnPublisherCommit"'|'"OnPublisherCancelled"' The script
---@param handler? fun(stream: ReactiveStream, publisher: ReactivePublisher) The script handler or nil to remove an existing handler
function ReactiveStream:SetScript(script, handler)
	assert(handler == nil or type(handler) == "function")
	assert(script == "OnPublisherCommit" or script == "OnPublisherCancelled")
	if handler then
		assert(type(handler) == "function")
		assert(not self._scripts[script])
		self._scripts[script] = handler
	else
		assert(self._scripts[script])
		self._scripts[script] = nil
	end
end

---Gets the number of active publishers on the stream.
---@return number
function ReactiveStream:GetNumPublishers()
	return #self._publishers
end



-- ============================================================================
-- ReactiveStream - Private Class Methods
-- ============================================================================

---@private
function ReactiveStream:_HandlePublisherEvent(publisher, event)
	if event == "OnHandled" then
		-- do nothing - we don't support auto-storing
	elseif event == "OnCommit" then
		if self._scripts.OnPublisherCommit then
			self._scripts.OnPublisherCommit(self, publisher)
		end
		local initialValue = self._publishers[publisher]
		if initialValue == NIL_INITIAL_VALUE then
			initialValue = nil
		end
		if initialValue ~= NO_INITIAL_VALUE then
			publisher:_HandleData(initialValue)
		end
	elseif event == "OnCancel" then
		self._publishers[publisher] = nil
		assert(Table.RemoveByValue(self._publishers, publisher) == 1)
		if self._scripts.OnPublisherCancelled then
			self._scripts.OnPublisherCancelled(self, publisher)
		end
	else
		error("Unknown event: "..tostring(event))
	end
end
