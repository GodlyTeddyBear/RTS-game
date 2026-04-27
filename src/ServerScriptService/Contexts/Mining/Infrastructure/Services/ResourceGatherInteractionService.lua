--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local CLICK_DETECTOR_NAME = "ManualGatherClickDetector"

local ResourceGatherInteractionService = {}
ResourceGatherInteractionService.__index = ResourceGatherInteractionService

function ResourceGatherInteractionService.new()
	local self = setmetatable({}, ResourceGatherInteractionService)
	self._factory = nil
	self._clickedSignal = Instance.new("BindableEvent")
	self.ResourceNodeClicked = self._clickedSignal.Event
	self._detectorsByPart = {} :: { [BasePart]: ClickDetector }
	self._connectionsByPart = {} :: { [BasePart]: RBXScriptConnection }
	self._lastGatheredAtByKey = {} :: { [string]: number }
	return self
end

function ResourceGatherInteractionService:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

function ResourceGatherInteractionService:AttachToRegisteredNodes(): Result.Result<number>
	local attachedCount = 0
	for _, entity in ipairs(self._factory:QueryResourceNodes()) do
		local resourcePart = self._factory:GetNodeInstance(entity)
		if resourcePart ~= nil and resourcePart.Parent ~= nil and self:_AttachToPart(resourcePart) then
			attachedCount += 1
		end
	end

	return Ok(attachedCount)
end

function ResourceGatherInteractionService:GetResourceNodeForPart(resourcePart: BasePart): (number?, any?)
	local entity = self._factory:FindResourceNodeByInstance(resourcePart)
	if entity == nil then
		return nil, nil
	end

	return entity, self._factory:GetResourceNode(entity)
end

function ResourceGatherInteractionService:CanGather(player: Player, resourcePart: BasePart, now: number): boolean
	local lastGatheredAt = self._lastGatheredAtByKey[self:_BuildCooldownKey(player, resourcePart)]
	if lastGatheredAt == nil then
		return true
	end

	return now - lastGatheredAt >= MiningConfig.MANUAL_GATHER_COOLDOWN_SECONDS
end

function ResourceGatherInteractionService:MarkGathered(player: Player, resourcePart: BasePart, now: number)
	self._lastGatheredAtByKey[self:_BuildCooldownKey(player, resourcePart)] = now
end

function ResourceGatherInteractionService:Cleanup()
	for _, connection in pairs(self._connectionsByPart) do
		connection:Disconnect()
	end

	for _, detector in pairs(self._detectorsByPart) do
		if detector.Parent ~= nil then
			detector:Destroy()
		end
	end

	table.clear(self._connectionsByPart)
	table.clear(self._detectorsByPart)
	table.clear(self._lastGatheredAtByKey)
end

function ResourceGatherInteractionService:Destroy()
	self:Cleanup()
	self._clickedSignal:Destroy()
end

function ResourceGatherInteractionService:_AttachToPart(resourcePart: BasePart): boolean
	if self._detectorsByPart[resourcePart] ~= nil then
		return false
	end

	local detector = self:_GetOrCreateClickDetector(resourcePart)
	self._detectorsByPart[resourcePart] = detector
	self._connectionsByPart[resourcePart] = detector.MouseClick:Connect(function(player: Player)
		self._clickedSignal:Fire(player, resourcePart)
	end)

	return true
end

function ResourceGatherInteractionService:_GetOrCreateClickDetector(resourcePart: BasePart): ClickDetector
	local existing = resourcePart:FindFirstChild(CLICK_DETECTOR_NAME)
	if existing ~= nil and not existing:IsA("ClickDetector") then
		existing:Destroy()
		existing = nil
	end

	local detector = existing :: ClickDetector?
	if detector == nil then
		detector = Instance.new("ClickDetector")
		detector.Name = CLICK_DETECTOR_NAME
		detector.Parent = resourcePart
	end

	detector.MaxActivationDistance = MiningConfig.MANUAL_GATHER_MAX_DISTANCE
	return detector
end

function ResourceGatherInteractionService:_BuildCooldownKey(player: Player, resourcePart: BasePart): string
	return (`{player.UserId}:{resourcePart:GetFullName()}`)
end

return ResourceGatherInteractionService
