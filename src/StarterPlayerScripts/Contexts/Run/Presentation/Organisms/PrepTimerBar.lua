--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local Border = require(script.Parent.Parent.Parent.Parent.App.Config.BorderTokens)
local useSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useSpring)
local useRunPhaseHud = require(script.Parent.Parent.Parent.Application.Hooks.useRunPhaseHud)

local function PrepTimerBar()
	local phaseHud = useRunPhaseHud()
	local spring = useSpring()
	local fillRef = React.useRef(nil :: Frame?)
	local now, setNow = React.useState(function()
		return Workspace:GetServerTimeNow()
	end)

	React.useEffect(function()
		local isMounted = true
		task.spawn(function()
			while isMounted do
				setNow(Workspace:GetServerTimeNow())
				task.wait(0.1)
			end
		end)

		return function()
			isMounted = false
		end
	end, {})

	local fillRatio = 0
	local hasValidTimer = phaseHud.runState == "Prep"
		and phaseHud.phaseEndsAt ~= nil
		and phaseHud.phaseDuration ~= nil
		and phaseHud.phaseDuration > 0

	if hasValidTimer then
		fillRatio = math.clamp((phaseHud.phaseEndsAt :: number - now) / (phaseHud.phaseDuration :: number), 0, 1)
	end

	React.useEffect(function()
		if not hasValidTimer or fillRef.current == nil then
			return
		end

		spring(fillRef, {
			Size = UDim2.fromScale(fillRatio, 1),
		}, "Smooth")
	end, { hasValidTimer, fillRatio })

	if phaseHud.runState ~= "Prep" then
		return nil
	end

	if phaseHud.phaseEndsAt == nil or phaseHud.phaseDuration == nil or phaseHud.phaseDuration <= 0 then
		return nil
	end

	return e(Frame, {
		Size = UDim2.fromScale(0.34, 0.014),
		Position = UDim2.fromScale(0.5, 0.865),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Colors.Surface.Primary,
		BackgroundTransparency = 0.05,
		ClipsDescendants = true,
		CornerRadius = Border.Radius.Full,
	}, {
		Fill = e(Frame, {
			ref = fillRef,
			Size = UDim2.fromScale(fillRatio, 1),
			BackgroundColor3 = Colors.Accent.Yellow,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0, 0),
			CornerRadius = Border.Radius.Full,
		}),
	})
end

return PrepTimerBar
