--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnumList = require(ReplicatedStorage.Utilities.EnumList)

local Enums = {
	ErrorKey = EnumList.new("InstancePlusErrorKey", {
		"InvalidClassName",
		"InvalidProps",
		"InvalidChildren",
		"InvalidChild",
		"InvalidElement",
	}),
}

Enums.ErrorMessage = table.freeze({
	[Enums.ErrorKey.InvalidClassName] = "InstancePlus ClassName must be a non-empty string",
	[Enums.ErrorKey.InvalidProps] = "InstancePlus Props must be a table when provided",
	[Enums.ErrorKey.InvalidChildren] = "InstancePlus Children must be an array of Instances or valid element specs",
	[Enums.ErrorKey.InvalidChild] = "InstancePlus child must be an Instance or valid element spec",
	[Enums.ErrorKey.InvalidElement] = "InstancePlus element spec must contain a valid ClassName, optional Props table, and optional Children array",
})

return table.freeze(Enums)
