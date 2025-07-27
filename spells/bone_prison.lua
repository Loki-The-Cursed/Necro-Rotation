-- Current bone_prison.lua content review:

local my_utility = require("my_utility/my_utility")

local menu_elements_bone_prison_base = {
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_bone_prison")),
}

local function menu()
    if menu_elements_bone_prison_base.tree_tab:push("Bone Prison") then
        menu_elements_bone_prison_base.main_boolean:render("Enable Spell", "Automatically cast Bone Prison (1 enemy, 6+ enemies, or boss)")
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
    if not target then
        return false
    end

    local menu_boolean = menu_elements_bone_prison_base.main_boolean:get()
    
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

    -- Check if target is a boss (bosses always cast)
    local is_boss = target:is_boss()
    
    if not is_boss then
        -- Check enemy count: cast if 1 enemy OR 6+ enemies (skip 2-5 enemies)
        local player_pos = get_player_position()
        local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 10.0, 7.0, false)
        local enemy_count = area_data.n_hits

        if enemy_count ~= 1 and enemy_count < 6 then
            return false  -- Skip 2-5 enemies (not worth it)
        end
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
            console.print("[Necromancer] [SpellCast] [Bone Prison] Cast (" .. area_data.n_hits .. " enemies)", 1)
        end
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics,   
}
