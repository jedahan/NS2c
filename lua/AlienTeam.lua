// ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =====
//
// lua\AlienTeam.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
//                  Max McGuire (max@unknownworlds.com)
//
// This class is used for teams that are actually playing the game, e.g. Marines or Aliens.
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/TechData.lua")
Script.Load("lua/Skulk.lua")
Script.Load("lua/PlayingTeam.lua")
Script.Load("lua/UpgradeStructureManager.lua")

class 'AlienTeam' (PlayingTeam)

// Innate alien regeneration
AlienTeam.kAutoHealInterval = 2
AlienTeam.kStructureAutoHealInterval = 0.5
AlienTeam.kAutoHealUpdateNum = 20 // number of structures to update per autoheal update
AlienTeam.kSpawnScanInterval = 2
AlienTeam.kOrganicStructureHealRate = 0.02     // Health per second

AlienTeam.kPingSound = PrecacheAsset("sound/NS2.fev/ambient/feild_walkthrough")

// only update every second to not stress the server too much
AlienTeam.kAlienSpectatorUpdateIntervall = 1

AlienTeam.kSupportingStructureClassNames = {[kTechId.Hive] = {"Hive"} }
AlienTeam.kUpgradeStructureClassNames = {[kTechId.Crag] = {"Crag"}, [kTechId.Shift] = {"Shift"}, [kTechId.Shade] = {"Shade"} }

AlienTeam.kTechTreeIdsToUpdate = {}

function AlienTeam:GetTeamType()
    return kAlienTeamType
end

function AlienTeam:GetIsAlienTeam()
    return true
end

function AlienTeam:Initialize(teamName, teamNumber)

    PlayingTeam.Initialize(self, teamName, teamNumber)
    
    self.respawnEntity = Skulk.kMapName

    // List stores all the structures owned by builder player types such as the Gorge.
    // This list stores them based on the player platform ID in order to maintain structure
    // counts even if a player leaves and rejoins a server.
    self.clientOwnedStructures = { }
    self.lastAutoHealIndex = 1
    
    self.updateAlienArmorInTicks = nil
    
    self.timeLastSpawnCheck = 0
    self.overflowres = 0
    self.lastOverflowCheck = 0
    self.cloakables = {}
    self.cloakableCloakCount = {}
    
end

function AlienTeam:OnInitialized()

    PlayingTeam.OnInitialized(self)    

    self.timeLastAlienSpectatorCheck = 0
    self.lastPingOfDeathCheck = 0
    self.lastAutoHealIndex = 1
    self.timeLastWave = nil
    self.overflowres = 0
    self.clientOwnedStructures = { }
    self.lastOverflowCheck = 0
    self.cloakables = {}
    self.cloakableCloakCount = {}

end

function AlienTeam:GetTeamInfoMapName()
    return AlienTeamInfo.kMapName
end

local function RemoveGorgeStructureFromClient(self, techId, clientId)

    local structureTypeTable = self.clientOwnedStructures[clientId]
    
    if structureTypeTable then
    
        if not structureTypeTable[techId] then
        
            structureTypeTable[techId] = { }
            return
            
        end    
        
        local removeIndex = 0
        local structure = nil
        for index, id in ipairs(structureTypeTable[techId])  do
        
            if id then
            
                removeIndex = index
                structure = Shared.GetEntity(id)
                break
                
            end
            
        end
        
        if structure then
        
            table.remove(structureTypeTable[techId], removeIndex)
            structure.consumed = true
            structure:Kill()
            
        end
        
    end
    
end

function AlienTeam:AddGorgeStructure(player, structure)

    if player ~= nil and structure ~= nil then
    
        local clientId = Server.GetOwner(player):GetUserId()
        local structureId = structure:GetId()
        local techId = structure:GetTechId()
        
        if not self.clientOwnedStructures[clientId] then
            self.clientOwnedStructures[clientId] = { }
        end
        
        local structureTypeTable = self.clientOwnedStructures[clientId]
        
        if not structureTypeTable[techId] then
            structureTypeTable[techId] = { }
        end
        
        table.insertunique(structureTypeTable[techId], structureId)
               
    end
    
end

function AlienTeam:GetDroppedGorgeStructures(player, techId)

    local owner = Server.GetOwner(player)

    if owner then
    
        local clientId = owner:GetUserId()
        local structureTypeTable = self.clientOwnedStructures[clientId]
        
        if structureTypeTable then
            return structureTypeTable[techId]
        end
    
    end
    
end

function AlienTeam:GetNumDroppedGorgeStructures(player, techId)

    local structureTypeTable = self:GetDroppedGorgeStructures(player, techId)
    return (not structureTypeTable and 0) or #structureTypeTable
    
end

function AlienTeam:UpdateClientOwnedStructures(oldEntityId)

    if oldEntityId then
    
        for clientId, structureTypeTable in pairs(self.clientOwnedStructures) do
        
            for techId, structureList in pairs(structureTypeTable) do
            
                for i, structureId in ipairs(structureList) do
                
                    if structureId == oldEntityId then
                    
                        if newEntityId then
                            structureList[i] = newEntityId
                        else
                        
                            table.remove(structureList, i)
                            break
                            
                        end
                        
                    end
                    
                end
                
            end
            
        end
        
    end

end

function AlienTeam:OnEntityChange(oldEntityId, newEntityId)

    // Check if the oldEntityId matches any client's built structure and
    // handle the change.
    
    self:UpdateClientOwnedStructures(oldEntityId)
    self:UpdateCloakablesChanged(oldEntityId, newEntityId)
    
end

function AlienTeam:SpawnInitialStructures(techPoint)

    local tower, hive = PlayingTeam.SpawnInitialStructures(self, techPoint)
        
    return tower, hive
    
end

function AlienTeam:GetHasAbilityToRespawn()

    local hives = GetEntitiesForTeam("Hive", self:GetTeamNumber())
    return table.count(hives) > 0
    
end

function AlienTeam:GetOverflowResources()
    return self.overflowres
end

function AlienTeam:AddOverflowResources(extraRes)
    if extraRes > 0 then
        self.overflowres = self.overflowres + (math.floor(extraRes * 100) / 100)
    end
end

function AlienTeam:DeductOverflowResources(extraRes)
    if extraRes > 0 then
        self.overflowres = self.overflowres - extraRes
    end
end

function AlienTeam:Update(timePassed)

    PROFILE("AlienTeam:Update")
    
    if self.updateAlienArmorInTicks then
    
        if self.updateAlienArmorInTicks == 0 then
        
            for index, alien in ipairs(GetEntitiesForTeam("Alien", self:GetTeamNumber())) do
                alien:UpdateArmorAmount()
            end
            
            self.updateAlienArmorInTicks = nil
        
        else
            self.updateAlienArmorInTicks = self.updateAlienArmorInTicks - 1
        end
        
    end

    PlayingTeam.Update(self, timePassed)
    
    self:UpdateTeamAutoHeal(timePassed)
    self:UpdateCloakables()
    self:UpdateRespawn()
    self:UpdatePingOfDeath()
    self:UpdateOverflowResources()
    self:UpdateHiveInformation()
    
end

function AlienTeam:UpdateOverflowResources()
    if self.lastOverflowCheck + 1 < Shared.GetTime() and self:GetPresRecipientCount() > 0 then
        if self:GetOverflowResources() > 0 then
            local overflowres = math.min(self:GetOverflowResources(), self:GetPresRecipientCount() * 100)
            self:DeductOverflowResources(overflowres)
            self:SplitPres(overflowres, true)
        end
    end
end

function AlienTeam:UpdateHiveInformation()

    if self.timeToUpdateHiveInfo == nil or Shared.GetTime() >= self.timeToUpdateHiveInfo then
        for index, hive in ipairs(GetEntitiesForTeam("Hive", self:GetTeamNumber())) do
            if hive:GetIsAlive() then
                local hiveinfo = {
                                    key = index, 
                                    location = hive:GetLocationName(), 
                                    healthpercent = (hive:GetHealth() / hive:GetMaxHealth()), 
                                    buildprogress = ConditionalValue(hive:GetIsBuilt(), 1, hive:GetBuiltFraction()),
                                    timelastdamaged = hive.lastHiveFlinchEffectTime,
                                    techId = hive:GetTechId()
                                 }
                 for index, alien in ipairs(GetEntitiesForTeam("Alien", self:GetTeamNumber())) do
                    Server.SendNetworkMessage(alien, "HiveInfo", hiveinfo, false)
                 end
            end
        end
        self.timeToUpdateHiveInfo =  Shared.GetTime() + 1
    end
    
end

function AlienTeam:OnTechTreeUpdated()

    if self.updateAlienArmor then
        
        self.updateAlienArmor = false
        self.updateAlienArmorInTicks = 100
        
    end

end

function AlienTeam:UpdatePingOfDeath()

    if not self:GetHasAbilityToRespawn() and (not GetTournamentMode or not GetTournamentMode()) and self.lastPingOfDeathCheck + kPingOfDeathDelay < Shared.GetTime() then
        for index, alien in ipairs(GetEntitiesForTeam("Alien", self:GetTeamNumber())) do
            if alien:GetIsAlive() then
                local damage = math.max(0, alien:GetMaxHealth() * (kPingOfDeathDamagePercent / 100))
                alien:TakeDamage(damage, alien, alien, alien:GetOrigin(), nil, 0, damage, kDamageType.Falling)
                StartSoundEffectForPlayer(AlienTeam.kPingSound, alien)
            end
        end
        self.lastPingOfDeathCheck = Shared.GetTime()
    end

end

// update every tick but only a small amount of structures
function AlienTeam:UpdateTeamAutoHeal(timePassed)

    PROFILE("AlienTeam:UpdateTeamAutoHeal")

    local time = Shared.GetTime()
    
    if self.timeOfLastAutoHeal == nil then
        self.timeOfLastAutoHeal = Shared.GetTime()
    end
    
    if time > (self.timeOfLastAutoHeal + AlienTeam.kStructureAutoHealInterval) then
        
        local intervalLength = time - self.timeOfLastAutoHeal
        local gameEnts = GetEntitiesWithMixinForTeam("TeamMixin", self:GetTeamNumber())
        local numEnts = table.count(gameEnts)
        local toIndex = self.lastAutoHealIndex + AlienTeam.kAutoHealUpdateNum - 1
        toIndex = ConditionalValue(toIndex <= numEnts , toIndex, numEnts)
        
        for index = self.lastAutoHealIndex, toIndex do

            local entity = gameEnts[index]
            
            // players update the auto heal on their own
            if not entity:isa("Player") then
            
                local isHealable            = entity:GetIsHealable()
                local deltaTime             = 0
                
                if not entity.timeLastAutoHeal then
                    entity.timeLastAutoHeal = Shared.GetTime()
                else
                    deltaTime = Shared.GetTime() - entity.timeLastAutoHeal
                end

                if isHealable and deltaTime > AlienTeam.kAutoHealInterval then
                    entity:AddHealth(math.max(AlienTeam.kOrganicStructureHealRate * entity:GetMaxHealth(), 1), true)
                    entity.timeLastAutoHeal = Shared.GetTime()
                end
            
            end
        
        end
        
        if self.lastAutoHealIndex + AlienTeam.kAutoHealUpdateNum >= numEnts then
            self.lastAutoHealIndex = 1
        else
            self.lastAutoHealIndex = self.lastAutoHealIndex + AlienTeam.kAutoHealUpdateNum
        end 

        self.timeOfLastAutoHeal = Shared.GetTime()

   end
    
end

function AlienTeam:InitTechTree()

    PlayingTeam.InitTechTree(self)
    
    // Gorge specific orders
    self.techTree:AddOrder(kTechId.AlienMove)
    self.techTree:AddOrder(kTechId.AlienAttack)
    //self.techTree:AddOrder(kTechId.AlienDefend)
    self.techTree:AddOrder(kTechId.AlienConstruct)
    self.techTree:AddOrder(kTechId.Heal)
        
    // Hive types
    self.techTree:AddBuildNode(kTechId.Hive,                    kTechId.None,           kTechId.None)
    self.techTree:AddBuildNode(kTechId.CragHive,                kTechId.Hive,                kTechId.None)
    self.techTree:AddBuildNode(kTechId.ShadeHive,               kTechId.Hive,                kTechId.None)
    self.techTree:AddBuildNode(kTechId.ShiftHive,               kTechId.Hive,                kTechId.None)
    self.techTree:AddBuildNode(kTechId.WhipHive,                kTechId.Hive,                kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.UpgradeToCragHive,     kTechId.Hive,                kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.UpgradeToShadeHive,    kTechId.Hive,                kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.UpgradeToShiftHive,    kTechId.Hive,                kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.UpgradeToWhipHive,     kTechId.Hive,                kTechId.None)
    self.techTree:AddSpecial(kTechId.TwoHives)
    self.techTree:AddSpecial(kTechId.ThreeHives)
    
    // Alien Structures
    self.techTree:AddBuildNode(kTechId.Harvester,                 kTechId.None,               kTechId.None)
    self.techTree:AddBuildNode(kTechId.Crag,                      kTechId.CragHive,           kTechId.None)
    self.techTree:AddBuildNode(kTechId.Shift,                     kTechId.ShiftHive,          kTechId.None)
    self.techTree:AddBuildNode(kTechId.Shade,                     kTechId.ShadeHive,          kTechId.None)
    self.techTree:AddBuildNode(kTechId.Whip,                      kTechId.WhipHive,          kTechId.None)
    self.techTree:AddBuildNode(kTechId.Hydra,                     kTechId.None,               kTechId.None)
    
    // Lifeforms
    self.techTree:AddAction(kTechId.Skulk,                     kTechId.None,                kTechId.None)
    self.techTree:AddAction(kTechId.Gorge,                     kTechId.None,                kTechId.None)
    self.techTree:AddAction(kTechId.Lerk,                      kTechId.None,                kTechId.None)
    self.techTree:AddAction(kTechId.Fade,                      kTechId.None,                kTechId.None)
    self.techTree:AddAction(kTechId.Onos,                      kTechId.None,                kTechId.None)
    self.techTree:AddBuyNode(kTechId.Egg,                      kTechId.None,                kTechId.None)
    
    // Tier 2 Abilities
    self.techTree:AddUpgradeNode(kTechId.Leap,                kTechId.TwoHives,              kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.Umbra,               kTechId.TwoHives,              kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.BileBomb,            kTechId.TwoHives,              kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.Metabolize,          kTechId.TwoHives,              kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.Stomp,               kTechId.TwoHives,              kTechId.None)

    // Tier 3 Abilities
    self.techTree:AddUpgradeNode(kTechId.Xenocide,            kTechId.ThreeHives,              kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.PrimalScream,        kTechId.ThreeHives,              kTechId.None)
    --self.techTree:AddUpgradeNode(kTechId.WebStalk,          kTechId.ThreeHives,              kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.AcidRocket,          kTechId.ThreeHives,              kTechId.None)
    self.techTree:AddUpgradeNode(kTechId.Smash,               kTechId.ThreeHives,              kTechId.None)  
    self.techTree:AddUpgradeNode(kTechId.Charge,              kTechId.ThreeHives,              kTechId.None)      
    
    // Global alien upgrades. Make sure the first prerequisite is the main tech required for it, as this is 
    // what is used to display research % in the alien evolve menu.
    // The second prerequisite is needed to determine the buy node unlocked when the upgrade is actually researched.
    self.techTree:AddBuyNode(kTechId.Carapace, kTechId.Crag, kTechId.None, kTechId.AllAliens)    
    self.techTree:AddBuyNode(kTechId.Regeneration, kTechId.Crag, kTechId.None, kTechId.AllAliens)
    self.techTree:AddBuyNode(kTechId.Redemption, kTechId.Crag, kTechId.None, kTechId.AllAliens)
    
    self.techTree:AddBuyNode(kTechId.Celerity, kTechId.Shift, kTechId.None, kTechId.AllAliens)  
    self.techTree:AddBuyNode(kTechId.Adrenaline, kTechId.Shift, kTechId.None, kTechId.AllAliens)
    self.techTree:AddBuyNode(kTechId.Redeployment, kTechId.Shift, kTechId.None, kTechId.AllAliens)
    
    self.techTree:AddBuyNode(kTechId.Silence, kTechId.Shade, kTechId.None, kTechId.AllAliens)
    self.techTree:AddBuyNode(kTechId.Ghost , kTechId.Shade, kTechId.None, kTechId.AllAliens)
    self.techTree:AddBuyNode(kTechId.Aura, kTechId.Shade, kTechId.None, kTechId.AllAliens)
	
	self.techTree:AddBuyNode(kTechId.Focus, kTechId.Whip, kTechId.None, kTechId.AllAliens)
	self.techTree:AddBuyNode(kTechId.Fury, kTechId.Whip, kTechId.None, kTechId.AllAliens)
	self.techTree:AddBuyNode(kTechId.Bombard, kTechId.Whip, kTechId.None, kTechId.AllAliens)
    
    self.techTree:AddPassive(kTechId.ShiftTeleport,               kTechId.Shift,         kTechId.None)
    
    self.techTree:SetComplete()
    
end

function AlienTeam:GetNumHives()

    local teamInfoEntity = Shared.GetEntity(self.teamInfoEntityId)
    return teamInfoEntity:GetNumCapturedTechPoints()
    
end

function AlienTeam:GetActiveHiveCount()

    local activeHiveCount = 0
    
    for index, hive in ipairs(GetEntitiesForTeam("Hive", self:GetTeamNumber())) do
    
        if hive:GetIsAlive() and hive:GetIsBuilt() then
            activeHiveCount = activeHiveCount + 1
        end
    
    end

    return activeHiveCount

end

function AlienTeam:GetActiveEggCount()

    local activeEggCount = 0
    
    for _, egg in ipairs(GetEntitiesForTeam("Egg", self:GetTeamNumber())) do
    
        if egg:GetIsAlive() and egg:GetIsEmpty() then
            activeEggCount = activeEggCount + 1
        end
    
    end
    
    return activeEggCount

end

/**
 * Inform all alien players about the hive construction (add new abilities).
 */
function AlienTeam:OnHiveConstructed(newHive)
    
    SendTeamMessage(self, kTeamMessageTypes.HiveConstructed, newHive:GetLocationId()) 
    
end

function AlienTeam:OnHiveDelayedConstructed(newHive)

    local activeHiveCount = self:GetActiveHiveCount()
    
    for index, alien in ipairs(GetEntitiesForTeam("Alien", self:GetTeamNumber())) do
    
        if alien:GetIsAlive() and alien.OnHiveConstructed then
            alien:OnHiveConstructed(newHive, activeHiveCount)
        end
        
    end
    
end

/**
 * Inform all alien players about the hive destruction (remove abilities).
 */
function AlienTeam:OnHiveDestroyed(destroyedHive)

    local activeHiveCount = self:GetActiveHiveCount()
    
    for index, alien in ipairs(GetEntitiesForTeam("Alien", self:GetTeamNumber())) do
    
        if alien:GetIsAlive() and alien.OnHiveDestroyed then
            alien:OnHiveDestroyed(destroyedHive, activeHiveCount)
        end
        
    end
    
end

local checkForLostResearch = { [kTechId.Crag] = { "Crag", kTechId.Crag },
                               [kTechId.Shift] = { "Shift", kTechId.Shift },
                               [kTechId.Shade] = { "Shade", kTechId.Shade },
                               [kTechId.Whip] = { "Whip", kTechId.Whip } }

function AlienTeam:OnUpgradeChamberConstructed(upgradeChamber)

    if upgradeChamber:GetTechId() == kTechId.Crag then
        self.updateAlienArmor = true
    end

    local checkTech = checkForLostResearch[upgradeChamber:GetTechId()]
    if checkTech then
    
        local anyRemain = false
        for _, ent in ientitylist(Shared.GetEntitiesWithClassname(checkTech[1])) do
        
            // Don't count the upgradeChamber as it is being destroyed now.
            if ent ~= upgradeChamber and ent:GetTechId() == upgradeChamber:GetTechId() then
            
                anyRemain = true
                break
                
            end
            
        end
        
        if not anyRemain then
            SendTeamMessage(self, kTeamMessageTypes.ResearchComplete, checkTech[2])
        end
        
    end
    
end

function AlienTeam:OnUpgradeChamberDestroyed(upgradeChamber)

    if upgradeChamber:GetTechId() == kTechId.Crag then
        self.updateAlienArmor = true
    end
    
    local checkTech = checkForLostResearch[upgradeChamber:GetTechId()]
    if checkTech then
    
        local alreadyhas = 0
        for _, ent in ientitylist(Shared.GetEntitiesWithClassname(checkTech[1])) do
        
            // Don't count the upgradeChamber as it is being constructed now.
            if ent ~= upgradeChamber and ent:GetTechId() == upgradeChamber:GetTechId() then
            
                alreadyhas = alreadyhas + 1
                break
                
            end
            
        end
        
        if alreadyhas < kChamberLostNotification then
            SendTeamMessage(self, kTeamMessageTypes.ResearchLost, checkTech[2])
        end
        
    end
    
end

function AlienTeam:OnResearchComplete(structure, researchId)

    PlayingTeam.OnResearchComplete(self, structure, researchId)
    
    local checkForGainedResearch = { [kTechId.UpgradeRegenerationShell] = kTechId.Regeneration,
                                     [kTechId.UpgradeCarapaceShell] = kTechId.Carapace,
                                     [kTechId.UpgradeCeleritySpur] = kTechId.Celerity,
                                     [kTechId.UpgradeHyperMutationSpur] = kTechId.HyperMutation,
                                     [kTechId.UpgradeSilenceVeil] = kTechId.Silence,
                                     [kTechId.UpgradeAuraVeil] = kTechId.Aura }
    
    local gainedResearch = checkForGainedResearch[researchId]
    if gainedResearch then
        SendTeamMessage(self, kTeamMessageTypes.ResearchComplete, gainedResearch)
    end
    
end

function AlienTeam:UpdateCloakables()

    for index, cloakableId in ipairs(self.cloakables) do
        local cloakable = Shared.GetEntity(cloakableId)
        cloakable:SetIsCloaked(true, 1, false)
    end
 
end

function AlienTeam:RegisterCloakable(cloakable)

    //Print("AlienTeam:RegisterCloakable(%s)", ToString(cloakable))

    local entityId = cloakable:GetId()

    if self.cloakableCloakCount[entityId] == nil then
        self.cloakableCloakCount[entityId] = 0
    end
    
    table.insertunique(self.cloakables, entityId)
    self.cloakableCloakCount[entityId] = self.cloakableCloakCount[entityId] + 1
    
    //Print("num shades: %s", ToString(self.cloakableCloakCount[entityId]))

end

function AlienTeam:DeregisterCloakable(cloakable)

    //Print("AlienTeam:DeregisterCloakable(%s)", ToString(cloakable))

    local entityId = cloakable:GetId()

    if self.cloakableCloakCount[entityId] == nil then
        self.cloakableCloakCount[entityId] = 0
    end
    
    self.cloakableCloakCount[entityId] = math.max(self.cloakableCloakCount[entityId] - 1, 0)
    if self.cloakableCloakCount[entityId] == 0 then
        table.removevalue(self.cloakables, entityId)
    end
    
    //Print("num shades: %s", ToString(self.cloakableCloakCount[entityId]))

end

function AlienTeam:UpdateCloakablesChanged(oldEntityId, newEntityId)

    // can happen at server/round startup
    if self.cloakables == nil then
        return
    end

    // simply remove from list, new entity will be added automatically by the trigger
    if oldEntityId then
        table.removevalue(self.cloakables, oldEntityId)    
        self.cloakableCloakCount[oldEntityId] = nil
    end

end

function AlienTeam:GetSpectatorMapName()
    return AlienSpectator.kMapName
end

function AlienTeam:AwardResources(min, max, pointOwner)

    local resAwarded = math.random(min, max) 
    resAwarded = resAwarded - pointOwner:AwardResForKill(resAwarded)
    
    if resAwarded > 0 then
        self:SplitPres(resAwarded, true)
    end

end

local function AssignPlayerToEgg(self, player, spawntime, hive)

    local success = false
    local eggs = GetEntitiesForTeam("Egg", self:GetTeamNumber())
    local spawnHive = hive
    
    if not spawnHive then
        local hives = GetEntitiesForTeam("Hive", self:GetTeamNumber())
        spawnHive = hives[math.random(1,#hives)]
    end
    
    if spawnHive then
        Shared.SortEntitiesByDistance(spawnHive:GetOrigin(), eggs)
        
        //Get hives for selected spawn hive.
        local localhiveeggs = { }
        for _, egg in ipairs(eggs) do
            if egg:GetHive() == spawnHive then
                table.insert(localhiveeggs, egg)
            end
        end
        //If hive has eggs, randomly select one
        local hiveeggs = #localhiveeggs
        if hiveeggs ~= nil and hiveeggs >= 1 then
            localhiveeggs[math.random(1, hiveeggs)]:SetQueuedPlayerId(player:GetId(), spawntime)
            success = true
        else
            // Find the closest egg, doesn't matter which Hive owns it.
            for _, egg in ipairs(eggs) do
            
                // Any egg is fine as long as it is free.
                if egg:GetIsFree() then
                    egg:SetQueuedPlayerId(player:GetId(), spawntime)
                    success = true
                    break
                end
                
            end
        end
    end
    
    return success
    
end

local function GetSpawnTime()
    return kAlienWaveSpawnInterval
end

local function RespawnPlayer(self, hive)

    if hive:GetIsAlive() and hive.queuedplayer then
        local alien = Shared.GetEntity(hive.queuedplayer)
        local spawntime = hive.timeWaveEnds
        if alien then
            local egg = nil
            if alien.GetHostEgg then
                egg = alien:GetHostEgg()
            end

            // player has no egg assigned, check for free egg
            if egg == nil then
                local success = AssignPlayerToEgg(self, alien, spawntime, hive)
                if alien.GetHostEgg then
                    egg = alien:GetHostEgg()
                end
                if not success then
                    //Fail spawn, player will automatically re-queue.
                    self:PutPlayerInRespawnQueue(alien, spawntime - GetSpawnTime())
                else
                    alien:SetWaveSpawnEndTime(spawntime)
                end
            end
            if egg ~= nil then
                //Egg spawn is a go houston
                success, newPlayer = egg:SpawnPlayer()
                if not success or newPlayer == nil then
                    //Not sure how this happens but i think its causing the spawn bug
                    //Requeue the player making sure to post date them correspondingly
                    Print(ToString("FAILEGGSPAWN"))
                    self:PutPlayerInRespawnQueue(alien, spawntime - GetSpawnTime())   
                end
            else
                self:PutPlayerInRespawnQueue(alien, spawntime - GetSpawnTime())            
            end
        end
    end
    hive.queuedplayer = nil
    hive.timeWaveEnds = 0
  
end

function AlienTeam:UpdateRespawn()

    local time = Shared.GetTime()
    
    if self.timeLastSpawnCheck == nil then
        self.timeLastSpawnCheck = Shared.GetTime()
    end
    //Dont check spawn every frame cause thats pretty dumb
    if time > (self.timeLastSpawnCheck + AlienTeam.kSpawnScanInterval) then
        local hives = GetEntitiesForTeam("Hive", self:GetTeamNumber())
        for _, hive in ipairs(hives) do
            if hive:GetIsBuilt() and hive:GetIsAlive() then
                // Spawns one player per WaveDuration, loops through each player to ensure player is selected incase of oddities
                // Assigns players to eggs much earlier, also checks when they should actually be respawning incase their egg died
                if hive.timeWaveEnds == 0 and self:GetNumPlayersInQueue() > 0 then 
                    local player = self:GetOldestQueuedPlayer()
                    if player and player:isa("AlienSpectator") then 
                        hive.queuedplayer = player:GetId()
                        self:RemovePlayerFromRespawnQueue(player)
                    end
                    if hive.queuedplayer then    
                        hive.timeWaveEnds = GetSpawnTime() + Shared.GetTime()      
                        local player = Shared.GetEntity(hive.queuedplayer)
                        if player then
                            AssignPlayerToEgg(self, player, hive.timeWaveEnds, hive)
                            player:SetWaveSpawnEndTime(hive.timeWaveEnds)
                        end      
                    end       
                end

                // spawn aliens in a wave, do nothing if the wave time has not passed yet   
                if hive.timeWaveEnds ~= 0 and hive.timeWaveEnds < Shared.GetTime() then
                    RespawnPlayer(self, hive)
                end
            end
        end
    end

end
