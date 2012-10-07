//
// lua\UmbraCloud.lua

Script.Load("lua/CommAbilities/CommanderAbility.lua")

class 'UmbraCloud' (CommanderAbility)

UmbraCloud.kMapName = "UmbraCloud"

UmbraCloud.kUmbraCloudEffect = PrecacheAsset("cinematics/alien/Crag/umbra.cinematic")
local kUmbraSound = PrecacheAsset("sound/NS2.fev/alien/structures/crag/umbra")

UmbraCloud.kType = CommanderAbility.kType.Repeat

// duration of cinematic, increase cinematic duration and kUmbraCloudDuration to 12 to match the old value from Crag.lua
UmbraCloud.kUmbraCloudDuration = kUmbraDuration
UmbraCloud.kRadius = kUmbraRadius
UmbraCloud.kMaxRange = 20
local kThinkTime = 0.5
UmbraCloud.kTravelSpeed = 60 // meters per second

local networkVars =
{
}

function UmbraCloud:GetRepeatCinematic()
    return UmbraCloud.kUmbraCloudEffect
end

function UmbraCloud:GetType()
    return UmbraCloud.kType
end
    
function UmbraCloud:GetLifeSpan()
    return UmbraCloud.kUmbraCloudDuration
end

function UmbraCloud:OnInitialized()

    CommanderAbility.OnInitialized(self)
    self.soundplayed = false
end

function UmbraCloud:SetTravelDestination(position)
    self.destination = position
end

function UmbraCloud:GetThinkTime()
    //attempt dynamic think time per modified per cloud :/
    //makes initial cloud movement fast but doesnt add useless cycles
    return kThinkTime
end

if Server then

    function UmbraCloud:Perform()
    
        for _, target in ipairs(GetEntitiesWithMixinForTeamWithinRange("Umbra", self:GetTeamNumber(), self:GetOrigin(), UmbraCloud.kRadius)) do
            target:SetHasUmbra(true, kUmbraRetainTime)
        end
        
    end
    
    function UmbraCloud:OnUpdate(deltaTime)
    
        CommanderAbility.OnUpdate(self, deltaTime)
        
        if self.destination then
        
            local travelVector = self.destination - self:GetOrigin()
            if travelVector:GetLength() > 0.3 then
                local distanceFraction = (self.destination - self:GetOrigin()):GetLength() / UmbraCloud.kMaxRange
                self:SetOrigin( self:GetOrigin() + GetNormalizedVector(travelVector) * deltaTime * UmbraCloud.kTravelSpeed * distanceFraction )
            end
            if travelVector:GetLength() < 2 and not self.soundplayed then
                Shared.PlayWorldSound(nil, kUmbraSound, nil, self:GetOrigin())
                self.soundplayed = true
            end
        
        end
    
    end

end

Shared.LinkClassToMap("UmbraCloud", UmbraCloud.kMapName, networkVars)