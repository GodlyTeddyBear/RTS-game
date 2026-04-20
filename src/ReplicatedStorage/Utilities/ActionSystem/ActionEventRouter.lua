--!strict

--[=[
	@class ActionEventRouter
	Wires AnimationTrack keyframe markers to action class event handlers.
	@server
]=]

local Types = require(script.Parent.Types)

local ActionEventRouter = {}

--[=[
	Wire all named keyframe markers on a track to fire the action's event handler.
	Connects to `KeyframeReached` and filters events by the action's `Events` table.

	@within ActionEventRouter
	@param track AnimationTrack -- The animation track to listen to
	@param actionDef IAction -- The action class instance with Events definitions
	@param context TActionContext -- Injected context (Model, SoundEngine, VFXService, etc.)
	@return () -> () -- Cleanup function that disconnects all marker connections (idempotent)
]=]
function ActionEventRouter.Wire(
	track: AnimationTrack,
	actionDef: Types.IAction,
	context: Types.TActionContext
): () -> ()
	local connections: { RBXScriptConnection } = {}
	local cleaned = false

	-- Wire each named marker from the action's Events table individually.
	-- Roblox animation markers use GetMarkerReachedSignal, not KeyframeReached.
	-- KeyframeReached only fires for named keyframes, not the flag markers added
	-- in the Animation Editor's marker track.
	for markerName in (actionDef.Events or {}) do
		local conn = track:GetMarkerReachedSignal(markerName):Connect(function()
			if actionDef.OnEvent then
				actionDef:OnEvent(markerName, context)
			end
		end)
		table.insert(connections, conn)
	end

	return function()
		if cleaned then
			return
		end
		cleaned = true
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
	end
end

return ActionEventRouter
