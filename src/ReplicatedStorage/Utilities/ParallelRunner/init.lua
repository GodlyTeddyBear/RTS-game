--!strict

local ParallelRunner = require(script.src)

export type TResult<T> = ParallelRunner.TResult<T>
export type TFieldType = ParallelRunner.TFieldType
export type TResultField = ParallelRunner.TResultField
export type TCompiledJob = ParallelRunner.TCompiledJob
export type TDefineJobConfig = ParallelRunner.TDefineJobConfig
export type TRunnerConfig = ParallelRunner.TRunnerConfig
export type TRegisterJobConfig = ParallelRunner.TRegisterJobConfig
export type TRunRequest = ParallelRunner.TRunRequest
export type TRunOutput = ParallelRunner.TRunOutput
export type TRunPromise = ParallelRunner.TRunPromise
export type TManagedJobPolicyPreset = ParallelRunner.TManagedJobPolicyPreset
export type TManagedJobConfig = ParallelRunner.TManagedJobConfig
export type TManagedJobDispatchStatus = ParallelRunner.TManagedJobDispatchStatus
export type TManagedJobStatus = ParallelRunner.TManagedJobStatus
export type TManagedJobResult = ParallelRunner.TManagedJobResult
export type TManagedJob = ParallelRunner.TManagedJob
export type TSharedPacket = ParallelRunner.TSharedPacket
export type TSharedCompiledHandle = ParallelRunner.TSharedCompiledHandle
export type TRowFieldValidationResult = ParallelRunner.TRowFieldValidationResult
export type TSchemaRowValidationMode = ParallelRunner.TSchemaRowValidationMode
export type TSchemaRowValidationResult = ParallelRunner.TSchemaRowValidationResult
export type TSchemaRowsValidationResult = ParallelRunner.TSchemaRowsValidationResult
export type TRowApplicationResult = ParallelRunner.TRowApplicationResult
export type TRunnerRunHandle = ParallelRunner.TRunnerRunHandle
export type TRunner = ParallelRunner.TRunner

return ParallelRunner
