--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Options = require(script.Parent.Options)
local Specs = require(script.Parent.Specs)
local Target = require(script.Parent.Target)
local Types = require(script.Parent.Types)

type TPreparedVFXRequest = Types.TPreparedVFXRequest
type TResolvedAttachTarget = Types.TResolvedAttachTarget
type TVFXRequest = Types.TVFXRequest
type TVFXRegistry = Types.TVFXRegistry

local Policies = {}

local function _BuildCandidate(registry: any, request: any): { Registry: any, Request: any }
	return {
		Registry = registry,
		Request = request,
	}
end

local function _ValidateBaseRequest(registry: any, request: any): Result.Result<any>
	return Specs.HasValidBaseRequestSpec:IsSatisfiedBy(_BuildCandidate(registry, request))
end

function Policies.PrepareSpawn(registry: TVFXRegistry, request: TVFXRequest): Result.Result<TPreparedVFXRequest>
	local validationResult = Specs.HasValidSpawnRequestSpec:IsSatisfiedBy(_BuildCandidate(registry, request))
	if not validationResult.success then
		return validationResult :: any
	end

	local normalizedRequest = Options.CreateRequest(request)
	local category = Options.ResolveCategory(normalizedRequest.Category)
	local effectCFrame = Options.ResolveSpawnCFrame(normalizedRequest)

	return Result.Ok(Options.CreatePreparedRequest(normalizedRequest, category, effectCFrame :: CFrame, nil))
end

function Policies.PrepareAttach(registry: TVFXRegistry, request: TVFXRequest): Result.Result<TPreparedVFXRequest>
	local validationResult = Specs.HasValidAttachRequestSpec:IsSatisfiedBy(_BuildCandidate(registry, request))
	if not validationResult.success then
		return validationResult :: any
	end

	local normalizedRequest = Options.CreateRequest(request)
	local category = Options.ResolveCategory(normalizedRequest.Category)
	local targetResult = Target.Resolve(normalizedRequest.Target :: Instance)
	if not targetResult.success then
		return targetResult :: any
	end

	local resolvedTarget = targetResult.value
	local effectCFrame = resolvedTarget.CFrame * (normalizedRequest.Offset or CFrame.new())

	return Result.Ok(Options.CreatePreparedRequest(normalizedRequest, category, effectCFrame, resolvedTarget))
end

function Policies.Prepare(registry: TVFXRegistry, request: TVFXRequest): Result.Result<TPreparedVFXRequest>
	local validationResult = _ValidateBaseRequest(registry, request)
	if not validationResult.success then
		return validationResult :: any
	end

	if request.Target ~= nil then
		return Policies.PrepareAttach(registry, request)
	end

	return Policies.PrepareSpawn(registry, request)
end

return table.freeze(Policies)
