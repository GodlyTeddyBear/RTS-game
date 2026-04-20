--!strict
--[[
	=========  ENTRANCE EFFECTS  =========
	Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

	Pre-made entrance animations using centralized Scheduler.
	Supports both time-based (easing) and spring-based animation.
]]

--[[
	=========  MODULES  =========
]]
local Config = require(script.Parent.Parent.Config)
local Check = require(script.Parent.Parent.Utils.Check)
local AnimationFactory = require(script.Parent.Parent.Core.AnimationFactory)
local Easing = require(script.Parent.Parent.Utils.Easing)
local Helpers = require(script.Parent.Parent.Utils.Helpers)
local Transform = require(script.Parent.Parent.Utils.Transform)
local Types = require(script.Parent.Parent.Core.Types)
local spr = require(script.Parent.Parent.Dependencies.spr)

local assertArg = Check._assertArg
local getEasing = Helpers._getEasing
local isValidElement = Helpers._isValidElement
local getTransparencyProps = Helpers._getTransparencyProps
local setSelectiveTransparency = Helpers._setSelectiveTransparency
local Defaults = Config.Defaults

--[[
	=========  TYPES  =========
]]
type EntranceConfig = Types.EntranceConfig
type EffectController = Types.EffectController

--[[
	=========  HELPER FUNCTIONS  =========
]]
local function buildSprTargets(element: GuiObject, originals: {[string]: any}, props: {string}): {[string]: number}
	local targets: {[string]: number} = {}
	for _, prop in props do
		targets[prop] = originals[prop] or 0
	end
	return targets
end

--[[
	=========  MAIN MODULE  =========
]]
local Entrance = {}

function Entrance.fadeIn(element: GuiObject, config: EntranceConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local props = getTransparencyProps(element, config)

	setSelectiveTransparency(element, 1, props)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY
		local cancelled = false

		task.delay(delay, function()
			if cancelled or not isValidElement(element) then return end
			spr.target(element, damping, frequency, buildSprTargets(element, originals, props))
			if onComplete then
				spr.completed(element, onComplete)
			end
		end)

		return {
			stop = function()
				cancelled = true
				spr.stop(element)
				if isValidElement(element) then
					Transform._restoreState(element)
				end
			end,
			pause = function()
				warn("[BitFrames] pause() is not supported for spring animations")
			end,
			resume = function()
				warn("[BitFrames] resume() is not supported for spring animations")
			end,
		}
	end

	local duration = math.max(config and config.duration or Defaults.DURATION, 0.001)
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = -delay

	local function reset()
		if isValidElement(element) then
			Transform._restoreState(element)
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			if not isValidElement(element) then return true end

			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = 1 - (1 - orig) * eased
			end

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"fadeIn",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Entrance.fadeInUp(element: GuiObject, config: EntranceConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local originalPosition = originals.Position
	local offsetY = config and config.distance or 20
	local props = getTransparencyProps(element, config)

	setSelectiveTransparency(element, 1, props)
	element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		task.delay(delay, function()
			local targets = buildSprTargets(element, originals, props)
			targets.Position = originalPosition :: any
			spr.target(element, damping, frequency, targets)
			if onComplete then
				spr.completed(element, onComplete)
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
		Transform._restoreState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = 1 - (1 - orig) * eased
			end
			element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY * (1 - eased))

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"fadeInUp",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Entrance.fadeInDown(element: GuiObject, config: EntranceConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local originalPosition = originals.Position
	local offsetY = -(config and config.distance or 20)
	local props = getTransparencyProps(element, config)

	setSelectiveTransparency(element, 1, props)
	element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY)

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		task.delay(delay, function()
			local targets = buildSprTargets(element, originals, props)
			targets.Position = originalPosition :: any
			spr.target(element, damping, frequency, targets)
			if onComplete then
				spr.completed(element, onComplete)
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
		Transform._restoreState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = 1 - (1 - orig) * eased
			end
			element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY * (1 - eased))

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"fadeInDown",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Entrance.scaleIn(element: GuiObject, config: EntranceConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element, true)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local uiScale = Transform._getUIScale(element)
	local originalScale = uiScale.Scale
	local initialScale = config and config.initialScale or 0.8
	local props = getTransparencyProps(element, config)

	setSelectiveTransparency(element, 1, props)
	uiScale.Scale = originalScale * initialScale

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		task.delay(delay, function()
			spr.target(element, damping, frequency, buildSprTargets(element, originals, props))
			spr.target(uiScale, damping, frequency, { Scale = originalScale })
			if onComplete then
				spr.completed(element, onComplete)
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
		Transform._restoreState(element)
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = 1 - (1 - orig) * eased
			end
			uiScale.Scale = originalScale * (initialScale + (1 - initialScale) * eased)

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"scaleIn",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Entrance.scaleInBounce(element: GuiObject, config: EntranceConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element, true)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local uiScale = Transform._getUIScale(element)
	local originalScale = uiScale.Scale
	local initialScale = config and config.initialScale or 0.5
	local props = getTransparencyProps(element, config)

	setSelectiveTransparency(element, 1, props)
	uiScale.Scale = originalScale * initialScale

	if useSpring then
		local damping = config and config.damping or 0.6
		local frequency = config and config.frequency or 4

		task.delay(delay, function()
			spr.target(element, damping, frequency, buildSprTargets(element, originals, props))
			spr.target(uiScale, damping, frequency, { Scale = originalScale })
			if onComplete then
				spr.completed(element, onComplete)
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

	local duration = config and config.duration or 0.5
	local easingFn = Easing.OutBack
	local elapsed = -delay

	local function reset()
		Transform._restoreState(element)
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)

			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = 1 - (1 - orig) * t
			end
			uiScale.Scale = originalScale * (initialScale + (1 - initialScale) * easingFn(t))

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"scaleInBounce",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Entrance.zoomIn(element: GuiObject, config: EntranceConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element, true)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local uiScale = Transform._getUIScale(element)
	local originalScale = uiScale.Scale
	local initialScale = config and config.initialScale or 0
	local props = getTransparencyProps(element, config)

	setSelectiveTransparency(element, 1, props)
	uiScale.Scale = originalScale * initialScale

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		task.delay(delay, function()
			spr.target(element, damping, frequency, buildSprTargets(element, originals, props))
			spr.target(uiScale, damping, frequency, { Scale = originalScale })
			if onComplete then
				spr.completed(element, onComplete)
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
		Transform._restoreState(element)
		Transform._removeUIScale(element)
		Transform._clearState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = 1 - (1 - orig) * eased
			end
			uiScale.Scale = originalScale * (initialScale + (1 - initialScale) * eased)

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"zoomIn",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Entrance.dropIn(element: GuiObject, config: EntranceConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)

	local useSpring = config and config.spring
	local delay = config and config.delay or 0
	local onComplete = config and config.onComplete
	local originals = Transform._getOriginal(element)
	local originalPosition = originals.Position
	local offsetY = -(config and config.distance or 100)
	local props = getTransparencyProps(element, config)

	setSelectiveTransparency(element, 1, props)
	element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY)

	if useSpring then
		local damping = config and config.damping or 0.5
		local frequency = config and config.frequency or 3

		task.delay(delay, function()
			local targets = buildSprTargets(element, originals, props)
			targets.Position = originalPosition :: any
			spr.target(element, damping, frequency, targets)
			if onComplete then
				spr.completed(element, onComplete)
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

	local duration = config and config.duration or 0.5
	local easingFn = Easing.OutBounce
	local elapsed = -delay

	local function reset()
		Transform._restoreState(element)
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			if elapsed < 0 then return false end

			local t = math.clamp(elapsed / duration, 0, 1)

			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = 1 - (1 - orig) * t
			end
			element.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + offsetY * (1 - easingFn(t)))

			if t >= 1 then
				reset()
				return true
			end
			return false
		end,
		onComplete,
		reset,
		"dropIn",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

return table.freeze(Entrance)
