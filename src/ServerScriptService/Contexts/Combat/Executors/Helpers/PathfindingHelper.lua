--!strict

--[[
    PathfindingHelper - Shared utility for SimplePath lifecycle management.

    Used by movement actions (Chase, Flee, Wander) to create and run SimplePath
    instances. Keeps pathfinding plumbing out of individual action files.

    RunPath returns a Promise that:
        - Resolves when Reached fires
        - Rejects  when Error or Blocked fires
        - Cleans up (Stop + Destroy) on cancel or settlement

    Callers store the returned Promise and check its status each Tick via
    Promise.Status (Started = running, Resolved = reached, Rejected = failed).
    Cancelling the Promise stops and destroys the path immediately.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SimplePath = require(ReplicatedStorage.Utilities.SimplePath)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local DEFAULT_AGENT_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
}

local PathfindingHelper = {}

--[[
    Create a SimplePath for an entity's model.
    Returns the Path instance or nil if the model is missing/invalid.
]]
function PathfindingHelper.CreatePath(entity: any, services: any, agentParams: { [string]: any }?): any?
	local npc = services.NPCEntityFactory
	local modelRef = npc:GetModelRef(entity)

	if not modelRef or not modelRef.Instance or not modelRef.Instance.PrimaryPart then
		return nil
	end

	local success, path = pcall(function()
		return SimplePath.new(modelRef.Instance, agentParams or DEFAULT_AGENT_PARAMS)
	end)

	if not success then
		return nil
	end

	path.Visualize = true
	return path
end

--[[
    Run a path to targetPosition.
    Returns a Promise that resolves on Reached, rejects on Error/Blocked,
    and stops + destroys the path on cancel or settlement.

    Promise status meanings for callers:
        Promise.Status.Started  → still navigating
        Promise.Status.Resolved → destination reached
        Promise.Status.Rejected → pathfinding failed
]]
function PathfindingHelper.RunPath(path: any, targetPosition: Vector3): any
	return Promise.new(function(resolve, reject, onCancel)
		local janitor: any? = Janitor.new()

		local function cleanup()
			if janitor then
				local j = janitor
				janitor = nil
				j:Destroy()
			end
		end

		janitor:Add(path.Reached:Connect(function()
			cleanup()
			resolve()
		end))

		janitor:Add(path.Error:Connect(function()
			cleanup()
			reject("PathError")
		end))

		janitor:Add(path.Blocked:Connect(function()
			cleanup()
			reject("PathBlocked")
		end))

		janitor:Add(function()
			pcall(function()
				if path.Status == SimplePath.StatusType.Active then
					path:Stop()
				end
			end)
			pcall(function()
				path:Destroy()
			end)
		end)

		onCancel(function()
			cleanup()
		end)

		-- Promise.try runs path:Run on a background thread (handles ComputeAsync
		-- yielding) and catches any internal SimplePath errors automatically.
		Promise.try(function()
			path:Run(targetPosition)
		end):catch(function(err)
			cleanup()
			reject(err)
		end)
	end):catch(warn)
end

return PathfindingHelper
