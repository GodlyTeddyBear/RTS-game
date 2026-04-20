--!strict

--[[
	EquipmentService - Attaches and detaches tool models on worker rigs.

	Responsibilities:
	- Clone tool models from the ToolRegistry
	- Wire the tool's Motor6D (Part0 = Right Arm, Part1 = Handle)
	- Parent the tool into the worker model
	- Destroy equipped tools on unequip

	The Motor6D for each tool lives inside the tool model's Motors folder.
	On equip it is reparented into "Right Arm" (R6 rig) so Roblox's constraint solver picks it up.

	Pattern: Infrastructure layer service with dependency injection
]]

local EquipmentService = {}
EquipmentService.__index = EquipmentService

export type TEquipmentService = typeof(setmetatable({} :: { ToolRegistry: any }, EquipmentService))

local EQUIPPED_TOOL_ATTR = "EquippedTool"

function EquipmentService.new(toolRegistry: any): TEquipmentService
	assert(toolRegistry, "EquipmentService requires a ToolRegistry")

	local self = setmetatable({}, EquipmentService)
	self.ToolRegistry = toolRegistry

	return self
end

--[[
	Equip a tool onto a worker model.

	Steps:
	1. Clone the tool model from the registry
	2. Find "Right Arm" in the worker rig (R6)
	3. Find Motor6D in the tool's Motors folder
	4. Set Motor6D Part0 = Right Arm, Part1 = Handle
	5. Reparent Motor6D into Right Arm
	6. Parent the tool clone into the worker model
	7. Tag the tool with the EquippedTool attribute for lookup

	Returns true on success, false if anything is missing.
]]
function EquipmentService:EquipTool(model: Model, toolId: string): boolean
	self:UnequipTool(model)

	local toolClone: Model? = self.ToolRegistry:GetToolModel(toolId)
	if not toolClone then
		warn("[EquipmentService] Could not get tool model:", toolId, "for worker:", model.Name)
		return false
	end

	local parts = self:_ResolveToolParts(model, toolClone, toolId)
	if not parts then
		toolClone:Destroy()
		return false
	end

	-- Wire Motor6D — must live inside Part0's hierarchy for Roblox to solve the joint
	parts.Motor.Part0 = parts.RightArm
	parts.Motor.Part1 = parts.Handle
	parts.Motor.Parent = parts.RightArm

	toolClone:SetAttribute(EQUIPPED_TOOL_ATTR, toolId)
	toolClone.Parent = model
	return true
end

--- Resolves Right Arm, Handle, and Motor6D from the model and tool clone.
--- Returns nil (with a warn) if any required part is missing.
function EquipmentService:_ResolveToolParts(model: Model, toolClone: Model, toolId: string): { RightArm: BasePart, Handle: BasePart, Motor: Motor6D }?
	local rightArm = model:FindFirstChild("Right Arm", true)
	if not rightArm or not rightArm:IsA("BasePart") then
		warn("[EquipmentService] Right Arm not found in worker model:", model.Name)
		return nil
	end

	local handle = (toolClone :: any).PrimaryPart or toolClone:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		warn("[EquipmentService] Handle not found on tool:", toolId)
		return nil
	end

	local motorsFolder = toolClone:FindFirstChild("Motors")
	if not motorsFolder then
		warn("[EquipmentService] Motors folder not found on tool:", toolId)
		return nil
	end

	local motor = motorsFolder:FindFirstChildWhichIsA("Motor6D")
	if not motor then
		warn("[EquipmentService] Motor6D not found in Motors folder of tool:", toolId)
		return nil
	end

	return { RightArm = rightArm :: BasePart, Handle = handle :: BasePart, Motor = motor :: Motor6D }
end

--[[
	Unequip any currently equipped tool from a worker model.
	Safe to call when no tool is equipped.
]]
function EquipmentService:UnequipTool(model: Model)
	for _, child in model:GetChildren() do
		if child:GetAttribute(EQUIPPED_TOOL_ATTR) ~= nil then
			child:Destroy()
			return
		end
	end
end

return EquipmentService
