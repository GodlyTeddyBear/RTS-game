--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)

local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local useWorkerState = require(script.Parent.useWorkerState)
local useWorkerActions = require(script.Parent.useWorkerActions)
local WorkerViewModel = require(script.Parent.Parent.ViewModels.WorkerViewModel)
local useUnlockState = require(script.Parent.Parent.Parent.Parent.Unlock.Application.Hooks.useUnlockState)

--[=[
	@class useWorkersScreenController
	Screen controller hook for the Workers screen. Manages worker list state, UI element refs, and dispatch actions.
	@client
]=]

-- Sorts workers by production activity with latest activity first, then transforms to ViewModels.
local function _buildSortedWorkerList(workers: { [string]: any }, unlockState: { [string]: boolean }): { WorkerViewModel.TWorkerViewModel }
	local raw = {}
	for _, worker in pairs(workers) do
		table.insert(raw, worker)
	end
	table.sort(raw, function(a, b)
		return a.LastProductionTick < b.LastProductionTick
	end)
	local list: { WorkerViewModel.TWorkerViewModel } = {}
	for _, worker in ipairs(raw) do
		table.insert(list, WorkerViewModel.fromWorker(worker, unlockState))
	end
	return list
end

--[=[
	Compose worker screen state and callbacks for WorkersScreen template.
	@within useWorkersScreenController
	@return table -- Controller object with workerList, workerCount, overlay state, hire ref, callbacks, and action dispatchers
]=]
local function useWorkersScreenController()
	local workers = useWorkerState()
	local unlockState = useUnlockState()
	local workerActions = useWorkerActions()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()

	local overlayContainer, setOverlayContainer = React.useState(nil :: Frame?)

	local hireRef = React.useRef(nil :: TextButton?)
	local hireHover = useHoverSpring(hireRef, AnimationTokens.Interaction.ActionButton)

	local workerList = React.useMemo(function()
		return _buildSortedWorkerList(workers, unlockState)
	end, { workers, unlockState } :: { any })

	local onHireWorker = hireHover.onActivated(function()
		local result = workerActions.hireWorker("Apprentice")
		if result then
			result:catch(function()
				soundActions.playError()
			end)
		end
	end)

	local onAssignRole = function(workerId: string, roleId: string)
		soundActions.playButtonClick()
		local result = workerActions.assignRole(workerId, roleId)
		if result then
			result:catch(function()
				soundActions.playError()
			end)
		end
	end

	-- Routes target assignment to the correct action based on worker's assigned role
	local onOptionsSelect = function(workerId: string, roleKey: string, targetId: string)
		soundActions.playButtonClick()
		local result
		if roleKey == "Forge" then
			result = workerActions.assignForgeRecipe(workerId, targetId)
		elseif roleKey == "Brewery" then
			result = workerActions.assignBreweryRecipe(workerId, targetId)
		elseif roleKey == "Miner" then
			result = workerActions.assignTarget(workerId, targetId)
		elseif roleKey == "Lumberjack" then
			result = workerActions.assignLumberjackTarget(workerId, targetId)
		elseif roleKey == "Herbalist" then
			result = workerActions.assignHerbalistTarget(workerId, targetId)
		end
		if result then
			result:catch(function()
				soundActions.playError()
			end)
		end
	end

	return {
		workerList = workerList,
		workerCount = #workerList,
		overlayContainer = overlayContainer,
		setOverlayContainer = setOverlayContainer,
		hireRef = hireRef,
		hireHover = hireHover,
		onHireWorker = onHireWorker,
		onGoBack = function()
			soundActions.playMenuClose("Workers")
			navActions.goBack()
		end,
		onAssignRole = onAssignRole,
		onOptionsSelect = onOptionsSelect,
	}
end

return useWorkersScreenController
