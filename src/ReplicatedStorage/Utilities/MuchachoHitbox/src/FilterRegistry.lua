--!strict

local RunService = game:GetService("RunService")

local ROOT_FOLDER_NAME = "MuchachoHitboxParallelFilters"
local FILTERED_INSTANCES_FOLDER_NAME = "Instances"
local FILTER_TYPE_ATTRIBUTE = "FilterType"
local COLLISION_GROUP_ATTRIBUTE = "CollisionGroup"
local RESPECT_CAN_COLLIDE_ATTRIBUTE = "RespectCanCollide"
local MAX_PARTS_ATTRIBUTE = "MaxParts"

local ServerStorage = if RunService:IsServer() then game:GetService("ServerStorage") else nil

local FilterRegistry = {}

local function _GetRootFolder(): Folder?
	if ServerStorage == nil then
		return nil
	end

	local existing = ServerStorage:FindFirstChild(ROOT_FOLDER_NAME)
	if existing ~= nil then
		if existing:IsA("Folder") then
			return existing
		end

		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = ROOT_FOLDER_NAME
	folder.Parent = ServerStorage
	return folder
end

local function _GetOrCreateTokenFolder(token: string): Folder?
	local rootFolder = _GetRootFolder()
	if rootFolder == nil then
		return nil
	end

	local existing = rootFolder:FindFirstChild(token)
	if existing ~= nil then
		if existing:IsA("Folder") then
			return existing
		end

		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = token
	folder.Parent = rootFolder
	return folder
end

local function _GetOrCreateFilteredInstancesFolder(tokenFolder: Folder): Folder
	local existing = tokenFolder:FindFirstChild(FILTERED_INSTANCES_FOLDER_NAME)
	if existing ~= nil then
		if existing:IsA("Folder") then
			return existing
		end

		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FILTERED_INSTANCES_FOLDER_NAME
	folder.Parent = tokenFolder
	return folder
end

local function _ApplyFilterInstances(instancesFolder: Folder, filterInstances: { Instance })
	local existingValues = instancesFolder:GetChildren()
	local resolvedCount = #filterInstances

	for index, instance in ipairs(filterInstances) do
		local current = existingValues[index]
		local objectValue = if current ~= nil and current:IsA("ObjectValue") then current else nil
		if objectValue == nil then
			if current ~= nil then
				current:Destroy()
			end

			objectValue = Instance.new("ObjectValue")
			objectValue.Name = tostring(index)
			objectValue.Parent = instancesFolder
		end

		objectValue.Name = tostring(index)
		objectValue.Value = instance
	end

	for index = resolvedCount + 1, #existingValues do
		existingValues[index]:Destroy()
	end
end

local function _ReadFilterInstances(instancesFolder: Folder?): { Instance }
	if instancesFolder == nil then
		return {}
	end

	local resolvedInstances = {}
	local objectValues = {}

	for _, child in ipairs(instancesFolder:GetChildren()) do
		if child:IsA("ObjectValue") then
			table.insert(objectValues, child)
		end
	end

	table.sort(objectValues, function(left: ObjectValue, right: ObjectValue)
		return tonumber(left.Name) < tonumber(right.Name)
	end)

	for _, objectValue in ipairs(objectValues) do
		local value = objectValue.Value
		if value ~= nil then
			table.insert(resolvedInstances, value)
		end
	end

	return resolvedInstances
end

function FilterRegistry.SupportsParallelOverlapParams(overlapParams: OverlapParams?): boolean
	if not RunService:IsServer() then
		return false
	end

	return overlapParams ~= nil
end

function FilterRegistry.SyncOverlapParams(token: string, overlapParams: OverlapParams?): string?
	if not FilterRegistry.SupportsParallelOverlapParams(overlapParams) then
		return nil
	end

	local tokenFolder = _GetOrCreateTokenFolder(token)
	if tokenFolder == nil or overlapParams == nil then
		return nil
	end

	tokenFolder:SetAttribute(FILTER_TYPE_ATTRIBUTE, overlapParams.FilterType.Value)
	tokenFolder:SetAttribute(COLLISION_GROUP_ATTRIBUTE, overlapParams.CollisionGroup)
	tokenFolder:SetAttribute(RESPECT_CAN_COLLIDE_ATTRIBUTE, overlapParams.RespectCanCollide)
	tokenFolder:SetAttribute(MAX_PARTS_ATTRIBUTE, overlapParams.MaxParts)

	local instancesFolder = _GetOrCreateFilteredInstancesFolder(tokenFolder)
	_ApplyFilterInstances(instancesFolder, overlapParams.FilterDescendantsInstances)

	return token
end

function FilterRegistry.ResolveOverlapParams(token: string?): OverlapParams?
	if ServerStorage == nil or type(token) ~= "string" or token == "" then
		return nil
	end

	local rootFolder = _GetRootFolder()
	if rootFolder == nil then
		return nil
	end

	local tokenFolder = rootFolder:FindFirstChild(token)
	if tokenFolder == nil or not tokenFolder:IsA("Folder") then
		return nil
	end

	local filterTypeValue = tokenFolder:GetAttribute(FILTER_TYPE_ATTRIBUTE)
	local collisionGroup = tokenFolder:GetAttribute(COLLISION_GROUP_ATTRIBUTE)
	local respectCanCollide = tokenFolder:GetAttribute(RESPECT_CAN_COLLIDE_ATTRIBUTE)
	local maxParts = tokenFolder:GetAttribute(MAX_PARTS_ATTRIBUTE)
	if type(filterTypeValue) ~= "number" then
		return nil
	end

	local resolvedFilterType = nil
	for _, item in ipairs(Enum.RaycastFilterType:GetEnumItems()) do
		if item.Value == filterTypeValue then
			resolvedFilterType = item
			break
		end
	end
	if resolvedFilterType == nil then
		return nil
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = resolvedFilterType
	overlapParams.FilterDescendantsInstances = _ReadFilterInstances(
		tokenFolder:FindFirstChild(FILTERED_INSTANCES_FOLDER_NAME) :: Folder?
	)

	if type(collisionGroup) == "string" then
		overlapParams.CollisionGroup = collisionGroup
	end
	if type(respectCanCollide) == "boolean" then
		overlapParams.RespectCanCollide = respectCanCollide
	end
	if type(maxParts) == "number" then
		overlapParams.MaxParts = maxParts
	end

	return overlapParams
end

function FilterRegistry.RemoveToken(token: string?)
	if ServerStorage == nil or type(token) ~= "string" or token == "" then
		return
	end

	local rootFolder = _GetRootFolder()
	if rootFolder == nil then
		return
	end

	local tokenFolder = rootFolder:FindFirstChild(token)
	if tokenFolder ~= nil then
		tokenFolder:Destroy()
	end
end

return table.freeze(FilterRegistry)
