--!strict

local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type TElement = Types.TElement
type TProps = Types.TProps
type TChildren = Types.TChildren

local Element = {}

function Element.Create(className: string, props: TProps?, children: TChildren?): TElement
	Policies.CheckElement(className, props, children)

	return table.freeze({
		ClassName = className,
		Props = props,
		Children = children,
	})
end

return table.freeze(Element)
