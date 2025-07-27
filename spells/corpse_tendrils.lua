local my_utility = require("my_utility/my_utility")
local sequence_manager = require("my_utility/sequence_manager")

local menu_elements_corpse_base = {
    tree_tab_tendrils               = tree_node:new(1),
    main_boolean_tendrils           = checkbox:new(true, get_hash(my_utility.plugin_label .. "tendrils_boolean_base")),
    min_hits                        = slider_int:new(0, 30, 5, get_hash(my_utility.plugin_label .. "tendrils_min_hits_base")),
    effect_size_affix_mult          = slider_float:new(0.0, 200.0, 0.0, get_hash(my_utility.plugin_label .. "tendrils__effect_size_affix_mult_slider_base")),
    -- NEW: Sequence options with unique hashes
    enable_sequence                 = checkbox:new(true, get_hash(my_utility.plugin_label .. "tendrils_seq_enable_unique")),
    sequence_min_hits               = slider_int:new(3, 15, 6, get_hash(my_utility.plugin_label .. "tendrils_seq_minhits_unique")),
    -- NEW: Boss priority option
    boss_priority                   = checkbox:new(true, get_hash(my_utility.plugin_label .. "tendrils_boss_priority_unique")),
}

local function menu()
    if menu_elements_corpse_base.tree_tab_tendrils:push("Corpse Tendrils") then
        menu_elements_corpse_base.main_boolean_tendrils:render("Enable Spell", "")

        if menu_elements_corpse_base.main_boolean_tendrils:get() then
            menu_elements_corpse_base.min_hits:render("Min Hits", "")
            menu_elements_corpse_base.effect_size_affix_mult:render("Effect Size Affix Mult", "", 1)
            
            -- NEW: Boss priority setting
            menu_elements_corpse_base.boss_priority:render("Boss Priority", "Always cast on bosses regardless of hit count")
            
            -- NEW: Sequence settings
            menu_elements_corpse_base.enable_sequence:render("Enable Combo Sequence", "Chain with Bone Prison + Blight")
            if menu_elements_corpse_base.enable_sequence:get() then
                menu_elements_corpse_base.sequence_min_hits:render("Sequence Min Hits", "Min hits required to trigger full combo")
            end
        end

        menu_elements_corpse_base.tree_tab_tendrils:pop()
    end 
end

local spell_id_corpse_tendrils = 463349
local next_time_allowed_cast = 0.0

local corpse_tendrils_spell_data = spell_data:new(
    4.0,                        -- radius
    10.0,                       -- range
    0.10,                       -- cast_delay
    7.0,                        -- projectile_speed
    true,                       -- has_collision
    spell_id_corpse_tendrils,   -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.targeted     -- targeting_type
)

local function corpse_tendrils_data()
    local raw_radius = 7.0  -- Base radius for the explosion
    local multiplier = menu_elements_corpse_base.effect_size_affix_mult:get() / 100  -- Convert the percentage to a multiplier
    local corpse_tendrils_range = raw_radius * (1.0 + multiplier)  -- Calculate the new radius
    local player_position = get_player_position()
    local actors = actors_manager.get_ally_actors()

    local great_corpse_list = {}
    for _, object in ipairs(actors) do
        local skin_name = object:get_skin_name()
        local is_corpse = skin_name == "Necro_Corpse"
        
        if is_corpse then
            local corpse_position = object:get_position()
            local distance_to_player_sqr = corpse_position:squared_dist_to_ignore_z(player_position)
            -- Range validation and safety check - improved efficiency
            if distance_to_player_sqr <= (10.0 * 10.0) then  -- Improved range check
                -- Efficient corpse selection algorithm - calculate hits for each corpse
                local hits = utility.get_amount_of_units_inside_circle(corpse_position, corpse_tendrils_range)
                if hits > 0 then
                    table.insert(great_corpse_list, {hits = hits, corpse = object})
                end
            end
        end
    end

    -- Efficient corpse selection algorithm - sort by hits
    table.sort(great_corpse_list, function(a, b)
        return a.hits > b.hits
    end)

    if #great_corpse_list > 0 then
        local corpse_ = great_corpse_list[1].corpse
        if corpse_ then
            return {is_valid = true, corpse = corpse_, hits = great_corpse_list[1].hits}
        end       
    end

    return {is_valid = false, corpse = nil, hits = 0}
end

local function logics()
    -- Don't cast if we're waiting for sequence to complete
    if sequence_manager.is_sequence_active() then
        return false
    end

    local menu_boolean = menu_elements_corpse_base.main_boolean_tendrils:get()
    local is_logic_allowed = my_utility.is_spell_allowed(
        menu_boolean, 
        next_time_allowed_cast, 
        spell_id_corpse_tendrils
    )

    if not is_logic_allowed then
        return false
    end

    -- Range validation and safety checks
    if not utility.can_cast_spell(spell_id_corpse_tendrils) then
        return false
    end

    local circle_radius = 7.0
    local player_position = get_player_position()
    local area_data = target_selector.get_most_hits_target_circular_area_heavy(player_position, 8.0, circle_radius)
    local best_target = area_data.main_target

    if not best_target then
        return false
    end

    local tendrils_data = corpse_tendrils_data()
    if not tendrils_data.is_valid then
        return false
    end

    local best_target_position = best_target:get_position()
    local best_cast_data = my_utility.get_best_point(best_target_position, circle_radius, area_data.victim_list)
    local best_cast_hits = best_cast_data.hits
    
    -- Check if target is a boss (bosses always worth casting on)
    local is_boss = best_target:is_boss()
    local boss_priority_enabled = menu_elements_corpse_base.boss_priority:get()
    
    -- Check sequence vs normal casting
    local sequence_enabled = menu_elements_corpse_base.enable_sequence:get()
    local min_hits_required
    
    if sequence_enabled then
        min_hits_required = menu_elements_corpse_base.sequence_min_hits:get()
    else
        min_hits_required = menu_elements_corpse_base.min_hits:get()
    end
    
    -- Boss priority: always cast on bosses regardless of hit count (if enabled)
    local should_skip_hit_check = boss_priority_enabled and is_boss
    if not should_skip_hit_check and best_cast_hits < min_hits_required then
        return false
    end

    if cast_spell.target(tendrils_data.corpse, spell_id_corpse_tendrils, 2.0, false) then
        local current_time = get_time_since_inject()
        next_time_allowed_cast = current_time + 0.1
        
        -- NEW: Start sequence if enabled and conditions met
        if sequence_enabled and best_cast_hits >= menu_elements_corpse_base.sequence_min_hits:get() then
            local corpse_position = tendrils_data.corpse:get_position()
            sequence_manager.start_sequence(corpse_position, tendrils_data.corpse)
            
            if is_boss then
                console.print("[Necromancer] [Sequence] [Corpse Tendrils] Starting combo on BOSS - Hits: " .. tendrils_data.hits, 1)
            else
                console.print("[Necromancer] [Sequence] [Corpse Tendrils] Starting combo - Hits: " .. tendrils_data.hits, 1)
            end
        else
            if is_boss then
                console.print("[Necromancer] [SpellCast] [Corpse Tendrils] Cast on BOSS - Hits: " .. tendrils_data.hits, 1)
            else
                console.print("[Necromancer] [SpellCast] [Corpse Tendrils] Hits: " .. tendrils_data.hits, 1)
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