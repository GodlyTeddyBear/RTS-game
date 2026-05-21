--!strict

local Detection = require(script.Parent:WaitForChild("Detection"))
local FilterRegistry = require(script.Parent:WaitForChild("FilterRegistry"))
local Query = require(script.Parent:WaitForChild("Query"))
local Source = require(script.Parent:WaitForChild("Source"))
local Visualizer = require(script.Parent:WaitForChild("Visualizer"))
local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox
type THitboxRunner = Types.HitboxRunner

local activeHitboxes: { [string]: THitbox } = {}

local Lifecycle = {}

function Lifecycle.FindHitbox(key: string): THitbox?
	return activeHitboxes[key]
end

function Lifecycle.IsStepDue(hitbox: THitbox, deltaTime: number): boolean
	local updateInterval = hitbox.UpdateInterval
	if type(updateInterval) == "number" and updateInterval > 0 then
		local accumulator = hitbox._UpdateAccumulator or 0
		accumulator += deltaTime
		hitbox._UpdateAccumulator = accumulator
		if accumulator < updateInterval then
			return false
		end

		hitbox._UpdateAccumulator = 0
	end

	return true
end

function Lifecycle.ResolveStep(hitbox: THitbox): CFrame
	local _, hitboxCFrame = Source.ResolveQueryState(hitbox)
	Visualizer.Visualize(hitbox, hitboxCFrame)
	return hitboxCFrame
end

function Lifecycle.RunSerialDetection(hitbox: THitbox, hitboxCFrame: CFrame): boolean
	local parts = Query.CastSpatialQuery(hitbox, hitboxCFrame)
	Detection.Cast(hitbox, parts)
	return #parts > 0
end

function Lifecycle.RunNoHitDetection(hitbox: THitbox)
	Detection.CastNoHits(hitbox)
end

function Lifecycle.Step(hitbox: THitbox, deltaTime: number)
	if not Lifecycle.IsStepDue(hitbox, deltaTime) then
		return
	end

	Lifecycle.RunSerialDetection(hitbox, Lifecycle.ResolveStep(hitbox))
end

function Lifecycle.Start(hitbox: THitbox, runner: THitboxRunner?)
	if activeHitboxes[hitbox.Key] then
		error("A hitbox with this Key has already been started. Change the key if you want to start this hitbox.")
	end

	local Runner = require(script.Parent:WaitForChild("Runner"))
	local activeRunner = runner or Runner.GetInternal()
	activeHitboxes[hitbox.Key] = hitbox
	hitbox._Runner = activeRunner
	activeRunner:Register(hitbox)
end

function Lifecycle.Clear(hitbox: THitbox)
	hitbox.HitList = {}
	hitbox.HitListSet = {}
	hitbox.TouchingParts = {}
	hitbox.TouchingPartsSet = {}
	hitbox._UpdateAccumulator = 0
	hitbox._QueryCache = nil
	hitbox._ParallelMissCount = 0

	local runner = hitbox._Runner
	if runner ~= nil then
		runner:Unregister(hitbox)
		hitbox._Runner = nil
	end

	if hitbox._Connection ~= nil then
		hitbox._Connection:Disconnect()
		hitbox._Connection = nil
	end

	activeHitboxes[hitbox.Key] = nil

	FilterRegistry.RemoveToken(hitbox.Key)

	if hitbox._Box ~= nil then
		hitbox._Box:Destroy()
		hitbox._Box = nil
	end
end

function Lifecycle.Stop(hitbox: THitbox)
	if not Lifecycle.FindHitbox(hitbox.Key) then
		error("Hitbox has already been stopped")
	end

	Lifecycle.Clear(hitbox)
	if not hitbox.AutoDestroy then
		return
	end

	hitbox.Touched:DisconnectAll()
	hitbox.TouchEnded:DisconnectAll()
end

function Lifecycle.Destroy(hitbox: THitbox)
	if not Lifecycle.FindHitbox(hitbox.Key) then
		error("Hitbox has already been destroyed")
	end

	Lifecycle.Clear(hitbox)
	hitbox.Touched:DisconnectAll()
	hitbox.TouchEnded:DisconnectAll()
end

return Lifecycle
