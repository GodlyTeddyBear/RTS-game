--!strict

export type TProps = { [string]: any }

export type TElement = {
	ClassName: string,
	Props: TProps?,
	Children: TChildren?,
}

export type TChild = Instance | TElement
export type TChildren = { TChild }

local Types = {}

return Types
