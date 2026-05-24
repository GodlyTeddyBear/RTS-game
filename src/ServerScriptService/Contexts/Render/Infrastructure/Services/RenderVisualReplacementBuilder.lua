--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderVisualReplacementConfig =
	require(ReplicatedStorage.Contexts.Render.Config.RenderVisualReplacementConfig)

type TVisualReplacementCategoryConfig = RenderVisualReplacementConfig.TVisualReplacementCategoryConfig

type TPreprocessAssetsOptions = {
	AssetsRoot: Folder,
	TrueVisualsRoot: Folder,
}

local RenderVisualReplacementBuilder = {}
RenderVisualReplacementBuilder.__index = RenderVisualReplacementBuilder

local function _DestroyChildren(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
end

local function _EnsureNamedFolder(parent: Instance, folderName: string): Folder
	local existingFolder = parent:FindFirstChild(folderName)
	if existingFolder ~= nil then
		assert(existingFolder:IsA("Folder"), `RenderVisualReplacementBuilder: {folderName} must be a Folder`)
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = parent
	return folder
end

local function _GetReplacementCategoryConfig(instance: Instance): TVisualReplacementCategoryConfig?
	return RenderVisualReplacementConfig.GetCategoryConfigForInstance(instance)
end

local function _MoveChildrenToTrueVisualFolder(categoryRoot: Instance, targetFolder: Folder)
	_DestroyChildren(targetFolder)

	for _, child in ipairs(categoryRoot:GetChildren()) do
		child.Parent = targetFolder
	end

	local handle = targetFolder:FindFirstChild("Handle")
	if handle ~= nil and handle:IsA("BasePart") then
		for _, descendant in ipairs(handle:GetDescendants()) do
			if descendant:IsA("Weld") or descendant:IsA("WeldConstraint") or descendant:IsA("ManualWeld") then
				descendant:Destroy()
			end
		end
	end
end

local function _EnsureTrueVisualFolder(root: Folder, visualId: string): Folder
	return _EnsureNamedFolder(root, visualId)
end

function RenderVisualReplacementBuilder.new()
	local self = setmetatable({}, RenderVisualReplacementBuilder)
	return self
end

function RenderVisualReplacementBuilder:EnsureTrueVisualsRoot(): Folder
	local trueVisualsRoot = _EnsureNamedFolder(
		ReplicatedStorage,
		RenderVisualReplacementConfig.TrueVisualsFolderName
	)
	_DestroyChildren(trueVisualsRoot)
	return trueVisualsRoot
end

function RenderVisualReplacementBuilder:PreprocessAssets(options: TPreprocessAssetsOptions)
	local assetsRoot = options.AssetsRoot
	local trueVisualsRoot = options.TrueVisualsRoot

	local function visit(instance: Instance)
		local categoryConfig = _GetReplacementCategoryConfig(instance)
		if categoryConfig ~= nil then
			self:_ProcessCategoryRoot(instance, categoryConfig, trueVisualsRoot)
			return
		end

		for _, child in ipairs(instance:GetChildren()) do
			visit(child)
		end
	end

	visit(assetsRoot)
end

function RenderVisualReplacementBuilder:_ProcessCategoryRoot(
	categoryRoot: Instance,
	categoryConfig: TVisualReplacementCategoryConfig,
	trueVisualsRoot: Folder
)
	if #categoryRoot:GetChildren() == 0 then
		return
	end

	if categoryConfig.ServerBehavior == "DeleteChildren" then
		_DestroyChildren(categoryRoot)
		return
	end

	local visualId = HttpService:GenerateGUID(false)
	local trueVisualFolder = _EnsureTrueVisualFolder(trueVisualsRoot, visualId)

	_MoveChildrenToTrueVisualFolder(categoryRoot, trueVisualFolder)
	RenderVisualReplacementConfig.SetVisualReplacementId(categoryRoot, visualId)
end

return RenderVisualReplacementBuilder
