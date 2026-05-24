--!strict

local ServerStorage = game:GetService("ServerStorage")
local Teams = game:GetService("Teams")

local TeamService = require(ServerStorage.Utilities.TeamService)

local function clearTeams()
	for _, child in ipairs(Teams:GetChildren()) do
		child:Destroy()
	end
end

return function()
	describe("TeamService", function()
		beforeEach(function()
			clearTeams()
		end)

		afterEach(function()
			clearTeams()
		end)

		it("registers teams and returns frozen clones", function()
			local manager = TeamService.new()
			local registeredDefinition = manager:RegisterTeam({
				TeamId = "Player",
				DisplayName = "Players",
			})

			local fetchedDefinition = manager:GetTeam("Player")
			expect(registeredDefinition.TeamId).toBe("Player")
			expect(fetchedDefinition).never.toBeNil()
			expect(fetchedDefinition.TeamId).toBe("Player")
			expect(table.isfrozen(fetchedDefinition)).toBe(true)
			expect(function()
				(fetchedDefinition :: any).TeamId = "Changed"
			end).toThrow()

			manager:Destroy()
		end)

		it("keeps relationships based on primary team only when groups are present", function()
			local manager = TeamService.new()
			local playerOne = Instance.new("Player")
			local npcRoot = Instance.new("Folder")
			npcRoot:SetAttribute("TeamMemberId", "npc:wave_1_grunt_3")

			manager:RegisterTeams({
				{ TeamId = "Player" },
				{ TeamId = "Enemy" },
			})
			manager:SetRelationship("Player", "Enemy", TeamService.Relationship.Hostile)

			manager:AssignMember(playerOne, "Player")
			manager:AssignMember(npcRoot, "Enemy")
			manager:AddMemberToGroup(playerOne, "selection:1")
			manager:AddMemberToGroup(npcRoot, "selection:1")

			expect(manager:AreHostile(playerOne, npcRoot)).toBe(true)
			expect(manager:IsMemberInGroup(playerOne, "selection:1")).toBe(true)
			expect(manager:IsMemberInGroup(npcRoot, "selection:1")).toBe(true)

			manager:Destroy()
			playerOne:Destroy()
			npcRoot:Destroy()
		end)

		it("supports bulk assign and unassign behavior", function()
			local manager = TeamService.new()
			local memberA = {
				Kind = "npc",
				Id = "a",
			}
			local memberB = {
				Kind = "npc",
				Id = "b",
			}

			manager:RegisterTeam({
				TeamId = "Enemy",
			})

			expect(manager:AssignMembers({ memberA, memberB }, "Enemy")).toBe(2)
			expect(manager:GetMemberCount("Enemy")).toBe(2)
			expect(manager:UnassignMembers({ memberA, memberB })).toBe(2)
			expect(manager:GetMemberCount("Enemy")).toBe(0)

			manager:Destroy()
		end)

		it("updates team metadata and refreshes Roblox projection", function()
			local manager = TeamService.new()
			local player = Instance.new("Player")

			manager:RegisterTeam({
				TeamId = "Alpha",
				DisplayName = "Alpha Display",
				Roblox = {
					Name = "AlphaTeam",
					TeamColor = BrickColor.new("Bright blue"),
				},
			})

			manager:AssignMember(player, "Alpha")
			expect(player.Team).never.toBeNil()
			expect(player.Team.Name).toBe("AlphaTeam")

			manager:UpdateTeam("Alpha", {
				DisplayName = "Alpha Updated",
				Roblox = {
					Name = "AlphaNew",
					TeamColor = BrickColor.new("Bright red"),
					AutoAssignable = true,
				},
			})

			expect(player.Team).never.toBeNil()
			expect(player.Team.Name).toBe("AlphaNew")
			expect(player.Team.AutoAssignable).toBe(true)

			manager:Destroy()
			player:Destroy()
		end)

		it("exports and imports round-trip state with groups", function()
			local sourceManager = TeamService.new()
			local targetManager = TeamService.new()
			local member = {
				Kind = "npc",
				Id = "snapshot",
			}

			sourceManager:RegisterTeams({
				{ TeamId = "Player" },
				{ TeamId = "Enemy" },
			})
			sourceManager:SetRelationship("Player", "Enemy", TeamService.Relationship.Hostile)
			sourceManager:AssignMember(member, "Enemy")
			sourceManager:AddMemberToGroup(member, "wave:1")

			local snapshot = sourceManager:ExportState()
			local summary = targetManager:ImportState(snapshot)

			expect(summary.TeamCount).toBe(2)
			expect(summary.MemberCount).toBe(1)
			expect(summary.GroupCount).toBe(1)
			expect(targetManager:GetMemberTeam(member).TeamId).toBe("Enemy")
			expect(targetManager:IsMemberInGroup(member, "wave:1")).toBe(true)
			expect(targetManager:GetRelationshipByTeamIds("Player", "Enemy")).toBe(TeamService.Relationship.Hostile)

			sourceManager:Destroy()
			targetManager:Destroy()
		end)

		it("resolves ownership membership compatibility output", function()
			local manager = TeamService.new()
			local resolvedMembership = manager:ResolveOwnershipMembership({
				Faction = "Player",
				OwnerKind = "PlayerBase",
				OwnerId = "123",
			})

			expect(resolvedMembership.PrimaryTeamId).toBe("Player")
			expect(#resolvedMembership.GroupIds).toBe(1)
			expect(resolvedMembership.GroupIds[1]).toBe("PlayerBase:123")

			manager:Destroy()
		end)

		it("rejects invalid import data without mutating existing state", function()
			local manager = TeamService.new()

			manager:RegisterTeam({
				TeamId = "Player",
			})

			expect(function()
				manager:ImportState({
					Teams = {
						{
							TeamId = "Player",
						},
					},
					Relationships = {},
					Members = {
						{
							MemberKey = "npc:a",
							PrimaryTeamId = "Missing",
							GroupIds = {},
						},
					},
				} :: any)
			end).toThrow()

			expect(manager:HasTeam("Player")).toBe(true)
			manager:Destroy()
		end)

		it("rejects duplicate teams and team removal with active members unless forced", function()
			local manager = TeamService.new()
			local player = Instance.new("Player")

			manager:RegisterTeam({
				TeamId = "Player",
			})

			expect(function()
				manager:RegisterTeam({
					TeamId = "Player",
				})
			end).toThrow()

			manager:AssignMember(player, "Player")
			manager:AddMemberToGroup(player, "selection:1")

			expect(function()
				manager:RemoveTeam("Player")
			end).toThrow()

			local removedDefinition = manager:RemoveTeam("Player", {
				Force = true,
			})
			expect(removedDefinition.TeamId).toBe("Player")
			expect(manager:GetMemberTeam(player)).toBeNil()
			expect(manager:IsMemberInGroup(player, "selection:1")).toBe(true)

			manager:Destroy()
			player:Destroy()
		end)

		it("rejects raw instances without TeamMemberId when no custom resolver exists", function()
			local manager = TeamService.new()
			local instance = Instance.new("Folder")

			expect(function()
				manager:GetMemberKey(instance)
			end).toThrow()

			manager:Destroy()
			instance:Destroy()
		end)
	end)
end
