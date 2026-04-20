local class     = require(script.Parent.Parent.middleclass)
local Decorator = require(script.Parent.decorator)
local InvertDecorator = class('InvertDecorator', Decorator)

function InvertDecorator:success()
  self.control:fail()
end

function InvertDecorator:fail()
  self.control:success()
end

return InvertDecorator
