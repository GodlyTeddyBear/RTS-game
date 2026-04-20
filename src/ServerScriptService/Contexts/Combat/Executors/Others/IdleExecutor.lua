--!strict

--[=[
	@class IdleExecutor
	Default fallback executor when no other behavior applies.

	Non-committed and indefinite. Sets locomotion to Idle, stops humanoid
	movement (to prevent sliding), and returns "Running" every tick until
	replaced by a higher-priority action (Chase, Attack, etc.).
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseExecutor = require(script.Parent.Parent.Base.BaseExecutor)
local ExecutorTypes = require(ReplicatedStorage.Contexts.Combat.Types.ExecutorTypes)

type Entity = ExecutorTypes.Entity
type TActionServices = ExecutorTypes.TActionServices

local IdleExecutor = {}
IdleExecutor.__index = IdleExecutor
setmetatable(IdleExecutor, { __index = BaseExecutor })

export type TIdleExecutor = typeof(setmetatable({} :: { Config: ExecutorTypes.TExecutorConfig }, IdleExecutor))

function IdleExecutor.new(): TIdleExecutor
	local self = BaseExecutor.new({
		ActionId = "Idle",
		IsCommitted = false,
		Duration = nil,
	})
	return setmetatable(self :: any, IdleExecutor)
end

--[=[
	Start the idle state for an entity.
	@within IdleExecutor
	@param entity Entity
	@param _actionData { [string]: any }?
	@param services TActionServices
	@return boolean -- Always succeeds
]=]
function IdleExecutor:Start(entity: Entity, _actionData: { [string]: any }?, services: TActionServices): (boolean, string?)
	local npc = services.NPCEntityFactory
	local locoState = npc:GetLocomotionState(entity)
	if locoState and locoState.State ~= "Idle" then
		npc:SetLocomotionState(entity, "Idle")
	end

	-- Stop Humanoid movement to prevent sliding when entity holds position
	local modelRef = npc:GetModelRef(entity)
	if modelRef and modelRef.Instance and modelRef.Instance.PrimaryPart then
		local humanoid = modelRef.Instance:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(modelRef.Instance.PrimaryPart.Position)
		end
	end

	return true, nil
end

--[=[
	Keep the entity idle. Always returns "Running" to sustain the state.
	@within IdleExecutor
	@param _entity Entity
	@param _deltaTime number
	@param _services TActionServices
	@return string -- Always "Running"
]=]
function IdleExecutor:Tick(_entity: Entity, _deltaTime: number, _services: TActionServices): string
	return "Running"
end

return IdleExecutor
