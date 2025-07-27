-- Import the spell_data class from the global context
local spell_data_class = _G.spell_data

-- Create a module to hold our spell data
local spell_data_module = {}

-- Function to create spell data objects
function spell_data_module.create_spell_data(radius, range, cast_delay, projectile_speed, has_wall_collision, spell_id, geometry_type, targeting_type)
    return spell_data_class:new(
        radius,
        range,
        cast_delay,
        projectile_speed,
        has_wall_collision,
        spell_id,
        geometry_type or spell_geometry.rectangular,
        targeting_type or targeting_type.skillshot
    )
end

-- Define all Necromancer spell data
local spell_data = {
    -- Core/Basic Skills
    bone_splinters = {
        spell_id = 500962,
        data = spell_data_module.create_spell_data(
            0.4,           -- radius
            10.0,          -- range
            0.5,           -- cast_delay
            8.0,           -- projectile_speed
            false,         -- has_collision
            500962,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    hemorrhage = {
        spell_id = 484661,
        data = spell_data_module.create_spell_data(
            0.8,           -- radius
            4.0,           -- range
            0.4,           -- cast_delay
            2.0,           -- projectile_speed
            true,          -- has_collision
            484661,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    reap = {
        spell_id = 432896,
        data = spell_data_module.create_spell_data(
            1.0,           -- radius
            1.0,           -- range
            0.10,          -- cast_delay
            1.0,           -- projectile_speed
            true,          -- has_collision
            432896,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },

    -- Blood Skills
    blood_lance = {
        spell_id = 501629,
        data = spell_data_module.create_spell_data(
            0.7,           -- radius
            8.0,           -- range
            1.6,           -- cast_delay
            2.0,           -- projectile_speed
            true,          -- has_collision
            501629,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    blood_surge = {
        spell_id = 592163,
        data = spell_data_module.create_spell_data(
            2.0,           -- radius
            2.0,           -- range (self-cast)
            0.0,           -- cast_delay
            0.0,           -- projectile_speed
            false,         -- has_collision
            592163,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    blood_mist = {
        spell_id = 493422
    },
    blood_wave = {
        spell_id = 658216,
        data = spell_data_module.create_spell_data(
            2.0,           -- radius
            7.0,           -- range
            1.0,           -- cast_delay
            1.0,           -- projectile_speed
            true,          -- has_collision
            658216,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },

    -- Bone Skills
    bone_spear = {
        spell_id = 432879,
        data = spell_data_module.create_spell_data(
            0.5,           -- radius
            10.0,          -- range
            1.7,           -- cast_delay
            4.0,           -- projectile_speed
            false,         -- has_collision
            432879,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    bone_prison = {
        spell_id = 493453,
        data = spell_data_module.create_spell_data(
            2.0,           -- radius
            7.0,           -- range
            1.0,           -- cast_delay
            1.0,           -- projectile_speed
            true,          -- has_collision
            493453,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    bone_spirit = {
        spell_id = 469641,
        data = spell_data_module.create_spell_data(
            1.0,           -- radius
            12.0,          -- range
            0.10,          -- cast_delay
            1.0,           -- projectile_speed
            true,          -- has_collision
            469641,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.targeted
        )
    },
    bone_storm = {
        spell_id = 499281
    },

    -- Corpse Skills
    corpse_explosion = {
        spell_id = 432897,
        data = spell_data_module.create_spell_data(
            1.0,           -- radius
            10.0,          -- range
            0.10,          -- cast_delay
            10.0,          -- projectile_speed
            true,          -- has_collision
            432897,        -- spell_id
            spell_geometry.circular,
            targeting_type.targeted
        )
    },
    corpse_tendrils = {
        spell_id = 463349,
        data = spell_data_module.create_spell_data(
            4.0,           -- radius
            10.0,          -- range
            0.10,          -- cast_delay
            7.0,           -- projectile_speed
            true,          -- has_collision
            463349,        -- spell_id
            spell_geometry.circular,
            targeting_type.targeted
        )
    },

    -- Curse Skills
    decrepify = {
        spell_id = 915150,
        data = spell_data_module.create_spell_data(
            3.90,          -- radius (with effect size multiplier)
            9.0,           -- range
            0.40,          -- cast_delay
            0.0,           -- projectile_speed (instant)
            false,         -- has_collision
            915150,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    iron_maiden = {
        spell_id = 915152,
        data = spell_data_module.create_spell_data(
            3.90,          -- radius (with effect size multiplier)
            9.0,           -- range
            0.40,          -- cast_delay
            0.0,           -- projectile_speed (instant)
            false,         -- has_collision
            915152,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
	-- New added Decompose Skills
    decompose = {
        spell_id = 463175,
        data = spell_data_module.create_spell_data(
            2.0,          -- radius
            15.,          -- range
            0.80,         -- cast_delay
            1.0,          -- projectile_speed
            false,        -- has_collision
            463175,       -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    sever = {
        spell_id = 481785,
        data = spell_data_module.create_spell_data(
            0.40,          -- radius
            8.00,          -- range
            0.20,          -- cast_delay
            12.0,          -- projectile_speed
            true,          -- has_collision
            481785,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },
    -- Darkness Skills
    blight = {
        spell_id = 481293,
        data = spell_data_module.create_spell_data(
            0.40,          -- radius
            9.00,          -- range
            0.20,          -- cast_delay
            12.0,          -- projectile_speed
            true,          -- has_collision
            481293,        -- spell_id
            spell_geometry.rectangular,
            targeting_type.skillshot
        )
    },
    sever = {
        spell_id = 481785,
        data = spell_data_module.create_spell_data(
            0.40,          -- radius
            8.00,          -- range
            0.20,          -- cast_delay
            12.0,          -- projectile_speed
            true,          -- has_collision
            481785,        -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },

    -- Ultimate Skills
    army_of_the_dead = {
        spell_id = 497193
    },
    
    -- Minion Skills
    raise_skeleton = {
        spell_id = 1059157,
        data = spell_data_module.create_spell_data(
            1.0,           -- radius
            10.0,          -- range
            0.10,          -- cast_delay
            10.0,          -- projectile_speed
            true,          -- has_collision
            1059157,       -- spell_id
            spell_geometry.circular,
            targeting_type.targeted
        )
    },
    golem_control = {
        spell_id = 440463,
        data = spell_data_module.create_spell_data(
            1.0,           -- radius
            10.0,          -- range
            0.10,          -- cast_delay
            10.0,          -- projectile_speed
            true,          -- has_collision
            440463,        -- spell_id
            spell_geometry.circular,
            targeting_type.targeted
        )
    },

    -- Special/Book Skills
    soulrift = {
        spell_id = 1644584,
        data = spell_data_module.create_spell_data(
            3.0,           -- radius
            3.0,           -- range (self-cast area)
            0.0,           -- cast_delay
            0.0,           -- projectile_speed (instant)
            false,         -- has_collision
            1644584,       -- spell_id
            spell_geometry.circular,
            targeting_type.skillshot
        )
    },

    -- System spells
    evade = {
        spell_id = 337031
    },

    -- Enemy/Buff related
    enemies = {
        damage_resistance = {
            spell_id = 1094180,
            buff_ids = {
                provider = 2771801864,
                receiver = 2182649012
            }
        }
    }
}

-- Merge spell_data_module functions with spell_data for easier access
for k, v in pairs(spell_data_module) do
    spell_data[k] = v
end

return spell_data