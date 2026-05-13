--!strict

local Builder = require(script.Builder)
local Element = require(script.Element)
local Enums = require(script.Enums)
local Types = require(script.Types)

export type TProps = Types.TProps
export type TElement = Types.TElement
export type TChild = Types.TChild
export type TChildren = Types.TChildren

local InstancePlus = {
	ErrorKey = Enums.ErrorKey,
}

function InstancePlus.new(className: string, props: Types.TProps?, children: Types.TChildren?): Instance
	return Builder.Build(className, props, children)
end

function InstancePlus.Element(className: string, props: Types.TProps?, children: Types.TChildren?): Types.TElement
	return Element.Create(className, props, children)
end

return table.freeze(InstancePlus)
