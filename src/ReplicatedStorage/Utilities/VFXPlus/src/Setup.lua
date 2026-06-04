--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RenderAssetAccess = require(ReplicatedStorage.Contexts.Render.RenderAssetAccess)
local Result = require(ReplicatedStorage.Utilities.Result)

local Enums = require(script.Parent.Enums)
local Specs = require(script.Parent.Specs)
local Types = require(script.Parent.Types)

type TRuntimeFolderOptions = Types.TRuntimeFolderOptions
type TVFXRegistry = Types.TVFXRegistry

local DEFAULT_RUNTIME_FOLDER_NAME = "Effects"

local Setup = {}

local function _CreateEffectRegistryAdapter(effectsFolder: Folder): TVFXRegistry
	return {
		SkillEffectExists = function(_self, effectKey: string): boolean
			return RenderAssetAccess.SkillEffectExists(effectKey, {
				Root = effectsFolder,
			})
		end,
		GetSkillEffect = function(_self, effectKey: string): Folder | Model
			return RenderAssetAccess.GetSkillEffect(effectKey, {
				Root = effectsFolder,
			}) :: Folder | Model
		end,
		StatusEffectExists = function(_self, effectKey: string): boolean
			return RenderAssetAccess.StatusEffectExists(effectKey, {
				Root = effectsFolder,
			})
		end,
		GetStatusEffect = function(_self, effectKey: string): Folder | Model
			return RenderAssetAccess.GetStatusEffect(effectKey, {
				Root = effectsFolder,
			}) :: Folder | Model
		end,
	}
end

local function _BuildRuntimeFolderConflict(name: string): Result.Result<Folder>
	return Result.Err(
		Enums.ErrorKey.RuntimeFolderConflict.Name,
		Enums.ErrorMessage[Enums.ErrorKey.RuntimeFolderConflict],
		{
			Name = name,
		}
	)
end

function Setup.EnsureRuntimeFolder(
	parent: Instance?,
	name: string?,
	options: TRuntimeFolderOptions?
): Result.Result<Folder>
	local validationParentResult = Specs.HasValidRuntimeParentSpec:IsSatisfiedBy({
		Parent = parent,
	})
	if not validationParentResult.success then
		return validationParentResult :: any
	end

	local validationNameResult = Specs.HasValidRuntimeFolderNameSpec:IsSatisfiedBy({
		Name = name,
	})
	if not validationNameResult.success then
		return validationNameResult :: any
	end

	local resolvedParent = parent or Workspace
	local resolvedName = name or DEFAULT_RUNTIME_FOLDER_NAME
	local existing = resolvedParent:FindFirstChild(resolvedName)

	if existing ~= nil and existing:IsA("Folder") then
		return Result.Ok(existing :: Folder)
	end

	if existing ~= nil then
		if options == nil or options.ReplaceInvalid ~= true then
			return _BuildRuntimeFolderConflict(resolvedName)
		end

		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = resolvedName
	folder.Parent = resolvedParent

	return Result.Ok(folder)
end

function Setup.CreateEffectRegistry(effectsFolder: Folder): Result.Result<TVFXRegistry>
	local folderValidationResult = Specs.HasValidEffectsFolderSpec:IsSatisfiedBy({
		EffectsFolder = effectsFolder,
	})
	if not folderValidationResult.success then
		return folderValidationResult :: any
	end

	local ok, registryOrError = pcall(function()
		return _CreateEffectRegistryAdapter(effectsFolder)
	end)
	if not ok then
		return Result.Err(
			Enums.ErrorKey.RegistryCreateFailed.Name,
			Enums.ErrorMessage[Enums.ErrorKey.RegistryCreateFailed],
			{
				Error = tostring(registryOrError),
			}
		)
	end

	if not Specs.IsValidRegistry(registryOrError) then
		return Result.Err(
			Enums.ErrorKey.RegistryCreateFailed.Name,
			Enums.ErrorMessage[Enums.ErrorKey.RegistryCreateFailed]
		)
	end

	return Result.Ok(registryOrError)
end

return table.freeze(Setup)
