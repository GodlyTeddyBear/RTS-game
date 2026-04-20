--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

--[=[
	@class useWorkerState
	Read hook that subscribes to the worker state atom from WorkerController and returns current worker data.
	@client
]=]

--[=[
	Subscribe to the worker state atom.
	@within useWorkerState
	@return { [string]: TWorker } -- Current worker state indexed by ID, empty table if not yet hydrated
]=]
local function useWorkerState()
	local workerController = Knit.GetController("WorkerController")
	if not workerController then
		warn("useWorkerState: WorkerController not available")
		return {}
	end
	local workersAtom = workerController:GetWorkersAtom()
	return useAtom(workersAtom) or {}
end

return useWorkerState
