--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local RunTravelConfig = require(ReplicatedStorage.Contexts.Run.Config.RunTravelConfig)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

local Ok = Result.Ok

type RunState = RunTypes.RunState

local function _IsRunActive(runState: RunState): boolean
	return runState == "Prep"
		or runState == "Wave"
		or runState == "Resolution"
		or runState == "Climax"
		or runState == "Endless"
end

local RunTravelService = {}
RunTravelService.__index = RunTravelService

function RunTravelService.new()
	local self = setmetatable({}, RunTravelService)
	self._mapContext = nil
	return self
end

function RunTravelService:Init(_registry: any, _name: string)
end

function RunTravelService:Start(registry: any, _name: string)
	self._mapContext = registry:Get("MapContext")
end

function RunTravelService:TeleportAllPlayersToRunEntry(): Result.Result<boolean>
	local targetCFrame = self:_ResolveRunEntryCFrame()
	self:_TeleportPlayersToCFrame(targetCFrame)
	return Ok(true)
end

function RunTravelService:TeleportAllPlayersToLobby(): Result.Result<boolean>
	local targetCFrame = self:_ResolveLobbyCFrame()
	self:_TeleportPlayersToCFrame(targetCFrame)
	return Ok(true)
end

function RunTravelService:PositionPlayerForState(player: Player, runState: RunState): Result.Result<boolean>
	local targetCFrame = self:_ResolveCharacterTargetCFrame(runState)
	self:_TeleportPlayerToCFrame(player, targetCFrame)
	return Ok(true)
end

function RunTravelService:_ResolveCharacterTargetCFrame(runState: RunState): CFrame
	if _IsRunActive(runState) then
		return self:_ResolveLobbyCFrame()
	end

	return self:_ResolveLobbyCFrame()
end

function RunTravelService:_ResolveLobbyCFrame(): CFrame
	return self:_ResolveMapCFrame("GetLobbySpawnCFrame", RunTravelConfig.LOBBY_RETURN_CFRAME)
end

function RunTravelService:_ResolveRunEntryCFrame(): CFrame
	return self:_ResolveMapCFrame("GetRunEntryCFrame", RunTravelConfig.PHASE2_ENTRY_CFRAME)
end

function RunTravelService:_ResolveMapCFrame(methodName: string, fallbackCFrame: CFrame): CFrame
	if self._mapContext == nil then
		return fallbackCFrame
	end

	local ok, result = pcall(function()
		return self._mapContext[methodName](self._mapContext)
	end)
	if not ok or result == nil or not result.success then
		return fallbackCFrame
	end

	return result.value
end

function RunTravelService:_TeleportPlayersToCFrame(targetCFrame: CFrame)
	for _, player in Players:GetPlayers() do
		self:_TeleportPlayerToCFrame(player, targetCFrame)
	end
end

function RunTravelService:_TeleportPlayerToCFrame(player: Player, targetCFrame: CFrame)
	local character = player.Character
	if character == nil then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	rootPart.CFrame = targetCFrame
end

return RunTravelService
