--!strict

--[=[
    @class ProcessToggleMode
    Application command that toggles the Auto/Manual control mode for selected NPCs.
    @server
]=]

--[[
    ProcessToggleMode - Toggles control mode (Auto/Manual) for selected NPCs.

    Responsibilities:
    - Validate combat is active
    - Validate each NPC
    - Toggle mode: Auto → Manual, Manual → Auto
    - When switching to Auto, clear any pending player command

    Pattern: Application layer service
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local Ok, Err, Ensure, Catch = Result.Ok, Result.Err, Result.Ensure, Result.Catch

local ProcessToggleMode = {}
ProcessToggleMode.__index = ProcessToggleMode

export type TProcessToggleMode = typeof(setmetatable({} :: {
	NPCCommandPolicy: any,
	CommandWriteService: any,
	CombatLoopService: any,
	NPCEntityFactory: any,
}, ProcessToggleMode))

--[=[
    Creates a new `ProcessToggleMode` instance.
    @within ProcessToggleMode
    @return TProcessToggleMode
]=]
function ProcessToggleMode.new(): TProcessToggleMode
	local self = setmetatable({}, ProcessToggleMode)
	self.NPCCommandPolicy = nil :: any
	self.CommandWriteService = nil :: any
	self.CombatLoopService = nil :: any
	self.NPCEntityFactory = nil :: any
	return self
end

--[=[
    Wires dependencies from the service registry.
    @within ProcessToggleMode
    @param registry any -- The context-local service registry
]=]
function ProcessToggleMode:Start(registry: any, _name: string)
	self.NPCCommandPolicy = registry:Get("NPCCommandPolicy")
	self.CommandWriteService = registry:Get("CommandWriteService")
	self.CombatLoopService = registry:Get("CombatLoopService")
	self.NPCEntityFactory = registry:Get("NPCEntityFactory")
end

--[=[
    Sets all specified NPCs to Auto control mode, clearing any pending player command.
    NPCs already in Auto mode are unaffected (no-op per entity).
    @within ProcessToggleMode
    @param userId number -- The player's user ID
    @param npcIds {string} -- List of NPC IDs to set to Auto
    @return Result<number> -- `Ok(setCount)` on success; `Err` if combat is inactive or no valid NPCs were found
]=]
function ProcessToggleMode:Execute(userId: number, npcIds: { string }): Result.Result<number>
	return Catch(function()
		Ensure(self.CombatLoopService:IsActive(userId), "NoActiveCombat", Errors.NO_ACTIVE_COMBAT)
		Ensure(npcIds and #npcIds > 0, "NoNPCIds", Errors.NO_NPC_IDS)

		local setCount = 0
		for _, npcId in npcIds do
			local result = self.NPCCommandPolicy:Check(userId, npcId)
			if result.success then
				local entity = (result :: any).value.Entity
				self.CommandWriteService:SetControlMode(entity, "Auto")
				self.CommandWriteService:ClearCommand(entity)
				setCount += 1
				MentionSuccess("PlayerCommand:ProcessToggleMode:ModeChange",
					`Set {npcId} to Auto`)
			end
		end

		if setCount == 0 then
			return Err("NPCNotFound", Errors.NPC_NOT_FOUND, { userId = userId })
		end

		return Ok(setCount)
	end, "PlayerCommand:ProcessToggleMode")
end

return ProcessToggleMode
