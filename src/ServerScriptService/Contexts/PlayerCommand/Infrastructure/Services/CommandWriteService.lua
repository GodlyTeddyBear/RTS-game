--!strict

--[=[
    @class CommandWriteService
    Infrastructure service that writes player commands and control mode to ECS entities.
    @server
]=]

--[[
    CommandWriteService - Writes player commands to the ECS world.

    Responsibilities:
    - Set PlayerCommandComponent on entities
    - Clear PlayerCommandComponent from entities
    - Set/read control mode on NPC ECS components

    Pattern: Infrastructure layer service — ECS writes only.
]]

local CommandWriteService = {}
CommandWriteService.__index = CommandWriteService

export type TCommandWriteService = typeof(setmetatable({} :: {
	NPCEntityFactory: any,
}, CommandWriteService))

--[=[
    Creates a new `CommandWriteService` instance.
    @within CommandWriteService
    @return TCommandWriteService
]=]
function CommandWriteService.new(): TCommandWriteService
	local self = setmetatable({}, CommandWriteService)
	self.NPCEntityFactory = nil :: any
	return self
end

--[=[
    Wires dependencies from the service registry.
    @within CommandWriteService
    @param registry any -- The context-local service registry
]=]
function CommandWriteService:Start(registry: any, _name: string)
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
end

--[=[
    Writes a player command onto an entity's `PlayerCommandComponent`.
    @within CommandWriteService
    @param entity any -- The ECS entity to command
    @param commandType string -- The command type string (e.g. `"MoveToPosition"`)
    @param commandData {[string]: any}? -- Optional command payload
]=]
function CommandWriteService:WriteCommand(entity: any, commandType: string, commandData: { [string]: any }?)
	self.NPCEntityFactory:SetPlayerCommand(entity, commandType, commandData)
	if commandType == "AttackTarget" then
		self.NPCEntityFactory:SetTarget(entity, self:_ResolveTargetEntity(entity, commandData))
	elseif commandType ~= "AttackNearest" then
		self.NPCEntityFactory:SetTarget(entity, nil)
	end
end

--[=[
    Clears the active player command from an entity.
    @within CommandWriteService
    @param entity any -- The ECS entity to clear
]=]
function CommandWriteService:ClearCommand(entity: any)
	self.NPCEntityFactory:ClearPlayerCommand(entity)
	self.NPCEntityFactory:SetTarget(entity, nil)
end

--[=[
    Sets the control mode on the NPC ECS entity. Reveal sync replicates it to clients.
    @within CommandWriteService
    @param entity any -- The ECS entity whose model will be updated
    @param mode string -- `"Auto"` or `"Manual"`
]=]
function CommandWriteService:SetControlMode(entity: any, mode: string)
	local normalizedMode = if mode == "Manual" then "Manual" else "Auto"
	self.NPCEntityFactory:SetControlMode(entity, normalizedMode)
	if normalizedMode == "Auto" then
		self:ClearCommand(entity)
	end
end

--[=[
    Reads the control mode from an entity's ECS component.
    @within CommandWriteService
    @param entity any -- The ECS entity to query
    @return string -- `"Auto"` or `"Manual"`; defaults to `"Auto"` if not set
]=]
function CommandWriteService:GetControlMode(entity: any): string
	local controlMode = self.NPCEntityFactory:GetControlMode(entity)
	return controlMode and controlMode.Mode or "Auto"
end

--[=[
    Clears all active player commands for every living adventurer belonging to a user.
    @within CommandWriteService
    @param userId number -- The player's user ID
]=]
function CommandWriteService:ClearAllCommandsForUser(userId: number)
	local adventurers = self.NPCEntityFactory:QueryAliveAdventurers(userId)
	for _, entity in adventurers do
		self:ClearCommand(entity)
	end
end

function CommandWriteService:_ResolveTargetEntity(entity: any, commandData: { [string]: any }?): any?
	local targetNPCId = commandData and commandData.TargetNPCId
	if not targetNPCId then
		return nil
	end

	local team = self.NPCEntityFactory:GetTeam(entity)
	return self.NPCEntityFactory:GetEntityByNPCId(team and team.UserId or 0, targetNPCId)
end

return CommandWriteService
