--!strict

local ServerStorage = game:GetService("ServerStorage")
local WorkerBootstrap = require(ServerStorage.Utilities.ParallelActors.src.WorkerBootstrap)

WorkerBootstrap.Start(script)
