--!strict

local Enums = require(script.Enums)
local Manager = require(script.Manager)
local Resolver = require(script.Resolver)
local Types = require(script.Types)

export type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
export type TSelectionHandle = Types.TSelectionHandle
export type TSelectionManager = Types.TSelectionManager
export type TSelectionManagerConfig = Types.TSelectionManagerConfig
export type TSelectionRequest = Types.TSelectionRequest
export type TSelectionSetRequest = Types.TSelectionSetRequest
export type TSelectionResolverOptions = Types.TSelectionResolverOptions
export type THighlightConfig = Types.THighlightConfig
export type TRadiusConfig = Types.TRadiusConfig
export type TSelectionSnapshot = Types.TSelectionSnapshot
export type TSelectionHandleState = Types.TSelectionHandleState
export type TSelectionMode = Types.TSelectionMode
export type TInvalidationReason = Types.TInvalidationReason

local SelectionPlus = {
	HandleState = Enums.HandleState,
	SelectionMode = Enums.SelectionMode,
	InvalidationReason = Enums.InvalidationReason,
	ErrorKey = Enums.ErrorKey,
}

function SelectionPlus.new(config: TSelectionManagerConfig?): TSelectionManager
	return Manager.new(config)
end

function SelectionPlus.ResolveTarget(
	target: (Instance | TResolvedSelectionTarget)?,
	options: TSelectionResolverOptions?
): TResolvedSelectionTarget?
	return Resolver.ResolveTarget(target, options)
end

function SelectionPlus.ResolveTargetFromScreenPoint(
	camera: Camera,
	screenPoint: Vector2,
	options: TSelectionResolverOptions?
): TResolvedSelectionTarget?
	return Resolver.ResolveTargetFromScreenPoint(camera, screenPoint, options)
end

return table.freeze(SelectionPlus)
