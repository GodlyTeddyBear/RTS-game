--!strict

--[[
    ExecutorTypes - Type definitions for the executor system.

    Executors are server-side combat behaviors (MeleeAttack, Chase, Idle, etc.)
    selected by behavior trees and executed by ProcessCombatTick.
]]

-- Mirrors jecs.Entity<nil> — entities are nominal number wrappers at runtime.
export type Entity = { __T: nil }

export type TExecutorConfig = {
	ActionId: string,
	IsCommitted: boolean,
	Duration: number?,
	IsInterruptible: boolean?, -- If false (default), TakingDamage will not cancel this action's animation
}

export type TActionServices = {
	NPCEntityFactory: any,
	DamageCalculator: any,
	HitboxService: any,
	World: any,
	Components: any,
	CurrentTime: number,
	EventBuffer: { any },
	DungeonContext: any?,
	UserId: number?,
}

export type IExecutor = {
	Config: TExecutorConfig,
	Start: (self: IExecutor, entity: Entity, actionData: { [string]: any }?, services: TActionServices) -> (boolean, string?),
	Tick: (self: IExecutor, entity: Entity, deltaTime: number, services: TActionServices) -> string,
	Cancel: (self: IExecutor, entity: Entity, services: TActionServices) -> (),
	Complete: (self: IExecutor, entity: Entity, services: TActionServices) -> (),
}

return {}
