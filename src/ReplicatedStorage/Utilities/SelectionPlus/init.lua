--!strict

--[=[
    @class SelectionPlus
    Shared client-side selection utility for resolving world targets and rendering
    reusable selection visuals with explicit cleanup ownership.
    @client
]=]

local SelectionPlus = require(script.src)

--[=[
    @type TSelectionManagerConfig
    @within SelectionPlus
    Manager configuration for a `SelectionPlus` instance.
]=]
export type TSelectionManagerConfig = SelectionPlus.TSelectionManagerConfig

--[=[
    @type TSelectionResolverOptions
    @within SelectionPlus
    Resolver options used while turning hits or instances into selection targets.
]=]
export type TSelectionResolverOptions = SelectionPlus.TSelectionResolverOptions

--[=[
    @type THighlightConfig
    @within SelectionPlus
    Built-in highlight visual configuration.
]=]
export type THighlightConfig = SelectionPlus.THighlightConfig

--[=[
    @type TRadiusConfig
    @within SelectionPlus
    Built-in radius indicator configuration.
]=]
export type TRadiusConfig = SelectionPlus.TRadiusConfig

--[=[
    @type TSelectionRequest
    @within SelectionPlus
    Selection request consumed by `Select` and `SelectFromScreenPoint`.
]=]
export type TSelectionRequest = SelectionPlus.TSelectionRequest

--[=[
    @type TResolvedSelectionTarget
    @within SelectionPlus
    Normalized selection target resolved from either a hit or a direct instance.
]=]
export type TResolvedSelectionTarget = SelectionPlus.TResolvedSelectionTarget

--[=[
    @type TSelectionHandle
    @within SelectionPlus
    Returned handle for one active channel selection.
]=]
export type TSelectionHandle = SelectionPlus.TSelectionHandle

--[=[
    @type TSelectionManager
    @within SelectionPlus
    Stateful selection manager that owns active channels and cleanup.
]=]
export type TSelectionManager = SelectionPlus.TSelectionManager

return SelectionPlus
