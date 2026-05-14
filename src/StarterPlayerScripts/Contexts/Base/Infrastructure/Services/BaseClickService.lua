--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClickService = require(ReplicatedStorage.Utilities.ClickService)
local Option = require(ReplicatedStorage.Utilities.Option)
local BaseTypes = require(ReplicatedStorage.Contexts.Base.Types.BaseTypes)

type BaseState = BaseTypes.BaseState
type BaseAtom = () -> BaseState?
type BaseClickCallback = (Instance) -> ()
type BaseDiscoveryService = {
	GetActiveBaseInstance: (self: BaseDiscoveryService) -> Instance?,
}

local CLICK_DETECTOR_NAME = "BaseProductionClickDetector"
local CLICK_REFRESH_INTERVAL = 0.25
local MAX_ACTIVATION_DISTANCE = 96

local BaseClickService = {}
BaseClickService.__index = BaseClickService

local function _FindFirstBasePart(instance: Instance?): BasePart?
	if instance == nil then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		if instance.PrimaryPart ~= nil then
			return instance.PrimaryPart
		end

		return instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function _ResolveClickPart(target: Instance): any
	return Option.Wrap(_FindFirstBasePart(target))
end

local function _AsClickTarget(instance: Instance?): (Model | BasePart)?
	if instance == nil then
		return nil
	end

	if instance:IsA("Model") or instance:IsA("BasePart") then
		return instance
	end

	local nestedModel = instance:FindFirstChildWhichIsA("Model", true)
	if nestedModel ~= nil then
		return nestedModel
	end

	return _FindFirstBasePart(instance)
end

function BaseClickService.new(baseAtom: BaseAtom, discoveryService: BaseDiscoveryService, onClicked: BaseClickCallback)
	local self = setmetatable({}, BaseClickService)
	self._baseAtom = baseAtom
	self._discoveryService = discoveryService
	self._onClicked = onClicked
	self._clickService = ClickService.new({
		Name = CLICK_DETECTOR_NAME,
		MaxActivationDistance = MAX_ACTIVATION_DISTANCE,
		ResolvePart = _ResolveClickPart,
	})
	self._target = nil :: (Model | BasePart)?
	self._clickConnection = nil :: any
	self._heartbeatConnection = nil :: RBXScriptConnection?
	self._refreshAccumulator = 0
	return self
end

function BaseClickService:Start()
	if self._heartbeatConnection ~= nil then
		return
	end

	self:_RefreshAttachment()
	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		self._refreshAccumulator += deltaTime
		if self._refreshAccumulator < CLICK_REFRESH_INTERVAL then
			return
		end

		self._refreshAccumulator = 0
		self:_RefreshAttachment()
	end)
end

function BaseClickService:Destroy()
	if self._heartbeatConnection ~= nil then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	self:_DetachCurrentTarget()
	self._clickService:Destroy()
end

function BaseClickService:_RefreshAttachment()
	if self._baseAtom() == nil then
		self:_DetachCurrentTarget()
		return
	end

	local target = _AsClickTarget(self._discoveryService:GetActiveBaseInstance())
	if target == nil or target.Parent == nil then
		self:_DetachCurrentTarget()
		return
	end

	if self._target == target and self._clickService:Has(target) then
		return
	end

	self:_AttachTarget(target)
end

function BaseClickService:_AttachTarget(target: Model | BasePart)
	self:_DetachCurrentTarget()

	local attachResult = self._clickService:Attach(target)
	if not attachResult.success then
		warn(("[BaseClickService] Failed to attach base click detector: %s"):format(tostring(attachResult.message)))
		return
	end

	local handle = attachResult.value
	self._target = target
	self._clickConnection = handle.Clicked:Connect(function(player: Player)
		if player ~= Players.LocalPlayer or self._baseAtom() == nil then
			return
		end

		self._onClicked(target)
	end)
end

function BaseClickService:_DetachCurrentTarget()
	if self._clickConnection ~= nil then
		self._clickConnection:Disconnect()
		self._clickConnection = nil
	end

	local target = self._target
	if target ~= nil then
		self._clickService:Detach(target)
		self._target = nil
	end
end

return BaseClickService
