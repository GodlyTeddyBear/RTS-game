--!strict

--[[
    CombatEffectsConfig - Data-driven mapping from server event types to client effects.

    Each key is an EventType string matching TNPCEvent.EventType sent by the server.
    Values define which SFX and VFX to trigger automatically via CombatEventDispatcher.

    For complex logic (damage numbers, screen shake, UI updates), register a custom
    handler via CombatEventDispatcher:OnEvent() instead of adding fields here.

    Individual events can override these defaults via event.SoundKey / event.EffectKey.
]]

return table.freeze({
	Damaged = {
		SFX = nil, -- Populate with sound key, e.g. "SwordHit"
		VFX = nil, -- Populate with VFX name, e.g. "HitSpark"
	},
	Died = {
		SFX = nil, -- e.g. "DeathSound"
		VFX = nil, -- e.g. "DeathSmoke"
	},
	Blocked = {
		SFX = nil, -- e.g. "ShieldBlock"
		VFX = nil, -- e.g. "BlockSpark"
	},
	StatusApplied = {
		SFX = nil,
		VFX = nil,
	},
	Healed = {
		SFX = nil,
		VFX = nil,
	},
	AttackStarted = {
		SFX = nil,
		VFX = nil,
	},
})
