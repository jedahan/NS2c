//
// lua\Weapons\Alien\ShiftAbility.lua

Script.Load("lua/Weapons/Alien/StructureAbility.lua")

class 'ShiftStructureAbility' (StructureAbility)

function ShiftStructureAbility:GetEnergyCost(player)
    return 0
end

function ShiftStructureAbility:GetPrimaryAttackDelay()
    return 0
end

function ShiftStructureAbility:GetIconOffsetY(secondary)
    return kAbilityOffset.Hydra
end

function ShiftStructureAbility:GetGhostModelName(ability)
    return Shift.kModelName
end

function ShiftStructureAbility:GetDropStructureId()
    return kTechId.Shift
end

function ShiftStructureAbility:GetSuffixName()
    return "shift"
end

function ShiftStructureAbility:GetDropClassName()
    return "Shift"
end

function ShiftStructureAbility:GetDropMapName()
    return Shift.kMapName
end

function ShiftStructureAbility:IsAllowed(player)
    local structures = GetEntitiesForTeamWithinRange(self:GetDropClassName(), player:GetTeamNumber(), player:GetEyePos(), kMaxAlienStructureRange)
    local teamnum = player:GetTeamNumber()
    local techTree = GetTechTree(teamnum)
    local techNode = techTree:GetTechNode(kTechId.Shift)
    if techNode == nil then
        return false
    end
    return (techNode:GetAvailable() or player:GetUnassignedHives() > 0) and #structures < kMaxAlienStructuresofType
end
