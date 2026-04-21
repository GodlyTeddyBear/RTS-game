--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)

type StructureAttackPayload = StructureTypes.StructureAttackPayload

--[=[
	@class StructureAttackSystem
	Schedules structure attacks once their cooldowns elapse.
	@server
]=]
local StructureAttackSystem = {}
StructureAttackSystem.__index = StructureAttackSystem

--[=[
	Creates a new attack system wrapper.
	@within StructureAttackSystem
	@return StructureAttackSystem -- The new system instance.
]=]
function StructureAttackSystem.new()
	local self = setmetatable({}, StructureAttackSystem)
	self._registry = nil
	self._factory = nil
	self._onAttack = nil :: ((StructureAttackPayload) -> ())?
	return self
end

--[=[
	Resolves the structure entity factory used to read cooldown and target state.
	@within StructureAttackSystem
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureAttackSystem:Init(registry: any, _name: string)
	self._registry = registry
	self._factory = registry:Get("StructureEntityFactory")
end

--[=[
	Caches the attack callback so the tick path can stay allocation-light.
	@within StructureAttackSystem
]=]
function StructureAttackSystem:Start()
	self._onAttack = self._registry:Get("OnStructureAttacked")
end

--[=[
	Advances cooldowns and emits attack payloads for structures with valid targets.
	@within StructureAttackSystem
	@param dt number -- Seconds elapsed since the previous frame.
]=]
function StructureAttackSystem:Tick(dt: number)
	if dt <= 0 then
		return
	end

	-- Advance every active structure's cooldown before deciding whether it can attack.
	for _, structureEntity in ipairs(self._factory:QueryActiveEntities()) do
		local attackStats = self._factory:GetAttackStats(structureEntity)
		local cooldown = self._factory:GetCooldown(structureEntity)
		if attackStats == nil or cooldown == nil then
			continue
		end

		local elapsed = cooldown.Elapsed + dt
		self._factory:SetCooldownElapsed(structureEntity, elapsed)
		if elapsed < attackStats.AttackCooldown then
			continue
		end

		-- Keep accumulating cooldown while the structure has no target so the first shot is immediate.
		local targetEntity = self._factory:GetTarget(structureEntity)
		if targetEntity == nil then
			continue
		end

		local identity = self._factory:GetIdentity(structureEntity)
		if identity == nil then
			continue
		end

		-- Reset the cooldown only after a valid target is confirmed.
		self._factory:SetCooldownElapsed(structureEntity, 0)

		local onAttack = self._onAttack
		if onAttack then
			-- Emit the attack payload for CombatContext to resolve damage later.
			onAttack({
				structureEntity = structureEntity,
				targetEntity = targetEntity,
				damage = attackStats.AttackDamage,
				structureType = identity.StructureType,
			})
		end
	end
end

return StructureAttackSystem
