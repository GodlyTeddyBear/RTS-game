local class    = require(script.Parent.Parent.middleclass)
local Registry = require(script.Parent.Parent.registry)
local Node     = require(script.Parent.node)
local Decorator = class('Decorator', Node)

function Decorator:initialize(config)
  Node.initialize(self, config)
  self.node = Registry.getNode(self.node)
end

function Decorator:setNode(node)
  self.node = Registry.getNode(node)
end

function Decorator:start(object)
  self.node:start(object)
end

function Decorator:finish(object)
  self.node:finish(object)
end

function Decorator:run(object)
  self.node:setControl(self)
  self.node:call_run(object)
end

return Decorator
