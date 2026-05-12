--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type GridCoord = PlacementTypes.GridCoord
type PlacementAtom = PlacementTypes.PlacementAtom
type FootprintCacheLookup = PlacementTypes.FootprintCacheLookup

type RunState = RunTypes.RunState

export type TPlacementCursorSessionState = {
	_state: "Idle" | "Active",
	_confirming: boolean,
	_sessionId: number,
	_structureType: string?,
	_rotationQuarterTurns: number,
	_hoveredCoord: GridCoord?,
	_hoveredKey: string?,
	_hoveredFootprintCoords: { GridCoord },
	_isHoveredValid: boolean,
	_runState: RunState,
	_placementSignature: string,
	_validTiles: { GridCoord },
	_validTileSet: { [string]: boolean },
	_footprintCacheLookup: FootprintCacheLookup,
	_sessionJanitor: any,
	_highlightPool: any,
	_ghost: any,
	_placementCancelledSignal: BindableEvent,
}

export type TPlacementCursorDeps = {
	placementAtom: () -> PlacementAtom,
	runAtom: () -> { State: RunState },
	playerInputController: any,
	placementContext: any,
	ghostModelModule: any,
	gridService: any,
	runService: any,
	userInputService: any,
	workspace: any,
	onRenderStepped: () -> (),
	onInputBegan: (input: InputObject, gameProcessed: boolean) -> (),
	updateHoverState: () -> (),
	janitorFactory: any,
}

return table.freeze({})
