--!optimize 2
--Core.luau

local Types = require(script.Parent.Types)

local PoseController = require(script.PoseController)
local Connections = require(script.Connections)

local Core = {}
Core.__index = Core

function Core:Destroy()
	self.PoseController:Destroy()
	self.Connections:Destroy()
	
	setmetatable(self, nil)
	table.clear(self)
	self = nil
end

export type Core = typeof(Core) & {
	PoseController	: PoseController.PoseController,
	Connections		: Connections.Connections
}

local function new(rig: Model, coreAnimations: Types.AnimationsList, stateMachine: any?) : Core
	local animator = rig:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		error(`Animator not found for rig {rig}`)
	end
	
	local controller = PoseController.new(rig, coreAnimations)
	local connections = Connections.new(controller, rig, stateMachine)
	
	return setmetatable({
		_animator = animator,
		_rig = rig,
		
		PoseController = controller,
		Connections = connections
	}, Core)
end

return {
	new = new
}