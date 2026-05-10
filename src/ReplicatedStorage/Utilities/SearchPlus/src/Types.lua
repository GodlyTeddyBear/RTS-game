--!strict

local Enums = require(script.Parent.Enums)

--[=[
	@class SearchPlusTypes
	Shared type aliases for the `SearchPlus` package surface.
	@server
	@client
]=]

export type TSearchOptions = {
	Selector: string?,
	Path: { string }?,

	Recursive: boolean?,
	MaxDepth: number?,

	Name: string?,
	CaseInsensitiveName: boolean?,
	ClassName: string?,
	IsA: string?,
	Attributes: { [string]: any }?,
	Tags: { string }?,
	Predicate: ((Instance) -> boolean)?,
	ExcludeAttributes: { [string]: any }?,
	ExcludeTags: { string }?,
	ExcludePredicate: ((Instance) -> boolean)?,
}

export type TResolvedSearchMode = typeof(Enums.SearchMode.Selector)

export type TResolvedSearchOptions = {
	Mode: TResolvedSearchMode,
	Root: Instance,

	Selector: string?,
	Path: { string }?,

	Recursive: boolean,
	MaxDepth: number?,

	Name: string?,
	CaseInsensitiveName: boolean,
	ClassName: string?,
	IsA: string?,
	Attributes: { [string]: any }?,
	Tags: { string }?,
	Predicate: ((Instance) -> boolean)?,
	ExcludeAttributes: { [string]: any }?,
	ExcludeTags: { string }?,
	ExcludePredicate: ((Instance) -> boolean)?,
}

local Types = {}

return Types
