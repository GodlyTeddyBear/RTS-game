--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AnimatePlayerModule = {}

local animationController = nil

local function _GetAnimationController()
	if animationController == nil then
		animationController = Knit.GetController("AnimationController")
	end

	return animationController
end

function AnimatePlayerModule.setup(character: Model, animationsFolder: Folder, context: any)
	return _GetAnimationController():SetupWithFolder(character, "Player", animationsFolder, context)
end

return AnimatePlayerModule
