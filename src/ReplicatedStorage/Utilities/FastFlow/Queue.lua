local QueueStatic = {}
local Queue = {}
Queue.__index = Queue
export type Queue = typeof(setmetatable({}, Queue))

-- Create a new queue
function QueueStatic.New(): Queue
	local newQueue = {}
	newQueue._List = {}
	newQueue._Min = 1
	newQueue._Max = #newQueue._List + 1

	setmetatable(newQueue, Queue)
	return newQueue
end

-- Add an item to the end of the queue
function Queue:Add(value: any)
	self._List[self._Max] = value
	self._Max += 1
end

-- Remove the item at the front of the queue
function Queue:Remove(): any
	local value = self._List[self._Min]
	self._List[self._Min] = nil
	self._Min += 1
	return value
end

-- Get the length of the queue
function Queue:Length(): number
	return self._Max - self._Min
end

return QueueStatic
