--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(script.Parent.Shared)
local Types = require(script.Parent.Types)

local UtilitiesFolder = ReplicatedStorage.Utilities
local TaskQueue = require(UtilitiesFolder.TaskQueue)

local QueueMethods = {}
QueueMethods.__index = QueueMethods

local SerialQueueMethods = {}
SerialQueueMethods.__index = SerialQueueMethods

local PriorityQueueMethods = {}
PriorityQueueMethods.__index = PriorityQueueMethods

local QueueModule = {}

function QueueMethods:_ScheduleFlush()
	if self.Destroyed or self._Scheduled ~= nil or self._Flushing or self._Paused then
		return
	end

	if self.FlushMode == "Manual" then
		return
	end

	if self.FlushMode == "Defer" then
		self._Scheduled = true
		self._DeferredQueue:Add(true)
		return
	end

	local flushInterval = self.FlushInterval
	assert(flushInterval ~= nil, "FlushInterval is required when FlushMode is Timer")

	self._Scheduled = task.delay(flushInterval, function()
		self._Scheduled = nil
		self:Flush()
	end)
end

function QueueMethods:_ClearScheduled()
	if self._Scheduled == nil then
		return
	end

	if self.FlushMode == "Defer" then
		self._DeferredQueue:Clear()
	else
		task.cancel(self._Scheduled)
	end

	self._Scheduled = nil
end

function QueueMethods:_ApplyOverflowPolicy<T>(item: T): boolean
	local maxQueueSize = self.MaxQueueSize
	if maxQueueSize == nil or self.OverflowPolicy == "Grow" then
		return true
	end

	if #self._Queue < maxQueueSize then
		return true
	end

	if self.OverflowPolicy == "DropNewest" or self.OverflowPolicy == "Reject" then
		return false
	end

	if self.OverflowPolicy == "DropOldest" then
		table.remove(self._Queue, 1)
		return true
	end

	return true
end

function QueueMethods:Add<T>(item: T): boolean
	if self.Destroyed then
		return false
	end

	local coalesce = self.Coalesce
	if coalesce and coalesce(self._Queue, item) then
		self:_ScheduleFlush()
		return true
	end

	if not self:_ApplyOverflowPolicy(item) then
		return false
	end

	table.insert(self._Queue, item)

	local maxBatchSize = self.MaxBatchSize
	if maxBatchSize ~= nil and #self._Queue >= maxBatchSize and not self._Flushing and not self._Paused then
		self:_ClearScheduled()
		self:Flush()
		return true
	end

	self:_ScheduleFlush()
	return true
end

function QueueMethods:Flush()
	if self.Destroyed or self._Flushing or #self._Queue == 0 or self._Paused then
		return
	end

	self:_ClearScheduled()

	local batch = self._Queue
	self._Queue = {}
	self._Flushing = true
	self.OnFlush(batch)
	self._Flushing = false

	if not self.Destroyed and #self._Queue > 0 then
		self:_ScheduleFlush()
	end
end

function QueueMethods:Clear()
	if self.Destroyed or self._Flushing then
		return
	end

	self:_ClearScheduled()
	table.clear(self._Queue)
end

function QueueMethods:Destroy()
	if self.Destroyed then
		return
	end

	self:_ClearScheduled()
	table.clear(self._Queue)
	self.Destroyed = true
end

function QueueMethods:Pause()
	if self._Paused then
		return
	end

	self._Paused = true
	self:_ClearScheduled()
end

function QueueMethods:Resume()
	if not self._Paused then
		return
	end

	self._Paused = false
	if #self._Queue > 0 then
		self:_ScheduleFlush()
	end
end

function QueueMethods:IsPaused(): boolean
	return self._Paused
end

function QueueMethods:IsScheduled(): boolean
	return self._Scheduled ~= nil
end

function QueueMethods:GetSize(): number
	return #self._Queue
end

function SerialQueueMethods:_ProcessNext()
	if self.Destroyed or self._Running or self._Stopped then
		return
	end

	local entry = table.remove(self._Queue, 1)
	if entry == nil then
		return
	end

	self._Running = true

	task.spawn(function()
		entry.Worker(entry.Item)
		self._Running = false
		self:_ProcessNext()
	end)
end

function SerialQueueMethods:Add<T>(item: T, workerCallback: ((item: T) -> ())?)
	if self.Destroyed then
		return
	end

	local worker = workerCallback or self._Worker
	assert(worker ~= nil, "SerialQueue requires a worker callback")

	table.insert(self._Queue, {
		Item = item,
		Worker = worker,
	})

	if self._AutoStart and not self._Stopped then
		self:_ProcessNext()
	end
end

function SerialQueueMethods:Start()
	if self.Destroyed then
		return
	end

	self._Stopped = false
	self:_ProcessNext()
end

function SerialQueueMethods:Stop()
	self._Stopped = true
end

function SerialQueueMethods:Clear()
	table.clear(self._Queue)
end

function SerialQueueMethods:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self._Stopped = true
	self:Clear()
end

function SerialQueueMethods:IsRunning(): boolean
	return self._Running
end

function PriorityQueueMethods:Add<T>(item: T, priority: number)
	Shared.AssertFunction(self.OnFlush, "OnFlush")
	assert(type(priority) == "number", "priority must be a number")

	table.insert(self._Queue, {
		Item = item,
		Priority = priority,
		Order = self._Order,
	})

	self._Order += 1
end

function PriorityQueueMethods:Flush()
	if self.Destroyed or #self._Queue == 0 then
		return
	end

	table.sort(self._Queue, function(left, right)
		if left.Priority == right.Priority then
			return left.Order < right.Order
		end

		if self.HighestFirst then
			return left.Priority > right.Priority
		end

		return left.Priority < right.Priority
	end)

	local batch = table.create(#self._Queue)
	for index, entry in ipairs(self._Queue) do
		batch[index] = entry.Item
	end

	table.clear(self._Queue)
	self.OnFlush(batch)
end

function PriorityQueueMethods:Clear()
	table.clear(self._Queue)
end

function PriorityQueueMethods:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self:Clear()
end

function QueueModule.Queue<T>(config: Types.TQueueConfig<T>): Types.TQueue<T>
	assert(type(config) == "table", "config must be a table")
	assert(config.FlushMode == "Defer" or config.FlushMode == "Timer" or config.FlushMode == "Manual", "FlushMode must be Defer, Timer, or Manual")
	Shared.AssertFunction(config.OnFlush, "OnFlush")

	if config.FlushMode == "Timer" then
		assert(config.FlushInterval ~= nil, "FlushInterval is required when FlushMode is Timer")
		Shared.AssertNonNegativeNumber(config.FlushInterval :: number, "FlushInterval")
	end

	if config.MaxBatchSize ~= nil then
		Shared.AssertPositiveNumber(config.MaxBatchSize, "MaxBatchSize")
	end

	if config.MaxQueueSize ~= nil then
		Shared.AssertPositiveNumber(config.MaxQueueSize, "MaxQueueSize")
	end

	local self = setmetatable({
		FlushMode = config.FlushMode,
		FlushInterval = config.FlushInterval,
		MaxBatchSize = config.MaxBatchSize,
		MaxQueueSize = config.MaxQueueSize,
		OverflowPolicy = config.OverflowPolicy or "Grow",
		Coalesce = config.Coalesce,
		OnFlush = config.OnFlush,
		_DeferredQueue = nil :: any,
		_Queue = {} :: { T },
		_Scheduled = nil :: any,
		_Flushing = false,
		_Paused = false,
		Destroyed = false,
	}, QueueMethods)

	if config.FlushMode == "Defer" then
		self._DeferredQueue = TaskQueue.new(function()
			self._Scheduled = nil
			self:Flush()
		end)
	end

	return self :: any
end

function QueueModule.SerialQueue<T>(config: Types.TSerialQueueConfig<T>?): Types.TSerialQueue<T>
	local resolvedConfig = config or {}

	return setmetatable({
		_AutoStart = resolvedConfig.AutoStart ~= false,
		_Worker = resolvedConfig.Worker,
		_Queue = {},
		_Running = false,
		_Stopped = resolvedConfig.AutoStart == false,
		Destroyed = false,
	}, SerialQueueMethods) :: any
end

function QueueModule.PriorityQueue<T>(config: Types.TPriorityQueueConfig<T>): Types.TPriorityQueue<T>
	assert(type(config) == "table", "config must be a table")
	Shared.AssertFunction(config.OnFlush, "OnFlush")

	return setmetatable({
		OnFlush = config.OnFlush,
		HighestFirst = config.HighestFirst ~= false,
		_Queue = {},
		_Order = 1,
		Destroyed = false,
	}, PriorityQueueMethods) :: any
end

return QueueModule
