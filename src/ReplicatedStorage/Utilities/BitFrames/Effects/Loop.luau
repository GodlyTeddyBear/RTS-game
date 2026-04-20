--!strict
--[[
    =========  LOOP EFFECTS  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Pre-made continuous/infinite loop animations using centralized Scheduler.
]]

--[[
    =========  MODULES  =========
]]
local Check = require(script.Parent.Parent.Utils.Check)
local AnimationFactory = require(script.Parent.Parent.Core.AnimationFactory)
local Transform = require(script.Parent.Parent.Utils.Transform)
local Helpers = require(script.Parent.Parent.Utils.Helpers)
local Types = require(script.Parent.Parent.Core.Types)

local assertArg = Check._assertArg
local isValidElement = Helpers._isValidElement
local getTransparencyProps = Helpers._getTransparencyProps

--[[
    =========  TYPES  =========
]]
type LoopConfig = Types.LoopConfig
type EffectController = Types.EffectController

type LoopStepFn = (elapsed: number, speed: number, intensity: number) -> number

--[[
    =========  HELPER FUNCTIONS  =========
]]
local function createLoopEffect(
    element: GuiObject,
    getOriginal: (GuiObject) -> any,
    setProperty: (GuiObject, any, number) -> (),
    stepFn: LoopStepFn,
    config: LoopConfig?,
    defaultSpeed: number?,
    defaultIntensity: number?,
    animationType: string?
): EffectController
    local speed = config and config.speed or defaultSpeed or 1
    local intensity = config and config.intensity or defaultIntensity or 1
    

    
    local original = getOriginal(element)
    local elapsed = 0

    local function reset()
        if isValidElement(element) then
            Transform._restoreState(element)
        end
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(element) then return true end
            
            elapsed = elapsed + dt
            local value = stepFn(elapsed, speed, intensity)
            setProperty(element, original, value)
            return false
        end,
        nil,
        reset,
        animationType or "loop",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

--[[
    =========  MAIN MODULE  =========
]]
local Loop = {}

function Loop.spin(element: GuiObject, config: LoopConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    return createLoopEffect(
        element,
        function(_el) return 0 end,
        function(el, _, value) el.Rotation = (Transform._getOriginal(el).Rotation or 0) + value end,
        function(elapsed, speed, _) return (elapsed * speed * 360) % 360 end,
        config, 1, 1, "spin"
    )
end

function Loop.spinReverse(element: GuiObject, config: LoopConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    return createLoopEffect(
        element,
        function(_el) return 0 end,
        function(el, _, value) el.Rotation = (Transform._getOriginal(el).Rotation or 0) + value end,
        function(elapsed, speed, _) return 360 - (elapsed * speed * 360) % 360 end,
        config, 1, 1, "spinReverse"
    )
end

function Loop.float(element: GuiObject, config: LoopConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    local originalPosition = Transform._getOriginal(element).Position
    return createLoopEffect(
        element,
        function(_) return originalPosition end,
        function(el, orig, offset)
            el.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset + offset)
        end,
        function(elapsed, speed, intensity)
            return math.sin(elapsed * speed * math.pi * 2) * intensity
        end,
        config, 0.5, 5, "float"
    )
end

function Loop.breathe(element: GuiObject, config: LoopConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element, true)
    local uiScale = Transform._getUIScale(element)
    local originalScale = uiScale.Scale
    
    return createLoopEffect(
        element,
        function(_) return originalScale end,
        function(_, orig, delta) uiScale.Scale = orig + delta end,
        function(elapsed, speed, intensity)
            return math.sin(elapsed * speed * math.pi * 2) * intensity
        end,
        config, 0.5, 0.05, "breathe"
    )
end

function Loop.glow(element: GuiObject, config: LoopConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)
	local originals = Transform._getOriginal(element)
	local props = getTransparencyProps(element, config)

	local speed = config and config.speed or 0.67
	local intensity = config and config.intensity or 0.3
	local elapsed = 0

	local function reset()
		if isValidElement(element) then
			Transform._restoreState(element)
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			if not isValidElement(element) then return true end

			elapsed = elapsed + dt
			local delta = (math.sin(elapsed * speed * math.pi * 2) + 1) / 2 * intensity
			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = math.clamp(orig + delta, 0, 1)
			end
			return false
		end,
		nil,
		reset,
		"glow",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Loop.swing(element: GuiObject, config: LoopConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    local originalRotation = Transform._getOriginal(element).Rotation
    
    return createLoopEffect(
        element,
        function(_) return originalRotation end,
        function(el, orig, delta) el.Rotation = orig + delta end,
        function(elapsed, speed, intensity)
            return math.sin(elapsed * speed * math.pi * 2) * intensity
        end,
        config, 1, 15, "swing"
    )
end

function Loop.sway(element: GuiObject, config: LoopConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    local originalPosition = Transform._getOriginal(element).Position
    
    return createLoopEffect(
        element,
        function(_) return originalPosition end,
        function(el, orig, offset)
            el.Position = UDim2.new(orig.X.Scale, orig.X.Offset + offset, orig.Y.Scale, orig.Y.Offset)
        end,
        function(elapsed, speed, intensity)
            return math.sin(elapsed * speed * math.pi * 2) * intensity
        end,
        config, 0.5, 10, "sway"
    )
end

function Loop.rainbowGradient(element: GuiObject, config: LoopConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    
    local gradient = element:FindFirstChildOfClass("UIGradient")
    local createdGradient = false
    local originalRotation = 0

    if not gradient then
        gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 100)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 200, 100)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 100)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 255, 100)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(100, 200, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(180, 100, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 200)),
        }
        gradient.Parent = element
        createdGradient = true
    else
        originalRotation = gradient.Rotation
    end
    
    local speed = config and config.speed or 1
    local intensity = config and config.intensity or 45
    local elapsed = 0
    
    local function reset()
        if gradient and gradient.Parent then
            if createdGradient then
                gradient:Destroy()
            else
                gradient.Rotation = originalRotation
            end
        end
    end
    
    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(element) or not gradient or not gradient.Parent then return true end
            
            elapsed = elapsed + dt
            local swing = math.sin(elapsed * speed * math.pi * 2) * intensity
            gradient.Rotation = swing
            return false
        end,
        nil,
        reset,
        "rainbowGradient",
        element
    )
    
    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

return table.freeze(Loop)

