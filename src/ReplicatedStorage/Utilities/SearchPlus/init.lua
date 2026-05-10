--!strict

--[=[
	@class SearchPlus
	Shared hierarchy-search helpers that compose exact path lookup, selector queries,
	and explicit filter-based traversal under one public package surface.
	@server
	@client
]=]

local SearchPlus = require(script.src)

--[=[
	@type TSearchOptions
	@within SearchPlus
	Request options used to resolve selector, path, or filter search mode.
]=]
export type TSearchOptions = SearchPlus.TSearchOptions

--[=[
	@type TResolvedSearchMode
	@within SearchPlus
	Normalized search mode resolved by the package policies.
]=]
export type TResolvedSearchMode = SearchPlus.TResolvedSearchMode

--[=[
	@type TResolvedSearchOptions
	@within SearchPlus
	Frozen normalized options payload consumed by internal search modules.
]=]
export type TResolvedSearchOptions = SearchPlus.TResolvedSearchOptions

return SearchPlus
