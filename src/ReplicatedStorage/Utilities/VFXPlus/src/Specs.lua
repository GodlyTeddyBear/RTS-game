--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Specification = require(ReplicatedStorage.Utilities.Specification)

local Enums = require(script.Parent.Enums)
local Options = require(script.Parent.Options)

local Specs = {}

local function _ErrorName(errorKey: any): string
	return errorKey.Name
end

function Specs.IsValidRegistry(registry: any): boolean
	return type(registry) == "table"
		and type(registry.SkillEffectExists) == "function"
		and type(registry.GetSkillEffect) == "function"
		and type(registry.StatusEffectExists) == "function"
		and type(registry.GetStatusEffect) == "function"
end

function Specs.IsValidRequest(request: any): boolean
	return type(request) == "table"
end

function Specs.IsValidEffectKey(effectKey: any): boolean
	return type(effectKey) == "string" and effectKey ~= ""
end

function Specs.IsValidCategory(category: any): boolean
	return Options.ResolveCategory(category) ~= nil
end

function Specs.IsValidParent(parent: any): boolean
	return typeof(parent) == "Instance" and parent.Parent ~= nil
end

function Specs.IsValidSpawnRequest(request: any): boolean
	if type(request) ~= "table" then
		return false
	end

	return typeof(request.CFrame) == "CFrame" or typeof(request.Position) == "Vector3"
end

function Specs.IsValidAttachTarget(target: any): boolean
	return typeof(target) == "Instance"
		and target.Parent ~= nil
		and (target:IsA("BasePart") or target:IsA("Model") or target:IsA("Attachment"))
end

function Specs.IsValidLifetime(lifetime: any): boolean
	return lifetime == nil or (type(lifetime) == "number" and lifetime > 0)
end

function Specs.IsValidEmitCount(emitCount: any): boolean
	return emitCount == nil or (type(emitCount) == "number" and emitCount > 0)
end

function Specs.IsValidAutoCleanup(autoCleanup: any): boolean
	return autoCleanup == nil or type(autoCleanup) == "boolean"
end

function Specs.IsValidRuntimeParent(parent: any): boolean
	return parent == nil or (typeof(parent) == "Instance" and parent.Parent ~= nil)
end

function Specs.IsValidRuntimeFolderName(name: any): boolean
	return name == nil or (type(name) == "string" and name ~= "")
end

function Specs.IsValidEffectsFolder(effectsFolder: any): boolean
	return typeof(effectsFolder) == "Instance"
		and effectsFolder:IsA("Folder")
end

local HasValidRegistry = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRegistry),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRegistry],
	function(candidate): boolean
		return Specs.IsValidRegistry(candidate.Registry)
	end
)

local HasValidRequest = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRequest),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRequest],
	function(candidate): boolean
		return Specs.IsValidRequest(candidate.Request)
	end
)

local HasValidEffectKey = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidEffectKey),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidEffectKey],
	function(candidate): boolean
		local request = candidate.Request
		return type(request) == "table" and Specs.IsValidEffectKey(request.EffectKey)
	end
)

local HasValidCategory = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidCategory),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidCategory],
	function(candidate): boolean
		local request = candidate.Request
		return type(request) == "table" and Specs.IsValidCategory(request.Category)
	end
)

local HasValidParent = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidParent),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidParent],
	function(candidate): boolean
		local request = candidate.Request
		return type(request) == "table" and Specs.IsValidParent(request.Parent)
	end
)

local HasValidSpawnShape = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidSpawnRequest),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidSpawnRequest],
	function(candidate): boolean
		return Specs.IsValidSpawnRequest(candidate.Request)
	end
)

local HasValidAttachTarget = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidAttachTarget),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidAttachTarget],
	function(candidate): boolean
		local request = candidate.Request
		return type(request) == "table" and Specs.IsValidAttachTarget(request.Target)
	end
)

local HasValidLifetime = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidLifetime),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidLifetime],
	function(candidate): boolean
		local request = candidate.Request
		return type(request) == "table" and Specs.IsValidLifetime(request.Lifetime)
	end
)

local HasValidEmitCount = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidEmitCount),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidEmitCount],
	function(candidate): boolean
		local request = candidate.Request
		return type(request) == "table" and Specs.IsValidEmitCount(request.EmitCount)
	end
)

local HasValidAutoCleanup = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidAutoCleanup),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidAutoCleanup],
	function(candidate): boolean
		local request = candidate.Request
		return type(request) == "table" and Specs.IsValidAutoCleanup(request.AutoCleanup)
	end
)

local HasValidRuntimeParent = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRuntimeParent),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRuntimeParent],
	function(candidate): boolean
		return Specs.IsValidRuntimeParent(candidate.Parent)
	end
)

local HasValidRuntimeFolderName = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRuntimeFolderName),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRuntimeFolderName],
	function(candidate): boolean
		return Specs.IsValidRuntimeFolderName(candidate.Name)
	end
)

local HasValidEffectsFolder = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidEffectsFolder),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidEffectsFolder],
	function(candidate): boolean
		return Specs.IsValidEffectsFolder(candidate.EffectsFolder)
	end
)

Specs.HasValidRegistrySpec = HasValidRegistry
Specs.HasValidRequestSpec = HasValidRequest
Specs.HasValidEffectKeySpec = HasValidEffectKey
Specs.HasValidCategorySpec = HasValidCategory
Specs.HasValidParentSpec = HasValidParent
Specs.HasValidSpawnShapeSpec = HasValidSpawnShape
Specs.HasValidAttachTargetSpec = HasValidAttachTarget
Specs.HasValidLifetimeSpec = HasValidLifetime
Specs.HasValidEmitCountSpec = HasValidEmitCount
Specs.HasValidAutoCleanupSpec = HasValidAutoCleanup
Specs.HasValidRuntimeParentSpec = HasValidRuntimeParent
Specs.HasValidRuntimeFolderNameSpec = HasValidRuntimeFolderName
Specs.HasValidEffectsFolderSpec = HasValidEffectsFolder
Specs.HasValidBaseRequestSpec = Specification.All({
	HasValidRegistry,
	HasValidRequest,
	HasValidEffectKey,
	HasValidCategory,
	HasValidParent,
	HasValidLifetime,
	HasValidEmitCount,
	HasValidAutoCleanup,
})
Specs.HasValidSpawnRequestSpec = Specification.All({
	Specs.HasValidBaseRequestSpec,
	HasValidSpawnShape,
})
Specs.HasValidAttachRequestSpec = Specification.All({
	Specs.HasValidBaseRequestSpec,
	HasValidAttachTarget,
})

return table.freeze(Specs)
