--!strict

local RenderRingQueue = {}
RenderRingQueue.__index = RenderRingQueue

export type RingQueue<T> = typeof(setmetatable(
	{} :: {
		_head: number,
		_tail: number,
		_data: { [number]: T },
	},
	RenderRingQueue
))

function RenderRingQueue.new<T>(): RingQueue<T>
	return setmetatable({
		_head = 1,
		_tail = 0,
		_data = {},
	}, RenderRingQueue) :: any
end

function RenderRingQueue:IsEmpty(): boolean
	return self._head > self._tail
end

function RenderRingQueue:Push<T>(value: T)
	self._tail += 1
	self._data[self._tail] = value
end

function RenderRingQueue:Pop<T>(): T?
	if self._head > self._tail then
		if self._head > 1 then
			self._head = 1
			self._tail = 0
		end
		return nil
	end

	local value = self._data[self._head]
	self._data[self._head] = nil
	self._head += 1

	return value
end

function RenderRingQueue:Clear()
	table.clear(self._data)
	self._head = 1
	self._tail = 0
end

return RenderRingQueue
