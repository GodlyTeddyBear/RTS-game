--!strict

local Errors = table.freeze({
	INVALID_PLAYER = "Player must be a valid Player instance.",
	INVALID_USER_ID = "User id must be a positive integer.",
	INVALID_MEMBER_HANDLE = "Team member handle must contain a valid kind and non-empty id.",
})

return Errors
