--!strict

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox
type THitboxRunner = Types.HitboxRunner

local internalRunnerConnection: RBXScriptConnection? = nil
local internalRunner: THitboxRunner? = nil

local Runner = {}

function Runner.Create(): THitboxRunner
	local runner = {} :: THitboxRunner
	runner._hitboxes = {}
	runner._destroyed = false

	function runner:Register(hitbox: THitbox)
		if self._destroyed then
			error("Cannot register hitbox on a destroyed MuchachoHitbox runner")
		end

		self._hitboxes[hitbox] = true
	end

	function runner:Unregister(hitbox: THitbox)
		self._hitboxes[hitbox] = nil
	end

	function runner:Step(deltaTime: number)
		if self._destroyed then
			return
		end

		for hitbox in pairs(self._hitboxes) do
			if hitbox._Runner == self then
				hitbox:Step(deltaTime)
			end
		end
	end

	function runner:Destroy()
		if self._destroyed then
			return
		end

		self._destroyed = true
		for hitbox in pairs(self._hitboxes) do
			if hitbox._Runner == self then
				hitbox._Runner = nil
			end
		end

		table.clear(self._hitboxes)
	end

	return runner
end

function Runner.GetInternal(): THitboxRunner
	if internalRunner == nil then
		internalRunner = Runner.Create()
	end

	if internalRunnerConnection == nil then
		internalRunnerConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			local runner = internalRunner
			if runner ~= nil then
				runner:Step(deltaTime)
			end
		end)
	end

	return internalRunner
end

return Runner
