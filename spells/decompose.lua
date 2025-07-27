local my_utility = require("my_utility/my_utility");

local menu_elements_decompose = 
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_decompose_base")),
    elite_focus           = checkbox:new(true, get_hash(my_utility.plugin_label .. "decompose_elite_focus")),
}

local function menu()
    
    if menu_elements_decompose.tree_tab:push("Decompose") then
        menu_elements_decompose.main_boolean:render("Enable Spell", "")
        menu_elements_decompose.elite_focus:render("Elite/Boss Focus", "Stop movement and channel on elites/bosses for 5 seconds")
 
        menu_elements_decompose.tree_tab:pop()
    end
end

local spell_id_decompose = 463175
local next_time_allowed_cast = 0.0;
local channel_end_time = 0.0;
local is_channeling = false;
local decompose_spell_data = spell_data:new(
    2.0,                        -- radius
    15.0,                       -- range
    0.80,                       -- cast_delay
    1.0,                        -- projectile_speed
    false,                      -- has_collision
    spell_id_decompose,         -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.skillshot    -- targeting_type
)

local function logics(target)

    local menu_boolean = menu_elements_decompose.main_boolean:get();
    local elite_focus = menu_elements_decompose.elite_focus:get();
    local current_time = get_time_since_inject();
    
    -- Check if we're still channeling
    if is_channeling and current_time < channel_end_time then
        -- Stop movement while channeling
        if elite_focus then
            orbwalker.set_movement(false);
        end
        return false;
    end
    
    -- Reset channeling state when finished
    if is_channeling and current_time >= channel_end_time then
        is_channeling = false;
        if elite_focus then
            orbwalker.set_movement(true);
        end
    end
    
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_decompose);

    if not is_logic_allowed then
        return false;
    end;

    -- Check if target is elite/boss when elite focus is enabled
    if elite_focus then
        local is_elite = target:is_elite()
        local is_boss = target:is_boss()
        local is_champion = target:is_champion()
        
        if not is_elite and not is_boss and not is_champion then
            return false;
        end
    end

    local target_position = target:get_position();

    cast_spell.target(target, decompose_spell_data, false)
    
    -- Set channeling state for 5 seconds if elite focus is enabled
    if elite_focus then
        is_channeling = true;
        channel_end_time = current_time + 5.0;
        orbwalker.set_movement(false);
        console.print("Necro Plugin, Channeling Decompose on Elite/Boss for 5 seconds");
    else
        console.print("Necro Plugin, Casted Decompose");
    end
    
    next_time_allowed_cast = current_time + 0.8;
    return true;

end

return 
{
    menu = menu,
    logics = logics,   
}