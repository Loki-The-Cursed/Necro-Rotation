local my_utility = require("my_utility/my_utility")
local sequence_manager = require("my_utility/sequence_manager")

local menu_elements_bone_prison_base = {
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_bone_prison")),
    -- NEW: Sequence participation option with unique hash
    participate_sequence  = checkbox:new(true, get_hash(my_utility.plugin_label .. "bone_prison_seq_participate_unique")),
}

local function menu()
    if menu_elements_bone_prison_base.tree_tab:push("Bone Prison") then
        menu_elements_bone_prison_base.main_boolean:render("Enable Spell", "Automatically cast Bone Prison (1 enemy, 6+ enemies, or boss)")
        -- NEW: Sequence participation setting
        menu_elements_bone_prison_base.participate_sequence:render("Join Combo Sequence", "Participate in Tendrils -> Prison -> Blight combo")
        menu_elements_bone_prison_base.tree_tab:pop()
    end
end

local bone_prison_spell_id = 493453
local next_time_allowed_cast = 0.0

local bone_prison_data = spell_data:new(
    2.0,                        -- radius
    7.0,                        -- range
    1.0,                        -- cast_delay
    1.0,                        -- projectile_speed
    true,                       -- has_collision
    bone_prison_spell_id,       -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.skillshot    -- targeting_type
)

local function logics(target)
    local menu_boolean = menu_elements_bone_prison_base.main_boolean:get()
    
    -- Early exit if spell is disabled
    if not menu_boolean then
        return false
    end
    
    local participate_sequence = menu_elements_bone_prison_base.participate_sequence:get()
    
    -- NEW: Check if we should cast as part of sequence (PRIORITY CHECK)
    if participate_sequence and sequence_manager.should_cast_next_step("bone_prison") then
        -- Basic spell availability check
        if not utility.can_cast_spell(bone_prison_spell_id) then
            return false
        end
        
        -- Check spell cooldown/timing
        local is_logic_allowed = my_utility.is_spell_allowed(
            true,  -- Force enabled for sequence
            next_time_allowed_cast, 
            bone_prison_spell_id
        )
        if not is_logic_allowed then
            return false
        end
        
        local sequence_position = sequence_manager.get_sequence_position()
        if sequence_position then
            local player_position = get_player_position()
            local distance = sequence_position:dist_to(player_position)
            
            -- Check if sequence position is within range
            if distance <= 7.0 then
                -- Use position-based casting for sequence
                if cast_spell.position(sequence_position, bone_prison_spell_id, false) then
                    local current_time = get_time_since_inject()
                    next_time_allowed_cast = current_time + 0.1
                    
                    sequence_manager.advance_step()
                    console.print("[Necromancer] [Sequence] [Bone Prison] Cast at sequence position", 1)
                    return true
                end
            else
                -- Position too far, reset sequence
                console.print("[Necromancer] [Sequence] [Bone Prison] Position too far - resetting", 1)
                sequence_manager.reset_sequence()
            end
        else
            -- No sequence position, reset sequence
            console.print("[Necromancer] [Sequence] [Bone Prison] No sequence position - resetting", 1)
            sequence_manager.reset_sequence()
        end
        return false
    end
    
    -- ORIGINAL LOGIC: Normal bone prison casting (when not in sequence)
    if not target then
        return false
    end

    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean, 
        next_time_allowed_cast, 
        bone_prison_spell_id
    )

    if not is_logic_allowed then
        return false
    end

    if not utility.can_cast_spell(bone_prison_spell_id) then
        return false
    end

    -- Check if target is a boss (bosses always cast regardless of count)
    local is_boss = target:is_boss()
    
    if not is_boss then
        -- Get enemy count in area
        local player_pos = get_player_position()
        local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 10.0, 7.0, false)
        local enemy_count = area_data.n_hits

        if enemy_count >= 1 and enemy_count <= 5 then
            -- 1-5 enemies: only cast if elite quality or higher
            local is_elite = target:is_elite()
            local is_champion = target:is_champion()
            
            if not is_elite and not is_champion then
                return false  -- Skip 1-5 normal enemies
            end
            -- Continue if elite/champion (1-5 count)
        elseif enemy_count < 6 then
            return false  -- This shouldn't happen, but safety check
        end
        -- enemy_count >= 6: always cast (any enemy type)
    end

    local target_position = target:get_position()
    local player_position = get_player_position()
    local distance = target_position:dist_to(player_position)
    
    -- Check if target is within spell range
    if distance > 7.0 then
        return false
    end

    if cast_spell.target(target, bone_prison_data, false) then
        local current_time = get_time_since_inject()
        next_time_allowed_cast = current_time + 0.1  -- Minimal delay for spam casting
        
        if is_boss then
            console.print("[Necromancer] [SpellCast] [Bone Prison] Cast on BOSS", 1)
        else
            local player_pos = get_player_position()
            local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 10.0, 7.0, false)
            local enemy_count = area_data.n_hits
            
            if enemy_count <= 5 then
                -- Small group of elite+ enemies
                local target_type = "Elite"
                if target:is_champion() then
                    target_type = "Champion"
                end
                console.print("[Necromancer] [SpellCast] [Bone Prison] Cast on " .. target_type .. " (" .. enemy_count .. " enemies)", 1)
            else
                -- Large group (6+ any enemies)
                console.print("[Necromancer] [SpellCast] [Bone Prison] Cast on large group (" .. enemy_count .. " enemies)", 1)
            end
        end
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics,   
}