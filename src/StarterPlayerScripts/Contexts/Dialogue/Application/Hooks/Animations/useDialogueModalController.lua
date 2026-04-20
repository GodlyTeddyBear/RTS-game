--!strict

local TweenService = game:GetService("TweenService")
local React = require(game:GetService("ReplicatedStorage").Packages.React)
local useReducedMotion = require(script.Parent.Parent.Parent.Parent.Parent.App.Application.Hooks.useReducedMotion)

-- Position constants for entrance animation
local PANEL_TARGET_POSITION = UDim2.fromScale(0.5, 0.75)
local PANEL_HIDDEN_POSITION = UDim2.fromScale(0.5, 1.03)

-- Animation timing constants
local OPTION_STAGGER_SECONDS = 0.05
local TYPEWRITER_STEP_SECONDS = 0.02

local function createTween(instance: Instance, tweenInfo: TweenInfo, goals: { [string]: any }): Tween
	local tween = TweenService:Create(instance, tweenInfo, goals)
	tween:Play()
	return tween
end

export type TDialogueModalController = {
	panelRef: { current: Frame? },
	optionScaleRefs: { current: { [string]: UIScale? } },
	scrollLayoutRef: { current: UIListLayout? },
	displayedDialogueText: string,
	panelTargetPosition: UDim2,
}

--[=[
	@function useDialogueModalController
	@within useDialogueModalController
	Animation orchestration hook for DialogueModal. Owns all refs, tweens, and
	the typewriter effect. Returns stable refs and derived state for the pure view.
	@param dialogueText string -- The full dialogue text to typewrite
	@param options { { Id: string, Text: string } } -- Current dialogue options (for stagger animation)
	@return TDialogueModalController
	@client
]=]
local function useDialogueModalController(
	dialogueText: string,
	options: { { Id: string, Text: string } }
): TDialogueModalController
	local prefersReducedMotion = useReducedMotion()
	local panelRef = React.useRef(nil :: Frame?)
	local optionScaleRefs = React.useRef({} :: { [string]: UIScale? })
	local scrollLayoutRef = React.useRef(nil :: UIListLayout?)
	local activePanelTweenRef = React.useRef(nil :: Tween?)
	local activeOptionTweensRef = React.useRef({} :: { Tween })
	local typewriterIdRef = React.useRef(0)
	local displayedDialogueText, setDisplayedDialogueText = React.useState(dialogueText)

	-- Auto-size the dialogue scroll canvas when content height changes
	React.useEffect(function()
		local layout = scrollLayoutRef.current
		if not layout then
			return
		end

		local function updateCanvas()
			local scroll = layout.Parent
			if scroll and scroll:IsA("ScrollingFrame") then
				local contentY = layout.AbsoluteContentSize.Y
				scroll.CanvasSize = UDim2.fromOffset(0, contentY)
			end
		end

		local connection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
		updateCanvas()

		return function()
			connection:Disconnect()
		end
	end, {})

	-- Animate panel entrance: slide up from bottom
	React.useEffect(function()
		local panel = panelRef.current
		if not panel then
			return
		end

		if prefersReducedMotion then
			panel.Position = PANEL_TARGET_POSITION
			return
		end

		panel.Position = PANEL_HIDDEN_POSITION
		local panelTween = createTween(
			panel,
			TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Position = PANEL_TARGET_POSITION }
		)
		activePanelTweenRef.current = panelTween
	end, { prefersReducedMotion })

	-- Animate options entrance: staggered scale-in from 0.84 to 1
	React.useEffect(function()
		for _, tween in ipairs(activeOptionTweensRef.current) do
			tween:Cancel()
		end
		table.clear(activeOptionTweensRef.current)

		if prefersReducedMotion then
			for _, option in ipairs(options) do
				local optionScale = optionScaleRefs.current[option.Id]
				if optionScale then
					optionScale.Scale = 1
				end
			end
			return
		end

		local cancelled = false
		local tweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for index, option in ipairs(options) do
			local optionScale = optionScaleRefs.current[option.Id]
			if optionScale then
				optionScale.Scale = 0.84
				task.delay((index - 1) * OPTION_STAGGER_SECONDS, function()
					if cancelled or optionScale.Parent == nil then
						return
					end
					local optionTween = createTween(optionScale, tweenInfo, { Scale = 1 })
					table.insert(activeOptionTweensRef.current, optionTween)
				end)
			end
		end

		return function()
			cancelled = true
			for _, tween in ipairs(activeOptionTweensRef.current) do
				tween:Cancel()
			end
			table.clear(activeOptionTweensRef.current)
		end
	end, { options, prefersReducedMotion } :: { any })

	-- Animate dialogue text: character-by-character reveal (typewriter effect)
	React.useEffect(function()
		typewriterIdRef.current += 1
		local currentTypewriterId = typewriterIdRef.current

		if prefersReducedMotion then
			setDisplayedDialogueText(dialogueText)
			return
		end

		setDisplayedDialogueText("")
		task.spawn(function()
			for index = 1, #dialogueText do
				if typewriterIdRef.current ~= currentTypewriterId then
					return
				end
				setDisplayedDialogueText(string.sub(dialogueText, 1, index))
				task.wait(TYPEWRITER_STEP_SECONDS)
			end
		end)

		return function()
			typewriterIdRef.current += 1
		end
	end, { dialogueText, prefersReducedMotion } :: { any })

	-- Cleanup: cancel all active tweens when component unmounts
	React.useEffect(function()
		return function()
			if activePanelTweenRef.current then
				activePanelTweenRef.current:Cancel()
				activePanelTweenRef.current = nil
			end
			for _, tween in ipairs(activeOptionTweensRef.current) do
				tween:Cancel()
			end
			table.clear(activeOptionTweensRef.current)
			typewriterIdRef.current += 1
		end
	end, {})

	return {
		panelRef = panelRef,
		optionScaleRefs = optionScaleRefs,
		scrollLayoutRef = scrollLayoutRef,
		displayedDialogueText = displayedDialogueText,
		panelTargetPosition = PANEL_TARGET_POSITION,
	}
end

return useDialogueModalController
