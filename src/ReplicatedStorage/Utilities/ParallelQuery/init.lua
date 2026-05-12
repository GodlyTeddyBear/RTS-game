--!strict

--[=[
    @class ParallelQuery
    Server-only wrapper around `Parallelizer` that manages actor setup and decodes flat task results into row tables.
    @server
]=]

local ParallelQuery = require(script.src)

--[=[
    @type TFieldType
    @within ParallelQuery
    Supported public field types for result schemas.
]=]
export type TFieldType = ParallelQuery.TFieldType

--[=[
    @type TResultField
    @within ParallelQuery
    One ordered field inside an operation result schema.
]=]
export type TResultField = ParallelQuery.TResultField

--[=[
    @type TOperationDefinition
    @within ParallelQuery
    Module contract used by worker clones and the main-thread wrapper.
]=]
export type TOperationDefinition = ParallelQuery.TOperationDefinition

--[=[
    @type TParallelQueryConfig
    @within ParallelQuery
    Construction config for a managed `ParallelQuery` runner.
]=]
export type TParallelQueryConfig = ParallelQuery.TParallelQueryConfig

--[=[
    @type TParallelQueryError
    @within ParallelQuery
    Structured failure payload emitted by `Run` and `RunAsync`.
]=]
export type TParallelQueryError = ParallelQuery.TParallelQueryError

--[=[
    @type TRunRequest
    @within ParallelQuery
    Per-run dispatch options for one registered operation.
]=]
export type TRunRequest = ParallelQuery.TRunRequest

--[=[
    @type TParallelQueryRunner
    @within ParallelQuery
    Managed runner instance that owns actors, tasks, and cleanup.
]=]
export type TParallelQueryRunner = ParallelQuery.TParallelQueryRunner

return ParallelQuery
