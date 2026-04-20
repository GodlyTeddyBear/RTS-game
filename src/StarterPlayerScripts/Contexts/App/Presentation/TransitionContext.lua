--!strict
--[=[
	@class TransitionContext
	React context that connects `AnimatedRouter` with `useScreenTransition` for coordinated enter/exit animations.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

--[[
	TransitionContext - React context for router-screen animation communication.

	The AnimatedRouter provides this context. The useScreenTransition hook
	reads from it to coordinate enter/exit animations with the router's
	state machine.

	Protocol:
		1. Router mounts screen → hook reads context
		2. Hook registers its exit handler via RegisterExit
		3. Hook snaps elements to origins, reveals container, runs enter phases
		4. Hook calls OnEntranceComplete when enter finishes
		5. On navigation: router calls the registered exit handler
		6. Exit handler runs exit phases → calls onComplete callback
		7. Router unmounts old screen, mounts new screen
]]

--[=[
	@interface TTransitionContext
	@within TransitionContext
	.RegisterExit ((exitHandler: (onComplete: () -> ()) -> ()) -> ())? -- Register a handler the router calls when it needs the screen to exit.
	.OnEntranceComplete (() -> ())? -- Signal to the router that entrance animation has finished.
]=]
export type TTransitionContext = {
	-- Called by the hook to register its exit animation handler.
	-- The router will call exitHandler(onComplete) when it's time to exit.
	-- If no exit handler is registered, the router skips exit instantly.
	RegisterExit: ((exitHandler: (onComplete: () -> ()) -> ()) -> ())?,

	-- Called by the hook after entrance animations finish (or instantly if no enter phases).
	OnEntranceComplete: (() -> ())?,
}

local Context = React.createContext(nil :: TTransitionContext?)

return {
	Context = Context,
	Provider = Context.Provider,
}
