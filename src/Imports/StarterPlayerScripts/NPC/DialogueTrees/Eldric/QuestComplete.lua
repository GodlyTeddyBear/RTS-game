--!strict

--[[
	Eldric/QuestComplete - Post-quest dialogue tree for Eldric the Elder

	This tree is loaded when the "EldricQuestComplete" flag is true,
	demonstrating the tree swapping mechanism.
	The DialogueManager selects this variant instead of Greeting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DH = require(ReplicatedStorage.Contexts.NPC.DialogueHelpers)

return function(flagReader: (string) -> any, flagSetter: (string, any) -> (), _npcId: string)
	return DH.CreateTree({
		-- Node 1: Post-quest greeting
		DH.CreateNode("Ah, the hero returns! The village owes you a great debt for clearing those mines. You've brought peace to us all.", {
			DH.CreateOption("It was nothing.", nil, 2, "Nonsense! True courage is rare in these times."),
			DH.CreateOption("What will you do now?", nil, 3),
			DH.CreateOption("Just checking in. Take care, Eldric.", nil, -1),
		}),

		-- Node 2: Humble response
		DH.CreateNode("You are too modest. The village will remember your bravery for generations to come. If there is ever anything you need, you have only to ask.", {
			DH.CreateOption("Actually, about that map you mentioned...", function()
				local revealed = flagReader("EldricSecretRevealed")
				if revealed then
					flagSetter("EldricMapQuestStarted", true)
				end
			end, 4),
			DH.CreateOption("Thank you, Eldric. Farewell.", nil, -1),
		}),

		-- Node 3: Future plans
		DH.CreateNode("Perhaps it's time to reopen the old trade routes. With the mines safe again, merchants might return. This village could thrive once more.", {
			DH.CreateOption("I'd like to see that happen.", nil, -1, "As would I, friend. As would I."),
			DH.CreateOption("Good luck with that. I'm off to new adventures.", nil, -1, "May the road rise to meet you, adventurer."),
		}),

		-- Node 4: Map follow-up
		DH.CreateCondition(
			function()
				return flagReader("EldricSecretRevealed") == true
			end,
			DH.CreateNode("So you remember the map... Yes, I believe you've proven yourself worthy. When the time is right, I'll show you where it leads. But not today — there are preparations to make.", {
				DH.CreateOption("I understand. I'll be ready.", nil, -1),
				DH.CreateOption("Take your time, Eldric.", nil, -1),
			}),
			function()
				-- If secret wasn't revealed, show generic response
			end
		),
	})
end
