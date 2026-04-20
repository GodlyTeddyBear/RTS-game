--!strict

--[[
    SelectionVisualService - Manages Highlight and ground circle visuals
    for selected NPC models.

    Lifecycle: Show on select, destroy on deselect/death.
    Ground circles follow NPC position via a RenderStepped connection.
]]

local RunService = game:GetService("RunService")
local SelectionConfig = require(script.Parent.Parent.Config.SelectionConfig)

local SelectionVisualService = {}
SelectionVisualService.__index = SelectionVisualService

type TSelectionVisual = {
	Highlight: Highlight,
	Circle: Part,
	Model: Model,
}

export type TSelectionVisualService = typeof(setmetatable({} :: {
	_Visuals: { [string]: TSelectionVisual },
	_UpdateConnection: RBXScriptConnection?,
}, SelectionVisualService))

function SelectionVisualService.new(): TSelectionVisualService
	local self = setmetatable({}, SelectionVisualService)
	self._Visuals = {}
	self._UpdateConnection = nil
	return self
end

function SelectionVisualService:ShowSelection(npcId: string, model: Model)
	-- Remove existing visual if any
	self:HideSelection(npcId)

	-- Create Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "SelectionHighlight"
	highlight.Adornee = model
	highlight.FillColor = SelectionConfig.HighlightFillColor
	highlight.OutlineColor = SelectionConfig.HighlightOutlineColor
	highlight.FillTransparency = SelectionConfig.HighlightFillTransparency
	highlight.OutlineTransparency = SelectionConfig.HighlightOutlineTransparency
	highlight.Parent = model

	-- Create ground circle
	local circle = Instance.new("Part")
	circle.Name = "SelectionCircle"
	circle.Shape = Enum.PartType.Cylinder
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.CanTouch = false
	circle.Size = SelectionConfig.CircleSize
	circle.Color = SelectionConfig.CircleColor
	circle.Transparency = SelectionConfig.CircleTransparency
	circle.Material = Enum.Material.Neon
	-- Rotate cylinder to lay flat (cylinder extends along Y by default)
	circle.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	circle.Parent = workspace

	-- Position it initially
	if model.PrimaryPart then
		local pos = model.PrimaryPart.Position
		circle.CFrame = CFrame.new(pos.X, pos.Y + SelectionConfig.CircleYOffset, pos.Z)
			* CFrame.Angles(0, 0, math.rad(90))
	end

	self._Visuals[npcId] = {
		Highlight = highlight,
		Circle = circle,
		Model = model,
	}

	-- Start update loop if not running
	if not self._UpdateConnection then
		self._UpdateConnection = RunService.RenderStepped:Connect(function()
			self:_UpdateCirclePositions()
		end)
	end
end

function SelectionVisualService:HideSelection(npcId: string)
	local visual = self._Visuals[npcId]
	if not visual then
		return
	end

	if visual.Highlight and visual.Highlight.Parent then
		visual.Highlight:Destroy()
	end

	if visual.Circle and visual.Circle.Parent then
		visual.Circle:Destroy()
	end

	self._Visuals[npcId] = nil

	-- Stop update loop if no more visuals
	if next(self._Visuals) == nil and self._UpdateConnection then
		self._UpdateConnection:Disconnect()
		self._UpdateConnection = nil
	end
end

function SelectionVisualService:ClearAll()
	for npcId, _ in self._Visuals do
		self:HideSelection(npcId)
	end
	self:ClearMoveMarker()
end

function SelectionVisualService:_UpdateCirclePositions()
	for _, visual in self._Visuals do
		if visual.Model and visual.Model.PrimaryPart and visual.Circle and visual.Circle.Parent then
			local pos = visual.Model.PrimaryPart.Position
			visual.Circle.CFrame = CFrame.new(pos.X, pos.Y + SelectionConfig.CircleYOffset, pos.Z)
				* CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

---
-- Enemy Hover Highlight (pick-target mode)
---

function SelectionVisualService:ShowEnemyHighlight(npcId: string, model: Model)
	self:HideEnemyHighlight()

	local highlight = Instance.new("Highlight")
	highlight.Name = "EnemyTargetHighlight"
	highlight.Adornee = model
	highlight.FillColor = SelectionConfig.EnemyHighlightFillColor
	highlight.OutlineColor = SelectionConfig.EnemyHighlightOutlineColor
	highlight.FillTransparency = SelectionConfig.EnemyHighlightFillTransparency
	highlight.OutlineTransparency = SelectionConfig.EnemyHighlightOutlineTransparency
	highlight.Parent = model

	self._EnemyHighlight = { Highlight = highlight, NPCId = npcId }
end

function SelectionVisualService:HideEnemyHighlight()
	if self._EnemyHighlight then
		if self._EnemyHighlight.Highlight and self._EnemyHighlight.Highlight.Parent then
			self._EnemyHighlight.Highlight:Destroy()
		end
		self._EnemyHighlight = nil
	end
end

function SelectionVisualService:GetHighlightedEnemyId(): string?
	if self._EnemyHighlight then
		return self._EnemyHighlight.NPCId
	end
	return nil
end

---
-- Confirmed Target Highlight (persistent black outline after E confirm)
---

function SelectionVisualService:ShowTargetedHighlight(npcId: string, model: Model)
	-- Remove existing targeted highlight on this NPC if any
	self:HideTargetedHighlight(npcId)

	local highlight = Instance.new("Highlight")
	highlight.Name = "TargetedHighlight"
	highlight.Adornee = model
	highlight.FillColor = SelectionConfig.TargetedHighlightFillColor
	highlight.OutlineColor = SelectionConfig.TargetedHighlightOutlineColor
	highlight.FillTransparency = SelectionConfig.TargetedHighlightFillTransparency
	highlight.OutlineTransparency = SelectionConfig.TargetedHighlightOutlineTransparency
	highlight.Parent = model

	-- Create red ground circle
	local circle = Instance.new("Part")
	circle.Name = "TargetedCircle"
	circle.Shape = Enum.PartType.Cylinder
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.CanTouch = false
	circle.Size = SelectionConfig.TargetedCircleSize
	circle.Color = SelectionConfig.TargetedCircleColor
	circle.Transparency = SelectionConfig.TargetedCircleTransparency
	circle.Material = Enum.Material.Neon
	circle.Parent = workspace

	if model.PrimaryPart then
		local pos = model.PrimaryPart.Position
		circle.CFrame = CFrame.new(pos.X, pos.Y + SelectionConfig.CircleYOffset, pos.Z)
			* CFrame.Angles(0, 0, math.rad(90))
	end

	if not self._TargetedHighlights then
		self._TargetedHighlights = {}
	end
	self._TargetedHighlights[npcId] = { Highlight = highlight, Circle = circle, Model = model }

	-- Start update loop if not running
	if not self._TargetedUpdateConnection then
		self._TargetedUpdateConnection = RunService.RenderStepped:Connect(function()
			self:_UpdateTargetedCirclePositions()
		end)
	end
end

function SelectionVisualService:HideTargetedHighlight(npcId: string)
	if not self._TargetedHighlights then
		return
	end
	local entry = self._TargetedHighlights[npcId]
	if not entry then
		return
	end

	if entry.Highlight and entry.Highlight.Parent then
		entry.Highlight:Destroy()
	end
	if entry.Circle and entry.Circle.Parent then
		entry.Circle:Destroy()
	end
	self._TargetedHighlights[npcId] = nil

	if next(self._TargetedHighlights) == nil and self._TargetedUpdateConnection then
		self._TargetedUpdateConnection:Disconnect()
		self._TargetedUpdateConnection = nil
	end
end

function SelectionVisualService:ClearAllTargetedHighlights()
	if not self._TargetedHighlights then
		return
	end
	for npcId, _ in self._TargetedHighlights do
		self:HideTargetedHighlight(npcId)
	end
end

function SelectionVisualService:_UpdateTargetedCirclePositions()
	if not self._TargetedHighlights then
		return
	end
	for _, entry in self._TargetedHighlights do
		if entry.Model and entry.Model.PrimaryPart and entry.Circle and entry.Circle.Parent then
			local pos = entry.Model.PrimaryPart.Position
			entry.Circle.CFrame = CFrame.new(pos.X, pos.Y + SelectionConfig.CircleYOffset, pos.Z)
				* CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

--[[
    Show a persistent move marker at the target position.
    Replaces any existing move marker.
]]
function SelectionVisualService:ShowMoveMarker(position: Vector3)
	self:ClearMoveMarker()

	local marker = Instance.new("Part")
	marker.Name = "MoveMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Size = SelectionConfig.MoveMarkerSize
	marker.Color = SelectionConfig.MoveMarkerColor
	marker.Transparency = SelectionConfig.MoveMarkerTransparency
	marker.Material = Enum.Material.Neon
	marker.CFrame = CFrame.new(position.X, position.Y + 0.1, position.Z)
		* CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = workspace

	self._MoveMarker = marker
end

function SelectionVisualService:ClearMoveMarker()
	if self._MoveMarker and self._MoveMarker.Parent then
		self._MoveMarker:Destroy()
	end
	self._MoveMarker = nil
end

return SelectionVisualService
