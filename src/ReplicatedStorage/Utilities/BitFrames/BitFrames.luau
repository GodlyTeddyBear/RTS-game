--!strict
--[[
	=========  BITFRAMES  =========
	Made by @RiseBit | Discord: risebit | Github: https://github.com/RiseBit
]]

local RunService = game:GetService("RunService")
if not RunService:IsClient() then
	error("[BitFrames] This library can only be used on the client", 2)
end

--[[
	=========  MODULES  =========
]]
local Config = require(script.Parent.Config)
local Check = require(script.Parent.Utils.Check)
local Entrance = require(script.Parent.Effects.Entrance)
local Exit = require(script.Parent.Effects.Exit)
local Attention = require(script.Parent.Effects.Attention)
local Loop = require(script.Parent.Effects.Loop)
local TextEffect = require(script.Parent.Effects.TextEffect)
local Transition = require(script.Parent.Effects.Transition)
local Interaction = require(script.Parent.Effects.Interaction)
local UIEvent = require(script.Parent.UIHelper.UIEvent)

local Types = require(script.Parent.Core.Types)
local Chain = require(script.Parent.Core.Chain)
local Tween = require(script.Parent.Core.Tween)
local Fusion = require(script.Parent.Dependencies.fusion)
local Shime = require(script.Parent.Dependencies.Shime)
local ezVisuals = require(script.Parent.Dependencies.ezvisualz)

--[[
	=========  TYPES  =========
]]
type EffectController = Types.EffectController

--[[
	=========  CONSTANTS  =========
]]
local DURATIONS = { default = 0.3, attention = 0.5, loop = 1 }

local EFFECT_GROUPS = {
	{ module = Entrance, effects = {"fadeIn", "fadeInUp", "fadeInDown", "scaleIn", "scaleInBounce", "zoomIn", "dropIn"}, duration = DURATIONS.default },
	{ module = Exit, effects = {"fadeOut", "fadeOutUp", "fadeOutDown", "scaleOut", "shrinkOut", "zoomOut"}, duration = DURATIONS.default },
	{ module = Attention, effects = {"pulse", "shake", "bounce", "wiggle", "flash", "heartbeat", "jello", "confetti"}, duration = DURATIONS.attention, usesLoops = true },
	{ module = Loop, effects = {"spin", "spinReverse", "float", "breathe", "glow", "swing", "sway"}, duration = DURATIONS.loop },
}

local TEXT_SPECIAL = {
	typewriter = { default = 1, getDuration = function(arg: string, cfg: any) return #arg * (cfg and cfg.speed or 0.05) end },
	scramble = { default = 1 },
	rollValue = { default = 1 },
	fadeColor = { default = DURATIONS.default },
}

--[[
	=========  CHAIN REGISTRATION  =========
]]
for name, info in TEXT_SPECIAL do
	(Chain :: any)[name] = function(self: Chain.ChainClassImpl, arg: any, config: any)
		local duration = info.getDuration and info.getDuration(arg, config) or (config and config.duration or info.default)
		return self:_addEffect(function() return TextEffect[name](self._instance :: any, arg, config) end, duration)
	end
end

for _, group in EFFECT_GROUPS do
	for _, effectName in group.effects do
		(Chain :: any)[effectName] = function(self: Chain.ChainClassImpl, config: any)
			local duration = config and config.duration or group.duration
			if group.usesLoops and config and config.loops then duration *= config.loops end
			return self:_addEffect(function() return group.module[effectName](self._instance, config) end, duration)
		end
	end
end

for _, effectName in {"colorCycle", "colorPulse", "glitch"} do
	(Chain :: any)[effectName] = function(self: Chain.ChainClassImpl, config: any)
		return self:_addEffect(function() return TextEffect[effectName](self._instance :: any, config) end, DURATIONS.loop)
	end
end

--[[
	=========  MODULE WRAPPER  =========
]]
local function wrapModule<T>(module: T, isTextModule: boolean?): T
	local isValid = if isTextModule 
		then function(v: any) return typeof(v) == "Instance" and (v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox")) end
		else function(v: any) return typeof(v) == "Instance" and v:IsA("GuiObject") end

	return setmetatable({}, {
		__index = function(_, effectName: string)
			local fn = (module :: any)[effectName]
			if type(fn) ~= "function" then return fn end

			return function(input: any, ...)
				if typeof(input) == "table" then
					local controllers: { EffectController } = {}
					for _, item in input do
						if isValid(item) then table.insert(controllers, fn(item, ...)) end
					end
					return { stop = function() for _, c in controllers do if c.stop then c.stop() end end end }
				elseif isValid(input) then
					return fn(input, ...)
				else
					error(`[BitFrames] {effectName}: Invalid input type`, 2)
				end
			end
		end
	}) :: T
end

--[[
	=========  MAIN MODULE  =========
]]
local BitFrames = {
	Easing = Config.Easing,
	SpringPresets = Config.Spring,
	Entrance = wrapModule(Entrance, false),
	Exit = wrapModule(Exit, false),
	Attention = wrapModule(Attention, false),
	Loop = wrapModule(Loop, false),
	TextEffect = wrapModule(TextEffect, true),
	Transition = wrapModule(Transition, false),
	Interaction = wrapModule(Interaction, false),
	Tween = Tween,
	EzVisuals = ezVisuals,
	Shime = Shime,
	Fusion = Fusion,
	UIEvent = UIEvent,
}

function BitFrames.new(instance: GuiObject)
	Check._assertGuiObject(instance, "instance")
	return Chain._new(instance) :: any
end

return BitFrames