--!strict

--[=[
	@class Types
	Shared type definitions for the action system.
]=]

--[=[
	@type TActionContext
	@within Types
	Dependency bag injected into action handlers by the owning controller.

	@interface TActionContext
	.Model Model? -- Optional Model instance for the actor
	.SoundEngine any -- Service for playing sound effects
	.VFXService any -- Service for spawning visual effects
	.ResolveTargetInstance (() -> Instance?)? -- Callback to resolve current target
	.CombatService any? -- Optional combat system for server callbacks
	.NPCId string? -- Optional NPC identifier for combat notifications
]=]
export type TActionContext = {
	Model: Model?,
	SoundEngine: any,
	VFXService: any,
	ResolveTargetInstance: (() -> Instance?)?,
	CombatService: any?,
	ActorId: string?,
	ActorKind: "Enemy" | "Structure"?,
	NPCId: string?,
}

--[=[
	@type TEventDef
	@within Types
	Configuration for a keyframe marker event in an action animation.

	@interface TEventDef
	.SFX string? -- Sound effect ID to play
	.VFX string? -- Visual effect name to spawn
	.VFXAtTarget boolean? -- If true, spawn VFX at resolved target instead of actor
	.ServerCallback string? -- Name of server callback to fire on CombatService
]=]
export type TEventDef = {
	SFX: string?,
	VFX: string?,
	VFXAtTarget: boolean?,
	ServerCallback: string?,
}

--[=[
	@type IAction
	@within Types
	Interface for action classes that respond to animation keyframe markers and lifecycle events.

	@interface IAction
	.AnimationKey string -- Matches the AnimationState attribute value
	.Looped boolean -- Whether the action animation loops
	.Events { [string]: TEventDef }? -- Map of marker names to effect definitions
	.OnStart (self: IAction, track: AnimationTrack, context: TActionContext) -> () -- Called when animation starts
	.OnEvent (self: IAction, name: string, context: TActionContext) -> () -- Called on keyframe marker
	.OnCustomEvent ((self: IAction, name: string, context: TActionContext) -> ())? -- Optional custom marker logic
	.OnStop (self: IAction, context: TActionContext) -> () -- Called when animation stops
]=]
export type IAction = {
	AnimationKey: string,
	Looped: boolean,
	Events: { [string]: TEventDef }?,
	OnStart: (self: IAction, track: AnimationTrack, context: TActionContext) -> (),
	OnEvent: (self: IAction, name: string, context: TActionContext) -> (),
	OnCustomEvent: ((self: IAction, name: string, context: TActionContext) -> ())?,
	OnStop: (self: IAction, context: TActionContext) -> (),
}

return nil
