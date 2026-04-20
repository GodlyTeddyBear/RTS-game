--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECSRevealApplier = require(ServerScriptService.Infrastructure.ECSRevealApplier)
local NPCConfig = require(script.Parent.Parent.Parent.Config.NPCConfig)
local WeaponCategoryConfig = require(ReplicatedStorage.Contexts.Combat.Config.WeaponCategoryConfig)

local NPCRevealAdapter = {}
NPCRevealAdapter.__index = NPCRevealAdapter

export type TNPCRevealAdapter = typeof(setmetatable({} :: {
	World: any,
	Components: any,
}, NPCRevealAdapter))

function NPCRevealAdapter.new(): TNPCRevealAdapter
	return setmetatable({}, NPCRevealAdapter)
end

function NPCRevealAdapter:Init(registry: any, _name: string)
	self.World = registry:Get("World")
	self.Components = registry:Get("Components")
end

function NPCRevealAdapter:Apply(entity: any, model: Model)
	ECSRevealApplier.Apply(model, self:BuildRevealState(entity))
end

function NPCRevealAdapter:BuildRevealState(entity: any): ECSRevealApplier.TRevealState?
	local identity = self.World:get(entity, self.Components.NPCIdentityComponent)
	local team = self.World:get(entity, self.Components.TeamComponent)
	local health = self.World:get(entity, self.Components.HealthComponent)
	if not identity or not team or not health then
		return nil
	end

	local animation = self:_ResolveAnimation(entity)
	local command = self.World:get(entity, self.Components.PlayerCommandComponent)
	local controlMode = self.World:get(entity, self.Components.ControlModeComponent)
	local targetName = self:_ResolveTargetName(entity, command)
	local clearAttributes = {}

	if not command or not command.CommandType then
		table.insert(clearAttributes, "LastCommand")
	end
	if not targetName then
		table.insert(clearAttributes, "TargetName")
	end

	return {
		Attributes = {
			NPCId = identity.NPCId,
			NPCType = identity.NPCType,
			Team = team.Team,
			DisplayName = identity.DisplayName or identity.NPCType,
			MaxHP = health.Max,
			CurrentHP = health.Current,
			AnimationState = animation.State,
			AnimationLooping = animation.Looping,
			ControlMode = if controlMode then controlMode.Mode else "Auto",
			LastCommand = if command then command.CommandType else nil,
			TargetName = targetName,
		},
		ClearAttributes = clearAttributes,
		Tags = {
			[NPCConfig.COMBAT_NPC_TAG] = true,
		},
	}
end

function NPCRevealAdapter:_ResolveAnimation(entity: any): { State: string, Looping: boolean }
	local combatState = self.World:get(entity, self.Components.CombatStateComponent)
	local state = if combatState then combatState.State else "None"

	if state == "Attacking" then
		local weaponComp = self.World:get(entity, self.Components.WeaponCategoryComponent)
		if weaponComp then
			local profile = WeaponCategoryConfig[weaponComp.Category]
			if profile then
				return { State = profile.ActionId, Looping = false }
			end
		end
		return { State = "Attack", Looping = false }
	end

	if state == "Dead" then
		return { State = "Death", Looping = false }
	end

	return { State = "Idle", Looping = false }
end

function NPCRevealAdapter:_ResolveTargetName(entity: any, command: any?): string?
	local target = self.World:get(entity, self.Components.TargetComponent)
	if target and target.TargetEntity then
		return self:_GetNPCType(target.TargetEntity)
	end

	if command and command.CommandType == "AttackTarget" then
		local commandData = command.CommandData
		local targetNPCId = commandData and commandData.TargetNPCId
		if targetNPCId then
			local team = self.World:get(entity, self.Components.TeamComponent)
			local targetEntity = self:_FindEntityByNPCId(team and team.UserId or 0, targetNPCId)
			if targetEntity then
				return self:_GetNPCType(targetEntity)
			end
		end
	end

	return nil
end

function NPCRevealAdapter:_FindEntityByNPCId(userId: number, npcId: string): any?
	for targetEntity in self.World:query(
		self.Components.NPCIdentityComponent,
		self.Components.TeamComponent
	) do
		local team = self.World:get(targetEntity, self.Components.TeamComponent)
		local identity = self.World:get(targetEntity, self.Components.NPCIdentityComponent)
		if team and team.UserId == userId and identity and identity.NPCId == npcId then
			return targetEntity
		end
	end
	return nil
end

function NPCRevealAdapter:_GetNPCType(entity: any): string?
	local identity = self.World:get(entity, self.Components.NPCIdentityComponent)
	return identity and identity.NPCType or nil
end

return NPCRevealAdapter
