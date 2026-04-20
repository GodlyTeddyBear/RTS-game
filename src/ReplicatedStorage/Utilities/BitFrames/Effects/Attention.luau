--!strict
--[[
    =========  ATTENTION EFFECTS  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Pre-made attention animations using centralized Scheduler.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

--[[
    =========  MODULES  =========
]]
local Config = require(script.Parent.Parent.Config)
local Check = require(script.Parent.Parent.Utils.Check)
local AnimationFactory = require(script.Parent.Parent.Core.AnimationFactory)
local Transform = require(script.Parent.Parent.Utils.Transform)
local Helpers = require(script.Parent.Parent.Utils.Helpers)
local Types = require(script.Parent.Parent.Core.Types)

local assertArg = Check._assertArg
local isValidElement = Helpers._isValidElement
local getTransparencyProps = Helpers._getTransparencyProps
local AttentionDefaults = Config.AttentionDefaults

--[[
    =========  TYPES  =========
]]
type AttentionConfig = Types.AttentionConfig
type EffectController = Types.EffectController

type AttentionStepFn = (t: number, intensity: number) -> number



--[[
    =========  HELPER FUNCTIONS  =========
]]
local function createAttentionEffect(
    element: GuiObject,
    getOriginal: (GuiObject) -> any,
    setProperty: (GuiObject, any, number) -> (),
    stepFn: AttentionStepFn,
    config: AttentionConfig?,
    defaultDuration: number?,
    defaultLoops: number?,
    defaultIntensity: number?
): EffectController
    local duration = math.max(config and config.duration or defaultDuration or AttentionDefaults.DURATION, 0.001)
    local loops = config and config.loops or defaultLoops or AttentionDefaults.LOOPS
    local intensity = config and config.intensity or defaultIntensity or 0.1
    local onComplete = config and config.onComplete

    local original = getOriginal(element)
    local elapsed = 0
    local currentLoop = 0

    local function reset()
        if isValidElement(element) then
            setProperty(element, original, 0)
            Transform._restoreState(element)
            Transform._removeUIScale(element)
            Transform._clearState(element)
        end
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(element) then return true end
            
            elapsed = elapsed + dt
            local t = elapsed / duration

            if t >= 1 then
                currentLoop = currentLoop + 1
                elapsed = elapsed - duration
                t = elapsed / duration
                if loops > 0 and currentLoop >= loops then
                    reset()
                    return true
                end
            end

            local value = stepFn(t, intensity)
            setProperty(element, original, value)
            return false
        end,
        onComplete,
        reset,
        "attention",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

--[[
    =========  MAIN MODULE  =========
]]
local Attention = {}

function Attention.pulse(element: GuiObject, config: AttentionConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element, true)
    local uiScale = Transform._getUIScale(element)
    local originalScale = uiScale.Scale 
    
    return createAttentionEffect(
        element,
        function(_) return originalScale end,
        function(_, orig, delta) uiScale.Scale = orig + delta end,
        function(t, intensity) return intensity * math.sin(t * math.pi * 2) end,
        config, 0.4, 1, 0.1
    )
end

function Attention.shake(element: GuiObject, config: AttentionConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    local originalRotation = Transform._getOriginal(element).Rotation
    
    return createAttentionEffect(
        element,
        function(_) return originalRotation end,
        function(el, orig, delta) el.Rotation = orig + delta end,
        function(_, intensity) return intensity * (math.random() * 2 - 1) end,
        config, 0.1, 3, 5
    )
end

function Attention.bounce(element: GuiObject, config: AttentionConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    local originalPosition = Transform._getOriginal(element).Position
    
    return createAttentionEffect(
        element,
        function(_) return originalPosition end,
        function(el, orig, offsetY)
            el.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset + offsetY)
        end,
        function(t, intensity) return -intensity * math.abs(math.sin(t * math.pi)) end,
        config, 0.3, 1, 10
    )
end

function Attention.wiggle(element: GuiObject, config: AttentionConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element)
    local originalRotation = Transform._getOriginal(element).Rotation
    
    return createAttentionEffect(
        element,
        function(_) return originalRotation end,
        function(el, orig, delta) el.Rotation = orig + delta end,
        function(t, intensity) return intensity * math.sin(t * math.pi * 4) end,
        config, 0.15, 2, 10
    )
end

function Attention.flash(element: GuiObject, config: AttentionConfig?): EffectController
	assertArg(element, "element", "Instance")
	Transform._prepareAnimation(element)
	local originals = Transform._getOriginal(element)
	local props = getTransparencyProps(element, config)

	local duration = math.max(config and config.duration or 0.2, 0.001)
	local loops = config and config.loops or 2
	local intensity = config and config.intensity or 0.5
	local onComplete = config and config.onComplete

	local elapsed = 0
	local currentLoop = 0

	local function reset()
		if isValidElement(element) then
			for _, prop in props do
				(element :: any)[prop] = originals[prop] or 0
			end
			Transform._restoreState(element)
			Transform._clearState(element)
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			if not isValidElement(element) then return true end

			elapsed = elapsed + dt
			local t = elapsed / duration

			if t >= 1 then
				currentLoop = currentLoop + 1
				elapsed = elapsed - duration
				t = elapsed / duration
				if loops > 0 and currentLoop >= loops then
					reset()
					return true
				end
			end

			local delta = intensity * math.abs(math.sin(t * math.pi))
			for _, prop in props do
				local orig = originals[prop] or 0
				(element :: any)[prop] = math.clamp(orig + delta, 0, 1)
			end
			return false
		end,
		onComplete,
		reset,
		"attention",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, reset)
end

function Attention.heartbeat(element: GuiObject, config: AttentionConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element, true)
    local uiScale = Transform._getUIScale(element)
    local originalScale = uiScale.Scale
    
    return createAttentionEffect(
        element,
        function(_) return originalScale end,
        function(_, orig, delta) uiScale.Scale = orig + delta end,
        function(t, intensity)
            if t < 0.14 then
                return intensity * (t / 0.14)
            elseif t < 0.28 then
                return intensity * (1 - (t - 0.14) / 0.14 * 0.5)
            elseif t < 0.42 then
                return intensity * 0.5 + intensity * 0.5 * ((t - 0.28) / 0.14)
            elseif t < 0.7 then
                return intensity * (1 - (t - 0.42) / 0.28)
            else
                return 0
            end
        end,
        config, 0.6, 1, 0.15
    )
end

function Attention.jello(element: GuiObject, config: AttentionConfig?): EffectController
    assertArg(element, "element", "Instance")
    Transform._prepareAnimation(element, true)
    local uiScale = Transform._getUIScale(element)
    local originalScale = uiScale.Scale
    
    return createAttentionEffect(
        element,
        function(_) return originalScale end,
        function(_, orig, delta) uiScale.Scale = orig + delta end,
        function(t, intensity)
            local decay = math.exp(-t * 4)
            return math.sin(t * math.pi * 6) * decay * intensity
        end,
        config, 0.5, 1, 0.1
    )
end

function Attention.confetti(element: GuiObject?, config: any): EffectController
	local cfg = config or {}
	local count = cfg.count or 50
	local duration = cfg.duration or 2
	local colors = cfg.colors or {
		Color3.fromRGB(255, 107, 107), -- Red
		Color3.fromRGB(255, 193, 7),   -- Yellow
		Color3.fromRGB(76, 175, 80),   -- Green
		Color3.fromRGB(33, 150, 243),  -- Blue
		Color3.fromRGB(156, 39, 176),  -- Purple
		Color3.fromRGB(255, 152, 0),   -- Orange
		Color3.fromRGB(0, 188, 212),   -- Cyan
		Color3.fromRGB(233, 30, 99),   -- Pink
	}
	local screenWide = if cfg.screenWide ~= nil then cfg.screenWide else true
	
	local container: GuiObject
	local shouldCleanupContainer = false
	
	if screenWide then
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return { stop = function() end, pause = function() end, resume = function() end }
		end
		
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ConfettiEffect"
		screenGui.DisplayOrder = 100
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = playerGui
		
		container = Instance.new("Frame")
		container.Name = "ConfettiContainer"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundTransparency = 1
		container.Parent = screenGui
		shouldCleanupContainer = true
	else
		-- If not screenWide, require element or parent
		local parent = cfg.parent or element
		if not parent then
			warn("[BitFrames] Attention.confetti: Element or Parent required for non-screenwide effect")
			return { stop = function() end, pause = function() end, resume = function() end }
		end
		
		container = Instance.new("Frame")
		container.Name = "ConfettiContainer"
		container.Size = UDim2.fromScale(1, 1)
		container.BackgroundTransparency = 1
		container.Parent = parent
		shouldCleanupContainer = true
	end
	
	local confettiPieces: { Frame } = {}
	local stopped = false
	
	for i = 1, count do
		local piece = Instance.new("Frame")
		piece.Name = "Confetti_" .. i
		piece.Size = UDim2.fromOffset(math.random(8, 16), math.random(4, 8))
		piece.BackgroundColor3 = colors[math.random(1, #colors)]
		piece.BorderSizePixel = 0
		piece.Rotation = math.random(0, 360)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		
		local startX = math.random(0, 100) / 100
		piece.Position = UDim2.fromScale(startX, -0.1)
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = piece
		
		piece.Parent = container
		table.insert(confettiPieces, piece)
		
		local endX = startX + (math.random(-20, 20) / 100)
		local fallDuration = duration * (0.8 + math.random() * 0.4)
		local rotationAmount = math.random(-720, 720)
		
		local tweenInfo = TweenInfo.new(fallDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tween = TweenService:Create(piece, tweenInfo, {
			Position = UDim2.fromScale(endX, 1.2),
			Rotation = piece.Rotation + rotationAmount,
			BackgroundTransparency = 0.5,
		})
		
		task.delay(math.random() * 0.3, function()
			if not stopped then
				tween:Play()
			end
		end)
	end
	
	task.delay(duration + 0.5, function()
		if shouldCleanupContainer and container and container.Parent then
			local screenGui = container.Parent
			container:Destroy()
			if screenGui:IsA("ScreenGui") and screenGui.Name == "ConfettiEffect" then
				screenGui:Destroy()
			end
		end
	end)
	
	return {
		stop = function()
			stopped = true
			if shouldCleanupContainer and container and container.Parent then
				local screenGui = container.Parent
				container:Destroy()
				if screenGui:IsA("ScreenGui") and screenGui.Name == "ConfettiEffect" then
					screenGui:Destroy()
				end
			end
		end,
		pause = function() end, -- Interface conformity
		resume = function() end, -- Interface conformity
	}
end

return table.freeze(Attention)
