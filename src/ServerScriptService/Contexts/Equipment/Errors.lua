--!strict

local Errors = table.freeze({
	INVALID_USER_ID = "Equipment requires a valid user id",
	INVALID_ITEM_ID = "Equipment item id is not configured",
	INVALID_SLOT_ID = "Equipment slot id is not configured",
	SLOT_MISMATCH = "Equipment item cannot be equipped in that slot",
	SLOT_OCCUPIED = "Equipment slot is already occupied",
	SLOT_EMPTY = "Equipment slot is empty",
	ITEM_NOT_OWNED = "Inventory does not contain the equipment item",
	INVALID_OWNER_KIND = "Equipment owner kind is not supported",
	INVALID_OWNER_ID = "Equipment owner id must be numeric for v1 entity owners",
	OWNER_NOT_FOUND = "Equipment owner model was not found",
	OWNER_MODEL_INVALID = "Equipment owner must resolve to a Model",
	MISSING_ASSETS_ROOT = "ReplicatedStorage.Assets is missing",
	MISSING_ASSET_FOLDER = "Equipment asset folder is missing",
	MISSING_EQUIPMENT_ASSET = "Equipment asset could not be resolved",
	NO_ACCESSORIES_IN_MODEL = "Armor and accessory equipment models must contain Accessory children",
	MISSING_TOOL_MOTORS = "Tool equipment model must contain a Motors folder",
	NO_VALID_TOOL_MOTORS = "Tool equipment model must contain at least one Motor6D",
	MISSING_RIGHT_ARM = "Tool owner model must contain RightArm, Right Arm, or RightHand",
	INVALID_TOOL_MOTOR_PART = "Tool Motor6D must have Part1 set to a BasePart inside the tool model",
	ATTACHMENT_NOT_FOUND = "Equipment attachment handle was not found",
})

return Errors
