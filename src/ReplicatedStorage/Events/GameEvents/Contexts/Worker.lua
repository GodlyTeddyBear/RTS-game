--!strict

--[=[
	@class WorkerEvents
	Event registry for the Worker bounded context.
	@server
]=]

--[=[
	@prop WorkerHired string
	@within WorkerEvents
	Fired when a new worker is hired. Emitted with: `(userId: number, workerId: string, workerType: string)`
]=]

--[=[
	@prop WorkerLeveledUp string
	@within WorkerEvents
	Fired when a worker gains a level. Emitted with: `(userId: number, workerId: string, newLevel: number)`
]=]

--[=[
	@prop WorkerRoleAssigned string
	@within WorkerEvents
	Fired when a worker's role is changed. Emitted with: `(userId: number, workerId: string, newRole: string)`
]=]

--[=[
	@prop MiningCompleted string
	@within WorkerEvents
	Fired when a worker completes a mining task. Emitted with: `(userId: number, workerId: string, resourceType: string, quantity: string)`
]=]

local events = table.freeze({
	WorkerHired = "Worker.WorkerHired",
	WorkerLeveledUp = "Worker.WorkerLeveledUp",
	WorkerRoleAssigned = "Worker.WorkerRoleAssigned",
	MiningCompleted = "Worker.MiningCompleted",
})

-- Validation schemas: event name -> array of expected argument type strings
local schemas: { [string]: { string } } = {
	[events.WorkerHired] = { "number", "string", "string" },
	[events.WorkerLeveledUp] = { "number", "string", "number" },
	[events.WorkerRoleAssigned] = { "number", "string", "string" },
	[events.MiningCompleted] = { "number", "string", "string", "string" },
}

return { events = events, schemas = schemas }
