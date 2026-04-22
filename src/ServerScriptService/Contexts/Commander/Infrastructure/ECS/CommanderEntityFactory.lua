--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseECSEntityFactory = require(ReplicatedStorage.Utilities.BaseECSEntityFactory)
local CommanderTypes = require(ReplicatedStorage.Contexts.Commander.Types.CommanderTypes)

type SlotKey = CommanderTypes.SlotKey
type CooldownEntry = CommanderTypes.CooldownEntry
type CooldownState = CommanderTypes.CooldownState
type CommanderState = CommanderTypes.CommanderState

type HealthComponent = {
	hp: number,
	maxHp: number,
}

type IdentityComponent = {
	UserId: number,
}

type CooldownsComponent = {
	Cooldowns: CooldownState,
}

local CommanderEntityFactory = {}
CommanderEntityFactory.__index = CommanderEntityFactory
setmetatable(CommanderEntityFactory, BaseECSEntityFactory)

local function _cloneCooldowns(source: CooldownState): CooldownState
	local clone = {} :: CooldownState
	for slotKey, entry in pairs(source) do
		if entry ~= nil then
			clone[slotKey] = {
				startedAt = entry.startedAt,
				duration = entry.duration,
			}
		end
	end
	return clone
end

function CommanderEntityFactory.new()
	local self = setmetatable(BaseECSEntityFactory._new("Commander"), CommanderEntityFactory)
	self._entityByUserId = {} :: { [number]: number }
	self._userIdByEntity = {} :: { [number]: number }
	return self
end

function CommanderEntityFactory:Init(registry: any, _name: string)
	BaseECSEntityFactory.InitBase(self, registry, "CommanderComponentRegistry")
	assert(
		self._components ~= nil
			and self._components.IdentityComponent ~= nil
			and self._components.HealthComponent ~= nil
			and self._components.CooldownsComponent ~= nil
			and self._components.ActiveTag ~= nil,
		"CommanderEntityFactory: missing CommanderComponentRegistry components"
	)
end

function CommanderEntityFactory:CreateOrResetCommander(userId: number, maxHp: number): number
	self:RequireReady()

	local entity = self._entityByUserId[userId]
	if entity == nil then
		entity = self._world:entity()
		self._entityByUserId[userId] = entity
		self._userIdByEntity[entity] = userId
		self._world:set(entity, self._components.IdentityComponent, {
			UserId = userId,
		} :: IdentityComponent)
	end

	self._world:set(entity, self._components.HealthComponent, {
		hp = maxHp,
		maxHp = maxHp,
	} :: HealthComponent)
	self._world:set(entity, self._components.CooldownsComponent, {
		Cooldowns = {} :: CooldownState,
	} :: CooldownsComponent)
	self._world:add(entity, self._components.ActiveTag)

	return entity
end

function CommanderEntityFactory:GetEntityByUserId(userId: number): number?
	self:RequireReady()
	return self._entityByUserId[userId]
end

function CommanderEntityFactory:GetUserIdByEntity(entity: number): number?
	self:RequireReady()
	return self._userIdByEntity[entity]
end

function CommanderEntityFactory:GetHealth(userId: number): HealthComponent?
	self:RequireReady()
	local entity = self._entityByUserId[userId]
	if entity == nil then
		return nil
	end
	return self._world:get(entity, self._components.HealthComponent)
end

function CommanderEntityFactory:SetHP(userId: number, hp: number): number?
	self:RequireReady()
	local entity = self._entityByUserId[userId]
	if entity == nil then
		return nil
	end

	local health = self._world:get(entity, self._components.HealthComponent)
	if health == nil then
		return nil
	end

	local clampedHp = math.max(0, math.min(health.maxHp, hp))
	self._world:set(entity, self._components.HealthComponent, {
		hp = clampedHp,
		maxHp = health.maxHp,
	} :: HealthComponent)
	return clampedHp
end

function CommanderEntityFactory:ApplyDamage(userId: number, amount: number): number?
	self:RequireReady()
	local entity = self._entityByUserId[userId]
	if entity == nil then
		return nil
	end

	local health = self:GetHealth(userId)
	if health == nil then
		return nil
	end

	local sanitizedAmount = math.max(0, amount)
	local nextHp = math.max(0, health.hp - sanitizedAmount)
	self._world:set(entity, self._components.HealthComponent, {
		hp = nextHp,
		maxHp = health.maxHp,
	} :: HealthComponent)
	return nextHp
end

function CommanderEntityFactory:GetCooldowns(userId: number): CooldownState?
	self:RequireReady()
	local entity = self._entityByUserId[userId]
	if entity == nil then
		return nil
	end

	local cooldowns = self._world:get(entity, self._components.CooldownsComponent) :: CooldownsComponent?
	if cooldowns == nil then
		return nil
	end

	return _cloneCooldowns(cooldowns.Cooldowns)
end

function CommanderEntityFactory:SetCooldown(userId: number, slotKey: SlotKey, duration: number)
	self:RequireReady()
	local entity = self._entityByUserId[userId]
	if entity == nil then
		return
	end

	local current = self._world:get(entity, self._components.CooldownsComponent) :: CooldownsComponent?
	local nextCooldowns = _cloneCooldowns(if current == nil then {} :: CooldownState else current.Cooldowns)
	nextCooldowns[slotKey] = {
		startedAt = os.clock(),
		duration = duration,
	} :: CooldownEntry

	self._world:set(entity, self._components.CooldownsComponent, {
		Cooldowns = nextCooldowns,
	} :: CooldownsComponent)
end

function CommanderEntityFactory:ClearCooldown(userId: number, slotKey: SlotKey)
	self:RequireReady()
	local entity = self._entityByUserId[userId]
	if entity == nil then
		return
	end

	local current = self._world:get(entity, self._components.CooldownsComponent) :: CooldownsComponent?
	if current == nil then
		return
	end

	local nextCooldowns = _cloneCooldowns(current.Cooldowns)
	nextCooldowns[slotKey] = nil

	self._world:set(entity, self._components.CooldownsComponent, {
		Cooldowns = nextCooldowns,
	} :: CooldownsComponent)
end

function CommanderEntityFactory:GetCommanderState(userId: number): CommanderState?
	self:RequireReady()
	local health = self:GetHealth(userId)
	if health == nil then
		return nil
	end

	local cooldowns = self:GetCooldowns(userId) or ({} :: CooldownState)
	return {
		hp = health.hp,
		maxHp = health.maxHp,
		cooldowns = cooldowns,
	}
end

function CommanderEntityFactory:RemoveCommander(userId: number)
	self:RequireReady()
	local entity = self._entityByUserId[userId]
	if entity == nil then
		return
	end

	if self._world:has(entity, self._components.ActiveTag) then
		self._world:remove(entity, self._components.ActiveTag)
	end

	self._entityByUserId[userId] = nil
	self._userIdByEntity[entity] = nil
	self:MarkForDestruction(entity)
end

function CommanderEntityFactory:FlushPendingDeletes(): boolean
	self:RequireReady()
	return self:FlushDestructionQueue()
end

return CommanderEntityFactory
