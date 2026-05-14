--!strict

local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox

local Visualizer = {}

function Visualizer.EnsureContainer(hitbox: THitbox): Instance
	local existingContainer = hitbox.VisualizerContainer
	if existingContainer ~= nil and existingContainer.Parent ~= nil then
		return existingContainer
	end

	local existing = workspace:FindFirstChild("Hitboxes")
	if existing ~= nil and existing:IsA("Folder") then
		hitbox.VisualizerContainer = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "Hitboxes"
	folder.Parent = workspace
	hitbox.VisualizerContainer = folder
	return folder
end

function Visualizer.Visualize(hitbox: THitbox, hitboxCFrame: CFrame)
	if not hitbox.Visualizer then
		return
	end

	if hitbox._Box == nil then
		local part = Instance.new("Part")
		part.Name = "Visualizer"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Color = hitbox.VisualizerColor
		part.Transparency = hitbox.VisualizerTransparency
		part.CFrame = hitboxCFrame

		if hitbox.Shape == Enum.PartType.Ball then
			part.Shape = Enum.PartType.Ball
			if typeof(hitbox.Size) == "Vector3" then
				part.Size = hitbox.Size
			else
				local diameter = hitbox.Size * 2
				part.Size = Vector3.new(diameter, diameter, diameter)
			end
		else
			part.Shape = Enum.PartType.Block
			part.Size = hitbox.Size :: Vector3
		end

		part.Parent = Visualizer.EnsureContainer(hitbox)
		hitbox._Box = part
		return
	end

	hitbox._Box.CFrame = hitboxCFrame
end

return Visualizer
