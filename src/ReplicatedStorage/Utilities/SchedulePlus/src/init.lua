--!strict

local Lifecycle = require(script.Lifecycle)
local Ordering = require(script.Ordering)
local Queue = require(script.Queue)
local Timing = require(script.Timing)
local Types = require(script.Types)

export type TCancelableHandle = Types.TCancelableHandle
export type TExecutionHandle = Types.TExecutionHandle
export type TScope = Types.TScope
export type TQueueConfig<T> = Types.TQueueConfig<T>
export type TQueue<T> = Types.TQueue<T>
export type TSerialQueueConfig<T> = Types.TSerialQueueConfig<T>
export type TSerialQueue<T> = Types.TSerialQueue<T>
export type TPriorityQueueConfig<T> = Types.TPriorityQueueConfig<T>
export type TPriorityQueue<T> = Types.TPriorityQueue<T>
export type TJob<T...> = Types.TJob<T...>
export type TScheduleConfig<T...> = Types.TScheduleConfig<T...>
export type TSchedule<T...> = Types.TSchedule<T...>
export type TPipelineConfig<TContext> = Types.TPipelineConfig<TContext>
export type TPipeline<TContext> = Types.TPipeline<TContext>
export type TSequenceStep = Types.TSequenceStep
export type TSequence = Types.TSequence
export type TRateLimitConfig = Types.TRateLimitConfig
export type TTickWhenConfig = Types.TTickWhenConfig
export type TDelayUntilConfig = Types.TDelayUntilConfig
export type TCancelable = Types.TCancelable

local SchedulePlus = {}

SchedulePlus.Delay = Timing.Delay
SchedulePlus.DelayUntil = Timing.DelayUntil
SchedulePlus.NextFrame = Timing.NextFrame
SchedulePlus.AfterFrames = Timing.AfterFrames
SchedulePlus.Throttle = Timing.Throttle
SchedulePlus.ThrottleLeading = Timing.ThrottleLeading
SchedulePlus.ThrottleTrailing = Timing.ThrottleTrailing
SchedulePlus.ThrottleLeadingTrailing = Timing.ThrottleLeadingTrailing
SchedulePlus.Debounce = Timing.Debounce
SchedulePlus.DebounceLeading = Timing.DebounceLeading
SchedulePlus.DebounceTrailing = Timing.DebounceTrailing
SchedulePlus.Interval = Timing.Interval
SchedulePlus.IntervalImmediate = Timing.IntervalImmediate
SchedulePlus.Tick = Timing.Tick
SchedulePlus.TickWhen = Timing.TickWhen
SchedulePlus.Queue = Queue.Queue
SchedulePlus.SerialQueue = Queue.SerialQueue
SchedulePlus.PriorityQueue = Queue.PriorityQueue
SchedulePlus.Schedule = Ordering.Schedule
SchedulePlus.Pipeline = Ordering.Pipeline
SchedulePlus.Sequence = Ordering.Sequence
SchedulePlus.Scope = Lifecycle.Scope

SchedulePlus.Timing = {
	Delay = Timing.Delay,
	DelayUntil = Timing.DelayUntil,
	NextFrame = Timing.NextFrame,
	AfterFrames = Timing.AfterFrames,
	Interval = Timing.Interval,
	IntervalImmediate = Timing.IntervalImmediate,
	Tick = Timing.Tick,
	TickWhen = Timing.TickWhen,
	Throttle = Timing.Throttle,
	ThrottleLeading = Timing.ThrottleLeading,
	ThrottleTrailing = Timing.ThrottleTrailing,
	ThrottleLeadingTrailing = Timing.ThrottleLeadingTrailing,
	Debounce = Timing.Debounce,
	DebounceLeading = Timing.DebounceLeading,
	DebounceTrailing = Timing.DebounceTrailing,
}

SchedulePlus.Queueing = {
	Queue = Queue.Queue,
	SerialQueue = Queue.SerialQueue,
	PriorityQueue = Queue.PriorityQueue,
}

SchedulePlus.Ordering = {
	Schedule = Ordering.Schedule,
	Pipeline = Ordering.Pipeline,
	Sequence = Ordering.Sequence,
}

SchedulePlus.Lifecycle = {
	Scope = Lifecycle.Scope,
}

return SchedulePlus
