--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

type GridCoord = PlacementTypes.GridCoord

type PlacementAtom = PlacementTypes.PlacementAtom

type RunState = RunTypes.RunState

export type TPlacementCursorSessionState = {
	_state: "Idle" | "Active",
	_confirming: boolean,
	_sessionId: number,
	_structureType: string?,
	_hoveredCoord: GridCoord?,
	_hoveredKey: string?,
	_isHoveredValid: boolean,
	_runState: RunState,
	_placementSignature: string,
	_validTiles: { GridCoord },
	_validTileSet: { [string]: boolean },
	_sessionJanitor: any,
	_highlightPool: any,
	_ghost: any,
	_placementCancelledSignal: BindableEvent,
}

export type TPlacementCursorDeps = {
	placementAtom: () -> PlacementAtom,
	runAtom: () -> { state: RunState },
	playerInputController: any,
	placementRemoteClient: any,
	ghostModelModule: any,
	gridService: any,
	runService: any,
	userInputService: any,
	workspace: any,
	onRenderStepped: () -> (),
	onInputBegan: (input: InputObject, gameProcessed: boolean) -> (),
	updateHoverState: () -> (),
}

return table.freeze({})
