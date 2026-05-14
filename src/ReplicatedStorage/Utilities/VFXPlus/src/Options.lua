--!strict

local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TVFXRequest = Types.TVFXRequest
type TPreparedVFXRequest = Types.TPreparedVFXRequest
type TResolvedAttachTarget = Types.TResolvedAttachTarget

local Options = {}

local function _CloneMetadata(metadata: { [string]: any }?): { [string]: any }?
	if metadata == nil then
		return nil
	end

	return table.clone(metadata)
end

function Options.ResolveCategory(category: any): any?
	if category == nil then
		return Enums.EffectCategory.Skill
	end

	if Enums.EffectCategory:BelongsTo(category) then
		return category
	end

	if category == "Skill" then
		return Enums.EffectCategory.Skill
	end

	if category == "StatusEffect" then
		return Enums.EffectCategory.StatusEffect
	end

	return nil
end

function Options.CreateRequest(spec: TVFXRequest): TVFXRequest
	return {
		EffectKey = spec.EffectKey,
		Category = spec.Category,
		Parent = spec.Parent,
		Position = spec.Position,
		CFrame = spec.CFrame,
		Target = spec.Target,
		Offset = spec.Offset,
		Lifetime = spec.Lifetime,
		EmitCount = spec.EmitCount,
		AutoCleanup = spec.AutoCleanup,
		Metadata = _CloneMetadata(spec.Metadata),
	}
end

function Options.ResolveSpawnCFrame(request: TVFXRequest): CFrame?
	if request.CFrame ~= nil then
		return request.CFrame
	end

	if request.Position ~= nil then
		return CFrame.new(request.Position)
	end

	return nil
end

function Options.CreatePreparedRequest(
	request: TVFXRequest,
	category: any,
	effectCFrame: CFrame,
	resolvedTarget: TResolvedAttachTarget?
): TPreparedVFXRequest
	return {
		EffectKey = request.EffectKey,
		Category = category,
		Parent = request.Parent :: Instance,
		CFrame = effectCFrame,
		Target = request.Target,
		TargetPart = if resolvedTarget ~= nil then resolvedTarget.TargetPart else nil,
		Offset = request.Offset,
		Lifetime = request.Lifetime,
		EmitCount = request.EmitCount,
		AutoCleanup = request.AutoCleanup == true,
		Metadata = _CloneMetadata(request.Metadata),
	}
end

return table.freeze(Options)
