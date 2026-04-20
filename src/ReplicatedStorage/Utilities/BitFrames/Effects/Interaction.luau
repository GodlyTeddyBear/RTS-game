--!strict
--[[
	=========  INTERACTION EFFECTS  =========
	Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

	Interactive feedback effects for click/tap, hover, and press.
	These are typically triggered by user input events.
]]

--[[
	=========  SERVICES  =========
]]
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

--[[
	=========  MODULES  =========
]]
local Check = require(script.Parent.Parent.Utils.Check)
local AnimationFactory = require(script.Parent.Parent.Core.AnimationFactory)
local Types = require(script.Parent.Parent.Core.Types)

local assertArg = Check._assertArg

--[[
	=========  TYPES  =========
]]
type RippleConfig = Types.RippleConfig
type PressConfig = Types.PressConfig
type HighlightConfig = Types.HighlightConfig
type EffectController = Types.EffectController

--[[
	=========  CONSTANTS  =========
]]
local DEFAULT_RIPPLE_DURATION = 0.5
local DEFAULT_RIPPLE_COLOR = Color3.new(1, 1, 1)
local DEFAULT_RIPPLE_TRANSPARENCY = 0.6
local DEFAULT_RIPPLE_MAX_SIZE = 2
local DEFAULT_PRESS_DURATION = 0.35
local DEFAULT_PRESS_SIZE = 60
local DEFAULT_PRESS_COLOR = Color3.new(1, 1, 1)
local DEFAULT_PRESS_TRANSPARENCY = 0.5
local DEFAULT_HIGHLIGHT_DURATION = 0.2

--[[
	=========  HELPER FUNCTIONS  =========
]]
local function cloneCorner(element: GuiObject, parent: GuiObject)
	local corner = element:FindFirstChildOfClass("UICorner")
	if corner then
		local cloned = corner:Clone()
		cloned.Parent = parent
	end
end

--[[
	=========  MAIN MODULE  =========
]]
local Interaction = {}

function Interaction.ripple(element: GuiObject, position: Vector2?, config: RippleConfig?): EffectController
	assertArg(element, "element", "Instance")

	local duration = config and config.duration or DEFAULT_RIPPLE_DURATION
	local color = config and config.color or DEFAULT_RIPPLE_COLOR
	local transparency = config and config.transparency or DEFAULT_RIPPLE_TRANSPARENCY
	local maxSize = config and config.maxSize or DEFAULT_RIPPLE_MAX_SIZE
	local onComplete = config and config.onComplete

	local absPos = element.AbsolutePosition
	local absSize = element.AbsoluteSize

	if absSize.X <= 0 or absSize.Y <= 0 then
		return {
			stop = function() end,
			pause = function() end,
			resume = function() end,
		}
	end

	local clickPos: Vector2
	if position and position.X and position.Y then
		local guiInset = GuiService:GetGuiInset()
		clickPos = Vector2.new(position.X, position.Y - (guiInset.Y or 0))
	else
		clickPos = Vector2.new(absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2)
	end

	local relativeX = math.clamp((clickPos.X - absPos.X) / absSize.X, 0, 1)
	local relativeY = math.clamp((clickPos.Y - absPos.Y) / absSize.Y, 0, 1)

	local rippleContainer = Instance.new("Frame")
	rippleContainer.Name = "_BitFramesRipple"
	rippleContainer.Size = UDim2.new(1, 0, 1, 0)
	rippleContainer.BackgroundTransparency = 1
	rippleContainer.ClipsDescendants = true
	rippleContainer.ZIndex = element.ZIndex + 1
	rippleContainer.Parent = element

	cloneCorner(element, rippleContainer)

	local maxDimension = math.max(absSize.X, absSize.Y) * maxSize
	local ripple = Instance.new("Frame")
	ripple.Name = "Ripple"
	ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	ripple.Position = UDim2.new(relativeX, 0, relativeY, 0)
	ripple.Size = UDim2.new(0, 0, 0, 0)
	ripple.BackgroundColor3 = color
	ripple.BackgroundTransparency = transparency
	ripple.BorderSizePixel = 0
	ripple.Parent = rippleContainer

	local rippleUICorner = Instance.new("UICorner")
	rippleUICorner.CornerRadius = UDim.new(1, 0)
	rippleUICorner.Parent = ripple

	local elapsed = 0

	local function cleanup()
		if rippleContainer and rippleContainer.Parent then
			rippleContainer:Destroy()
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			if not rippleContainer or not rippleContainer.Parent then
				return true
			end
			
			elapsed = elapsed + dt
			local t = math.clamp(elapsed / duration, 0, 1)

			local size = maxDimension * t
			ripple.Size = UDim2.new(0, size, 0, size)
			ripple.BackgroundTransparency = transparency + (1 - transparency) * t

			if t >= 1 then
				cleanup()
				return true
			end
			return false
		end,
		onComplete,
		cleanup,
		"ripple",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, cleanup)
end

function Interaction.press(element: GuiObject, position: Vector2?, config: PressConfig?): EffectController
	assertArg(element, "element", "Instance")

	local duration = config and config.duration or DEFAULT_PRESS_DURATION
	local color = config and config.color or DEFAULT_PRESS_COLOR
	local transparency = config and config.transparency or DEFAULT_PRESS_TRANSPARENCY
	local maxSize = config and config.size or DEFAULT_PRESS_SIZE
	local onComplete = config and config.onComplete

	local absPos = element.AbsolutePosition
	local absSize = element.AbsoluteSize

	if absSize.X <= 0 or absSize.Y <= 0 then
		return {
			stop = function() end,
			pause = function() end,
			resume = function() end,
		}
	end

	local clickPos: Vector2
	if position then
		clickPos = position
	else
		clickPos = UserInputService:GetMouseLocation()
	end

	local relativeX = math.clamp((clickPos.X - absPos.X) / absSize.X, 0, 1)
	local relativeY = math.clamp((clickPos.Y - absPos.Y) / absSize.Y, 0, 1)

	local pressContainer = Instance.new("Frame")
	pressContainer.Name = "_BitFramesPress"
	pressContainer.Size = UDim2.new(1, 0, 1, 0)
	pressContainer.BackgroundTransparency = 1
	pressContainer.ClipsDescendants = true
	pressContainer.ZIndex = element.ZIndex + 1
	pressContainer.Parent = element

	cloneCorner(element, pressContainer)

	local pressCircle = Instance.new("Frame")
	pressCircle.Name = "PressCircle"
	pressCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	pressCircle.Position = UDim2.new(relativeX, 0, relativeY, 0)
	pressCircle.Size = UDim2.new(0, 0, 0, 0)
	pressCircle.BackgroundColor3 = color
	pressCircle.BackgroundTransparency = transparency
	pressCircle.BorderSizePixel = 0
	pressCircle.Parent = pressContainer

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)
	circleCorner.Parent = pressCircle

	local elapsed = 0

	local function cleanup()
		if pressContainer and pressContainer.Parent then
			pressContainer:Destroy()
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			if not pressContainer or not pressContainer.Parent then
				return true
			end
			
			elapsed = elapsed + dt
			local t = math.clamp(elapsed / duration, 0, 1)

			local easedT = 1 - (1 - t) * (1 - t)
			local size = maxSize * easedT
			pressCircle.Size = UDim2.new(0, size, 0, size)
			pressCircle.BackgroundTransparency = transparency + (1 - transparency) * t

			if t >= 1 then
				cleanup()
				return true
			end
			return false
		end,
		onComplete,
		cleanup,
		"press",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, cleanup)
end

function Interaction.highlight(element: GuiObject, config: HighlightConfig?): EffectController
	assertArg(element, "element", "Instance")

	local duration = config and config.duration or DEFAULT_HIGHLIGHT_DURATION
	local color = config and config.color or Color3.new(1, 1, 1)
	local transparency = config and config.transparency or 0.7

	local highlight = Instance.new("Frame")
	highlight.Name = "_BitFramesHighlight"
	highlight.Size = UDim2.new(1, 0, 1, 0)
	highlight.BackgroundColor3 = color
	highlight.BackgroundTransparency = 1
	highlight.BorderSizePixel = 0
	highlight.ZIndex = element.ZIndex + 1
	highlight.Parent = element

	cloneCorner(element, highlight)

	local elapsed = 0

	local function cleanup()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end

	local animation = AnimationFactory._create(
		function(dt: number): boolean
			elapsed = elapsed + dt
			local t = math.clamp(elapsed / duration, 0, 1)

			if t < 0.5 then
				highlight.BackgroundTransparency = 1 - (1 - transparency) * (t * 2)
			else
				highlight.BackgroundTransparency = transparency + (1 - transparency) * ((t - 0.5) * 2)
			end

			if t >= 1 then
				cleanup()
				return true
			end
			return false
		end,
		nil,
		cleanup,
		"highlight",
		element
	)

	AnimationFactory._start(animation)
	return AnimationFactory._createController(animation, cleanup)
end

function Interaction.bindRipple(element: GuiButton, config: RippleConfig?): { disconnect: () -> () }
	assertArg(element, "element", "Instance")

	local connection = element.MouseButton1Click:Connect(function()
		local mouseLocation = UserInputService:GetMouseLocation()
		Interaction.ripple(element, mouseLocation, config)
	end)

	return {
		disconnect = function()
			connection:Disconnect()
		end,
	}
end

function Interaction.bindPress(element: GuiObject, config: PressConfig?): { disconnect: () -> () }
	assertArg(element, "element", "Instance")

	local connections: { RBXScriptConnection } = {}

	local function handleInput(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			Interaction.press(element, position, config)
		end
	end

	table.insert(connections, element.InputBegan:Connect(handleInput))

	return {
		disconnect = function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end,
	}
end

function Interaction.hover(element: GuiObject, config: Types.HoverConfig?): EffectController
	assertArg(element, "element", "Instance")

	local scale = config and config.scale or 1.05
	local duration = config and config.duration or 0.2
	local easing = config and config.easing or "OutQuad" -- Using string for built-in tweens
	
	-- We use simple TweenService for hover as it's often more performant for simple scale
    -- and doesn't always need the full Scheduler overhead for persistent event binding
    -- But since this is BitFrames, we can use our internal Tween or just direct TS.
    -- Let's use direct TweenService for simplicity in this binding, 
    -- OR better: use the Entrance/Exit scale logic? No, simplistic is better here.
    
    local TweenService = game:GetService("TweenService")
    local TweenService = game:GetService("TweenService")
    
    local connections: { RBXScriptConnection } = {}
    local currentTween: Tween? = nil
    
    local function animate(targetScale: number)
        if currentTween then currentTween:Cancel() end
        
        local uiScale = element:FindFirstChild("_BitFramesHoverScale") :: UIScale
        if not uiScale then
             uiScale = Instance.new("UIScale")
             uiScale.Name = "_BitFramesHoverScale"
             uiScale.Parent = element
        end
        
        local style = Enum.EasingStyle[easing] or Enum.EasingStyle.Quad
        local info = TweenInfo.new(duration, style, Enum.EasingDirection.Out)
        currentTween = TweenService:Create(uiScale, info, { Scale = targetScale })
        if currentTween then currentTween:Play() end
    end
    
    table.insert(connections, element.MouseEnter:Connect(function()
        animate(scale)
    end))
    
    table.insert(connections, element.MouseLeave:Connect(function()
        animate(1)
    end))
    
    return {
        stop = function()
            for _, conn in connections do conn:Disconnect() end
            local uiScale = element:FindFirstChild("_BitFramesHoverScale")
            if uiScale then uiScale:Destroy() end
        end,
        pause = function() end, -- Not applicable
        resume = function() end, -- Not applicable
    }
end

return table.freeze(Interaction)
