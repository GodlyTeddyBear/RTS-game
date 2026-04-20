--!strict

--[[
    SelectionService - Handles click-select and box-select for NPC models.

    Responsibilities:
    - Raycast to find NPC models under the cursor
    - Resolve Model → NPCId via Attribute
    - Filter: only adventurer NPCs are selectable
    - Screen-space box selection: project NPC positions, check if inside rectangle
]]

local CollectionService = game:GetService("CollectionService")
local workspace = game:GetService("Workspace")
local SelectionConfig = require(script.Parent.Parent.Config.SelectionConfig)

local SelectionService = {}
SelectionService.__index = SelectionService

export type TSelectionService = typeof(setmetatable({} :: {
	_Camera: Camera,
}, SelectionService))

function SelectionService.new(): TSelectionService
	local self = setmetatable({}, SelectionService)
	self._Camera = workspace.CurrentCamera
	return self
end

--[[
    Raycast from screen position to find a CombatNPC model.
    Returns (npcId, model, team) or nil.
]]
function SelectionService:RaycastForNPC(screenPosition: Vector2): (string?, Model?, string?)
	local camera = self._Camera
	if not camera then
		return nil, nil, nil
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	if not result or not result.Instance then
		return nil, nil, nil
	end

	-- Walk up ancestors to find a tagged CombatNPC model
	local current: Instance? = result.Instance
	while current and current ~= workspace do
		if current:IsA("Model") and CollectionService:HasTag(current, SelectionConfig.NPCTag) then
			local model = current :: Model
			local npcId = model:GetAttribute("NPCId") :: string?
			local team = model:GetAttribute("Team") :: string?
			return npcId, model, team
		end
		current = current.Parent
	end

	return nil, nil, nil
end

--[[
    Raycast to get a world position on the ground.
    Returns the hit position or nil.
]]
function SelectionService:RaycastForGround(screenPosition: Vector2): Vector3?
	local camera = self._Camera
	if not camera then
		return nil
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	if result then
		return result.Position
	end

	return nil
end

--[[
    Get all adventurer NPCs whose screen positions fall inside a selection rectangle.
    Returns { { NPCId: string, Model: Model } }
]]
function SelectionService:BoxSelect(topLeft: Vector2, bottomRight: Vector2): { { NPCId: string, Model: Model } }
	local camera = self._Camera
	if not camera then
		return {}
	end

	-- Normalize the rectangle and expand by padding for easier selection
	local pad = SelectionConfig.BoxSelectPadding
	local minX = math.min(topLeft.X, bottomRight.X) - pad
	local maxX = math.max(topLeft.X, bottomRight.X) + pad
	local minY = math.min(topLeft.Y, bottomRight.Y) - pad
	local maxY = math.max(topLeft.Y, bottomRight.Y) + pad

	local selected = {}

	for _, instance in CollectionService:GetTagged(SelectionConfig.NPCTag) do
		if not instance:IsA("Model") then
			continue
		end

		local model = instance :: Model
		local team = model:GetAttribute("Team") :: string?
		if team ~= "Adventurer" then
			continue
		end

		local npcId = model:GetAttribute("NPCId") :: string?
		if not npcId then
			continue
		end

		local primaryPart = model.PrimaryPart
		if not primaryPart then
			continue
		end

		local screenPos, onScreen = camera:WorldToScreenPoint(primaryPart.Position)
		if not onScreen then
			continue
		end

		if screenPos.X >= minX and screenPos.X <= maxX and screenPos.Y >= minY and screenPos.Y <= maxY then
			table.insert(selected, { NPCId = npcId, Model = model })
		end
	end

	return selected
end

return SelectionService
