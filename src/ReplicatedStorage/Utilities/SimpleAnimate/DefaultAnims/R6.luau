local Types = require(script.Parent.Parent.Types)
-- DO NOT EDIT THE KEYS (KEYS AS IN IDLE, RUN, WALK, ETC), MAY BREAK SCRIPT
-- ONLY EDIT THE TABLES

-- R6
local Animations: Types.AnimationsList = {
	Idle = {
		{id = "180435571", weight = 5},
		{id = "180435792", weight = 5},
	},
	Run = {
		{id = "180426354", weight = 10, stopFadeTime = 0.2},
	},
	Walk = {
		{id = "180426354", weight = 10}
	},
	GettingUp = {
		{id = "125750702", weight = 10}
	},
	FallingDown = {
		{id = "125750702", weight = 10}
	},
	Jumping = {
		{id = "125750702", weight = 10}
	},
	Freefall = {
		{id = "180436148", weight = 10}
	},
	FellOff = {
		{id = "180436148", weight = 10}
	},
	Landed = {
		{id = "180436148", weight = 10}
	},
	Seated = {
		{id = "178130996", weight = 10}
	},
	Swimming = {
		{id = "180426354", weight = 10}
	},
	SwimIdle = {
		{id = "180426354", weight = 10}
	},
	Climbing = {
		{id = "180436334", weight = 10}
	},
	PlatformStanding = {
		{id = "180435571", weight = 10}
	},
	Dead = {
		{id = "180435571", weight = 10}
	}
}

local Emotes = {
	wave = {
		{id = "128777973", weight = 10, looped = false} 
	},
	point = {
		{id = "128853357", weight = 10, looped = false} 
	},
	dance = {
		{id = "182435998", weight = 10}, 
		{id = "182491037", weight = 10}, 
		{id = "182491065", weight = 10} 
	},
	dance2 = {
		{id = "182436842", weight = 10}, 
		{id = "182491248", weight = 10}, 
		{id = "182491277", weight = 10} 
	},
	dance3 = {
		{id = "182436935", weight = 10}, 
		{id = "182491368", weight = 10}, 
		{id = "182491423", weight = 10} 
	},
	laugh = {
		{id = "129423131", weight = 10, looped = false} 
	},
	cheer = {
		{id = "129423030", weight = 10, looped = false} 
	},
}

return {
	Animations = Animations,
	Emotes = Emotes
}