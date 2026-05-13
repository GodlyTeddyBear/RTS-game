--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Specification = require(ReplicatedStorage.Utilities.Specification)

local Enums = require(script.Parent.Enums)

local Specs = {}

local function _ErrorName(errorKey: any): string
	return errorKey.Name
end

function Specs.IsValidConfig(config: any): boolean
	return config == nil or type(config) == "table"
end

function Specs.IsValidChannelName(channelName: any): boolean
	return type(channelName) == "string" and channelName ~= ""
end

function Specs.IsValidTarget(target: any): boolean
	if typeof(target) == "Instance" then
		return true
	end

	if type(target) ~= "table" then
		return false
	end

	return typeof(target.Root) == "Instance"
		and typeof(target.Adornee) == "Instance"
		and typeof(target.WorldPosition) == "Vector3"
end

function Specs.IsValidTargetList(targets: any): boolean
	if type(targets) ~= "table" or #targets == 0 then
		return false
	end

	for _, target in ipairs(targets) do
		if not Specs.IsValidTarget(target) then
			return false
		end
	end

	return true
end

function Specs.IsValidResolverOptions(options: any): boolean
	if options == nil then
		return true
	end

	return type(options) == "table"
		and (options.RayLength == nil or (type(options.RayLength) == "number" and options.RayLength > 0))
		and (options.AdorneeSelector == nil or type(options.AdorneeSelector) == "string")
		and (options.WorldPositionSelector == nil or type(options.WorldPositionSelector) == "string")
		and (options.ResolveRoot == nil or type(options.ResolveRoot) == "function")
		and (options.ResolveAdornee == nil or type(options.ResolveAdornee) == "function")
		and (options.ResolveWorldPosition == nil or type(options.ResolveWorldPosition) == "function")
end

function Specs.IsValidHighlightOptions(options: any): boolean
	if options == nil then
		return true
	end

	return type(options) == "table"
		and (options.Enabled == nil or type(options.Enabled) == "boolean")
		and (options.FillColor == nil or typeof(options.FillColor) == "Color3")
		and (options.OutlineColor == nil or typeof(options.OutlineColor) == "Color3")
		and (options.FillTransparency == nil or type(options.FillTransparency) == "number")
		and (options.OutlineTransparency == nil or type(options.OutlineTransparency) == "number")
		and (options.DepthMode == nil or typeof(options.DepthMode) == "EnumItem")
		and (options.Parent == nil or typeof(options.Parent) == "Instance")
		and (options.Adornee == nil or typeof(options.Adornee) == "Instance")
		and (options.BuildVisual == nil or type(options.BuildVisual) == "function")
end

function Specs.IsValidRadiusOptions(options: any): boolean
	if options == nil then
		return true
	end

	return type(options) == "table"
		and (options.Enabled == nil or type(options.Enabled) == "boolean")
		and (options.Radius == nil or (type(options.Radius) == "number" and options.Radius >= 0))
		and (options.Height == nil or type(options.Height) == "number")
		and (options.Color == nil or typeof(options.Color) == "Color3")
		and (options.Transparency == nil or type(options.Transparency) == "number")
		and (options.ClampToGround == nil or type(options.ClampToGround) == "boolean")
		and (options.Offset == nil or typeof(options.Offset) == "Vector3")
		and (options.Parent == nil or typeof(options.Parent) == "Instance")
		and (options.BuildVisual == nil or type(options.BuildVisual) == "function")
end

function Specs.IsValidMetadata(metadata: any): boolean
	return metadata == nil or type(metadata) == "table"
end

function Specs.IsValidSelectionMode(mode: any): boolean
	return mode == nil or Enums.SelectionMode:BelongsTo(mode)
end

function Specs.IsServiceAlive(isDestroyed: boolean): boolean
	return not isDestroyed
end

function Specs.IsHandleAlive(isDestroyed: boolean): boolean
	return not isDestroyed
end

function Specs.IsLegalTransition(currentState: any, canTransition: boolean): boolean
	if currentState == Enums.HandleState.Destroyed then
		return false
	end

	return canTransition
end

local HasValidConfig = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidConfig),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidConfig],
	function(candidate): boolean
		return Specs.IsValidConfig(candidate.Config)
	end
)

local HasValidChannelName = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidChannelName),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidChannelName],
	function(candidate): boolean
		return Specs.IsValidChannelName(candidate.ChannelName)
	end
)

local HasValidTarget = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidTarget),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidTarget],
	function(candidate): boolean
		return Specs.IsValidTarget(candidate.Target)
	end
)

local HasValidTargetList = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidTargetList),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidTargetList],
	function(candidate): boolean
		return Specs.IsValidTargetList(candidate.Targets)
	end
)

local HasValidResolverOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidResolverOptions),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidResolverOptions],
	function(candidate): boolean
		return Specs.IsValidResolverOptions(candidate.ResolverOptions)
	end
)

local HasValidHighlightOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidHighlightOptions),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidHighlightOptions],
	function(candidate): boolean
		return Specs.IsValidHighlightOptions(candidate.Highlight)
	end
)

local HasValidRadiusOptions = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidRadiusOptions),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidRadiusOptions],
	function(candidate): boolean
		return Specs.IsValidRadiusOptions(candidate.Radius)
	end
)

local HasValidMetadata = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidMetadata),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidMetadata],
	function(candidate): boolean
		return Specs.IsValidMetadata(candidate.Metadata)
	end
)

local HasValidSelectionMode = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidSelectionMode),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidSelectionMode],
	function(candidate): boolean
		return Specs.IsValidSelectionMode(candidate.Mode)
	end
)

local HasAliveService = Specification.new(
	_ErrorName(Enums.ErrorKey.SelectionServiceDestroyed),
	Enums.ErrorMessage[Enums.ErrorKey.SelectionServiceDestroyed],
	function(candidate): boolean
		return Specs.IsServiceAlive(candidate.IsDestroyed)
	end
)

local HasAliveHandle = Specification.new(
	_ErrorName(Enums.ErrorKey.SelectionHandleDestroyed),
	Enums.ErrorMessage[Enums.ErrorKey.SelectionHandleDestroyed],
	function(candidate): boolean
		return Specs.IsHandleAlive(candidate.IsDestroyed)
	end
)

local HasLegalTransition = Specification.new(
	_ErrorName(Enums.ErrorKey.IllegalSelectionHandleTransition),
	Enums.ErrorMessage[Enums.ErrorKey.IllegalSelectionHandleTransition],
	function(candidate): boolean
		return Specs.IsLegalTransition(candidate.CurrentState, candidate.CanTransition)
	end
)

Specs.HasValidConfigSpec = HasValidConfig
Specs.HasValidChannelNameSpec = HasValidChannelName
Specs.HasValidTargetSpec = HasValidTarget
Specs.HasValidTargetListSpec = HasValidTargetList
Specs.HasValidResolverOptionsSpec = HasValidResolverOptions
Specs.HasValidHighlightOptionsSpec = HasValidHighlightOptions
Specs.HasValidRadiusOptionsSpec = HasValidRadiusOptions
Specs.HasValidMetadataSpec = HasValidMetadata
Specs.HasValidSelectionModeSpec = HasValidSelectionMode
Specs.HasAliveServiceSpec = HasAliveService
Specs.HasAliveHandleSpec = HasAliveHandle
Specs.HasLegalTransitionSpec = HasLegalTransition
Specs.HasValidRequestSpec = Specification.All({
	HasValidConfig,
	HasValidResolverOptions,
	HasValidHighlightOptions,
	HasValidRadiusOptions,
	HasValidMetadata,
})
Specs.HasValidSetRequestSpec = Specification.All({
	HasValidConfig,
	HasValidTargetList,
	HasValidResolverOptions,
	HasValidHighlightOptions,
	HasValidRadiusOptions,
	HasValidMetadata,
})

return table.freeze(Specs)
