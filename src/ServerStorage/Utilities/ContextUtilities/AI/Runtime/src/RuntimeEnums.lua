--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

-- Centralized runtime enum registries keep AI runtime status families discoverable and typo-safe.
local RuntimeEnums = {
	TreeStatus = EnumList.new("AiRuntimeTreeStatus", {
		"SkippedNoTree",
		"SkippedNotReady",
		"Ran",
		"TreeDefect",
	}),
	StartStatus = EnumList.new("AiRuntimeStartStatus", {
		"NoAction",
		"Blocked",
		"NoChange",
		"MissingAction",
		"FailedToStart",
		"Started",
		"Replaced",
	}),
	CommitStatus = EnumList.new("AiRuntimeCommitStatus", {
		"Committed",
		"Skipped",
		"InvalidResult",
	}),
	TickStatus = EnumList.new("AiRuntimeTickStatus", {
		"NoCurrentAction",
		"MissingAction",
		"Running",
		"Success",
		"Fail",
	}),
	ResolveStatus = EnumList.new("AiRuntimeResolveStatus", {
		"Resolved",
		"Skipped",
		"InvalidResult",
	}),
	CancelStatus = EnumList.new("AiRuntimeCancelStatus", {
		"NoCurrentAction",
		"MissingAction",
		"Cancelled",
	}),
	DeathStatus = EnumList.new("AiRuntimeDeathStatus", {
		"NoCurrentAction",
		"MissingAction",
		"Handled",
	}),
	CleanupStatus = EnumList.new("AiRuntimeCleanupStatus", {
		"NoCurrentAction",
		"Handled",
		"ClearedAfterFailure",
		"InvalidActorType",
	}),
	CleanupKind = EnumList.new("AiRuntimeCleanupKind", {
		"Cancel",
		"Death",
	}),
}

return table.freeze(RuntimeEnums)
