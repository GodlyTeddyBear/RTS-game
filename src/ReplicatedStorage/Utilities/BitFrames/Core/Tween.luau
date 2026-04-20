--!strict
--[[
    =========  TWEEN  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Generic tweening for any property with easing or spring physics.
]]

--[[
    =========  MODULES  =========
]]
local Config = require(script.Parent.Parent.Config)
local Check = require(script.Parent.Parent.Utils.Check)
local Types = require(script.Parent.Types)
local EasingUtils = require(script.Parent.Parent.Utils.Easing)
local AnimationFactory = require(script.Parent.AnimationFactory)
local spr = require(script.Parent.Parent.Dependencies.spr)

local Defaults = Config.Defaults

--[[
    =========  TYPES  =========
]]
type TweenableProperties = { [string]: any }

--[[
    =========  HELPER FUNCTIONS  =========
]]
local function lerpValue(from: any, to: any, alpha: number): any
	local valueType = typeof(from)

	if valueType == "number" then
		return from + (to - from) * alpha
	elseif valueType == "UDim2" then
		return UDim2.new(
			from.X.Scale + (to.X.Scale - from.X.Scale) * alpha,
			from.X.Offset + (to.X.Offset - from.X.Offset) * alpha,
			from.Y.Scale + (to.Y.Scale - from.Y.Scale) * alpha,
			from.Y.Offset + (to.Y.Offset - from.Y.Offset) * alpha
		)
	elseif valueType == "UDim" then
		return UDim.new(
			from.Scale + (to.Scale - from.Scale) * alpha,
			from.Offset + (to.Offset - from.Offset) * alpha
		)
	elseif valueType == "Vector2" then
		return from:Lerp(to, alpha)
	elseif valueType == "Vector3" then
		return from:Lerp(to, alpha)
	elseif valueType == "Color3" then
		return from:Lerp(to, alpha)
	elseif valueType == "CFrame" then
		return from:Lerp(to, alpha)
	elseif valueType == "Rect" then
		return Rect.new(
			from.Min.X + (to.Min.X - from.Min.X) * alpha,
			from.Min.Y + (to.Min.Y - from.Min.Y) * alpha,
			from.Max.X + (to.Max.X - from.Max.X) * alpha,
			from.Max.Y + (to.Max.Y - from.Max.Y) * alpha
		)
	end

	return if alpha >= 0.5 then to else from
end

--[[
    =========  MAIN MODULE  =========
]]
local Tween = {}

function Tween.tween(instance: GuiObject, properties: TweenableProperties, config: Types.TweenConfig?): Types.EffectController
	Check._assertGuiObject(instance, "instance")

	local duration = math.max(config and config.duration or Defaults.DURATION, 0.001)
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local easingName = config and config.easing or Defaults.EASING
	local easingFn = EasingUtils.get(easingName) or EasingUtils.OutQuad

	local startValues: { [string]: any } = {}
	for prop, _ in properties do
		startValues[prop] = (instance :: any)[prop]
	end

	local elapsed = -delay

	local function reset()
		for prop, targetValue in properties do
			if instance and instance.Parent then
				(instance :: any)[prop] = targetValue
			end
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			if not instance or not instance.Parent then return true end

			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			for prop, targetValue in properties do
				(instance :: any)[prop] = lerpValue(startValues[prop], targetValue, eased)
			end

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"tween",
		instance
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Tween.spring(instance: GuiObject, properties: TweenableProperties, config: Types.SpringConfig?): Types.EffectController
	Check._assertGuiObject(instance, "instance")

	local damping = config and config.damping or Defaults.DAMPING
	local frequency = config and config.frequency or Defaults.FREQUENCY
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local cancelled = false

	task.delay(delay, function()
		if cancelled or not instance or not instance.Parent then return end
		spr.target(instance, damping, frequency, properties)
		if onComplete then
			spr.completed(instance, onComplete)
		end
	end)

	return {
		stop = function()
			cancelled = true
			spr.stop(instance)
		end,
		pause = function()
			warn("[BitFrames] pause() is not supported for spring animations")
		end,
		resume = function()
			warn("[BitFrames] resume() is not supported for spring animations")
		end,
	}
end

return table.freeze(Tween)
