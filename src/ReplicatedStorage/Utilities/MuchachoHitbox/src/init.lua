--!strict

local HttpService = game:GetService("HttpService")

local GoodSignal = require(script.Parent.GoodSignal)
local Lifecycle = require(script.Lifecycle)
local Runner = require(script.Runner)
local Types = require(script.Parent.Types)

type THitbox = Types.Hitbox

local MuchachoHitbox = {}
local HitboxMethods = {}
HitboxMethods.__index = HitboxMethods

local DEFAULT_UPDATE_INTERVAL = 15 / 60

function HitboxMethods:FindHitbox(key: string)
	return Lifecycle.FindHitbox(key)
end

function HitboxMethods:Start(runner)
	return Lifecycle.Start(self, runner)
end

function HitboxMethods:Stop()
	return Lifecycle.Stop(self)
end

function HitboxMethods:Destroy()
	return Lifecycle.Destroy(self)
end

function HitboxMethods:Step(deltaTime: number)
	return Lifecycle.Step(self, deltaTime)
end

function MuchachoHitbox.CreateRunner()
	return Runner.Create()
end

function MuchachoHitbox.CreateHitbox()
	local hitbox = setmetatable({}, HitboxMethods) :: THitbox

	hitbox.DetectionMode = "Default"
	hitbox.AutoDestroy = true
	hitbox.UpdateInterval = DEFAULT_UPDATE_INTERVAL

	hitbox.Visualizer = true
	hitbox.VisualizerColor = Color3.fromRGB(255, 0, 0)
	hitbox.VisualizerTransparency = 0.8
	hitbox.VisualizerContainer = nil

	hitbox.VelocityPrediction = false
	hitbox.VelocityPredictionTime = 0.1

	hitbox.OverlapParams = OverlapParams.new()

	hitbox.Size = Vector3.new(0, 0, 0)
	hitbox.Shape = Enum.PartType.Block
	hitbox.CFrame = CFrame.new()
	hitbox.Offset = CFrame.new()

	hitbox.Key = HttpService:GenerateGUID(false)

	hitbox.HitList = {}
	hitbox.HitListSet = {}
	hitbox.TouchingParts = {}
	hitbox.TouchingPartsSet = {}

	hitbox.Touched = GoodSignal.new()
	hitbox.TouchEnded = GoodSignal.new()

	hitbox._UpdateAccumulator = 0
	hitbox._QueryCache = nil
	hitbox._ParallelMissCount = 0
	hitbox._Runner = nil
	hitbox._Connection = nil
	hitbox._Box = nil

	return hitbox
end

return MuchachoHitbox
