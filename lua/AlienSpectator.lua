// ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\AlienSpectator.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
//                  Max McGuire (max@unknownworlds.com)
//
// Alien spectators can choose their upgrades and lifeform while dead.
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================

Script.Load("lua/TeamSpectator.lua")
Script.Load("lua/ScoringMixin.lua")

if Client then
    Script.Load("lua/TeamMessageMixin.lua")
end

class 'AlienSpectator' (TeamSpectator)

AlienSpectator.kMapName = "alienspectator"

local networkVars =
{
    eggId = "private entityid",
    queuePosition = "private integer (-1 to 100)",
    timeWaveSpawnEnd = "private time"
}

local function UpdateQueuePosition(self)

    self.queuePosition = self:GetTeam():GetPlayerPositionInRespawnQueue(self)
    return true
    
end

function AlienSpectator:OnCreate()

    TeamSpectator.OnCreate(self)
    
    InitMixin(self, ScoringMixin, { kMaxScore = kMaxScore })
    
    if Client then
        InitMixin(self, TeamMessageMixin, { kGUIScriptName = "GUIAlienTeamMessage" })
    end
    
end

function AlienSpectator:OnInitialized()

    TeamSpectator.OnInitialized(self)

    self:SetTeamNumber(2)
    
    self.eggId = Entity.invalidId
    self.queuePosition = 0
    self.movedToEgg = false
    self.timeWaveSpawnEnd = 0
    
    if Server then
    
        self.evolveTechIds = { kTechId.Skulk }
        self:AddTimedCallback(UpdateQueuePosition, 0.1)
        UpdateQueuePosition(self)
        
    end
    
    if Client and Client.GetLocalPlayer() == self then
        self.spawnHUD = GetGUIManager():CreateGUIScript("GUIAlienSpectatorHUD")
    end
    
end

function AlienSpectator:OnDestroy()

    TeamSpectator.OnDestroy(self)
    
    if Client  then
    
        if self.spawnHUD then
        
            GetGUIManager():DestroyGUIScript(self.spawnHUD)
            self.spawnHUD = nil
            
        end
        
        if self.requestMenu then
        
            GetGUIManager():DestroyGUIScript(self.requestMenu)
            self.requestMenu = nil
            
        end  
        
    end
    
end

if Client then

    function AlienSpectator:OnInitLocalClient()
    
            Spectator.OnInitLocalClient(self)
            
            if self.requestMenu == nil then
                self.requestMenu = GetGUIManager():CreateGUIScript("GUIRequestMenu")
            end
        
    end

end

function AlienSpectator:GetIsValidToSpawn()
    return true
end

// Returns egg we're currently spawning in or nil if none
function AlienSpectator:GetHostEgg()

    if self.eggId ~= Entity.invalidId then
        return Shared.GetEntity(self.eggId)
    end
    
    return nil
    
end

function AlienSpectator:SetEggId(id, autospawntime)

    self.eggId = id
    
    if self.eggId == Entity.invalidId then
        self.timeWaveSpawnEnd = 0
    else
        self.timeWaveSpawnEnd = autospawntime
    end
    
end

function AlienSpectator:GetEggId()
    return self.eggId
end

function AlienSpectator:GetQueuePosition()
    return self.queuePosition + 1
end

function AlienSpectator:GetAutoSpawnTime()
    return self.timeWaveSpawnEnd - Shared.GetTime()
end

function AlienSpectator:SpawnPlayerOnAttack()
    /*
    if Server and self:GetEggId() then
        local newegg
        local curegg = self:GetHostEgg()
        local eggs = GetEntitiesForTeam("Egg", self:GetTeamNumber())
        local playerorigin = self:GetOrigin()
        Shared.SortEntitiesByDistance(playerorigin, eggs)
        for _, egg in ipairs(eggs) do
            if egg:GetIsFree() and egg ~= curegg then
                newegg = egg
                break
            end
        end
        if newegg and curegg and newegg:GetIsFree() then
            newegg:SetQueuedPlayerId(self:GetId(), self:GetWaveSpawnEndTime())
        end
    else
        self:TriggerInvalidSound()
    end

    return false, nil
    */
end

// Same as Skulk so his view height is right when spawning in
function AlienSpectator:GetMaxViewOffsetHeight()
    return Skulk.kViewOffsetHeight
end

function AlienSpectator:SetWaveSpawnEndTime(time)
    self.timeWaveSpawnEnd = time
end

function AlienSpectator:GetWaveSpawnEndTime()
    return self.timeWaveSpawnEnd
end

/**
 * Prevent the camera from penetrating into the world when waiting to spawn at an Egg.
 */
function AlienSpectator:GetPreventCameraPenetration()

    local followTarget = Shared.GetEntity(self:GetFollowTargetId())
    return followTarget and followTarget:isa("Egg")
    
end

Shared.LinkClassToMap("AlienSpectator", AlienSpectator.kMapName, networkVars)