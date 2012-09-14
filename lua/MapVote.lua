//NS2 End Round map vote.
//Replaces current automatic map switching on round-end.

kDAKRevisions["MapVote"] = 1.2
local kMaxMapVoteChatLength = 74
local cycleTime = 0
local Maps = { }
local TiedMaps = { }
local VotingMaps = { }
local MapVotes = { }
local PlayerVotes = { }
local RTVVotes = { }

local mapvoteintiated = false
local mapvoterunning = false
local mapvotecomplete = false
local mapvotenotify = 0
local mapvotedelay = 0
local nextmap

local ServerAdminPath = Server.GetAdminPath()
local mapCycleFileName = "mapcycle.txt"

if kDAKConfig._MapVote then

	local function LoadMapCycle()

		cycleTime = 900 //15 Minutes
		local file
		
		if kCheckGameDirectory then
			file = io.open("game://" .. ServerAdminPath .. mapCycleFileName)
		else
			file = io.open("user://" .. ServerAdminPath .. mapCycleFileName)
		end
		
		if file then
		
			for line in file:lines() do
			
				// Trim any white space from the line
				line = line:gsub("^%s*(.-)%s*$", "%1")
				
				// Check for the form a = b
				local var, val = line:match("^([%w_]+)%s*=%s*(.+)$")
				
				if var == "min_time" then
				
					// Convert minutes to seconds
					cycleTime = tonumber(val) * 60
					
				elseif var ~= "mode" then
					table.insert(Maps, line)
				end
				
			end
			
		end

	end

	LoadMapCycle()

	function MapCycle_TestCycleMap()

		if Shared.GetTime() < cycleTime then
			// We haven't been on the current map for long enough.
			return
		end
		
		mapvoteintiated = true
		mapvotedelay = Shared.GetTime() + kDAKConfig.kVoteStartDelay
		
		chatMessage = string.sub(string.format(kDAKConfig.kVoteMapBeginning, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength)
		Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		
		chatMessage = string.sub(string.format(kDAKConfig.kVoteMapHowToVote, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength)
		Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		
	end

	local function UpdateMapVoteCountDown()

		chatMessage = string.sub(string.format(kDAKConfig.kVoteMapStarted, string.format(kDAKConfig.kVoteMinimumPercentage)), 1, kMaxChatLength)
		Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		
		VotingMaps = { }
		MapVotes = { }
		PlayerVotes= { }
		local validmaps = 1
		local recentlyplayed = false
		
		if kDAKSettings.PreviousMaps == nil then
			kDAKSettings.PreviousMaps = { }
		end
		
		if #TiedMaps > 1 then
		
			for i = 1, #TiedMaps do
						
				VotingMaps[validmaps] = TiedMaps[i]
				MapVotes[validmaps] = 0
				chatMessage = string.sub(string.format(kDAKConfig.kVoteMapMapListing, ToString(validmaps), TiedMaps[i]), 1, kMaxMapVoteChatLength) .. "******"
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				validmaps = validmaps + 1
				
			end
			
		else
			local tempMaps = { }
			
			if #kDAKSettings.PreviousMaps > kDAKConfig.kDontRepeatFor then
				for i = 1, #kDAKSettings.PreviousMaps - kDAKConfig.kDontRepeatFor do
					table.remove(kDAKSettings.PreviousMaps, i)
				end
			end
			
			for i = 1, #Maps do
			
				recentlyplayed = false
				for j = 1, #kDAKSettings.PreviousMaps do
					if Maps[i] == kDAKSettings.PreviousMaps[j] then
						recentlyplayed = true
					end				
				end

				if Maps[i] ~= tostring(Shared.GetMapName()) and not recentlyplayed then	
					table.insert(tempMaps, Maps[i])
				end
				
			end
			
			if #tempMaps < kDAKConfig.kMapsToSelect then
			
				for i = 1, (kDAKConfig.kMapsToSelect - #tempMaps) do
					if kDAKSettings.PreviousMaps[i] ~= tostring(Shared.GetMapName()) then
						table.insert(tempMaps, kDAKSettings.PreviousMaps[i])
					end
				end
			
			end
			
			if #tempMaps > 0 then
				for i = 1, 100 do //After 100 tries just give up, you failed.
				
					local map = tempMaps[math.random(1, #tempMaps)]
					if tempMaps[map] ~= true then
					
						tempMaps[map] = true
						VotingMaps[validmaps] = map
						MapVotes[validmaps] = 0
						chatMessage = string.sub(string.format(kDAKConfig.kVoteMapMapListing, ToString(validmaps), map), 1, kMaxMapVoteChatLength) .. "******"
						Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
						validmaps = validmaps + 1
						
					end
					
					if validmaps > kDAKConfig.kMapsToSelect then
						break
					end
				
				end
			else
			
				chatMessage = string.sub(string.format(kDAKConfig.kVoteMapInsufficientMaps, ToString(validmaps), map), 1, kMaxMapVoteChatLength) .. "******"
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				mapvoteintiated = false
				return
				
			end
			
		end
		
		TiedMaps = { }
		mapvoterunning = true
		mapvoteintiated = false
		mapvotedelay = Shared.GetTime() + kDAKConfig.kVotingDuration
		mapvotenotify = Shared.GetTime() + kDAKConfig.kVoteNotifyDelay

	end

	local function ProcessandSelectMap()

		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		local mapname
		local totalvotes = 0
		
		// This is cleared so that only valid players votes still in the game will count.
		MapVotes = { }
		
		for _, player in ientitylist(playerRecords) do
			
			local client = Server.GetOwner(player)
			if client ~= nil then
				if PlayerVotes[client:GetUserId()] ~= nil then
					if MapVotes[PlayerVotes[client:GetUserId()]] ~= nil then
						MapVotes[PlayerVotes[client:GetUserId()]] = MapVotes[PlayerVotes[client:GetUserId()]] + 1
					else
						MapVotes[PlayerVotes[client:GetUserId()]] = 1
					end
				end					
			end
		
		end
		
		for map, votes in pairs(MapVotes) do
			
			if votes == totalvotes then
			
				table.insert(TiedMaps, VotingMaps[map])
				
			elseif votes > totalvotes then
			
				totalvotes = votes
				mapname = VotingMaps[map]
				TiedMaps = { }
				table.insert(TiedMaps, VotingMaps[map])
				
			end

		end

		if mapname == nil then
		
			chatMessage = string.sub(string.format(kDAKConfig.kVoteMapNoWinner), 1, kMaxMapVoteChatLength) .. "******"
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			mapvotedelay = 0
			mapvotecomplete = true	
			
		elseif #TiedMaps > 1 then
		
			chatMessage = string.sub(string.format(kDAKConfig.kVoteMapTie, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength) 
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			mapvoteintiated = true
			mapvotedelay = Shared.GetTime() + kDAKConfig.kVoteStartDelay
			mapvotecomplete = false	
			mapvoterunning = false
				
		elseif totalvotes >= math.ceil(playerRecords:GetSize() * (kDAKConfig.kVoteMinimumPercentage / 100)) then
		
			chatMessage = string.sub(string.format(kDAKConfig.kVoteMapWinner, mapname, ToString(totalvotes)), 1, kMaxMapVoteChatLength) .. "******"
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			nextmap = mapname
			mapvotedelay = Shared.GetTime() + kDAKConfig.kVoteChangeDelay
			mapvotecomplete = true	
					
		elseif totalvotes < math.ceil(playerRecords:GetSize() * (kDAKConfig.kVoteMinimumPercentage / 100)) then

			chatMessage = string.sub(string.format(kDAKConfig.kVoteMapMinimumNotMet, mapname, ToString(totalvotes), ToString(math.ceil(playerRecords:GetSize() * (kDAKConfig.kVoteMinimumPercentage / 100)))), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			mapvotedelay = 0
			mapvotecomplete = true	
			
		end
		
		mapvotenotify = 0
		
		if mapvotecomplete then
			mapvoterunning = false
			mapvoteintiated = false
			
		end

	end

	local function UpdateMapVotes(deltaTime)

		PROFILE("MapVote:UpdateMapVotes")
		
		if mapvotecomplete then
			
			if Shared.GetTime() > mapvotedelay then
			
				table.insert(kDAKSettings.PreviousMaps, nextmap)
				SaveDAKSettings()
				if nextmap ~= nil then 
					Server.StartMap(nextmap)
				end
				nextmap = nil
				mapvotecomplete = false
				
			end
			
		end
		
		if mapvoteintiated then
		
			if Shared.GetTime() > mapvotedelay then
				UpdateMapVoteCountDown()
			end
			
		end
		
		if mapvoterunning then
		
			if Shared.GetTime() > mapvotedelay then
				ProcessandSelectMap()	
			elseif Shared.GetTime() > mapvotenotify then
				chatMessage = string.sub(string.format(kDAKConfig.kVoteMapTimeLeft, mapvotedelay - Shared.GetTime()), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				i = 1
				for map, votes in pairs(MapVotes) do
					chatMessage = string.sub(string.format(kDAKConfig.kVoteMapCurrentMapVotes, votes, VotingMaps[map], i), 1, kMaxMapVoteChatLength) .. "******"
					Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)			
					i = i + 1
				end
				mapvotenotify = Shared.GetTime() + kDAKConfig.kVoteNotifyDelay
				
			end

		end
		return true
	end

	table.insert(kDAKOnServerUpdate, function(deltatime) return UpdateMapVotes(deltatime) end)

	local function UpdateRTV(silent, playername)

		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		local totalvotes = 0
		
		for i = #RTVVotes, 1, -1 do
			local clientid = RTVVotes[i]
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
				table.remove(RTVVotes, i)
			end
		
		end
		
		if totalvotes >= math.ceil((playerRecords:GetSize() * (kDAKConfig.kRTVMinimumPercentage / 100))) then
		
			mapvoteintiated = true
			mapvotedelay = Shared.GetTime() + kDAKConfig.kVoteStartDelay
			
			chatMessage = string.sub(string.format(kDAKConfig.kVoteMapBeginning, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
			chatMessage = string.sub(string.format(kDAKConfig.kVoteMapHowToVote, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
			RTVVotes = { }
			
		elseif not silent then
		
			chatMessage = string.sub(string.format(kDAKConfig.kVoteMapRockTheVote, playername, totalvotes, math.ceil((playerRecords:GetSize() * (kDAKConfig.kRTVMinimumPercentage / 100)))), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
		end
		return true

	end

	table.insert(kDAKOnClientDisconnect, function(client) return UpdateRTV(true, "") end)

	local function OnCommandVote(client, mapnumber)

		local idNum = tonumber(mapnumber)
		if idNum ~= nil and mapvoterunning and client ~= nil then
			local player = client:GetControllingPlayer()
			if VotingMaps[idNum] ~= nil and player ~= nil then
				
				if PlayerVotes[client:GetUserId()] ~= nil then			
					chatMessage = string.sub(string.format("You already voted for %s.", VotingMaps[PlayerVotes[client:GetUserId()]]), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				else
					MapVotes[idNum] = MapVotes[idNum] + 1
					PlayerVotes[client:GetUserId()] = idNum
					Shared.Message(string.format("%s voted for %s", player:GetName(), VotingMaps[idNum]))
					EnhancedLog(string.format("%s voted for %s", player:GetName(), VotingMaps[idNum]))
					chatMessage = string.sub(string.format("Vote cast for %s.", VotingMaps[idNum]), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
			end
			
		end
		
	end

	Event.Hook("Console_vote",               OnCommandVote)

	local function OnCommandRTV(client)

		if client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				if mapvoterunning or mapvoteintiated or mapvotecomplete then
					chatMessage = string.sub(string.format("Map vote already running."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					return
				end
				if RTVVotes[client:GetUserId()] ~= nil then			
					chatMessage = string.sub(string.format("You already voted for a mapvote."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				else
					table.insert(RTVVotes,client:GetUserId())
					RTVVotes[client:GetUserId()] = true
					Shared.Message(string.format("%s rock'd the vote.", client:GetUserId()))
					EnhancedLog(string.format("%s rock'd the vote.", client:GetUserId()))
					UpdateRTV(false, player:GetName())
				end
			end
			
		end
		
	end

	Event.Hook("Console_rtv",               OnCommandRTV)
	Event.Hook("Console_rockthevote",               OnCommandRTV)
	
	local function OnCommandTimeleft(client)

		if client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				chatMessage = string.sub(string.format("%.1f Minutes Remaining.", math.max(0,(cycleTime - Shared.GetTime())/60)), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			end
			
		end
		
	end

	Event.Hook("Console_timeleft",               OnCommandTimeleft)

	local function StartMapVote(client)

		if client ~= nil then 		
			if mapvoterunning or mapvoteintiated or mapvotecomplete then
				local player = client:GetControllingPlayer()
				if player ~= nil then
					chatMessage = string.sub(string.format("Map vote already running."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
			
			else
			
				mapvoteintiated = true
				mapvotedelay = Shared.GetTime() + kDAKConfig.kVoteStartDelay
				
				chatMessage = string.sub(string.format(kDAKConfig.kVoteMapBeginning, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				
				chatMessage = string.sub(string.format(kDAKConfig.kVoteMapHowToVote, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				
			end
			
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_votemap", client)
			end
		end

	end

	CreateServerAdminCommand("Console_sv_votemap", StartMapVote, "Will start a map vote.")

	local function CancelMapVote(client)
	
		if client ~= nil then 
			if mapvoterunning or mapvoteintiated or mapvotecomplete then
			
				mapvotenotify = 0
				mapvotecomplete = false
				mapvoterunning = false
				mapvoteintiated = false
				mapvotedelay = 0
				VotingMaps = { }
				MapVotes = { }
				PlayerVotes= { }
				
				chatMessage = string.sub(string.format(kDAKConfig.kVoteMapCancelled, kDAKConfig.kVoteStartDelay), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, "Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
			else
			
				local player = client:GetControllingPlayer()
				if player ~= nil then
					chatMessage = string.sub(string.format("Map vote not running."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - Admin", -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
				
			end
			
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_cancelmapvote", client)
			end
		end
	end

	CreateServerAdminCommand("Console_sv_cancelmapvote", CancelMapVote, "Will cancel a map vote.")

	Shared.Message("MapVote Loading Complete")
	
end