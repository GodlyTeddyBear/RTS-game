--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkerBootstrap = require(ReplicatedStorage.Utilities.ParallelActors.src.WorkerBootstrap)

WorkerBootstrap.Start(script)
