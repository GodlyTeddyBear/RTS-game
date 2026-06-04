--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentTypes = require(ReplicatedStorage.Contexts.Equipment.Types.EquipmentTypes)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TEquipmentDefinition = EquipmentTypes.TEquipmentDefinition
type TAttachmentHandle = EquipmentTypes.TAttachmentHandle

local Ok = Result.Ok
local Err = Result.Err

local EquipmentAttachmentService = {}
EquipmentAttachmentService.__index = EquipmentAttachmentService

local RIGHT_ARM_NAMES = table.freeze({
	"RightArm",
	"Right Arm",
	"RightHand",
})

function EquipmentAttachmentService.new()
	local self = setmetatable({}, EquipmentAttachmentService)
	self._renderContext = nil
	self._handles = {} :: { [string]: TAttachmentHandle }
	return self
end

function EquipmentAttachmentService:Init(_registry: any, _name: string)
end

function EquipmentAttachmentService:Start(registry: any, _name: string)
	self._renderContext = registry:Get("RenderContext")
end

function EquipmentAttachmentService:Attach(
	ownerModel: Model,
	definition: TEquipmentDefinition,
	attachmentId: string
): Result.Result<TAttachmentHandle>
	local existing = self._handles[attachmentId]
	if existing ~= nil then
		self:Detach(attachmentId)
	end

	if definition.AssetFamily == "Tool" then
		return self:_AttachTool(ownerModel, definition.AssetId, attachmentId)
	elseif definition.AssetFamily == "Armor" then
		return self:_AttachAccessoryContainer(ownerModel, definition.AssetId, attachmentId, "Armor")
	elseif definition.AssetFamily == "Accessory" then
		return self:_AttachAccessoryContainer(ownerModel, definition.AssetId, attachmentId, "Accessory")
	end

	return Err("InvalidItemId", Errors.INVALID_ITEM_ID, { assetFamily = definition.AssetFamily })
end

function EquipmentAttachmentService:Detach(attachmentId: string): Result.Result<boolean>
	local handle = self._handles[attachmentId]
	if handle == nil then
		return Ok(false)
	end

	self._handles[attachmentId] = nil
	for _, instance in ipairs(handle.Instances) do
		if instance.Parent ~= nil then
			instance:Destroy()
		end
	end

	return Ok(true)
end

function EquipmentAttachmentService:ClearAll(): Result.Result<boolean>
	local attachmentIds = {}
	for attachmentId in self._handles do
		table.insert(attachmentIds, attachmentId)
	end

	for _, attachmentId in ipairs(attachmentIds) do
		self:Detach(attachmentId)
	end

	return Ok(true)
end

function EquipmentAttachmentService:_AttachAccessoryContainer(
	ownerModel: Model,
	assetId: string,
	attachmentId: string,
	assetFamily: "Armor" | "Accessory"
): Result.Result<TAttachmentHandle>
	if self._renderContext == nil then
		return Err("MissingAssetFolder", Errors.MISSING_ASSET_FOLDER, { assetFamily = assetFamily })
	end

	local wrapperResult = if assetFamily == "Armor"
		then self._renderContext:GetArmorModel(assetId)
		else self._renderContext:GetAccessoryModel(assetId)
	local wrapper = if wrapperResult.success then wrapperResult.value else nil
	if wrapper == nil then
		return Err("MissingEquipmentAsset", Errors.MISSING_EQUIPMENT_ASSET, {
			assetFamily = assetFamily,
			assetId = assetId,
		})
	end

	local attachedInstances = {}
	for _, child in ipairs(wrapper:GetChildren()) do
		if child:IsA("Accessory") then
			child.Parent = ownerModel
			table.insert(attachedInstances, child)
		end
	end

	wrapper:Destroy()

	if #attachedInstances == 0 then
		return Err("NoAccessoriesInModel", Errors.NO_ACCESSORIES_IN_MODEL, {
			assetFamily = assetFamily,
			assetId = assetId,
		})
	end

	local handle = {
		Id = attachmentId,
		OwnerModel = ownerModel,
		Instances = attachedInstances,
	}
	self._handles[attachmentId] = handle
	return Ok(handle)
end

function EquipmentAttachmentService:_AttachTool(
	ownerModel: Model,
	assetId: string,
	attachmentId: string
): Result.Result<TAttachmentHandle>
	if self._renderContext == nil then
		return Err("MissingAssetFolder", Errors.MISSING_ASSET_FOLDER, { assetFamily = "Tool" })
	end

	local toolModelResult = self._renderContext:GetToolModel(assetId)
	local toolModel = if toolModelResult.success then toolModelResult.value else nil
	if toolModel == nil then
		return Err("MissingEquipmentAsset", Errors.MISSING_EQUIPMENT_ASSET, {
			assetFamily = "Tool",
			assetId = assetId,
		})
	end

	local rightArm = self:_FindRightArm(ownerModel)
	if rightArm == nil then
		toolModel:Destroy()
		return Err("MissingRightArm", Errors.MISSING_RIGHT_ARM, { ownerModel = ownerModel.Name })
	end

	local motorsFolder = toolModel:FindFirstChild("Motors")
	if motorsFolder == nil or not motorsFolder:IsA("Folder") then
		toolModel:Destroy()
		return Err("MissingToolMotors", Errors.MISSING_TOOL_MOTORS, { assetId = assetId })
	end

	local motors = {}
	for _, child in ipairs(motorsFolder:GetChildren()) do
		if child:IsA("Motor6D") then
			table.insert(motors, child :: Motor6D)
		end
	end

	if #motors == 0 then
		toolModel:Destroy()
		return Err("NoValidToolMotors", Errors.NO_VALID_TOOL_MOTORS, { assetId = assetId })
	end

	for _, motor in ipairs(motors) do
		local part1 = motor.Part1
		if part1 == nil or not part1:IsA("BasePart") or not part1:IsDescendantOf(toolModel) then
			toolModel:Destroy()
			return Err("InvalidToolMotorPart", Errors.INVALID_TOOL_MOTOR_PART, {
				assetId = assetId,
				motorName = motor.Name,
			})
		end
	end

	toolModel.Parent = ownerModel
	for _, motor in ipairs(motors) do
		if motor.Part0 == nil or not motor.Part0:IsDescendantOf(ownerModel) then
			motor.Part0 = rightArm
		end
		motor.Parent = rightArm
	end

	if #motorsFolder:GetChildren() == 0 then
		motorsFolder:Destroy()
	end

	local attachedInstances = { toolModel }
	for _, motor in ipairs(motors) do
		table.insert(attachedInstances, motor)
	end

	local handle = {
		Id = attachmentId,
		OwnerModel = ownerModel,
		Instances = attachedInstances,
	}
	self._handles[attachmentId] = handle
	return Ok(handle)
end

function EquipmentAttachmentService:_FindRightArm(ownerModel: Model): BasePart?
	for _, partName in ipairs(RIGHT_ARM_NAMES) do
		local part = ownerModel:FindFirstChild(partName, true)
		if part ~= nil and part:IsA("BasePart") then
			return part
		end
	end

	return nil
end

return EquipmentAttachmentService
