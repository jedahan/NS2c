// ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =======
//
// lua\AlienStructureEffects.lua
//
//    Created by:   Charlie Cleveland (charlie@unknownworlds.com)
//
// ========= For more information, visit us at http://www.unknownworlds.com =====================
kAlienStructureEffects = 
{

    construct =
    {
        alienConstruct =
        {
            {sound = "sound/NS2.fev/alien/structures/generic_build", isalien = true, done = true},
        },
    },
    
    death =
    {
        alienStructureDeathParticleEffect =
        {        
            // Plays the first effect that evalutes to true
            {cinematic = "cinematics/alien/structures/death_small.cinematic", classname = "Web", done = true},
            {cinematic = "cinematics/alien/structures/death_hive.cinematic", classname = "Hive", done = true},
            {cinematic = "cinematics/alien/structures/death_large.cinematic", classname = "Whip", done = true},
                        
            {cinematic = "cinematics/alien/structures/death_small.cinematic", classname = "Crag", done = true},
            {cinematic = "cinematics/alien/structures/death_small.cinematic", classname = "Shade", done = true},
            {cinematic = "cinematics/alien/structures/death_small.cinematic", classname = "Shift", done = true},
            
            {cinematic = "cinematics/alien/structures/death_harvester.cinematic", classname = "Harvester", done = true},
        },
        
        alienStructureDeathSounds =
        {
            
            {sound = "sound/NS2.fev/alien/structures/harvester_death", classname = "Harvester"},
            {sound = "sound/NS2.fev/alien/structures/hive_death", classname = "Hive"},
            {sound = "sound/NS2.fev/alien/structures/death_grenade", classname = "Structure", doer = "Grenade", isalien = true, done = true},
            {sound = "sound/NS2.fev/alien/structures/death_axe", classname = "Structure", doer = "Axe", isalien = true, done = true},            
            {sound = "sound/NS2.fev/alien/structures/death_small", classname = "Structure", isalien = true, done = true},
            {sound = "sound/NS2.fev/alien/structures/death_small", classname = "Web", done = true},
            
            {sound = "sound/NS2.fev/alien/structures/death_small", classname = "Crag", done = true},
            {sound = "sound/NS2.fev/alien/structures/death_small", classname = "Shade", done = true},
            {sound = "sound/NS2.fev/alien/structures/death_small", classname = "Shift", done = true},
            
        },       
    },
    
    harvester_collect =
    {
        harvesterCollectEffect =
        {
            {sound = "sound/NS2.fev/alien/structures/harvester_harvested"},
            //{cinematic = "cinematics/alien/harvester/resource_collect.cinematic"},
            {animation = {{.4, "active1"}, {.7, "active2"}}, force = false},
        },
    },
    
    egg_death =
    {
        eggEggDeathEffects =
        {
            {sound = "sound/NS2.fev/alien/structures/egg/death"},
            {cinematic = "cinematics/alien/egg/burst.cinematic"},
        },
    },

    hydra_attack =
    {
        hydraAttackEffects =
        {
            {sound = "sound/NS2.fev/alien/structures/hydra/attack"},
            //{cinematic = "cinematics/alien/hydra/spike_fire.cinematic"},
        },
    },
    
    player_start_gestate =
    {
        playerStartGestateEffects = 
        {
            {private_sound = "sound/NS2.fev/alien/common/gestate"},
        },
    },
    
    player_end_gestate =
    {
        playerStartGestateEffects = 
        {
            {stop_sound = "sound/NS2.fev/alien/common/gestate"},
        },
    },
    
    // Triggers when crag tries to heal entities
    crag_heal =
    {        
        cragTriggerHealEffects = 
        {
            {cinematic = "cinematics/alien/crag/heal.cinematic"}
        },
    },
    
    whip_attack =
    {
        whipAttackEffects =
        {
            {sound = "sound/NS2.fev/alien/structures/whip/hit"},
        },
    },
    
    whip_attack_start =
    {
        whipAttackEffects =
        {
            {sound = "sound/NS2.fev/alien/structures/whip/swing"},
        },
    },

}

GetEffectManager():AddEffectData("AlienStructureEffects", kAlienStructureEffects)
