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
    @type TStaticOperationDefinition
    @within ParallelQuery
    Static-schema operation definition returned by the authoring helper module.
]=]
export type TStaticOperationDefinition = ParallelQuery.TStaticOperationDefinition

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

--[=[
    @type TSharedMemoryScalar
    @within ParallelQuery
    Scalar value supported by `BuildSharedMemory`.
]=]
export type TSharedMemoryScalar = ParallelQuery.TSharedMemoryScalar

--[=[
    @type TSharedMemoryArray
    @within ParallelQuery
    Array-like child table supported by `BuildSharedMemory`.
]=]
export type TSharedMemoryArray = ParallelQuery.TSharedMemoryArray

--[=[
    @type TSharedMemoryFieldValue
    @within ParallelQuery
    Root field value supported by `BuildSharedMemory`.
]=]
export type TSharedMemoryFieldValue = ParallelQuery.TSharedMemoryFieldValue

--[=[
    @type TSharedMemoryFieldMap
    @within ParallelQuery
    Root field map consumed by `BuildSharedMemory`.
]=]
export type TSharedMemoryFieldMap = ParallelQuery.TSharedMemoryFieldMap

--[=[
    @type TSharedMemorySnapshotBuilder
    @within ParallelQuery
    Mutable snapshot builder used by `ParallelQuery.SharedMemoryAuthoring`.
]=]
export type TSharedMemorySnapshotBuilder = ParallelQuery.TSharedMemorySnapshotBuilder

--[=[
    @type TManagedAsyncResult
    @within ParallelQuery
    Reusable async result payload for opt-in state helpers.
]=]
export type TManagedAsyncResult = ParallelQuery.TManagedAsyncResult

--[=[
    @type TManagedAsyncState
    @within ParallelQuery
    Reusable async request state for opt-in state helpers.
]=]
export type TManagedAsyncState = ParallelQuery.TManagedAsyncState

--[=[
    @type TManagedDispatchStatus
    @within ParallelQuery
    Status returned by `BeginManagedRequest`.
]=]
export type TManagedDispatchStatus = ParallelQuery.TManagedDispatchStatus

--[=[
    @type TManagedCompletionStatus
    @within ParallelQuery
    Status returned by `CompleteManagedRequest`.
]=]
export type TManagedCompletionStatus = ParallelQuery.TManagedCompletionStatus

--[=[
    @type TManagedConsumeStatus
    @within ParallelQuery
    Status returned by `ConsumeLatestManagedResult`.
]=]
export type TManagedConsumeStatus = ParallelQuery.TManagedConsumeStatus

--[=[
    @type TManagedJobPolicyPreset
    @within ParallelQuery
    Named convenience policy preset for managed-job completion behavior.
]=]
export type TManagedJobPolicyPreset = ParallelQuery.TManagedJobPolicyPreset

--[=[
    @type TManagedJobPolicyConfig
    @within ParallelQuery
    Managed-job policy config used to select a named preset.
]=]
export type TManagedJobPolicyConfig = ParallelQuery.TManagedJobPolicyConfig

--[=[
    @type TManagedJobDispatchStatus
    @within ParallelQuery
    Status returned by managed job `Dispatch`.
]=]
export type TManagedJobDispatchStatus = ParallelQuery.TManagedJobDispatchStatus

--[=[
    @type TManagedJobConfig
    @within ParallelQuery
    Config used by `CreateManagedJob` to bind one operation to ergonomic dispatch helpers.
]=]
export type TManagedJobConfig = ParallelQuery.TManagedJobConfig

--[=[
    @type TManagedJobResult
    @within ParallelQuery
    Completed managed job result returned by `PollCompleted`.
]=]
export type TManagedJobResult = ParallelQuery.TManagedJobResult

--[=[
    @type TManagedJob
    @within ParallelQuery
    Operation-bound managed job created from a `ParallelQuery` runner.
]=]
export type TManagedJob = ParallelQuery.TManagedJob

--[=[
    @type TRowFieldValidationResult
    @within ParallelQuery
    Structural validation result for one decoded result row.
]=]
export type TRowFieldValidationResult = ParallelQuery.TRowFieldValidationResult

--[=[
    @type TSchemaRowValidationMode
    @within ParallelQuery
    Schema validation mode for decoded rows.
]=]
export type TSchemaRowValidationMode = ParallelQuery.TSchemaRowValidationMode

--[=[
    @type TSchemaRowValidationResult
    @within ParallelQuery
    Validation result for one decoded row checked against a result schema.
]=]
export type TSchemaRowValidationResult = ParallelQuery.TSchemaRowValidationResult

--[=[
    @type TSchemaRowsValidationResult
    @within ParallelQuery
    Batch validation summary for decoded rows checked against a result schema.
]=]
export type TSchemaRowsValidationResult = ParallelQuery.TSchemaRowsValidationResult

--[=[
    @type TMemoryFieldValidationResult
    @within ParallelQuery
    Structural validation result for cached shared memory.
]=]
export type TMemoryFieldValidationResult = ParallelQuery.TMemoryFieldValidationResult

--[=[
    @type TRowApplicationResult
    @within ParallelQuery
    Summary returned by canonical row-application helpers.
]=]
export type TRowApplicationResult = ParallelQuery.TRowApplicationResult

--[=[
    @type TReductionSummary
    @within ParallelQuery
    Summary returned by row reduction helpers.
]=]
export type TReductionSummary = ParallelQuery.TReductionSummary

--[=[
    @type TParallelQueryProfileCounters
    @within ParallelQuery
    Generic runner or managed-job debug counters for `ParallelQuery` profiling.
]=]
export type TParallelQueryProfileCounters = ParallelQuery.TParallelQueryProfileCounters

--[=[
    @type TParallelQueryOperationProfileSnapshot
    @within ParallelQuery
    One operation profile snapshot inside a runner profile report.
]=]
export type TParallelQueryOperationProfileSnapshot = ParallelQuery.TParallelQueryOperationProfileSnapshot

--[=[
    @type TParallelQueryProfileSnapshot
    @within ParallelQuery
    Read-only debug/profile snapshot for one runner.
]=]
export type TParallelQueryProfileSnapshot = ParallelQuery.TParallelQueryProfileSnapshot

--[=[
    @type TManagedJobProfileSnapshot
    @within ParallelQuery
    Read-only debug/profile snapshot for one managed job.
]=]
export type TManagedJobProfileSnapshot = ParallelQuery.TManagedJobProfileSnapshot

--[=[
    Canonical authoring helpers are available at runtime through:
    - `ParallelQuery.Field`
    - `ParallelQuery.RowDefaults`
    - `ParallelQuery.Operation`

    Use raw operation tables when schema shape is dynamic at runtime.
    Use the helper modules when the operation has a static schema and you want less boilerplate for fields and empty rows.

    Canonical runtime helpers are available at runtime through:
    - `ParallelQuery.ValidationHelpers`
    - `ParallelQuery.ResultApplication`
    - `ParallelQuery.ManagedJobPolicies`
    - `ParallelQuery.ResultReduction`
    - `ParallelQuery.SharedMemoryAuthoring`

    Preferred usage patterns:
    - Use `RunAsync` when the caller wants direct Promise control and already owns request lifecycle state.
    - Use `CreateManagedJob` when the caller wants stale-result rejection, timeout expiry, and a named policy preset.
    - Put large shared arrays into cached local memory and keep request arguments to per-run scalar inputs.
    - Combine `ValidationHelpers` with `ResultApplication` for `validate -> resolve -> apply` row handling.
    - Use `ResultReduction` when validated rows should become lookup maps, grouped rows, or pair aggregates.
    - Use `SharedMemoryAuthoring` to build snapshot arrays first, then pack them through `BuildSharedMemory`.
]=]

return ParallelQuery
