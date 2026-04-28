--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local CLICK_DETECTOR_NAME = "ManualGatherClickDetector"

--[=[
    @class ResourceGatherInteractionService
    Owns click-detector wiring and cooldown tracking for manual mining resource gathering.
    @server
]=]
local ResourceGatherInteractionService = {}
ResourceGatherInteractionService.__index = ResourceGatherInteractionService

-- Creates the interaction service and its click signal.
--[=[
    Creates the resource-gather interaction service.
    @within ResourceGatherInteractionService
    @return ResourceGatherInteractionService -- The new service instance.
]=]
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

-- Resolves the mining entity factory during init.
--[=[
    Resolves the mining entity factory during init.
    @within ResourceGatherInteractionService
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function ResourceGatherInteractionService:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

-- Attaches click detectors to every registered resource node.
--[=[
    Attaches click detectors to every registered resource node.
    @within ResourceGatherInteractionService
    @return Result.Result<number> -- The number of nodes attached.
]=]
function ResourceGatherInteractionService:AttachToRegisteredNodes(): Result.Result<number>
	-- Visit the registered resource nodes and attach interactions for any live parts.
	local attachedCount = 0
	for _, entity in ipairs(self._factory:QueryResourceNodes()) do
		local resourcePart = self._factory:GetNodeInstance(entity)
		if resourcePart ~= nil and resourcePart.Parent ~= nil and self:_AttachToPart(resourcePart) then
			attachedCount += 1
		end
	end

	return Ok(attachedCount)
end

-- Looks up the mining entity and resource record for a clicked resource part.
--[=[
    Looks up the mining entity and resource record for a clicked resource part.
    @within ResourceGatherInteractionService
    @param resourcePart BasePart -- The clicked resource part.
    @return number? -- The entity id, if present.
    @return any? -- The resource-node record, if present.
]=]
function ResourceGatherInteractionService:GetResourceNodeForPart(resourcePart: BasePart): (number?, any?)
	local entity = self._factory:FindResourceNodeByInstance(resourcePart)
	if entity == nil then
		return nil, nil
	end

	return entity, self._factory:GetResourceNode(entity)
end

-- Checks whether the player is still inside the manual gather cooldown window.
--[=[
    Checks whether the player can gather from the supplied resource part at the current time.
    @within ResourceGatherInteractionService
    @param player Player -- The gathering player.
    @param resourcePart BasePart -- The resource part being gathered.
    @param now number -- The current clock timestamp.
    @return boolean -- Whether gathering is allowed.
]=]
function ResourceGatherInteractionService:CanGather(player: Player, resourcePart: BasePart, now: number): boolean
	local lastGatheredAt = self._lastGatheredAtByKey[self:_BuildCooldownKey(player, resourcePart)]
	if lastGatheredAt == nil then
		return true
	end

	return now - lastGatheredAt >= MiningConfig.MANUAL_GATHER_COOLDOWN_SECONDS
end

-- Records the latest gather timestamp for the player-part pair.
--[=[
    Records the latest gather timestamp for the player-part pair.
    @within ResourceGatherInteractionService
    @param player Player -- The gathering player.
    @param resourcePart BasePart -- The resource part being gathered.
    @param now number -- The current clock timestamp.
]=]
function ResourceGatherInteractionService:MarkGathered(player: Player, resourcePart: BasePart, now: number)
	self._lastGatheredAtByKey[self:_BuildCooldownKey(player, resourcePart)] = now
end

-- Disconnects all click wiring and clears the cooldown cache.
--[=[
    Disconnects all click wiring and clears the cooldown cache.
    @within ResourceGatherInteractionService
]=]
function ResourceGatherInteractionService:Cleanup()
	-- Disconnect every active click wiring before destroying detectors.
	for _, connection in pairs(self._connectionsByPart) do
		connection:Disconnect()
	end

	-- Remove the detector instances from the map so the next attach pass can rebuild them cleanly.
	for _, detector in pairs(self._detectorsByPart) do
		if detector.Parent ~= nil then
			detector:Destroy()
		end
	end

	table.clear(self._connectionsByPart)
	table.clear(self._detectorsByPart)
	table.clear(self._lastGatheredAtByKey)
end

-- Cleans up the service-owned signal after all attachments are removed.
--[=[
    Destroys the interaction service after cleanup completes.
    @within ResourceGatherInteractionService
]=]
function ResourceGatherInteractionService:Destroy()
	self:Cleanup()
	self._clickedSignal:Destroy()
end

-- Attaches one detector and forwards clicks through the shared signal.
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

-- Reuses an existing click detector when possible and normalizes its activation distance.
local function _GetOrCreateClickDetector(resourcePart: BasePart): ClickDetector
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

-- Builds the cooldown cache key from the player id and backing part path.
function ResourceGatherInteractionService:_BuildCooldownKey(player: Player, resourcePart: BasePart): string
	return (`{player.UserId}:{resourcePart:GetFullName()}`)
end

return ResourceGatherInteractionService
