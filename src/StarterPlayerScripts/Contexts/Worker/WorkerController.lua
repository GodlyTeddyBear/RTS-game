--!strict

--[=[
	@class WorkerController
	Knit client controller. Manages worker sync, animation lifecycle via CollectionService, and action dispatch.
	@client
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local TargetSchema = require(ReplicatedStorage.Contexts.Targeting.Config.TargetSchema)
local RoleTargetTypeConfig = require(ReplicatedStorage.Contexts.Worker.Config.RoleTargetTypeConfig)

-- Infrastructure
local WorkerSyncClient = require(script.Parent.Infrastructure.WorkerSyncClient)
local AnimateWorkerModule = require(script.Parent.AnimateWorkerModule)

-- Action system
local ActionRegistry = require(ReplicatedStorage.Utilities.ActionSystem.ActionRegistry)

local TAG = "AnimatedWorker"

local WorkerController = Knit.CreateController({
	Name = "WorkerController",
})

---
-- Knit Lifecycle
---

function WorkerController:KnitInit()
	-- Registry for local sub-services
	self._Registry = Registry.new("Client")
	self._Registry:Register("WorkerSyncClient", WorkerSyncClient.new(), "Infrastructure")

	-- Auto-register all action classes from the Actions folder
	for _, module in script.Parent.Actions:GetChildren() do
		if module:IsA("ModuleScript") then
			local name = module.Name:gsub("Action$", "")
			local action = require(module) :: any
			ActionRegistry.Register(name, action.new())
		end
	end

	-- Init all
	self._Registry:InitAll()

	-- Cache refs
	self.SyncService = self._Registry:Get("WorkerSyncClient")

	-- Track active cleanup functions per model
	self._ActiveCleanups = {} :: { [Model]: () -> () }

	print("WorkerController initialized")
end

function WorkerController:KnitStart()
	-- Resolve cross-context deps
	local WorkerContext = Knit.GetService("WorkerContext")
	self.WorkerContext = WorkerContext

	-- Start sub-services (WorkerSyncClient:Start() begins Blink listener)
	self._Registry:StartOrdered({ "Infrastructure", "Application" })

	-- Get SoundEngine from SoundController (deferred — SoundController initialises in KnitStart too)
	local _soundEngine = nil
	local function getSoundEngine()
		if not _soundEngine then
			local SoundController = Knit.GetController("SoundController")
			_soundEngine = SoundController
		end
		return _soundEngine
	end

	-- Get VFXEngine from VFXController
	local VFXController = Knit.GetController("VFXController")
	local TargetingController = Knit.GetController("TargetingController")
	self.TargetingController = TargetingController

	-- Build shared context table (Model is stamped per-worker by AnimateWorkerModule.setup)
	local function buildContext(model: Model): any
		return {
			Model = nil, -- stamped by AnimateWorkerModule.setup()
			SoundEngine = getSoundEngine(),
			VFXService = VFXController:GetVFXEngine(),
			ResolveTargetInstance = function(): Instance?
				return self:ResolveCurrentTargetInstance(model)
			end,
		}
	end

	-- CollectionService runner — replaces the Studio-only AnimateWorker script
	local function onTagAdded(instance: Instance)
		if not instance:IsA("Model") then return end
		local model = instance :: Model

		local context = buildContext(model)
		AnimateWorkerModule.setup(model, context):andThen(function(cleanup)
			if cleanup then
				self._ActiveCleanups[model] = cleanup
			end
		end)
	end

	local function onTagRemoved(instance: Instance)
		if not instance:IsA("Model") then return end
		local model = instance :: Model
		local cleanup = self._ActiveCleanups[model]
		if cleanup then
			cleanup()
			self._ActiveCleanups[model] = nil
			print("[WorkerController] Cleaned up worker:", model.Name)
		end
	end

	-- Handle already-tagged instances
	for _, instance in CollectionService:GetTagged(TAG) do
		task.spawn(onTagAdded, instance)
	end

	-- Handle future tagged instances
	CollectionService:GetInstanceAddedSignal(TAG):Connect(onTagAdded)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(onTagRemoved)

	task.delay(0.3, function()
		self:RequestWorkerState()
	end)

	print("WorkerController started")
end

-- Extract worker ID from model using WorkerId attribute or Name pattern
local function _ExtractWorkerId(model: Model): string?
	local workerIdAttr = model:GetAttribute("WorkerId")
	if type(workerIdAttr) == "string" and workerIdAttr ~= "" then
		return workerIdAttr
	end

	local parsedId = string.match(model.Name, "^Worker_(.+)$")
	if parsedId and parsedId ~= "" then
		return parsedId
	end

	return nil
end

-- Look up worker data from the current sync state by extracting ID from model
local function _GetWorkerFromModel(self: any, model: Model): any?
	local workerId = _ExtractWorkerId(model)
	if not workerId then
		return nil
	end

	local workers = self.SyncService:GetWorkersAtom()()
	return workers[workerId]
end

function WorkerController:_ExtractWorkerId(model: Model): string?
	return _ExtractWorkerId(model)
end

function WorkerController:_GetWorkerFromModel(model: Model): any?
	return _GetWorkerFromModel(self, model)
end

--[=[
	Resolve the worker's current assignment target instance for action/VFX usage.
	@within WorkerController
	@param model Model -- Worker model
	@return Instance? -- Target instance if assigned and resolvable, nil otherwise
]=]
function WorkerController:ResolveCurrentTargetInstance(model: Model): Instance?
	if not self.TargetingController then
		return nil
	end

	local worker = self:_GetWorkerFromModel(model)
	if not worker or not worker.TaskTarget then
		return nil
	end

	local targetType = RoleTargetTypeConfig[worker.AssignedTo or ""]
	if not targetType then
		return nil
	end

	local sourceTargetId = worker.TaskTarget
	local typeIdTag = TargetSchema.GetTypeIdTag(targetType, sourceTargetId)
	local matches = self.TargetingController:FindAllByTag(typeIdTag)
	if #matches > 0 then
		return matches[1]
	end

	return self.TargetingController:FindFirstByTypeAndId(targetType, sourceTargetId)
end

---
-- Public API Methods
---

--[=[
	Get the workers atom for UI components.
	@within WorkerController
	@return Atom -- Atom containing workers table
]=]
function WorkerController:GetWorkersAtom()
	return self.SyncService:GetWorkersAtom()
end

--[=[
	Request initial worker state (hydration).
	@within WorkerController
	@return Result -- Async result of state request
	@yields
]=]
function WorkerController:RequestWorkerState()
	return self.WorkerContext:RequestWorkerState()
		:catch(function(err)
			warn("[WorkerController:RequestWorkerState]", err.type, err.message)
		end)
end

--[=[
	Hire a worker of the given type.
	@within WorkerController
	@param workerType string -- Worker type (e.g., "Apprentice")
	@return Result -- Async result of hire operation
	@yields
]=]
function WorkerController:HireWorker(workerType: string)
	return self.WorkerContext:HireWorker(workerType)
		:catch(function(err)
			warn("[WorkerController:HireWorker]", err.type, err.message)
		end)
end

--[=[
	Assign a role to a worker.
	@within WorkerController
	@param workerId string -- Worker ID
	@param roleId string -- Role ID to assign
	@return Result -- Async result of role assignment
	@yields
]=]
function WorkerController:AssignWorkerRole(workerId: string, roleId: string)
	return self.WorkerContext:AssignRole(workerId, roleId)
		:catch(function(err)
			warn("[WorkerController:AssignWorkerRole]", err.type, err.message)
		end)
end

--[=[
	Assign a miner worker to a specific ore type.
	@within WorkerController
	@param workerId string -- Worker ID
	@param oreId string -- Ore ID to assign
	@return Result -- Async result of ore assignment
	@yields
]=]
function WorkerController:AssignMinerOre(workerId: string, oreId: string)
	return self.WorkerContext:AssignMinerOre(workerId, oreId)
		:catch(function(err)
			warn("[WorkerController:AssignMinerOre]", err.type, err.message)
		end)
end

--[=[
	Assign a Forge worker to automatically craft a specific recipe.
	@within WorkerController
	@param workerId string -- Worker ID
	@param recipeId string -- Recipe ID to assign
	@return Result -- Async result of recipe assignment
	@yields
]=]
function WorkerController:AssignForgeRecipe(workerId: string, recipeId: string)
	return self.WorkerContext:AssignForgeRecipe(workerId, recipeId)
		:catch(function(err)
			warn("[WorkerController:AssignForgeRecipe]", err.type, err.message)
		end)
end

--[=[
	Assign a Brewery worker to automatically brew a specific recipe.
	@within WorkerController
	@param workerId string -- Worker ID
	@param recipeId string -- Brewery recipe ID to assign
	@return Result -- Async result of recipe assignment
	@yields
]=]
function WorkerController:AssignBreweryRecipe(workerId: string, recipeId: string)
	return self.WorkerContext:AssignBreweryRecipe(workerId, recipeId)
		:catch(function(err)
			warn("[WorkerController:AssignBreweryRecipe]", err.type, err.message)
		end)
end

--[=[
	Assign a Lumberjack worker to a specific tree type.
	@within WorkerController
	@param workerId string -- Worker ID
	@param treeId string -- Tree type ID to assign
	@return Result -- Async result of tree assignment
	@yields
]=]
function WorkerController:AssignLumberjackTarget(workerId: string, treeId: string)
	return self.WorkerContext:AssignLumberjackTarget(workerId, treeId)
		:catch(function(err)
			warn("[WorkerController:AssignLumberjackTarget]", err.type, err.message)
		end)
end

--[=[
	Assign a Herbalist worker to a specific plant type.
	@within WorkerController
	@param workerId string -- Worker ID
	@param plantId string -- Plant type ID to assign
	@return Result -- Async result of plant assignment
	@yields
]=]
function WorkerController:AssignHerbalistTarget(workerId: string, plantId: string)
	return self.WorkerContext:AssignHerbalistTarget(workerId, plantId)
		:catch(function(err)
			warn("[WorkerController:AssignHerbalistTarget]", err.type, err.message)
		end)
end

return WorkerController
