--!strict
--[[
	=========  EXIT EFFECTS  =========
	Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

	Pre-made exit animations using centralized Scheduler.
	Supports both time-based (easing) and spring-based animation.
]]

--[[
	=========  MODULES  =========
]]
local Config = require(script.Parent.Parent.Config)
local Check = require(script.Parent.Parent.Utils.Check)
local AnimationFactory = require(script.Parent.Parent.Core.AnimationFactory)
local Helpers = require(script.Parent.Parent.Utils.Helpers)
local Transform = require(script.Parent.Parent.Utils.Transform)
local Types = require(script.Parent.Parent.Core.Types)
local spr = require(script.Parent.Parent.Dependencies.spr)

local assertArg = Check._assertArg
local getEasing = Helpers._getEasing
local isValidElement = Helpers._isValidElement
local getTransparencyProps = Helpers._getTransparencyProps
local setSelectiveTransparency = Helpers._setSelectiveTransparency
local lerpSelectiveTransparency = Helpers._lerpSelectiveTransparency
local Defaults = Config.Defaults

--[[
	=========  TYPES  =========
]]
type ExitConfig = Types.ExitConfig
type EffectController = Types.EffectController

--[[
	=========  HELPER FUNCTIONS  =========
]]
local function buildSprFadeOutTargets(props: {string}): {[string]: number}
	local targets: {[string]: number} = {}
	for _, prop in props do
		targets[prop] = 1
	end
	return targets
end

--[[
	=========  MAIN MODULE  =========
]]
local Exit = {}

function Exit.fadeOut(element: GuiObject, config: ExitConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local props = getTransparencyProps(element, config)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY
		local cancelled = false

		task.delay(delay, function()
			if cancelled or not isValidElement(element) then return end
			spr.target(element, damping, frequency, buildSprFadeOutTargets(props))
			if onComplete then
				spr.completed(element, onComplete)
			end
		end)

		return {
			stop = function()
				cancelled = true
				spr.stop(element)
				Transform._restoreState(element)
			end,
			pause = function()
				warn("[BitFrames] pause() is not supported for spring animations")
			end,
			resume = function()
				warn("[BitFrames] resume() is not supported for spring animations")
			end,
		}
	end

	local duration = config and config.duration or Defaults.DURATION
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = -delay

	local function reset()
		if isValidElement(element) then
			Transform._restoreState(element)
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			lerpSelectiveTransparency(element, originals, easingFn(t), props)

			if t >= 1 then
				setSelectiveTransparency(element, 1, props)
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"fadeOut",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, function() Transform._restoreState(element) end)
end

function Exit.fadeOutUp(element: GuiObject, config: ExitConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local originalPosition = originals.Position
	local offsetY = -(config and config.distance or 20)
	local props = getTransparencyProps(element, config)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY
		local targetPos = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY)

		task.delay(delay, function()
			local targets = buildSprFadeOutTargets(props)
			targets.Position = targetPos :: any
			spr.target(element, damping, frequency, targets)
			if onComplete then
				spr.completed(element, function()
					element.Position = originalPosition
					if onComplete then onComplete() end
				end)
			end
		end)

		return {
			stop = function()
				spr.stop(element)
				Transform._restoreState(element)
			end,
			pause = function() end,
			resume = function() end,
		}
	end

	local duration = config and config.duration or Defaults.DURATION
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = -delay

	local function reset()
		element.Position = originalPosition
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			lerpSelectiveTransparency(element, originals, eased, props)
			element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY * eased)

			if t >= 1 then
				setSelectiveTransparency(element, 1, props)
				element.Position = originalPosition
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"fadeOutUp",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, function() Transform._restoreState(element) end)
end

function Exit.fadeOutDown(element: GuiObject, config: ExitConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local originalPosition = originals.Position
	local offsetY = config and config.distance or 20
	local props = getTransparencyProps(element, config)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY
		local targetPos = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY)

		task.delay(delay, function()
			local targets = buildSprFadeOutTargets(props)
			targets.Position = targetPos :: any
			spr.target(element, damping, frequency, targets)
			if onComplete then
				spr.completed(element, function()
					element.Position = originalPosition
					if onComplete then onComplete() end
				end)
			end
		end)

		return {
			stop = function()
				spr.stop(element)
				Transform._restoreState(element)
			end,
			pause = function() end,
			resume = function() end,
		}
	end

	local duration = config and config.duration or Defaults.DURATION
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = -delay

	local function reset()
		element.Position = originalPosition
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			lerpSelectiveTransparency(element, originals, eased, props)
			element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY * eased)

			if t >= 1 then
				setSelectiveTransparency(element, 1, props)
				element.Position = originalPosition
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"fadeOutDown",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, function() Transform._restoreState(element) end)
end

function Exit.scaleOut(element: GuiObject, config: ExitConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element, true)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local uiScale = Transform._getUIScale(element)
	local originalScale = 1
	local props = getTransparencyProps(element, config)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		task.delay(delay, function()
			spr.target(element, damping, frequency, buildSprFadeOutTargets(props))
			spr.target(uiScale, damping, frequency, { Scale = config and config.targetScale or 0.8 })
			if onComplete then
				spr.completed(element, function()
					Transform._restoreState(element)
					Transform._removeUIScale(element)
					Transform._clearState(element)
					if onComplete then onComplete() end
				end)
			end
		end)

		return {
			stop = function()
				spr.stop(element)
				spr.stop(uiScale)
				Transform._restoreState(element)
				Transform._removeUIScale(element)
				Transform._clearState(element)
			end,
			pause = function() end,
			resume = function() end,
		}
	end

	local duration = config and config.duration or Defaults.DURATION
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = -delay

	local function reset()
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			lerpSelectiveTransparency(element, originals, eased, props)
			local targetScale = config and config.targetScale or 0.8
			uiScale.Scale = originalScale * (1 - (1 - targetScale) * eased)

			if t >= 1 then
				setSelectiveTransparency(element, 1, props)
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"scaleOut",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, function()
		Transform._restoreState(element)
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end)
end

function Exit.shrinkOut(element: GuiObject, config: ExitConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element, true)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local uiScale = Transform._getUIScale(element)
	local originalScale = 1
	local props = getTransparencyProps(element, config)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		task.delay(delay, function()
			spr.target(element, damping, frequency, buildSprFadeOutTargets(props))
			spr.target(uiScale, damping, frequency, { Scale = config and config.targetScale or 0 })
			if onComplete then
				spr.completed(element, function()
					Transform._restoreState(element)
					Transform._removeUIScale(element)
					Transform._clearState(element)
					if onComplete then onComplete() end
				end)
			end
		end)

		return {
			stop = function()
				spr.stop(element)
				spr.stop(uiScale)
				Transform._restoreState(element)
				Transform._removeUIScale(element)
				Transform._clearState(element)
			end,
			pause = function() end,
			resume = function() end,
		}
	end

	local duration = config and config.duration or Defaults.DURATION
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = -delay

	local function reset()
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			lerpSelectiveTransparency(element, originals, eased, props)
			local targetScale = config and config.targetScale or 0
			uiScale.Scale = originalScale * (1 - (1 - targetScale) * eased)

			if t >= 1 then
				setSelectiveTransparency(element, 1, props)
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"shrinkOut",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, function()
		Transform._restoreState(element)
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end)
end

function Exit.zoomOut(element: GuiObject, config: ExitConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element, true)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local uiScale = Transform._getUIScale(element)
	local originalScale = 1
	local props = getTransparencyProps(element, config)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		task.delay(delay, function()
			spr.target(element, damping, frequency, buildSprFadeOutTargets(props))
			spr.target(uiScale, damping, frequency, { Scale = config and config.targetScale or 1.5 })
			if onComplete then
				spr.completed(element, function()
					Transform._restoreState(element)
					Transform._removeUIScale(element)
					Transform._clearState(element)
					if onComplete then onComplete() end
				end)
			end
		end)

		return {
			stop = function()
				spr.stop(element)
				spr.stop(uiScale)
				Transform._restoreState(element)
				Transform._removeUIScale(element)
				Transform._clearState(element)
			end,
			pause = function() end,
			resume = function() end,
		}
	end

	local duration = config and config.duration or Defaults.DURATION
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = -delay

	local function reset()
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			lerpSelectiveTransparency(element, originals, eased, props)
			local targetScale = config and config.targetScale or 1.5
			uiScale.Scale = originalScale * (1 + (targetScale - 1) * eased)

			if t >= 1 then
				setSelectiveTransparency(element, 1, props)
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"zoomOut",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, function()
		Transform._restoreState(element)
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end)
end

return table.freeze(Exit)
