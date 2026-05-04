local PriorityQueueStatic = {}
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue
export type PriorityQueue = typeof(setmetatable({}, PriorityQueue))

local floor = math.floor
local swap = function(arr, pos1, pos2)
	local temp = arr[pos2]
	arr[pos2] = arr[pos1]
	arr[pos1] = temp
end

-- Create a new priority queue
function PriorityQueueStatic.New(): PriorityQueue
	local newQueue = {}
	newQueue._Items = {}
	newQueue._Values = {}
	setmetatable(newQueue, PriorityQueue)
	return newQueue
end

-- Add a new item into the priority queue
function PriorityQueue:Add(item: any, priority: number)
	local index = self:Length() + 1
	self._Values[index] = priority
	self._Items[index] = item
	self:_Swim()
end

-- Remove the highest priority item from the priority queue
function PriorityQueue:Remove(): any
	local front = self._Items[1]
	local index = self:Length()

	self:_Swap(1, index)
	self._Values[index] = nil
	self._Items[index] = nil
	self:_Sink()

	return front
end

function PriorityQueue:Length(): number
	return #self._Items
end

function PriorityQueue:_Swap(pos1: number, pos2: number)
	swap(self._Items, pos1, pos2)
	swap(self._Values, pos1, pos2)
end

function PriorityQueue:_Max(pos1: number, pos2: number): any
	if self._Values[pos2] and self._Values[pos1] < self._Values[pos2] then
		return pos2
	else
		return pos1
	end
end

function PriorityQueue:_Sink()
	local pos = 1
	local len = self:Length()

	while pos * 2 <= len do
		local child = self:_Max(pos * 2, pos * 2 + 1)
		if self._Values[pos] < self._Values[child] then
			self:_Swap(pos, child)
			pos = child
		else
			break
		end
	end
end

function PriorityQueue:_Swim()
	local pos = self:Length()

	while pos > 1 do
		local parent = floor(pos / 2)
		if self._Values[pos] > self._Values[parent] then
			self:_Swap(pos, parent)
			pos = parent
		else
			break
		end
	end
end

return PriorityQueueStatic
