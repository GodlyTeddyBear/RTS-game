--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

--[=[
	@class useWorkerActions
	Write hook that exposes worker mutation actions. Does not subscribe to any atom — suitable for event handlers.
	@client
]=]

--[=[
	Get all worker action functions.
	@within useWorkerActions
	@return table -- Object with methods: hireWorker, assignRole, assignTarget, assignForgeRecipe, assignLumberjackTarget, assignHerbalistTarget, takeRankExam, completeMasterpiece
]=]
local function useWorkerActions()
	return {
		--[=[
			Hire a new worker of the specified type.
			@within useWorkerActions
			@param workerType string -- Worker type (e.g., "Apprentice")
			@return Result -- Async result of hire operation
		]=]
		hireWorker = function(workerType: string)
			return Knit.GetController("WorkerController"):HireWorker(workerType)
		end,

		--[=[
			Assign a role to a worker.
			@within useWorkerActions
			@param workerId string -- Worker ID
			@param roleId string -- Role ID to assign (e.g., "Miner", "Forge")
			@return Result -- Async result of role assignment
		]=]
		assignRole = function(workerId: string, roleId: string)
			return Knit.GetController("WorkerController"):AssignWorkerRole(workerId, roleId)
		end,

		--[=[
			Assign a miner worker to a specific ore type.
			@within useWorkerActions
			@param workerId string -- Worker ID
			@param oreId string -- Ore ID to assign
			@return Result -- Async result of ore assignment
		]=]
		assignTarget = function(workerId: string, oreId: string)
			return Knit.GetController("WorkerController"):AssignMinerOre(workerId, oreId)
		end,

		--[=[
			Assign a Forge worker to automatically craft a specific recipe.
			@within useWorkerActions
			@param workerId string -- Worker ID
			@param recipeId string -- Recipe ID to assign
			@return Result -- Async result of recipe assignment
		]=]
		assignForgeRecipe = function(workerId: string, recipeId: string)
			return Knit.GetController("WorkerController"):AssignForgeRecipe(workerId, recipeId)
		end,

		--[=[
			Assign a Brewery worker to automatically brew a specific recipe.
			@within useWorkerActions
			@param workerId string -- Worker ID
			@param recipeId string -- Brewery recipe ID to assign
			@return Result -- Async result of recipe assignment
		]=]
		assignBreweryRecipe = function(workerId: string, recipeId: string)
			return Knit.GetController("WorkerController"):AssignBreweryRecipe(workerId, recipeId)
		end,

		--[=[
			Assign a Lumberjack worker to a specific tree type.
			@within useWorkerActions
			@param workerId string -- Worker ID
			@param treeId string -- Tree type ID to assign
			@return Result -- Async result of tree assignment
		]=]
		assignLumberjackTarget = function(workerId: string, treeId: string)
			return Knit.GetController("WorkerController"):AssignLumberjackTarget(workerId, treeId)
		end,

		--[=[
			Assign a Herbalist worker to a specific plant type.
			@within useWorkerActions
			@param workerId string -- Worker ID
			@param plantId string -- Plant type ID to assign
			@return Result -- Async result of plant assignment
		]=]
		assignHerbalistTarget = function(workerId: string, plantId: string)
			return Knit.GetController("WorkerController"):AssignHerbalistTarget(workerId, plantId)
		end,

	}
end

return useWorkerActions
