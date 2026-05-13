--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

local Enums = require(script.Parent.Enums)
local Handle = require(script.Parent.Handle)
local Policies = require(script.Parent.Policies)
local Profiles = require(script.Parent.Profiles)
local Resolver = require(script.Parent.Resolver)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TProximityHandle = Types.TProximityHandle
type TProximityManager = Types.TProximityManager
type TProximityOptions = Types.TProximityOptions
type TProximityProfile = Types.TProximityProfile
type TProximityTarget = Types.TProximityTarget
type TResolvedProximityOptions = Types.TResolvedProximityOptions

local Manager = {}
Manager.__index = Manager

function Manager.new(config: Types.TProximityManagerConfig?): TProximityManager
	Policies.CheckOptions(config)

	local self = setmetatable({}, Manager) :: any
	self._config = Validation.NormalizeManagerConfig(config)
	self._handlesByKey = {} :: { [string]: TProximityHandle }
	self._stash = StashPlus.new()
	self._isDestroyed = false

	return self
end

function Manager:Create(key: string, target: TProximityTarget, options: TProximityOptions?): TProximityHandle
	Policies.CheckServiceAlive(self)
	Policies.CheckKey(key)
	Policies.CheckTarget(target)
	Policies.CheckOptions(options)

	local resolvedOptions = Validation.ResolveOptions(self._config, options)
	local resolvedParent = Resolver.ResolvePromptParent(target, resolvedOptions.ResolveParent)
	Policies.CheckResolvedParent(resolvedParent)

	-- Replace any previous binding for the same key before creating the new handle scope.
	self:Remove(key)

	local prompt = Resolver.CreatePrompt(resolvedParent :: BasePart | Attachment, resolvedOptions)
	local handle = self:_CreateHandle(
		key,
		target,
		prompt,
		true,
		resolvedOptions,
		Enums.RegistrationMode.Create
	)

	return handle
end

function Manager:Register(key: string, prompt: ProximityPrompt, options: TProximityOptions?): TProximityHandle
	Policies.CheckServiceAlive(self)
	Policies.CheckKey(key)
	Policies.CheckPrompt(prompt)
	Policies.CheckOptions(options)

	local resolvedOptions = Validation.ResolveOptions(self._config, options)

	-- Replace any previous binding for the same key before taking over this prompt.
	self:Remove(key)

	Resolver.ApplyPromptOptions(prompt, resolvedOptions)

	local target = prompt.Parent
	assert(target ~= nil, Enums.ErrorMessage[Enums.ErrorKey.InvalidPrompt])

	local handle = self:_CreateHandle(
		key,
		target :: any,
		prompt,
		resolvedOptions.OwnsPrompt,
		resolvedOptions,
		Enums.RegistrationMode.Register
	)

	return handle
end

function Manager:BindProfile(
	key: string,
	targetOrPrompt: TProximityTarget | ProximityPrompt,
	profile: TProximityProfile,
	overrides: TProximityOptions?
): TProximityHandle
	Policies.CheckServiceAlive(self)
	Policies.CheckKey(key)
	Policies.CheckProfile(profile)
	Policies.CheckOptions(overrides)

	local resolvedOptions = Profiles.ResolveProfile(self._config, profile, overrides)

	if targetOrPrompt:IsA("ProximityPrompt") then
		return self:Register(key, targetOrPrompt, resolvedOptions :: any)
	end

	return self:Create(key, targetOrPrompt :: TProximityTarget, resolvedOptions :: any)
end

function Manager:Get(key: string): TProximityHandle?
	Policies.CheckKey(key)

	local handle = self._handlesByKey[key]
	if handle == nil then
		return nil
	end

	if handle:GetState() == Enums.HandleState.Destroyed then
		self:_ForgetHandle(key, handle)
		return nil
	end

	return handle
end

function Manager:Remove(key: string)
	Policies.CheckKey(key)

	local handle = self._handlesByKey[key]
	if handle == nil then
		if self._stash:HasScope(key) then
			self._stash:DestroyScope(key)
		end
		return
	end

	handle:Destroy()
end

function Manager:Clear()
	local keys = {}
	for key in pairs(self._handlesByKey) do
		keys[#keys + 1] = key
	end

	for _, key in ipairs(keys) do
		self:Remove(key)
	end
end

function Manager:Destroy()
	if self._isDestroyed then
		return
	end

	self._isDestroyed = true
	self:Clear()
	table.clear(self._handlesByKey)
	self._stash:Destroy()
end

function Manager:_CreateHandle(
	key: string,
	target: TProximityTarget,
	prompt: ProximityPrompt,
	ownsPrompt: boolean,
	options: TResolvedProximityOptions,
	mode: any
): TProximityHandle
	local handleScope = self._stash:Scope(key)
	local handle = Handle.new(self, key, target, prompt, ownsPrompt, options, mode, handleScope)
	self._handlesByKey[key] = handle
	return handle
end

function Manager:_ForgetHandle(key: string, handle: TProximityHandle)
	if self._handlesByKey[key] ~= handle then
		return
	end

	self._handlesByKey[key] = nil

	if self._stash:HasScope(key) then
		self._stash:RemoveScope(key)
	end
end

return table.freeze(Manager)
