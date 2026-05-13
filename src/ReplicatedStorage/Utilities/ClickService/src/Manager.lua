--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Option = require(ReplicatedStorage.Utilities.Option)
local Result = require(ReplicatedStorage.Utilities.Result)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

local Detector = require(script.Parent.Detector)
local Handle = require(script.Parent.Handle)
local Policies = require(script.Parent.Policies)
local Resolver = require(script.Parent.Resolver)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TClickAttachOptions = Types.TClickAttachOptions
type TClickHandle = Types.TClickHandle
type TClickService = Types.TClickService
type TClickTarget = Types.TClickTarget
type TResolvedClickOptions = Types.TResolvedClickOptions

local CLICK_SIGNAL_KEY = "ClickedSignal"

local Manager = {}
Manager.__index = Manager

function Manager.new(config: Types.TClickManagerConfig?): TClickService
	Policies.CheckManagerConfig(config)

	local self = setmetatable({}, Manager) :: any
	self._config = Validation.NormalizeManagerConfig(config)
	self._handlesByTarget = {} :: { [Instance]: TClickHandle }
	self._stash = StashPlus.new()
	self._isDestroyed = false
	self.Clicked = GoodSignal.new()

	self._stash:Add(self.Clicked, {
		CleanupMethod = "DisconnectAll",
		Key = CLICK_SIGNAL_KEY,
		Label = CLICK_SIGNAL_KEY,
	})

	return self
end

function Manager:Attach(target: TClickTarget, options: TClickAttachOptions?): Result.Result<TClickHandle>
	local resolvedOptions = self:_ResolveOptions(options)
	local aliveResult = Policies.CheckServiceAlive(self, target, resolvedOptions.Name)
	if not aliveResult.success then
		return aliveResult
	end

	local targetResult = Policies.CheckTarget(target)
	if not targetResult.success then
		return targetResult
	end

	local existingHandleOption = self:GetHandle(target)
	if existingHandleOption:IsSome() then
		return Result.Ok(existingHandleOption:Unwrap())
	end

	local resolvedPartResult = Policies.CheckResolvedPart(
		target,
		Resolver.ResolveTarget(target, resolvedOptions.ResolvePart),
		resolvedOptions.Name
	)
	if not resolvedPartResult.success then
		return resolvedPartResult
	end

	local resolvedPart = resolvedPartResult.value
	local detectorCandidateResult = Policies.CheckDetectorCandidate(
		target,
		resolvedPart,
		resolvedOptions.Name,
		resolvedPart:FindFirstChild(resolvedOptions.Name)
	)
	if not detectorCandidateResult.success then
		return detectorCandidateResult
	end

	local detectorResult = Detector.EnsureDetector(target, resolvedPart, resolvedOptions)
	if not detectorResult.success then
		return detectorResult
	end

	local handle = Handle.new(self, target, resolvedPart, detectorResult.value, resolvedOptions)
	self._handlesByTarget[target] = handle

	return Result.Ok(handle)
end

function Manager:AttachMany(
	targets: { TClickTarget },
	options: TClickAttachOptions?
): Result.Result<{ TClickHandle }>
	Policies.CheckAttachOptions(options)

	return Result.traverse(targets, function(target: TClickTarget)
		return self:Attach(target, options)
	end)
end

function Manager:GetHandle(target: TClickTarget): any
	local handle = self._handlesByTarget[target]
	if handle == nil then
		return Option.None
	end

	if not handle:IsAttached() then
		self:_ForgetHandle(target, handle)
		return Option.None
	end

	return Option.Some(handle)
end

function Manager:GetDetector(target: TClickTarget): any
	return self:GetHandle(target):AndThen(function(handle: TClickHandle)
		return handle:GetDetector()
	end)
end

function Manager:Has(target: TClickTarget): boolean
	return self:GetHandle(target):IsSome()
end

function Manager:Detach(target: TClickTarget): boolean
	local handleOption = self:GetHandle(target)
	if handleOption:IsNone() then
		return false
	end

	return handleOption:Unwrap():Detach()
end

function Manager:DetachAll(): ()
	local targets = {}
	for target in pairs(self._handlesByTarget) do
		targets[#targets + 1] = target
	end

	for _, target in ipairs(targets) do
		self:Detach(target)
	end
end

function Manager:GetAttachedCount(): number
	local count = 0
	for target in pairs(self._handlesByTarget) do
		if self:Has(target) then
			count += 1
		end
	end

	return count
end

function Manager:Destroy(): ()
	if self._isDestroyed then
		return
	end

	self._isDestroyed = true

	local targets = {}
	for target in pairs(self._handlesByTarget) do
		targets[#targets + 1] = target
	end

	for _, target in ipairs(targets) do
		local handle = self._handlesByTarget[target]
		if handle ~= nil then
			handle:Destroy()
		end
	end

	table.clear(self._handlesByTarget)
	self._stash:Destroy()
end

function Manager:_ResolveOptions(options: TClickAttachOptions?): TResolvedClickOptions
	Policies.CheckAttachOptions(options)
	return Validation.ResolveAttachOptions(self._config, options)
end

function Manager:_ForgetHandle(target: Instance, handle: TClickHandle)
	if self._handlesByTarget[target] ~= handle then
		return
	end

	self._handlesByTarget[target] = nil
end

function Manager:_HandleClicked(player: Player, resolvedPart: BasePart, handle: TClickHandle)
	if self._isDestroyed then
		return
	end

	self.Clicked:Fire(player, resolvedPart, handle)
end

return table.freeze(Manager)
