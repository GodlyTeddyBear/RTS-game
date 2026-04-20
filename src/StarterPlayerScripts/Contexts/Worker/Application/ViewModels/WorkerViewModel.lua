--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkerConfig = require(ReplicatedStorage.Contexts.Worker.Config.WorkerConfig)
local WorkerLevelConfig = require(ReplicatedStorage.Contexts.Worker.Config.WorkerLevelConfig)
local RoleConfig = require(ReplicatedStorage.Contexts.Worker.Config.RoleConfig)
local RankConfig = require(ReplicatedStorage.Contexts.Worker.Config.RankConfig)
local RecipeConfig = require(ReplicatedStorage.Contexts.Forge.Config.RecipeConfig)
local BreweryRecipeConfig = require(ReplicatedStorage.Contexts.Brewery.Config.BreweryRecipeConfig)
local WorkerTypes = require(ReplicatedStorage.Contexts.Worker.Types.WorkerTypes)
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

--[=[
	@class WorkerViewModel
	Transforms backend worker data into UI-ready display state, including formatted labels and derived dropdown items.
	@client
]=]

--[=[
	@interface TDropdownItem
	@within WorkerViewModel
	.Id string -- Unique identifier for the dropdown item
	.DisplayName string -- Human-readable display name
	.IsLocked boolean? -- Whether the item is locked/unavailable (optional; defaults to false)
]=]

-- Shared dropdown item type (mirrors ActionDropdown.TDropdownItem)
export type TDropdownItem = {
	Id: string,
	DisplayName: string,
	IsLocked: boolean?,
}

--[=[
	@interface TWorkerViewModel
	@within WorkerViewModel
	.Id string -- Worker's unique ID
	.LevelLabel string -- Formatted level display (e.g., "Lv. 5")
	.XPLabel string -- Formatted XP display (e.g., "150 / 500 XP")
	.XPProgress number -- Normalized XP progress 0–1
	.SpeedLabel string -- Formatted production speed (e.g., "1.50x Speed")
	.AssignmentLabel string -- Current role assignment display
	.AssignedRole string -- Currently assigned role ID
	.TaskTarget string? -- Current task target ID if assigned
	.Rank string -- Worker's rank ID
	.RankLabel string -- Formatted rank display
	.RankBadgeColor Color3 -- Rank badge color
	.RoleItems { TDropdownItem } -- Available roles for assignment
	.AssignLabel string -- Assign button label
	.TargetItems { TDropdownItem } -- Available targets for current role
	.OptionsLabel string -- Options button label
	.OptionsSelectRole string -- Action handler key: "Forge" | "Brewery" | "Miner" | "Lumberjack" | "Herbalist" | ""
]=]

export type TWorkerViewModel = {
	Id: string,
	LevelLabel: string,
	XPLabel: string,
	XPProgress: number,
	SpeedLabel: string,
	AssignmentLabel: string,
	AssignedRole: string,
	TaskTarget: string?,
	Rank: string,
	RankLabel: string,
	RankBadgeColor: Color3,
	-- Derived dropdown data (moved from WorkerCard)
	RoleItems: { TDropdownItem },
	AssignLabel: string,
	TargetItems: { TDropdownItem },
	OptionsLabel: string,
	OptionsSelectRole: string, -- Which action handler to use: "Forge" | "Brewery" | "Miner" | "Lumberjack" | "Herbalist" | ""
}

local WorkerViewModel = {}

-- Exponential XP requirement: scales by growth factor each level
local function _calculateXPRequired(level: number): number
	return WorkerLevelConfig.XPRequirementBase * (WorkerLevelConfig.XPRequirementGrowth ^ (level - 1))
end

-- Production speed multiplier: starts at 1.0, scales linearly by level
local function _calculateProductionSpeed(level: number, workerType: string): number
	local config = WorkerConfig[workerType]
	if not config then
		return 1.0
	end
	return 1 + (level - 1) * config.LevelScaling
end

-- Check if a role is unlocked by examining unlock config and current unlock state
local function _isRoleUnlocked(roleId: string, unlockState: UnlockTypes.TUnlockState): boolean
	local entry = UnlockConfig[roleId]
	if not entry or entry.StartsUnlocked then
		return true
	end
	return unlockState[roleId] == true
end

-- Build role dropdown items, sorting "Undecided" first, then unlocked, then locked alphabetically
local function _buildRoleItems(unlockState: UnlockTypes.TUnlockState): { TDropdownItem }
	local items: { TDropdownItem } = {}
	for roleId, roleStats in pairs(RoleConfig) do
		table.insert(items, {
			Id = roleId,
			DisplayName = roleStats.DisplayName,
			IsLocked = not _isRoleUnlocked(roleId, unlockState),
		})
	end
	table.sort(items, function(a, b)
		if a.Id == "Undecided" then
			return true
		elseif b.Id == "Undecided" then
			return false
		end
		-- Locked items sort to the bottom
		if a.IsLocked ~= b.IsLocked then
			return not a.IsLocked
		end
		return a.DisplayName < b.DisplayName
	end)
	return items
end

-- Check if a target (ore, recipe, tree, plant) is unlocked
local function _isTargetUnlocked(targetId: string, unlockState: UnlockTypes.TUnlockState): boolean
	local entry = UnlockConfig[targetId]
	if not entry or entry.StartsUnlocked then
		return true
	end
	return unlockState[targetId] == true
end

-- Build target items based on assigned role (recipes for Forge, ore/trees/plants for others)
-- Returns items, label, and action key for route-based dispatch
local function _buildTargetItems(assignedRole: string, taskTarget: string?, unlockState: UnlockTypes.TUnlockState): (
	{ TDropdownItem },
	string,
	string
)
	local targetItems: { TDropdownItem } = {}
	local optionsLabel = "Options"
	local optionsSelectRole = ""

	if assignedRole == "Forge" then
		-- Forge role: show automatable recipes
		for recipeId, recipeData in pairs(RecipeConfig) do
			if recipeData.IsAutomatable then
				table.insert(targetItems, {
					Id = recipeId,
					DisplayName = recipeData.Name,
					IsLocked = not _isTargetUnlocked(recipeId, unlockState),
				})
			end
		end
		table.sort(targetItems, function(a, b)
			if a.IsLocked ~= b.IsLocked then
				return not a.IsLocked
			end
			return a.DisplayName < b.DisplayName
		end)

		if taskTarget then
			local recipe = RecipeConfig[taskTarget]
			optionsLabel = if recipe then recipe.Name else "Options"
		end

		optionsSelectRole = "Forge"
	elseif assignedRole == "Brewery" then
		-- Brewery role: show automatable brew recipes
		for recipeId, recipeData in pairs(BreweryRecipeConfig) do
			if recipeData.IsAutomatable then
				table.insert(targetItems, {
					Id = recipeId,
					DisplayName = recipeData.Name,
					IsLocked = not _isTargetUnlocked(recipeId, unlockState),
				})
			end
		end
		table.sort(targetItems, function(a, b)
			if a.IsLocked ~= b.IsLocked then
				return not a.IsLocked
			end
			return a.DisplayName < b.DisplayName
		end)

		if taskTarget then
			local recipe = BreweryRecipeConfig[taskTarget]
			optionsLabel = if recipe then recipe.Name else "Options"
		end

		optionsSelectRole = "Brewery"
	else
		-- Other roles: show targets from role's TargetConfig (ore, trees, plants)
		local roleData = RoleConfig[assignedRole]
		local targetConfig = roleData and roleData.TargetConfig or nil

		if targetConfig then
			for targetId, targetData in pairs(targetConfig) do
				table.insert(targetItems, {
					Id = targetId,
					DisplayName = targetData.DisplayName,
					IsLocked = not _isTargetUnlocked(targetId, unlockState),
				})
			end
			table.sort(targetItems, function(a, b)
				if a.IsLocked ~= b.IsLocked then
					return not a.IsLocked
				end
				return a.DisplayName < b.DisplayName
			end)

			local selectedTargetData = taskTarget and targetConfig[taskTarget]
			optionsLabel = if selectedTargetData then selectedTargetData.DisplayName else "Options"
		end

		if assignedRole == "Miner" then
			optionsSelectRole = "Miner"
		elseif assignedRole == "Lumberjack" then
			optionsSelectRole = "Lumberjack"
		elseif assignedRole == "Herbalist" then
			optionsSelectRole = "Herbalist"
		end
	end

	return targetItems, optionsLabel, optionsSelectRole
end

--[=[
	Transform a backend worker and unlock state into a UI-ready view model.
	Computes XP progress, speed multiplier, role items, and target items based on unlock state.
	@within WorkerViewModel
	@param worker WorkerTypes.TWorker -- Backend worker data
	@param unlockState UnlockTypes.TUnlockState -- Current player unlock state
	@return TWorkerViewModel -- UI-ready view model (frozen)
]=]
function WorkerViewModel.fromWorker(worker: WorkerTypes.TWorker, unlockState: UnlockTypes.TUnlockState): TWorkerViewModel
	local xpRequired = _calculateXPRequired(worker.Level)
	local xpProgress = math.clamp(worker.Experience / xpRequired, 0, 1)
	local speed = _calculateProductionSpeed(worker.Level, worker.Rank)

	local assignmentLabel = "Unassigned"
	if worker.AssignedTo then
		local roleData = RoleConfig[worker.AssignedTo]
		if roleData then
			assignmentLabel = roleData.DisplayName
		else
			assignmentLabel = worker.AssignedTo
		end
	end

	local rank = worker.Rank
	local rankData = RankConfig.Ranks[rank] or RankConfig.Ranks.Apprentice

	local assignedRole = worker.AssignedTo or "Undecided"
	local assignedRoleData = RoleConfig[assignedRole]
	local assignLabel = if assignedRoleData and assignedRole ~= "Undecided"
		then assignedRoleData.DisplayName
		else "Assign"

	local roleItems = _buildRoleItems(unlockState)
	local targetItems, optionsLabel, optionsSelectRole = _buildTargetItems(assignedRole, worker.TaskTarget, unlockState)

	return table.freeze({
		Id = worker.Id,
		LevelLabel = "Lv. " .. tostring(worker.Level),
		XPLabel = tostring(worker.Experience) .. " / " .. tostring(math.floor(xpRequired)) .. " XP",
		XPProgress = xpProgress,
		SpeedLabel = string.format("%.2fx Speed", speed),
		AssignmentLabel = assignmentLabel,
		AssignedRole = assignedRole,
		TaskTarget = worker.TaskTarget,
		Rank = rank,
		RankLabel = rankData.DisplayName,
		RankBadgeColor = rankData.BadgeColor,
		RoleItems = roleItems,
		AssignLabel = assignLabel,
		TargetItems = targetItems,
		OptionsLabel = optionsLabel,
		OptionsSelectRole = optionsSelectRole,
	} :: TWorkerViewModel)
end

return WorkerViewModel
