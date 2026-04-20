--!strict
--[=[
	@class AnimatedRouter
	Screen router with enter/exit animation support, implemented as a state machine that coordinates with `TransitionContext`.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useRef = React.useRef
local useEffect = React.useEffect
local useState = React.useState

local useNavigation = require(script.Parent.Parent.Application.Hooks.useNavigation)
local ScreenRegistry = require(script.Parent.Parent.Config.ScreenRegistry)
local TransitionContext = require(script.Parent.TransitionContext)

--[[
	AnimatedRouter - Screen transition state machine with navigation queuing.

	State machine: Idle → Exiting → Mounting → Idle

	Communication with screens uses TransitionContext (React context).
	The useScreenTransition hook registers exit handlers and signals
	entrance completion through this context.

	Flow:
	1. Navigation atom changes → router checks if transitioning
	2. If transitioning → queue the navigation (process after current finishes)
	3. If idle → enter Exiting state, call registered exit handler
	4. Exit handler runs exit phases → calls onComplete
	5. Router unmounts old screen, mounts new screen
	6. New screen's useScreenTransition hook runs entrance automatically
	7. Hook calls OnEntranceComplete → router returns to Idle
	8. If queued navigation exists → immediately process it

	If no exit handler is registered (screen has no exit animation),
	the router skips exit and mounts the new screen immediately.
]]

local EXIT_TIMEOUT = 3.0

local function NotFoundScreen()
	warn("[AnimatedRouter] Screen not found")
	return e("TextLabel", {
		Text = "Screen not found",
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 24,
	})
end

local function AnimatedRouter()
	local navigation = useNavigation()
	local currentScreenName = navigation.CurrentScreen

	-- Screen being displayed (may lag during transitions while animation plays)
	local displayedScreen, setDisplayedScreen = useState(currentScreenName)
	local prevScreenRef = useRef(currentScreenName)

	-- Gate to prevent starting a new transition while one is in progress
	local isTransitioningRef = useRef(false)

	-- Navigation target queued if nav occurred mid-transition; processed when current finishes
	local queuedScreenRef = useRef(nil :: string?)

	-- Exit handler (animation callback) registered by the current screen's useScreenTransition hook
	local exitHandlerRef = useRef(nil :: ((onComplete: () -> ()) -> ())?)

	-- Ref to _processTransition; stored so useMemo's closure can call it without forward-reference issues
	local processTransitionRef = useRef(nil :: ((targetScreen: string) -> ())?)

	-- Build transition context that screens use to register exit handlers and signal entrance completion
	local transitionCtxValue: TransitionContext.TTransitionContext = React.useMemo(function()
		-- Clear the previous exit handler when mounting a new screen
		exitHandlerRef.current = nil

		return {
			RegisterExit = function(handler: (onComplete: () -> ()) -> ())
				exitHandlerRef.current = handler
			end,

			OnEntranceComplete = function()
				-- Unblock transitions after the new screen's entrance animation finishes
				isTransitioningRef.current = false

				-- Process any navigation that was queued while the transition was in progress
				local queued = queuedScreenRef.current
				if queued then
					queuedScreenRef.current = nil
					local fn = processTransitionRef.current
					if fn then
						fn(queued)
					end
				end
			end,
		}
	end, { displayedScreen }) :: TransitionContext.TTransitionContext

	local function _buildExitCompleteHandler(targetScreen: string, timeoutThreadRef: { current: thread? })
		-- Guard: only allow the exit completion to fire once (screen may complete or timeout)
		local exitCompleted = false
		return function()
			if exitCompleted then
				return
			end
			exitCompleted = true

			-- Cancel the timeout since exit finished (either normally or was forced)
			if timeoutThreadRef.current then
				task.cancel(timeoutThreadRef.current)
				timeoutThreadRef.current = nil
			end

			-- Transition to the new screen
			prevScreenRef.current = targetScreen
			exitHandlerRef.current = nil
			setDisplayedScreen(targetScreen)
		end
	end

	local function _startExitTimeout(onExitComplete: () -> (), timeoutThreadRef: { current: thread? })
		-- Safeguard: if exit animation doesn't complete within 3 seconds, force the transition
		timeoutThreadRef.current = task.delay(EXIT_TIMEOUT, function()
			warn("[AnimatedRouter] Exit timeout for", prevScreenRef.current, "— forcing transition")
			onExitComplete()
		end)
	end

	-- Coordinate a transition to a new screen (handles queuing and exit animation)
	local function _processTransition(targetScreen: string)
		-- If already transitioning, queue this navigation for later
		if isTransitioningRef.current then
			queuedScreenRef.current = targetScreen
			return
		end

		-- Avoid redundant transitions to the same screen
		if targetScreen == prevScreenRef.current then
			return
		end

		-- Begin transition (block new navigations until this one completes)
		isTransitioningRef.current = true

		local timeoutThreadRef = { current = nil :: thread? }
		local onExitComplete = _buildExitCompleteHandler(targetScreen, timeoutThreadRef)
		_startExitTimeout(onExitComplete, timeoutThreadRef)

		-- Trigger the exit handler if the screen registered one; otherwise exit instantly
		local exitHandler = exitHandlerRef.current
		if exitHandler then
			exitHandler(onExitComplete)
		else
			onExitComplete()
		end
	end

	-- Update the ref so OnEntranceComplete (in the useMemo closure) can invoke _processTransition
	processTransitionRef.current = _processTransition

	-- Watch for navigation changes from the navigation atom
	useEffect(function()
		-- Skip if we're already on the target screen
		if currentScreenName == prevScreenRef.current then
			return
		end

		_processTransition(currentScreenName)
	end, { currentScreenName })

	-- Fallback for screens that never call OnEntranceComplete (e.g., screens without useScreenTransition)
	-- If the transition hasn't been unblocked after 100ms, force it to unblock and process any queued nav
	useEffect(function()
		local thread = task.delay(0.1, function()
			if isTransitioningRef.current then
				isTransitioningRef.current = false

				-- Process queued navigation if any
				local queued = queuedScreenRef.current
				if queued then
					queuedScreenRef.current = nil
					_processTransition(queued)
				end
			end
		end)

		return function()
			task.cancel(thread)
		end
	end, { displayedScreen })

	local ScreenComponent = ScreenRegistry[displayedScreen] or NotFoundScreen

	return e(TransitionContext.Provider, {
		value = transitionCtxValue,
	}, {
		Screen = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			CurrentScreen = e(ScreenComponent, {
				params = navigation.Params,
			}),
		}),
	})
end

return AnimatedRouter
