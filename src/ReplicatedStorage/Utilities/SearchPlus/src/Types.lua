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
	ScopePath: { string }?,
	ScopeSelector: string?,
	ScopeRecursive: boolean?,
	ScopeMaxDepth: number?,
	IncludeScopeRoot: boolean?,

	Recursive: boolean?,
	MaxDepth: number?,
	IncludeRoot: boolean?,

	Name: string?,
	Names: { string }?,
	CaseInsensitiveName: boolean?,
	ClassName: string?,
	ClassNames: { string }?,
	IsA: string?,
	IsAAny: { string }?,
	Attributes: { [string]: any }?,
	Tags: { string }?,
	TagsAny: { string }?,
	Instances: { Instance }?,
	ExcludeInstances: { Instance }?,
	AncestorOf: Instance?,
	DescendantOf: Instance?,
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
	ScopePath: { string }?,
	ScopeSelector: string?,
	ScopeRecursive: boolean,
	ScopeMaxDepth: number?,
	IncludeScopeRoot: boolean,

	Recursive: boolean,
	MaxDepth: number?,
	IncludeRoot: boolean,

	Name: string?,
	Names: { string }?,
	CaseInsensitiveName: boolean,
	ClassName: string?,
	ClassNames: { string }?,
	IsA: string?,
	IsAAny: { string }?,
	Attributes: { [string]: any }?,
	Tags: { string }?,
	TagsAny: { string }?,
	Instances: { Instance }?,
	ExcludeInstances: { Instance }?,
	AncestorOf: Instance?,
	DescendantOf: Instance?,
	Predicate: ((Instance) -> boolean)?,
	ExcludeAttributes: { [string]: any }?,
	ExcludeTags: { string }?,
	ExcludePredicate: ((Instance) -> boolean)?,
}

local Types = {}

return Types
