--!optimize 2
local RunService = game:GetService("RunService")

local DefaultBudget = 0.003
local MinFrameTime = 1 / 240

local ccreate = coroutine.create
local cyield = coroutine.yield
local cresume = coroutine.resume
local cstatus = coroutine.status
local cclose = coroutine.close
local now = os.clock

-- frame tracking
local FrameStart = now()
local FrameTime = 0
local EstimatedDelta = 1 / 60

RunService.Heartbeat:Connect(function(dt)
	local t = now()
	FrameTime = t - FrameStart
	FrameStart = t

	EstimatedDelta = EstimatedDelta * 0.9 + dt * 0.1
end)

-- ring queue logic
type Queue = {
	head: number,
	tail: number,
	data: { thread },
}

local function newQueue(): Queue
	return { head = 1, tail = 0, data = {} }
end

local function push(q: Queue, v: thread)
	q.tail += 1
	q.data[q.tail] = v
end

local function pop(q: Queue): thread?
	if q.head > q.tail then
		if q.head > 1 then
			q.head = 1
			q.tail = 0
		end
		return nil
	end

	local v = q.data[q.head]
	q.data[q.head] = nil
	q.head += 1

	return v
end

local function empty(q: Queue)
	return q.head > q.tail
end

-- scheduler
local Scheduler = {}
Scheduler.__index = Scheduler

export type SchedulerType = typeof(setmetatable(
	{} :: {
		queues: { [number]: Queue },
		priorities: { number },
		budget: number,
	},
	Scheduler
))

function Scheduler.new(Budget: number?): SchedulerType
	return setmetatable({
		queues = {},
		priorities = {},
		budget = Budget or DefaultBudget,
	}, Scheduler) :: any
end

-- add task
function Scheduler:Add(Fn: () -> (), Priority: number?)
	local p = Priority or 0
	local q = self.queues[p]

	if not q then
		q = newQueue()
		self.queues[p] = q

		table.insert(self.priorities, p)
		table.sort(self.priorities, function(a, b)
			return a > b
		end)
	end

	push(q, ccreate(Fn))
end

function Scheduler:Yield(...)
	cyield(...)
end

-- adaptive budget
function Scheduler:GetBudget()
	local target = math.max(MinFrameTime, EstimatedDelta * 0.85)
	local remaining = target - FrameTime

	if remaining <= 0 then
		return 0
	end
	return math.min(remaining, self.budget)
end

function Scheduler:Step()
	local stepStart = now()
	local budget = self:GetBudget()

	if budget <= 0 then
		return
	end

	for _, p in self.priorities do
		local q = self.queues[p]
		if not q or empty(q) then
			continue
		end

		while not empty(q) do
			local task = pop(q)
			if not task then
				break
			end

			local ok, err = cresume(task)

			if not ok then
				warn("Scheduler task error:", err)
				cclose(task)
			elseif cstatus(task) ~= "dead" then
				push(q, task)
			end

			if now() - stepStart > budget then
				return
			end
		end
	end
end

function Scheduler:Destroy()
	for _, q in self.queues do
		while not empty(q) do
			local t = pop(q)
			if t then
				cclose(t)
			end
		end
	end

	table.clear(self.queues)
	table.clear(self.priorities)
	table.clear(self)

	self.destroyed = true
	table.freeze(self)
end

return Scheduler
