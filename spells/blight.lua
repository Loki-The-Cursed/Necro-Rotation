local my_utility = require("my_utility/my_utility")
local sequence_manager = require("my_utility/sequence_manager")

local menu_elements_blight_base = {
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_blight_base")),
    filter_mode           = combo_box:new(0, get_hash(my_utility.plugin_label .. "blight_base_filter_mode")),
    -- NEW: Sequence participation option with unique hash
    participate_sequence  = checkbox:new(true, get_hash(my_utility.plugin_label .. "blight_seq_participate_unique")),
}

local function menu()
    if menu_elements_blight_base.tree_tab:push("Blight") then
        menu_elements_blight_base.main_boolean:render("Enable Spell", "Automatically cast Blight with filtering options")
 
        if menu_elements_blight_base.main_boolean:get() then
            local dropbox_options = {"No filter", "Elite & Boss Only", "Boss Only", "Champions & Bosses Only"}
            menu_elements_blight_base.filter_mode:render("Filter Modes", dropbox_options, "")
            -- NEW: Sequence participation setting
            menu_elements_blight_base.participate_sequence:render("Join Combo Sequence", "Participate in Tendrils -> Prison -> Blight combo")
        end
      
        menu_elements_blight_base.tree_tab:pop()
    end
end

local blight_spell_id = 481293
local next_time_allowed_cast = 0.0

local blight_spell_data = spell_data:new(
    0.40,                       -- radius
    9.00,                       -- range
    0.20,                       -- cast_delay
    12.0,                       -- projectile_speed
    true,                       -- has_wall_collision
    blight_spell_id,            -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    -- targeting_type
)

local function logics(target)
    local menu_boolean = menu_elements_blight_base.main_boolean:get()
    
    -- Early exit if spell is disabled
    if not menu_boolean then
        return false
    end
    
    local participate_sequence = menu_elements_blight_base.participate_sequence:get()
    
    -- NEW: Check if we should cast as part of sequence (final step) - PRIORITY CHECK
    if participate_sequence and sequence_manager.should_cast_next_step("blight") then
        -- Basic spell availability check
        if not utility.can_cast_spell(blight_spell_id) then
            return false
        end
        
        -- Check spell cooldown/timing
        local is_logic_allowed = my_utility.is_spell_allowed(
            true,  -- Force enabled for sequence
            next_time_allowed_cast, 
            blight_spell_id
        )
        if not is_logic_allowed then
            return false
        end
        
        local sequence_position = sequence_manager.get_sequence_position()
        if sequence_position then
            local player_position = get_player_position()
            local distance = sequence_position:dist_to(player_position)
            
            -- Check if sequence position is within range
            if distance <= 9.0 then
                -- Use the proper wall collision check from sequence_manager
                local has_collision = sequence_manager.check_wall_collision(player_position, sequence_position, 0.20)
                
                if not has_collision then
                    if cast_spell.position(sequence_position, blight_spell_id, false) then
                        local current_time = get_time_since_inject()
                        next_time_allowed_cast = current_time + 0.1
                        
                        -- Complete the sequence (this is the final spell)
                        sequence_manager.reset_sequence()
                        console.print("[Necromancer] [Sequence] [Blight] COMBO COMPLETE - Cast at sequence position", 1)
                        return true
                    else
                        console.print("[Necromancer] [Sequence] [Blight] Cast failed - resetting sequence", 1)
                        sequence_manager.reset_sequence()
                    end
                else
                    console.print("[Necromancer] [Sequence] [Blight] Wall collision detected - resetting sequence", 1)
                    sequence_manager.reset_sequence()
                end
            else
                -- Position too far, reset sequence
                console.print("[Necromancer] [Sequence] [Blight] Position too far - resetting", 1)
                sequence_manager.reset_sequence()
            end
        else
            -- No sequence position, reset sequence
            console.print("[Necromancer] [Sequence] [Blight] No sequence position - resetting", 1)
            sequence_manager.reset_sequence()
        end
        return false
    end
    
    -- ORIGINAL LOGIC: Normal blight casting (when not in sequence)
    if not target then
        return false
    end

    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean, 
        next_time_allowed_cast, 
        blight_spell_id
    )

    if not is_logic_allowed then
        return false
    end

    if not utility.can_cast_spell(blight_spell_id) then
        return false
    end

    -- Enhanced target filtering based on selected mode
    local filter_mode = menu_elements_blight_base.filter_mode:get()
    local is_boss = target:is_boss()
    local is_elite = target:is_elite()
    local is_champion = target:is_champion()

    if filter_mode == 1 then
        -- Elite & Boss Only mode (includes Champions)
        if not is_elite and not is_boss and not is_champion then
            return false
        end
    elseif filter_mode == 2 then
        -- Boss Only mode
        if not is_boss then
            return false
        end
    elseif filter_mode == 3 then
        -- Champions & Bosses Only mode (excludes regular elites)
        if not is_boss and not is_champion then
            return false
        end
    end
    -- filter_mode == 0 (No filter) allows any target

    -- Range validation
    local target_position = target:get_position()
    local player_position = get_player_position()
    local distance = target_position:dist_to(player_position)
    
    if distance > 9.0 then
        return false
    end

    -- Wall collision check
    local is_wall_collision = target_selector.is_wall_collision(player_position, target, 0.20)
    if is_wall_collision then
        return false
    end
    
    if cast_spell.target(target, blight_spell_data, false) then
        local current_time = get_time_since_inject()
        next_time_allowed_cast = current_time + 0.1  -- Rapid casting for spam capability
        
        -- Enhanced console output with target type and filter info
        local target_type = "Enemy"
        if is_boss then
            target_type = "BOSS"
        elseif is_champion then
            target_type = "CHAMPION"
        elseif is_elite then
            target_type = "ELITE"
        end
        
        local filter_names = {"All", "Elite+", "Boss Only", "Champion+"}
        local filter_name = filter_names[filter_mode + 1] or "Unknown"
        
        console.print("[Necromancer] [SpellCast] [Blight] Cast on " .. target_type .. " [Filter: " .. filter_name .. "]", 1)
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics,   
}