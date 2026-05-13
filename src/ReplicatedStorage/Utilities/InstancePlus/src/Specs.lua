--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Specification = require(ReplicatedStorage.Utilities.Specification)

local Enums = require(script.Parent.Enums)

local Specs = {}

local function _ErrorName(errorKey: any): string
	return errorKey.Name
end

function Specs.IsValidClassName(className: any): boolean
	return type(className) == "string" and className ~= ""
end

function Specs.IsValidProps(props: any): boolean
	return props == nil or type(props) == "table"
end

local function _IsArrayTable(children: { any }): boolean
	local count = 0

	for key in pairs(children) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end

		count += 1
	end

	for index = 1, count do
		if children[index] == nil then
			return false
		end
	end

	return true
end

function Specs.IsValidChildrenTable(children: any): boolean
	if children == nil then
		return true
	end

	return type(children) == "table" and _IsArrayTable(children)
end

function Specs.IsValidElementShape(element: any): boolean
	if type(element) ~= "table" then
		return false
	end

	return Specs.IsValidClassName(element.ClassName)
		and Specs.IsValidProps(element.Props)
		and Specs.IsValidChildrenTable(element.Children)
end

function Specs.IsValidChild(child: any): boolean
	if typeof(child) == "Instance" then
		return true
	end

	if not Specs.IsValidElementShape(child) then
		return false
	end

	return Specs.IsValidChildList(child.Children)
end

function Specs.IsValidChildList(children: any): boolean
	if not Specs.IsValidChildrenTable(children) then
		return false
	end

	if children == nil then
		return true
	end

	for _, child in ipairs(children) do
		if not Specs.IsValidChild(child) then
			return false
		end
	end

	return true
end

local HasValidClassName = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidClassName),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidClassName],
	function(candidate): boolean
		return Specs.IsValidClassName(candidate.ClassName)
	end
)

local HasValidProps = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidProps),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidProps],
	function(candidate): boolean
		return Specs.IsValidProps(candidate.Props)
	end
)

local HasValidChildren = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidChildren),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidChildren],
	function(candidate): boolean
		return Specs.IsValidChildList(candidate.Children)
	end
)

local HasValidChild = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidChild),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidChild],
	function(candidate): boolean
		return Specs.IsValidChild(candidate.Child)
	end
)

local HasValidElement = Specification.new(
	_ErrorName(Enums.ErrorKey.InvalidElement),
	Enums.ErrorMessage[Enums.ErrorKey.InvalidElement],
	function(candidate): boolean
		return Specs.IsValidElementShape(candidate.Element)
			and Specs.IsValidChildList((candidate.Element :: any).Children)
	end
)

Specs.HasValidClassNameSpec = HasValidClassName
Specs.HasValidPropsSpec = HasValidProps
Specs.HasValidChildrenSpec = HasValidChildren
Specs.HasValidChildSpec = HasValidChild
Specs.HasValidElementSpec = HasValidElement
Specs.HasValidBuildRequestSpec = Specification.All({
	HasValidClassName,
	HasValidProps,
	HasValidChildren,
})

return table.freeze(Specs)
