--!strict

local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type TChildren = Types.TChildren
type TElement = Types.TElement
type TProps = Types.TProps

local Builder = {}

local function _ApplyProps(instance: Instance, props: TProps?)
	if props == nil then
		return
	end

	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
end

local function _AttachChildren(parent: Instance, children: TChildren?)
	if children == nil then
		return
	end

	for _, child in ipairs(children) do
		Policies.CheckChild(child)

		if typeof(child) == "Instance" then
			child.Parent = parent
		else
			local builtChild = Builder.BuildElement(child :: TElement)
			builtChild.Parent = parent
		end
	end
end

local function _ApplyParent(instance: Instance, props: TProps?)
	if props == nil then
		return
	end

	local parent = props.Parent
	if parent ~= nil then
		instance.Parent = parent
	end
end

function Builder.Build(className: string, props: TProps?, children: TChildren?): Instance
	Policies.CheckBuildRequest(className, props, children)

	local instance = Instance.new(className)
	_ApplyProps(instance, props)
	_AttachChildren(instance, children)
	_ApplyParent(instance, props)

	return instance
end

function Builder.BuildElement(element: TElement): Instance
	Policies.CheckElement(element.ClassName, element.Props, element.Children)
	return Builder.Build(element.ClassName, element.Props, element.Children)
end

return table.freeze(Builder)
