//NS2 Vote Random Teams

kDAKRevisions["VoteRandom"] = 1.2
local kVoteRandomTeamsEnabled = false

local RandomNewRoundDelay = 15
local RandomVotes = { }
local RandomDuration = 0
local RandomRoundRecentlyEnded = 0

if kDAKConfig._VoteRandom then

	local function LoadVoteRandom()

		if kDAKSettings.RandomEnabledTill ~= nil then
			if kDAKSettings.RandomEnabledTill > Shared.GetSystemTime() then
				kVoteRandomTeamsEnabled = not kDAKConfig.kVoteRandomInstantly
				Shared.Message(string.format("VoteRandom set to %s", ToString(kVoteRandomTeamsEnabled)))
				EnhancedLog(string.format("VoteRandom set to %s", ToString(kVoteRandomTeamsEnabled)))
			else
				kVoteRandomTeamsEnabled = false
			end
		else
			kDAKSettings.RandomEnabledTill = 0
		end
	end

	LoadVoteRandom()
	
	local function ShuffleTeams(ShuffleAllPlayers)
		local playerList = ShufflePlayerList()
		
		for i = 1, (#playerList) do
			if ShuffleAllPlayers or playerList[i]:GetTeamNumber() == 0 then
				local teamnum = math.fmod(i,2) + 1
				//Trying just making team decision based on position in array.. two randoms seems to somehow result in similar teams..
				GetGamerules():JoinTeam(playerList[i], teamnum)
			end
		end
	end	

	local function UpdateRandomVotes(silent, playername)

		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		local totalvotes = 0
		
		for i = #RandomVotes, 1, -1 do
			local clientid = RandomVotes[i]
			local stillplaying = false
			
			for _, player in ientitylist(playerRecords) do
				if player ~= nil then
					local client = Server.GetOwner(player)
					if client ~= nil then
						if clientid == client:GetUserId() then
							stillplaying = true
							totalvotes = totalvotes + 1
							break
						end
					end					
				end
			end
			
			if not stillplaying then
				table.remove(RandomVotes, i)
			end
		
		end
		
		if totalvotes >= math.ceil((playerRecords:GetSize() * (kDAKConfig.kVoteRandomMinimumPercentage / 100))) then
		
			RandomVotes = { }
			
			if kDAKConfig.kVoteRandomInstantly then
				chatMessage = string.sub(string.format("Random teams have been enabled, the round will restart."), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				if Server then
					Shared.ConsoleCommand("sv_rrall")
					Shared.ConsoleCommand("sv_reset")
					ShuffleTeams(true)
				end
			else
				chatMessage = string.sub(string.format("Random teams have been enabled for the next %s Minutes", kDAKConfig.kVoteRandomDuration), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				kDAKSettings.RandomEnabledTill = Shared.GetSystemTime() + (kDAKConfig.kVoteRandomDuration * 60)
				SaveDAKSettings()
				kVoteRandomTeamsEnabled = true
			end
			
		elseif not silent then
		
			chatMessage = string.sub(string.format("%s voted for random teams. (%s votes, needed %s).", playername, totalvotes, math.ceil((playerRecords:GetSize() * (kDAKConfig.kVoteRandomMinimumPercentage / 100)))), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
		end
		return true
		
	end
	
	table.insert(kDAKOnClientDisconnect, function(client) return UpdateRandomVotes(true, "") end)

	local function VoteRandomClientConnect(client)

		if client ~= nil then
			local player = client:GetControllingPlayer()
		
			if player ~= nil and kVoteRandomTeamsEnabled then 
				chatMessage = string.sub(string.format("Random teams are enabled, you are being randomed to a team."), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				JoinRandomTeam(player)
			end
			return true
		end
		return false
	end
	
	table.insert(kDAKOnClientDelayedConnect, function(client) return VoteRandomClientConnect(client) end)

	local function RandomTeams()

		PROFILE("VoteRandom:RandomTeams")
		
		if kVoteRandomTeamsEnabled then
		
			local gamerules = GetGamerules()
			if gamerules:GetGameState() == kGameState.NotStarted and RandomRoundRecentlyEnded == nil then
				RandomRoundRecentlyEnded = Shared.GetTime()
				Print(ToString(RandomRoundRecentlyEnded))
			end
			if kDAKSettings.RandomEnabledTill > Shared.GetSystemTime() then
				kVoteRandomTeamsEnabled = not kDAKConfig.kVoteRandomInstantly
			else
				kVoteRandomTeamsEnabled = false
			end
			if RandomRoundRecentlyEnded ~= nil and RandomRoundRecentlyEnded + RandomNewRoundDelay < Shared.GetTime() then
				ShuffleTeams(false)
				RandomRoundRecentlyEnded = nil
			end
			
		end
		return true
	end

	table.insert(kDAKOnServerUpdate, function(deltatime) return RandomTeams() end)

	local function OnCommandVoteRandom(client)

		if client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				if kVoteRandomTeamsEnabled then
					chatMessage = string.sub(string.format("Random teams already enabled."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					return
				end
				if RandomVotes[client:GetUserId()] ~= nil then			
					chatMessage = string.sub(string.format("You already voted for random teams."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				else
					local playerRecords = Shared.GetEntitiesWithClassname("Player")
					table.insert(RandomVotes,client:GetUserId())
					RandomVotes[client:GetUserId()] = true
					Shared.Message(string.format("%s voted for random teams.", client:GetUserId()))
					EnhancedLog(string.format("%s voted for random teams.", client:GetUserId()))
					UpdateRandomVotes(false, player:GetName())
				end
			end
			
		end
		
	end

	Event.Hook("Console_voterandom",               OnCommandVoteRandom)

	local function VoteRandomOff(client)

		if kVoteRandomTeamsEnabled then
		
			kVoteRandomTeamsEnabled = false
			kDAKSettings.RandomEnabledTill = 0
			SaveDAKSettings()
			chatMessage = string.sub(string.format("Random teams have been disabled."), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			if client ~= nil then 
				local player = client:GetControllingPlayer()
				if player ~= nil then
					PrintToAllAdmins("sv_randomoff", client)
				end
			end
		end

	end

	CreateServerAdminCommand("Console_sv_randomoff", VoteRandomOff, "Turns off any currently active random teams vote.")

	local function VoteRandomOn(client)

		if kVoteRandomTeamsEnabled == false then
			
			if kDAKConfig.kVoteRandomInstantly then
				chatMessage = string.sub(string.format("Random teams have been enabled, the round will restart."), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				if Server then
					Shared.ConsoleCommand("sv_rrall")
					Shared.ConsoleCommand("sv_reset")
					ShuffleTeams(true)
				end
			else
				chatMessage = string.sub(string.format("Random teams have been enabled for the next %s Minutes", kDAKConfig.kVoteRandomDuration), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				kDAKSettings.RandomEnabledTill = Shared.GetSystemTime() + (kDAKConfig.kVoteRandomDuration * 60)
				SaveDAKSettings()
				kVoteRandomTeamsEnabled = true
			end
			if client ~= nil then 
				local player = client:GetControllingPlayer()
				if player ~= nil then
					PrintToAllAdmins("sv_randomon", client)
				end
			end
		end

	end

	CreateServerAdminCommand("Console_sv_randomon", VoteRandomOn, "Will enable random teams.")

	Shared.Message("VoteRandom Loading Complete")

end