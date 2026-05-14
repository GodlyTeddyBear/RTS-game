--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Orient = require(ReplicatedStorage.Utilities.Orient)
local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox

local Source = {}

local getCFrameByType = {
	Instance = function(point: BasePart): CFrame
		return point.CFrame
	end,
	CFrame = function(point: CFrame): CFrame
		return point
	end,
}

function Source.PredictVelocity(hitbox: THitbox): CFrame?
	if not hitbox.VelocityPrediction then
		return nil
	end

	local predictionTime = hitbox.VelocityPredictionTime
	local source = hitbox.CFrame
	if predictionTime == nil or predictionTime <= 0 or typeof(source) ~= "Instance" or not source:IsA("BasePart") then
		return nil
	end

	local velocityPart = source :: BasePart
	local predictedPosition = velocityPart.Position + velocityPart.AssemblyLinearVelocity * predictionTime
	return Orient.BuildAtPosition(velocityPart.CFrame, predictedPosition)
end

function Source.ResolveQueryState(hitbox: THitbox): (CFrame, CFrame)
	local predictedCFrame = Source.PredictVelocity(hitbox)
	if predictedCFrame ~= nil then
		return predictedCFrame, predictedCFrame * hitbox.Offset
	end

	local pointType = typeof(hitbox.CFrame)
	local pointGetter = getCFrameByType[pointType]
	if pointGetter == nil then
		error("Unsupported CFrame source type for MuchachoHitbox: " .. pointType)
	end

	local pointCFrame = pointGetter(hitbox.CFrame :: any)
	return pointCFrame, pointCFrame * hitbox.Offset
end

return Source
