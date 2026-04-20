local Types = require(script.Parent.Parent.Types)
-- DO NOT EDIT THE KEYS (KEYS AS IN IDLE, RUN, WALK, ETC), MAY BREAK SCRIPT
-- ONLY EDIT THE TABLES

-- R15
local Animations: Types.AnimationsList = {
	Idle = {
		{id = "507766666", weight = 1},
		{id = "507766951", weight = 1},
		{id = "507766388", weight = 9}
	},
	Run = {
		{id = "913376220", weight = 10},
	},
	Walk = {
		{id = "913402848", weight = 10}
	},
	GettingUp = {
		{id = "507766666", weight = 10}
	},
	FallingDown = {
		{id = "507766666", weight = 10}
	},
	Jumping = {
		{id = "507765000", weight = 10, fadeTime = 0.2}
	},
	Freefall = {
		{id = "507767968", weight = 10, fadeTime = 0.1}
	},
	FellOff = {
		{id = "507767968", weight = 10, fadeTime = 0.1}
	},
	Landed = {
		{id = "507766666", weight = 10}
	},
	Seated = {
		{id = "2506281703", weight = 10}
	},
	Swimming = {
		{id = "507784897", weight = 10}
	},
	SwimIdle = {
		{id = "507785072", weight = 10}
	},
	Climbing = {
		{id = "507765644", weight = 10}
	},
	PlatformStanding = {
		{id = "507766666", weight = 10}
	},
	Dead = {
		{id = "507766666", weight = 10}
	}
}

local Emotes = {
	wave = {
		{id = "507770239", weight = 10, looped = false} 
	},
	point = {
		{id = "507770453", weight = 10, looped = false} 
	},
	dance = {
		{id = "507771019", weight = 10}, 
		{id = "507771955", weight = 10}, 
		{id = "507772104", weight = 10} 
	},
	dance2 = {
		{id = "507776043", weight = 10}, 
		{id = "507776720", weight = 10}, 
		{id = "507776879", weight = 10} 
	},
	dance3 = {
		{id = "507777268", weight = 10}, 
		{id = "507777451", weight = 10}, 
		{id = "507777623", weight = 10} 
	},
	laugh = {
		{id = "507770818", weight = 10, looped = false} 
	},
	cheer = {
		{id = "507770677", weight = 10, looped = false} 
	},
}

return {
	Animations = Animations,
	Emotes = Emotes
}