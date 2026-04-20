local utility = script.Parent.Utility

local Signal = require(utility.SimpleSignal)

export type AnimInfo = {
	id: string,
	weight: number,
	anim: AnimationTrack?,
	fadeTime: number?,
	stopFadeTime: number?,
	speed: number?,
}

export type AnimationsList = {
	[string]: { AnimInfo },
}

export type PoseType =
	"Run"
	| "Idle"
	| "Walk"
	| "GettingUp"
	| "FallingDown"
	| "Freefall"
	| "FellOff"
	| "Jumping"
	| "Landed"
	| "Seated"
	| "Swimming"
	| "Climbing"
	| "SwimIdle"

export type StateMachine = {
	Running: Signal.RBXScriptSignal<number>,
	Climbing: Signal.RBXScriptSignal<number>,
	Swimming: Signal.RBXScriptSignal<number>,
	StateChanged: Signal.RBXScriptSignal<Enum.HumanoidStateType, Enum.HumanoidStateType>,
	Jumping: Signal.RBXScriptSignal,
	WalkSpeed: number,
}

return nil
