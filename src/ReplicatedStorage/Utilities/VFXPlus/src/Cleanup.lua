--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

type TVFXHandle = Types.TVFXHandle

local Cleanup = {}

function Cleanup.Schedule(handle: TVFXHandle, delaySeconds: number?): Result.Result<TVFXHandle>
	local resolvedDelay = delaySeconds or handle.Lifetime
	if type(resolvedDelay) ~= "number" or resolvedDelay <= 0 then
		return Result.Err(
			Enums.ErrorKey.InvalidLifetime.Name,
			Enums.ErrorMessage[Enums.ErrorKey.InvalidLifetime]
		)
	end

	if handle:IsDestroyed() then
		return Result.Ok(handle)
	end

	if handle.Stash:Has("AutoCleanupThread") then
		handle.Stash:RemoveAndCleanup("AutoCleanupThread")
		handle.CleanupScheduled = false
	end

	local cleanupThread = task.delay(resolvedDelay, function()
		if handle:IsDestroyed() then
			return
		end

		handle:Destroy()
	end)

	handle.Stash:AddThread(cleanupThread, {
		Key = "AutoCleanupThread",
		Label = "VFXPlusAutoCleanup",
	})
	handle.CleanupScheduled = true

	return Result.Ok(handle)
end

return table.freeze(Cleanup)
