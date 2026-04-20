--!strict

--[[
    NPCEventTypes - Type definitions for the NPC-to-client event bridge.

    TNPCEvent is the payload sent from server executors to the client via
    CombatContext.Client.NPCEvent. The client CombatEventDispatcher routes
    each event by TargetNPCId to the correct model and dispatches effects.

    EventType strings are intentionally open (not a union) so new event
    types can be added without modifying this file. The CombatEffectsConfig
    on the client maps known EventTypes to SFX/VFX definitions.
]]

export type TNPCEvent = {
	EventType: string,
	SourceNPCId: string?,
	TargetNPCId: string?,
	Damage: number?,
	NewHP: number?,
	MaxHP: number?,
	Position: Vector3?,
	IsCritical: boolean?,
	EffectKey: string?,
	SoundKey: string?,
	Custom: { [string]: any }?,
}

return {}
