--!strict

local CollectionService = game:GetService("CollectionService")

export type TVisualReplacementServerBehavior = "DeleteChildren" | "MoveChildrenToTrueVisuals"
export type TVisualReplacementClientBehavior = "ClientNoOp" | "ClientRestoreFromTrueVisuals"

export type TVisualReplacementCategoryConfig = {
	CategoryId: string,
	MatchClassNames: { string },
	ServerBehavior: TVisualReplacementServerBehavior,
	ClientBehavior: TVisualReplacementClientBehavior,
}

type TCategoryConfigMap = {
	[string]: TVisualReplacementCategoryConfig,
}

local RenderVisualReplacementConfig = {}

RenderVisualReplacementConfig.HiddenFolderName = "Hidden"
RenderVisualReplacementConfig.TrueVisualsFolderName = "RenderTrueVisuals"
RenderVisualReplacementConfig.SourceAssetsRootName = "Assets"
RenderVisualReplacementConfig.VisualReplacementTagPrefix = "RenderVisualReplacement:"

RenderVisualReplacementConfig.Categories = table.freeze({
	Accessory = table.freeze({
		CategoryId = "Accessory",
		MatchClassNames = table.freeze({ "Accessory" }),
		ServerBehavior = "MoveChildrenToTrueVisuals" :: TVisualReplacementServerBehavior,
		ClientBehavior = "ClientRestoreFromTrueVisuals" :: TVisualReplacementClientBehavior,
	}),
} :: TCategoryConfigMap)

local CategoriesByMatchClassName = {}

for _, categoryConfig: TVisualReplacementCategoryConfig in RenderVisualReplacementConfig.Categories do
	for _, className in ipairs(categoryConfig.MatchClassNames) do
		CategoriesByMatchClassName[className] = categoryConfig
	end
end

RenderVisualReplacementConfig.CategoriesByMatchClassName = table.freeze(CategoriesByMatchClassName)

function RenderVisualReplacementConfig.BuildVisualReplacementTag(visualId: string): string
	return RenderVisualReplacementConfig.VisualReplacementTagPrefix .. visualId
end

function RenderVisualReplacementConfig.GetVisualReplacementId(instance: Instance): string?
	local prefix = RenderVisualReplacementConfig.VisualReplacementTagPrefix
	for _, tag in ipairs(CollectionService:GetTags(instance)) do
		if string.sub(tag, 1, #prefix) == prefix then
			local visualId = string.sub(tag, #prefix + 1)
			if visualId ~= "" then
				return visualId
			end
		end
	end

	return nil
end

function RenderVisualReplacementConfig.SetVisualReplacementId(instance: Instance, visualId: string)
	RenderVisualReplacementConfig.ClearVisualReplacementId(instance)
	CollectionService:AddTag(instance, RenderVisualReplacementConfig.BuildVisualReplacementTag(visualId))
end

function RenderVisualReplacementConfig.ClearVisualReplacementId(instance: Instance)
	local prefix = RenderVisualReplacementConfig.VisualReplacementTagPrefix
	for _, tag in ipairs(CollectionService:GetTags(instance)) do
		if string.sub(tag, 1, #prefix) == prefix then
			CollectionService:RemoveTag(instance, tag)
		end
	end
end

function RenderVisualReplacementConfig.GetCategoryConfigForInstance(
	instance: Instance
): TVisualReplacementCategoryConfig?
	for className, categoryConfig in RenderVisualReplacementConfig.CategoriesByMatchClassName do
		if instance:IsA(className) then
			return categoryConfig
		end
	end

	return nil
end

function RenderVisualReplacementConfig.RequiresClientRestore(
	categoryConfig: TVisualReplacementCategoryConfig
): boolean
	return categoryConfig.ClientBehavior == "ClientRestoreFromTrueVisuals"
end

function RenderVisualReplacementConfig.IsInAccessoryTree(instance: Instance): boolean
	local current = instance

	while current ~= nil do
		if current:IsA("Accessory") then
			return true
		end

		current = current.Parent
	end

	return false
end

return table.freeze(RenderVisualReplacementConfig)
