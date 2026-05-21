--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

-- Centralized enum registries keep diagnostics and lifecycle labels stable across the AI package.
local Enums = {
	RegistrationKind = EnumList.new("AIRegistrationKind", {
		"Hook",
		"Action",
		"ActionPack",
		"Actor",
		"ActorBundle",
		"Behavior",
	}),
	BuildStage = EnumList.new("AIBuildStage", {
		"Collect",
		"RuntimeCreate",
		"RegisterActions",
		"RegisterActors",
		"BuildBehaviors",
		"Complete",
	}),
	BuilderState = EnumList.new("AIBuilderState", {
		"Collect",
		"Built",
		"Disposed",
	}),
	CatalogState = EnumList.new("AICatalogState", {
		"Collect",
		"Resolved",
		"Disposed",
	}),
	AssignmentSource = EnumList.new("AIAssignmentSource", {
		"Explicit",
		"ActorBundleDefault",
		"ActorTypeDefault",
		"ArchetypeDefault",
		"Fallback",
		"Missing",
	}),
}

return table.freeze(Enums)
