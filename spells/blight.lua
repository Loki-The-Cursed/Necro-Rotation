local my_utility = require("my_utility/my_utility")

local menu_elements_blight_base = {
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_blight_base")),
    filter_mode           = combo_box:new(0, get_hash(my_utility.plugin_label .. "blight_base_filter_mode")),
}

local function menu()
    if menu_elements_blight_base.tree_tab:push("Blight") then
        menu_elements_blight_base.main_boolean:render("Enable Spell", "Automatically cast Blight with filtering options")
 
        if menu_elements_blight_base.main_boolean:get() then
            local dropbox_options = {"No filter", "Elite & Boss Only", "Boss Only"}
            menu_elements_blight_base.filter_mode:render("Filter Modes", dropbox_options, "")
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
    if not target then
        return false
    end

    local menu_boolean = menu_elements_blight_base.main_boolean:get()
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

    -- Target filtering based on selected mode
    local filter_mode = menu_elements_blight_base.filter_mode:get()

    if filter_mode == 1 then
        -- Elite & Boss Only mode
        local is_elite = target:is_elite()
        local is_boss = target:is_boss()
        local is_champion = target:is_champion()
        if not is_elite and not is_boss and not is_champion then
            return false
        end
    elseif filter_mode == 2 then
        -- Boss Only mode
        local is_boss = target:is_boss()
        if not is_boss then
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
        
        -- Enhanced console output with target type info
        local target_type = "Enemy"
        if target:is_boss() then
            target_type = "BOSS"
        elseif target:is_elite() or target:is_champion() then
            target_type = "ELITE"
        end
        
        console.print("[Necromancer] [SpellCast] [Blight] Cast on " .. target_type, 1)
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics,   
}