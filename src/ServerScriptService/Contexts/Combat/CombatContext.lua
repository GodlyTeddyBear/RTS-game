--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local WaveConfig = require(ReplicatedStorage.Contexts.NPC.Config.WaveConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

-- Domain Services
local DamageCalculator = require(script.Parent.CombatDomain.Services.DamageCalculator)
local TargetSelector = require(script.Parent.CombatDomain.Services.TargetSelector)
local WeaponProfileResolver = require(script.Parent.CombatDomain.Services.WeaponProfileResolver)
-- Domain Policies
local StartCombatPolicy = require(script.Parent.CombatDomain.Policies.StartCombatPolicy)
local BehaviorTreeTickPolicy = require(script.Parent.CombatDomain.Policies.BehaviorTreeTickPolicy)
local WaveCompletionPolicy = require(script.Parent.CombatDomain.Policies.WaveCompletionPolicy)
local CombatPerceptionService = require(script.Parent.CombatDomain.Services.CombatPerceptionService)

-- Infrastructure Services
local BehaviorTreeFactory = require(script.Parent.Infrastructure.Services.BehaviorTreeFactory)
local CombatLoopService = require(script.Parent.Infrastructure.Services.CombatLoopService)
local HitboxService = require(script.Parent.Infrastructure.Services.HitboxService)
local LockOnService = require(script.Parent.Infrastructure.Services.LockOnService)

-- Executor System
local ExecutorRegistry = require(script.Parent.Executors.Base.ExecutorRegistry)
local IdleExecutor = require(script.Parent.Executors.Others.IdleExecutor)
local ChaseExecutor = require(script.Parent.Executors.Movements.ChaseExecutor)
local MeleeAttackExecutor = require(script.Parent.Executors.Attacks.MeleeAttackExecutor)
local RangedAttackExecutor = require(script.Parent.Executors.Attacks.RangedAttackExecutor)
local SwordAttackExecutor = require(script.Parent.Executors.Attacks.SwordAttackExecutor)
local DaggerAttackExecutor = require(script.Parent.Executors.Attacks.DaggerAttackExecutor)
local StaffAttackExecutor = require(script.Parent.Executors.Attacks.StaffAttackExecutor)
local PunchAttackExecutor = require(script.Parent.Executors.Attacks.PunchAttackExecutor)
local FleeExecutor = require(script.Parent.Executors.Movements.FleeExecutor)
local WanderExecutor = require(script.Parent.Executors.Movements.WanderExecutor)
local MoveToPositionExecutor = require(script.Parent.Executors.Movements.MoveToPositionExecutor)
local BlockExecutor = require(script.Parent.Executors.Others.BlockExecutor)
local ParryExecutor = require(script.Parent.Executors.Others.ParryExecutor)
local PowerStrikeExecutor = require(script.Parent.Executors.Skills.PowerStrikeExecutor)

-- Application Services
local StartCombat = require(script.Parent.Application.Commands.StartCombat)
local ProcessCombatTick = require(script.Parent.Application.Commands.ProcessCombatTick)
local EndCombat = require(script.Parent.Application.Commands.EndCombat)
local ProcessWaveTransition = require(script.Parent.Application.Commands.ProcessWaveTransition)

local Catch = Result.Catch
local MentionError = Result.MentionError
local Ok = Result.Ok
local Try = Result.Try

type TEndCombatResult = EndCombat.TEndCombatResult

--[=[
	@class CombatContext
	Knit service that owns the per-user combat lifecycle.

	Drives BT ticks, action transitions, hitbox activation, wave transitions,
	and combat start/end for every active combat session on the server.
	@server
]=]
local CombatContext = Knit.CreateService({
	Name = "CombatContext",
	Client = {
		NPCEvent = Knit.CreateSignal(),
		AnimationCallback = Knit.CreateSignal(),
	},
})

---
-- Knit Lifecycle
---

function CombatContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Domain Services
	registry:Register("DamageCalculator", DamageCalculator.new(), "Domain")
	registry:Register("TargetSelector", TargetSelector.new(), "Domain")
	registry:Register("WeaponProfileResolver", WeaponProfileResolver.new(), "Domain")
	registry:Register("StartCombatPolicy", StartCombatPolicy.new(), "Domain")
	registry:Register("BehaviorTreeTickPolicy", BehaviorTreeTickPolicy.new(), "Domain")
	registry:Register("WaveCompletionPolicy", WaveCompletionPolicy.new(), "Domain")
	registry:Register("CombatPerceptionService", CombatPerceptionService.new(), "Domain")

	-- Infrastructure Services
	local executorRegistry = ExecutorRegistry.new()
	executorRegistry:Register("Idle", IdleExecutor.new())
	executorRegistry:Register("Chase", ChaseExecutor.new())
	executorRegistry:Register("MeleeAttack", MeleeAttackExecutor.new())
	executorRegistry:Register("RangedAttack", RangedAttackExecutor.new())
	executorRegistry:Register("SwordAttack", SwordAttackExecutor.new())
	executorRegistry:Register("DaggerAttack", DaggerAttackExecutor.new())
	executorRegistry:Register("StaffAttack", StaffAttackExecutor.new())
	executorRegistry:Register("PunchAttack", PunchAttackExecutor.new())
	executorRegistry:Register("Flee", FleeExecutor.new())
	executorRegistry:Register("Wander", WanderExecutor.new())
	executorRegistry:Register("MoveToPosition", MoveToPositionExecutor.new())
	executorRegistry:Register("Block", BlockExecutor.new())
	executorRegistry:Register("Parry", ParryExecutor.new())
	executorRegistry:Register("PowerStrike", PowerStrikeExecutor.new())

	registry:Register("BehaviorTreeFactory", BehaviorTreeFactory.new(), "Infrastructure")
	registry:Register("CombatLoopService", CombatLoopService.new(), "Infrastructure")
	registry:Register("HitboxService", HitboxService.new(), "Infrastructure")
	registry:Register("LockOnService", LockOnService.new(), "Infrastructure")
	registry:Register("ExecutorRegistry", executorRegistry, "Infrastructure")

	-- Application Services
	registry:Register("StartCombat", StartCombat.new(), "Application")
	registry:Register("ProcessCombatTick", ProcessCombatTick.new(), "Application")
	registry:Register("EndCombat", EndCombat.new(), "Application")
	registry:Register("ProcessWaveTransition", ProcessWaveTransition.new(), "Application")

	registry:InitAll()

	-- Cache CombatLoopService early (available after InitAll) so cross-context
	-- getters work regardless of KnitStart order
	self.CombatLoopService = registry:Get("CombatLoopService")
end

function CombatContext:KnitStart()
	local registry = self.Registry

	-- Cross-context dependencies
	local NPCContext = Knit.GetService("NPCContext")
	local DungeonContext = Knit.GetService("DungeonContext")

	registry:Register("NPCContext", NPCContext)
	registry:Register("DungeonContext", DungeonContext)
	registry:Register("World", Try(NPCContext:GetWorld()))
	registry:Register("Components", Try(NPCContext:GetComponents()))
	registry:Register("NPCEntityFactory", Try(NPCContext:GetEntityFactory()))
	registry:Register("NPCModelFactory", Try(NPCContext:GetModelFactory()))
	registry:Register("GameObjectSyncService", Try(NPCContext:GetGameObjectSyncService()))

	registry:StartOrdered({ "Domain", "Infrastructure", "Application" })
	self.ExecutorRegistry = registry:Get("ExecutorRegistry")
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
	self.DamageCalculator = registry:Get("DamageCalculator")
	self.HitboxService = registry:Get("HitboxService")
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
	self.ProcessCombatTickService = registry:Get("ProcessCombatTick")
	self.StartCombatService = registry:Get("StartCombat")
	self.EndCombatService = registry:Get("EndCombat")
	self.ProcessWaveTransitionService = registry:Get("ProcessWaveTransition")
	self.LockOnService = registry:Get("LockOnService")

	-- Wire event flush callback: send batched events to the owning player
	self.ProcessCombatTickService.OnFlushEvents = function(userId: number, events: { any })
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self.Client.NPCEvent:Fire(player, events)
		end
	end

	-- Handle client→server animation callbacks (e.g., hitbox activation)
	self.Client.AnimationCallback:Connect(function(player: Player, npcId: string, callbackType: string)
		self:_OnAnimationCallback(player.UserId, npcId, callbackType)
	end)

	-- Register global combat tick system with the Planck scheduler.
	-- Tick continues on error — each userId's failure is isolated; others keep running.
	ServerScheduler:RegisterSystem(function()
		local deltaTime = ServerScheduler:GetDeltaTime()
		for userId, combat in self.CombatLoopService:GetActiveCombats() do
			if not combat.IsPaused then
				Catch(
					self.ProcessCombatTickService.Execute,
					"CombatContext",
					nil,
					self.ProcessCombatTickService,
					userId,
					deltaTime
				)
				local entities = self.NPCEntityFactory:QueryAliveEntities(userId)
				self.LockOnService:UpdateAll(entities)
			end
		end
	end, "CombatTick")

	-- Listen for wave completion events
	GameEvents.Bus:On(Events.Combat.WaveComplete, function(userId: number)
		self:_OnWaveComplete(userId)
	end)

	GameEvents.Bus:On(Events.Combat.AllAdventurersDead, function(userId: number)
		self:_OnAllAdventurersDead(userId)
	end)

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		self:StopCombatForUser(player.UserId)
	end)

	print("CombatContext started")
end

---
-- Server-to-Server API
---

--[=[
	Start combat for a user with pre-spawned entities.

	Counts total waves from `WaveConfig` for the zone, then delegates to
	`StartCombat:Execute`. Wrap the return value with `Try` if calling
	from inside another `Catch` boundary.
	@within CombatContext
	@param userId number
	@param adventurerEntities { [string]: any } -- Map of adventurerId → entity from SpawnAdventurerParty
	@param enemyEntities { any } -- Array of enemy entities from SpawnEnemyWave
	@param zoneId string
	@param onComplete ((status: string, deadAdventurerIds: { string }) -> ())? -- Called when combat resolves
	@return Result.Result<any>
]=]
function CombatContext:StartCombatForUser(
	userId: number,
	adventurerEntities: { [string]: any },
	enemyEntities: { any },
	zoneId: string,
	onComplete: ((string, { string }) -> ())?
): Result.Result<any>
	return Catch(function()
		-- Step 1: Wire ControlMode attribute listeners for all adventurer entities
		-- Syncs ECS component from model attribute without per-frame GetAttribute calls
		for _, entity in pairs(adventurerEntities) do
			self:_WireControlModeListener(entity)
		end

		-- Step 2: Attach lock-on constraints for all combat entities
		for _, entity in pairs(adventurerEntities) do
			self.LockOnService:AttachConstraint(entity)
		end
		for _, entity in ipairs(enemyEntities) do
			self.LockOnService:AttachConstraint(entity)
		end

		-- Step 3: Count total waves in this zone from WaveConfig
		local zoneWaves = WaveConfig[zoneId]
		local totalWaves = 0
		if zoneWaves then
			for waveNum, _ in pairs(zoneWaves) do
				if type(waveNum) == "number" and waveNum > totalWaves then
					totalWaves = waveNum
				end
			end
		end

		-- Step 4: Delegate to StartCombat command with wave count
		return self.StartCombatService:Execute(
			userId,
			adventurerEntities,
			enemyEntities,
			zoneId,
			totalWaves,
			onComplete
		)
	end, "Combat:StartCombatForUser")
end

--[=[
	Stop combat for a user (e.g., on disconnect or flee).

	No-ops if no active combat exists for the user.
	@within CombatContext
	@param userId number
	@return Result.Result<any>
]=]
function CombatContext:StopCombatForUser(userId: number): Result.Result<any>
	return Catch(function()
		if self.CombatLoopService:IsActive(userId) then
			self:_DetachLockOnForUser(userId)
			return self.EndCombatService:Execute(userId, "Fled")
		end
	end, "Combat:StopCombatForUser")
end

function CombatContext:HealAdventurer(userId: number, npcId: string, amount: number): Result.Result<any>
	return Catch(function()
		if amount <= 0 then
			return Result.Err("InvalidHealAmount", "Heal amount must be positive", {
				userId = userId,
				npcId = npcId,
				amount = amount,
			})
		end

		local entity = Try(self:_ResolveOwnedLivingAdventurer(userId, npcId))
		local newHP = self.NPCEntityFactory:ApplyHealing(entity, amount)
		local health = self.NPCEntityFactory:GetHealth(entity)
		local player = Players:GetPlayerByUserId(userId)
		if player and health then
			self.Client.NPCEvent:Fire(player, {
				{
					EventType = "Healed",
					SourceNPCId = nil,
					TargetNPCId = npcId,
					Damage = nil,
					NewHP = newHP,
					MaxHP = health.Max,
					Position = nil,
					IsCritical = nil,
					EffectKey = nil,
					SoundKey = nil,
					Custom = { Amount = amount },
				},
			})
		end

		return Ok({
			NPCId = npcId,
			Amount = amount,
			NewHP = newHP,
			MaxHP = health and health.Max or newHP,
		})
	end, "Combat:HealAdventurer")
end

function CombatContext:ValidateAdventurerTarget(userId: number, npcId: string): Result.Result<boolean>
	return Catch(function()
		Try(self:_ResolveOwnedLivingAdventurer(userId, npcId))
		return Ok(true)
	end, "Combat:ValidateAdventurerTarget")
end

---
-- Internal Event Handlers
---

function CombatContext:_ResolveOwnedLivingAdventurer(userId: number, npcId: string): Result.Result<any>
	if not self.CombatLoopService:IsActive(userId) then
		return Result.Err("CombatInactive", "No active combat for user", { userId = userId })
	end

	local entity = self.NPCEntityFactory:GetEntityByNPCId(userId, npcId)
	local identity = entity and self.NPCEntityFactory:GetIdentity(entity) or nil
	local team = entity and self.NPCEntityFactory:GetTeam(entity) or nil

	if not entity or not identity or not team then
		return Result.Err("TargetNotFound", "Target adventurer was not found", {
			userId = userId,
			npcId = npcId,
		})
	end
	if not identity.IsAdventurer or team.UserId ~= userId then
		return Result.Err("InvalidTarget", "Target must be an owned adventurer", {
			userId = userId,
			npcId = npcId,
		})
	end
	if not self.NPCEntityFactory:IsAlive(entity) then
		return Result.Err("TargetDead", "Target adventurer is not alive", {
			userId = userId,
			npcId = npcId,
		})
	end

	return Ok(entity)
end

--- Handle wave completion event: check if all waves are done or transition to next
function CombatContext:_OnWaveComplete(userId: number)
	local combat = self.CombatLoopService:GetActiveCombat(userId)
	if not combat then
		return
	end

	local currentWave = combat.CurrentWave
	local totalWaves = combat.TotalWaves

	-- If all waves cleared, end combat with Victory
	if currentWave >= totalWaves then
		local combatResult = Catch(
			self.EndCombatService.Execute,
			"CombatContext:_OnWaveComplete",
			nil,
			self.EndCombatService,
			userId,
			"Victory"
		)
		self:_DetachLockOnForUser(userId)
		if combatResult and combat.OnComplete then
			local endResult = combatResult :: TEndCombatResult
			combat.OnComplete("Victory", endResult.DeadAdventurerIds)
		end
		return
	end

	-- Otherwise, transition to next wave (spawn is asynchronous)
	local nextWave = currentWave + 1
	task.spawn(function()
		Catch(
			self.ProcessWaveTransitionService.Execute,
			"CombatContext:_OnWaveComplete",
			nil,
			self.ProcessWaveTransitionService,
			userId,
			combat.ZoneId,
			nextWave
		)
	end)
end

--- Handle party wipe event: end combat with Defeat
function CombatContext:_OnAllAdventurersDead(userId: number)
	local combat = self.CombatLoopService:GetActiveCombat(userId)
	if not combat then
		return
	end

	-- All adventurers are dead — Defeat
	local combatResult = Catch(
		self.EndCombatService.Execute,
		"CombatContext:_OnAllAdventurersDead",
		nil,
		self.EndCombatService,
		userId,
		"Defeat"
	)
	self:_DetachLockOnForUser(userId)
	if combatResult and combat.OnComplete then
		local endResult = combatResult :: TEndCombatResult
		combat.OnComplete("Defeat", endResult.DeadAdventurerIds)
	end
end


-- Detach lock-on constraints for all entities belonging to a user.
-- Called after every combat-end path so AlignOrientation instances are cleaned up.
function CombatContext:_DetachLockOnForUser(userId: number)
	local allEntities = self.NPCEntityFactory:QueryAllEntities(userId)
	for _, entity in ipairs(allEntities) do
		self.LockOnService:DetachConstraint(entity)
	end
end

--[=[
	Return the `CombatLoopService` instance for cross-context validation.
	@within CombatContext
	@return Result.Result<any> -- Always `Ok(CombatLoopService)`
]=]
function CombatContext:GetCombatLoopService(): Result.Result<any>
	return Ok(self.CombatLoopService)
end

---
-- Animation Callback Handler
---

type TAnimationCallbackResolution = {
	success: boolean,
	reason: string,
	entity: any?,
	actionId: string?,
}

type TAnimationActivationResult = {
	success: boolean,
	reason: string,
	source: string?,
}

function CombatContext:_ResolveAnimationCallbackActivation(
	userId: number,
	npcId: string,
	callbackType: string
): TAnimationCallbackResolution
	if callbackType ~= "ActivateHitbox" then
		return {
			success = false,
			reason = "UnsupportedCallbackType",
			entity = nil,
			actionId = nil,
		}
	end

	if not self.CombatLoopService:IsActive(userId) then
		return {
			success = false,
			reason = "CombatInactive",
			entity = nil,
			actionId = nil,
		}
	end

	local entity = self.NPCEntityFactory:GetEntityByNPCId(userId, npcId)
	if not entity then
		return {
			success = false,
			reason = "EntityNotFound",
			entity = nil,
			actionId = nil,
		}
	end

	local combatState = self.NPCEntityFactory:GetCombatState(entity)
	if not combatState or combatState.State ~= "Attacking" then
		return {
			success = false,
			reason = "CombatStateNotAttacking",
			entity = entity,
			actionId = nil,
		}
	end

	local actionComp = self.NPCEntityFactory:GetCombatAction(entity)
	if not actionComp or actionComp.ActionState ~= "Running" then
		return {
			success = false,
			reason = "ActionStateNotRunning",
			entity = entity,
			actionId = actionComp and actionComp.CurrentActionId or nil,
		}
	end

	local actionId = actionComp.CurrentActionId
	if not actionId then
		return {
			success = false,
			reason = "MissingCurrentActionId",
			entity = entity,
			actionId = nil,
		}
	end

	local executor = self.ExecutorRegistry:Get(actionId)
	if not executor or not executor.ActivateHitbox then
		return {
			success = false,
			reason = "ExecutorCannotActivateHitbox",
			entity = entity,
			actionId = actionId,
		}
	end

	return {
		success = true,
		reason = "Ready",
		entity = entity,
		actionId = actionId,
	}
end

function CombatContext:_WarnAnimationCallbackDrop(
	userId: number,
	npcId: string,
	callbackType: string,
	resolution: TAnimationCallbackResolution
)
	MentionError("Combat:AnimationCallback", "Dropped animation callback", {
		reason = resolution.reason,
		callbackType = callbackType,
		userId = userId,
		npcId = npcId,
		actionId = resolution.actionId,
	}, resolution.reason)
end

--[=[
	Handle client→server animation callbacks.

	Currently supports `"ActivateHitbox"` — spawns the hitbox for an NPC
	mid-attack, timed to the animation's strike marker. Events emitted by
	`ActivateHitbox` are flushed to the owning player immediately.

	:::caution
	All guardrails are enforced server-side before the hitbox spawns:
	entity ownership, Attacking state, Committed action, and activation
	idempotency. The executor's Tick handles the activation timeout.
	:::
	@within CombatContext
	@param userId number
	@param npcId string
	@param callbackType string -- Currently only `"ActivateHitbox"` is handled
	@private
]=]
function CombatContext:_OnAnimationCallback(userId: number, npcId: string, callbackType: string)
	-- Step 1: Validate callback eligibility (entity, state, executor, etc.)
	local resolution = self:_ResolveAnimationCallbackActivation(userId, npcId, callbackType)
	if not resolution.success then
		self:_WarnAnimationCallbackDrop(userId, npcId, callbackType, resolution)
		return
	end

	-- Step 2: Retrieve executor and invoke ActivateHitbox
	local actionId = resolution.actionId :: string
	local entity = resolution.entity
	local executor = self.ExecutorRegistry:Get(actionId)
	local eventBuffer = {}
	local activationResult = executor:ActivateHitbox(entity, {
		NPCEntityFactory = self.NPCEntityFactory,
		DamageCalculator = self.DamageCalculator,
		HitboxService = self.HitboxService,
		World = self.World,
		Components = self.Components,
		CurrentTime = os.clock(),
		EventBuffer = eventBuffer,
	})

	-- Step 3: Handle activation failure
	if not activationResult.success then
		MentionError("Combat:AnimationCallback", "Activation failed after callback receipt", {
			reason = activationResult.reason,
			source = activationResult.source or "AnimationCallback",
			userId = userId,
			npcId = npcId,
			actionId = actionId,
		}, activationResult.reason)
		return
	end

	-- Step 4: Flush events to owning player immediately
	if #eventBuffer > 0 and self.ProcessCombatTickService.OnFlushEvents then
		self.ProcessCombatTickService.OnFlushEvents(userId, eventBuffer)
	end
	--print("[AnimationCallback] Hitbox activated", "npcId:", npcId, "actionId:", actionId)
end

-- Sync the ControlMode ECS component from the model's ControlMode attribute.
-- Called once per adventurer entity at combat start. Uses AttributeChanged so
-- BehaviorTreeTickPolicy never needs to call GetAttribute on a hot path.
function CombatContext:_WireControlModeListener(entity: any)
	local modelRef = self.NPCEntityFactory:GetModelRef(entity)
	if not modelRef or not modelRef.Instance then
		return
	end

	local model = modelRef.Instance

	-- Step 1: Sync current value immediately in case it was set before combat started
	local current = model:GetAttribute("ControlMode")
	if current == "Manual" then
		self.NPCEntityFactory:SetControlMode(entity, "Manual")
	end

	-- Step 2: Keep ECS in sync whenever the attribute changes (driven by player RTS commands)
	model:GetAttributeChangedSignal("ControlMode"):Connect(function()
		local mode = model:GetAttribute("ControlMode")
		self.NPCEntityFactory:SetControlMode(entity, if mode == "Manual" then "Manual" else "Auto")
	end)
end

WrapContext(CombatContext, "CombatContext")

return CombatContext
