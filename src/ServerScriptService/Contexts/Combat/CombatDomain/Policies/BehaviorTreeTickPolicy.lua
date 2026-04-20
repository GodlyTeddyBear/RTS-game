--!strict

--[=[
	@class BehaviorTreeTickPolicy
	Domain policy that gates behavior tree ticks based on interval, action state, and manual mode.

	Answers: should this entity's behavior tree tick this frame?

	Responsibilities:
	1. Check if entity is in manual control mode (Infrastructure - model attribute)
	2. Check if current action is committed (Infrastructure - `CombatActionComponent`)
	3. Check if a behavior tree is assigned (Infrastructure - `BehaviorTreeComponent`)
	4. Check if the BT tick interval has elapsed (Infrastructure - `BehaviorTreeComponent`)
	5. Evaluate the `CanTickBehaviorTree` spec
	6. Return behavior tree data on success

	Result on success: `Ok({ BehaviorTree, IsManualAdventurer, PlayerCommand })`  
	Result on failure: `Err(...)` — manual mode, committed action, no BT, or interval not elapsed

	**Special case:** Manual-mode adventurers with a pending player command return
	`IsManualAdventurer = true` with the `PlayerCommand` so the caller can resolve
	the command without running the BT.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok = Result.Ok

local CombatSpecs = require(script.Parent.Parent.Specs.CombatSpecs)

local BehaviorTreeTickPolicy = {}
BehaviorTreeTickPolicy.__index = BehaviorTreeTickPolicy

--[=[
	@interface TBTTickPolicyResult
	@within BehaviorTreeTickPolicy
	.BehaviorTree any -- The behavior tree instance (if not manual mode)
	.IsManualAdventurer boolean -- True if entity is in manual control mode
	.PlayerCommand any? -- Player command to resolve (manual mode only)
]=]

export type TBehaviorTreeTickPolicy = typeof(setmetatable(
	{} :: {
		_npcEntityFactory: any,
	},
	BehaviorTreeTickPolicy
))

export type TBTTickPolicyResult = {
	BehaviorTree: any,
	IsManualAdventurer: boolean,
	PlayerCommand: any?,
}

function BehaviorTreeTickPolicy.new(): TBehaviorTreeTickPolicy
	local self = setmetatable({}, BehaviorTreeTickPolicy)
	self._npcEntityFactory = nil :: any
	return self
end

function BehaviorTreeTickPolicy:Start(registry: any, _name: string)
	self._npcEntityFactory = registry:Get("NPCEntityFactory")
end

--[=[
	Check if an entity's behavior tree should tick this frame.

	Validates that the entity is not in a committed action, is not in manual mode
	(unless overridden by a player command), has a behavior tree assigned, and the
	tick interval has elapsed since the last tick.
	@within BehaviorTreeTickPolicy
	@param entity any
	@param currentTime number -- `os.clock()` value for this frame
	@return Result.Result<TBTTickPolicyResult> -- Ok if conditions met, Err otherwise
]=]
function BehaviorTreeTickPolicy:Check(entity: any, currentTime: number): Result.Result<TBTTickPolicyResult>
	-- Check manual mode
	local isManualAdventurer = self:_IsManualAdventurer(entity)

	-- If manual, check for a player command to resolve
	if isManualAdventurer then
		local cmdComp = self._npcEntityFactory:GetPlayerCommand(entity)
		if cmdComp and cmdComp.CommandType then
			return Ok({
				BehaviorTree = nil,
				IsManualAdventurer = true,
				PlayerCommand = cmdComp,
			})
		end
	end

	-- Check action committed state
	local actionComp = self._npcEntityFactory:GetCombatAction(entity)
	local isNotCommitted = not actionComp or actionComp.ActionState ~= "Committed"

	-- Check BT existence and interval
	local bt = self._npcEntityFactory:GetBehaviorTree(entity)
	local hasBT = bt ~= nil
	local intervalReady = hasBT and (currentTime - bt.LastTickTime >= bt.TickInterval)

	local candidate: CombatSpecs.TBTTickCandidate = {
		IsNotManualMode = not isManualAdventurer,
		IsNotCommitted = isNotCommitted,
		HasBehaviorTree = hasBT,
		BTIntervalReady = intervalReady or false,
	}

	local specResult = CombatSpecs.CanTickBehaviorTree:IsSatisfiedBy(candidate)
	if not specResult.success then return specResult end

	return Ok({
		BehaviorTree = bt,
		IsManualAdventurer = false,
		PlayerCommand = nil,
	})
end

function BehaviorTreeTickPolicy:_IsManualAdventurer(entity: any): boolean
	local identity = self._npcEntityFactory:GetIdentity(entity)
	if not identity or not identity.IsAdventurer then
		return false
	end

	local controlMode = self._npcEntityFactory:GetControlMode(entity)
	return controlMode ~= nil and controlMode.Mode == "Manual"
end

return BehaviorTreeTickPolicy
