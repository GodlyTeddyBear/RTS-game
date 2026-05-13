--!strict

local Specs = require(script.Parent.Specs)

local Policies = {}

local function _RaiseValidationFailure(result: any)
	error(result.message, 3)
end

local function _AssertSatisfied(result: any)
	if not result.success then
		_RaiseValidationFailure(result)
	end
end

function Policies.CheckBuildRequest(className: any, props: any, children: any)
	_AssertSatisfied(Specs.HasValidBuildRequestSpec:IsSatisfiedBy({
		ClassName = className,
		Props = props,
		Children = children,
	}))
end

function Policies.CheckElement(className: any, props: any, children: any)
	_AssertSatisfied(Specs.HasValidElementSpec:IsSatisfiedBy({
		Element = {
			ClassName = className,
			Props = props,
			Children = children,
		},
	}))
end

function Policies.CheckChild(child: any)
	_AssertSatisfied(Specs.HasValidChildSpec:IsSatisfiedBy({
		Child = child,
	}))
end

function Policies.CheckChildren(children: any)
	_AssertSatisfied(Specs.HasValidChildrenSpec:IsSatisfiedBy({
		Children = children,
	}))
end

return table.freeze(Policies)
