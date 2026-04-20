--!strict
--[[
    =========  TRANSITION EFFECTS  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Pre-made transition animations between UI states using centralized Scheduler.
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
type TransitionConfig = Types.TransitionConfig
type EffectController = Types.EffectController
type SlideDirection = Types.SlideDirection

local VALID_DIRECTIONS: {[string]: boolean} = {
    left = true,
    right = true,
    up = true,
    down = true,
}

--[[
    =========  MAIN MODULE  =========
]]
local Transition = {}

function Transition.crossfade(fromElement: GuiObject, toElement: GuiObject, config: TransitionConfig?): EffectController
	assertArg(fromElement, "fromElement", "Instance")
	assertArg(toElement, "toElement", "Instance")
	Transform._prepareAnimation(fromElement)
	Transform._prepareAnimation(toElement)

	local useSpring = config and config.spring
	local onComplete = config and config.onComplete
	local fromOriginals = Transform._getOriginal(fromElement)
	local toOriginals = Transform._getOriginal(toElement)
	local fromProps = getTransparencyProps(fromElement, config)
	local toProps = getTransparencyProps(toElement, config)

	setSelectiveTransparency(toElement, 1, toProps)
	toElement.Visible = true

	local function reset()
		if isValidElement(fromElement) then Transform._restoreState(fromElement) end
		if isValidElement(toElement) then Transform._restoreState(toElement) end
	end

	if useSpring then
		local damping = config and config.damping or Defaults.DAMPING
		local frequency = config and config.frequency or Defaults.FREQUENCY

		local fromTargets: {[string]: number} = {}
		for _, prop in fromProps do
			fromTargets[prop] = 1
		end
		spr.target(fromElement, damping, frequency, fromTargets)

		local toTargets: {[string]: number} = {}
		for _, prop in toProps do
			toTargets[prop] = toOriginals[prop] or 0
		end
		spr.target(toElement, damping, frequency, toTargets)

		spr.completed(fromElement, function()
			fromElement.Visible = false
			if onComplete then onComplete() end
		end)

		return {
			stop = function()
				spr.stop(fromElement)
				spr.stop(toElement)
				reset()
			end,
			pause = function() end,
			resume = function() end,
		}
	end

	local duration = config and config.duration or Defaults.DURATION
	local easingFn = getEasing(config and config.easing or Defaults.EASING)
	local elapsed = 0

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			local t = math.clamp(elapsed / duration, 0, 1)
			local eased = easingFn(t)

			lerpSelectiveTransparency(fromElement, fromOriginals, eased, fromProps)
			for _, prop in toProps do
				local orig = toOriginals[prop] or 0
				(toElement :: any)[prop] = 1 - (1 - orig) * eased
			end

			if t >= 1 then
				setSelectiveTransparency(fromElement, 1, fromProps)
				for _, prop in toProps do
					(toElement :: any)[prop] = toOriginals[prop] or 0
				end
				fromElement.Visible = false
				return true
			end
			return false
		end,
		onComplete,
		nil,
		"crossfade",
		toElement
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Transition.slideReplace(fromElement: GuiObject, toElement: GuiObject, direction: SlideDirection?, config: TransitionConfig?): EffectController
    assertArg(fromElement, "fromElement", "Instance")
    assertArg(toElement, "toElement", "Instance")
    Transform._prepareAnimation(fromElement)
    Transform._prepareAnimation(toElement)

    local dir = direction or "left"
    if not VALID_DIRECTIONS[dir] then
        warn(`[BitFrames] Invalid direction '{dir}', using default 'left'`)
        dir = "left"
    end
    local useSpring = config and config.spring
    local onComplete = config and config.onComplete

    local fromOriginal = Transform._getOriginal(fromElement).Position
    local toOriginal = Transform._getOriginal(toElement).Position

    local dist = config and config.distance or 50
    local offsetX, offsetY = 0, 0
    if dir == "left" then offsetX = -dist
    elseif dir == "right" then offsetX = dist
    elseif dir == "up" then offsetY = -dist
    elseif dir == "down" then offsetY = dist
    end
    
    
    toElement.Position = UDim2.new(toOriginal.X.Scale, toOriginal.X.Offset - offsetX, toOriginal.Y.Scale, toOriginal.Y.Offset - offsetY)
    toElement.Visible = true

    local function reset()
        if isValidElement(fromElement) then Transform._restoreState(fromElement) end
        if isValidElement(toElement) then Transform._restoreState(toElement) end
    end

    if useSpring then
        local damping = config and config.damping or Defaults.DAMPING
        local frequency = config and config.frequency or Defaults.FREQUENCY
        local fromTarget = UDim2.new(fromOriginal.X.Scale, fromOriginal.X.Offset + offsetX, fromOriginal.Y.Scale, fromOriginal.Y.Offset + offsetY)

        spr.target(fromElement, damping, frequency, { Position = fromTarget })
        spr.target(toElement, damping, frequency, { Position = toOriginal })

        spr.completed(toElement, function()
            fromElement.Visible = false
            fromElement.Position = fromOriginal
            if onComplete then onComplete() end
        end)

        return {
            stop = function()
                spr.stop(fromElement)
                spr.stop(toElement)
                reset()
            end,
            pause = function() end,
            resume = function() end,
        }
    end

    local duration = config and config.duration or Defaults.DURATION
    local easingFn = getEasing(config and config.easing or Defaults.EASING)
    local elapsed = 0

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            elapsed = elapsed + dt
            local t = math.clamp(elapsed / duration, 0, 1)
            local eased = easingFn(t)

            fromElement.Position = UDim2.new(fromOriginal.X.Scale, fromOriginal.X.Offset + offsetX * eased, fromOriginal.Y.Scale, fromOriginal.Y.Offset + offsetY * eased)
            toElement.Position = UDim2.new(toOriginal.X.Scale, toOriginal.X.Offset - offsetX * (1 - eased), toOriginal.Y.Scale, toOriginal.Y.Offset - offsetY * (1 - eased))

            if t >= 1 then
                fromElement.Visible = false
                fromElement.Position = fromOriginal
                toElement.Position = toOriginal
                return true
            end
            return false
        end,
        onComplete,
        nil,
        "slideReplace",
        toElement
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

return table.freeze(Transition)
