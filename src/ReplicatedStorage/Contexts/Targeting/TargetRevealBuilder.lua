--!strict

local TargetSchema = require(script.Parent.Config.TargetSchema)

export type TAttributeValue =
	string
	| number
	| boolean
	| Vector3
	| CFrame
	| Color3
	| BrickColor
	| UDim
	| UDim2
	| NumberSequence
	| ColorSequence
	| NumberRange
	| Rect
	| nil

export type TRevealState = {
	Attributes: { [string]: TAttributeValue }?,
	ClearAttributes: { string }?,
	Tags: { [string]: boolean }?,
}

export type TTargetRevealOptions = {
	TargetType: string,
	SourceId: string,
	ScopeId: string,
	TargetId: string?,
}

local TargetRevealBuilder = {}

function TargetRevealBuilder.Build(options: TTargetRevealOptions): (string, TRevealState)
	assert(type(options.TargetType) == "string" and options.TargetType ~= "", "TargetType is required")
	assert(type(options.SourceId) == "string" and options.SourceId ~= "", "SourceId is required")
	assert(type(options.ScopeId) == "string" and options.ScopeId ~= "", "ScopeId is required")

	local targetId = options.TargetId
		or TargetSchema.MakeScopedTargetId(options.ScopeId, options.TargetType, options.SourceId)

	return targetId, {
		Attributes = {
			[TargetSchema.ATTR_TARGET_TYPE] = options.TargetType,
			[TargetSchema.ATTR_TARGET_ID] = targetId,
		},
		Tags = {
			[TargetSchema.GetTypeTag(options.TargetType)] = true,
			[TargetSchema.GetTypeIdTag(options.TargetType, options.SourceId)] = true,
		},
	}
end

return TargetRevealBuilder
