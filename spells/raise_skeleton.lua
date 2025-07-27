local my_utility = require("my_utility/my_utility")

local menu_elements = {
    raise_skeleton_submenu     = tree_node:new(1),
    auto_buff_boolean         = checkbox:new(true, get_hash(my_utility.plugin_label .. "auto_buff_boolean_base")),
    auto_buff_delay           = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "auto_buff_delay_base")),
}

local function menu()
    if menu_elements.raise_skeleton_submenu:push("Raise Skeleton") then
        menu_elements.auto_buff_boolean:render("Auto Buff", "Automatically raise skeletons from corpses")
        
        if menu_elements.auto_buff_boolean:get() then
            menu_elements.auto_buff_delay:render("Delay (seconds)", "Delay between casts in seconds")
        end
        
        menu_elements.raise_skeleton_submenu:pop()
    end
end

local raise_skeleton_id = 1059157

local raise_skeleton_spell_data = spell_data:new(
    1.0,                        -- radius
    10.0,                       -- range
    0.10,                       -- cast_delay
    10.0,                       -- projectile_speed
    true,                       -- has_collision
    raise_skeleton_id,          -- spell_id
    spell_geometry.circular,    -- geometry_type
    targeting_type.targeted     -- targeting_type
)

local function get_corpses_to_rise_list()
    local player_position = get_player_position()
    local actors = actors_manager.get_ally_actors()

    local corpse_list = {}
    for _, object in ipairs(actors) do
        if object then
            local skin_name = object:get_skin_name()
            local is_corpse = skin_name == "Necro_Corpse"
            
            if is_corpse then
                table.insert(corpse_list, object)
            end
        end
    end

    -- Sort by distance to player (closest first)
    table.sort(corpse_list, function(a, b)
        return a:get_position():squared_dist_to(player_position) < b:get_position():squared_dist_to(player_position)
    end)

    return corpse_list
end

local last_raise_skeleton = 0.0

local function logics()
    local menu_boolean = menu_elements.auto_buff_boolean:get()
    local delay_seconds = menu_elements.auto_buff_delay:get()
    
    if not menu_boolean then
        return false
    end

    local player = get_local_player()
    if not player then
        return false
    end

    if not utility.can_cast_spell(raise_skeleton_id) then
        return false
    end
    
    if not utility.is_spell_ready(raise_skeleton_id) then
        return false
    end

    local current_time = get_time_since_inject()
    if current_time < last_raise_skeleton then
        return false
    end
   
    local corpses_to_rise = get_corpses_to_rise_list()
    if #corpses_to_rise <= 0 then
        return false
    end
  
    local corpse_to_rise = corpses_to_rise[1]
    if not corpse_to_rise then
        return false
    end
    
    local corpse_position = corpse_to_rise:get_position()
    local player_position = get_player_position()
    
    local distance_squared = corpse_position:squared_dist_to(player_position)
    local max_range_squared = raise_skeleton_spell_data.range * raise_skeleton_spell_data.range
    
    if distance_squared > max_range_squared then
        return false
    end
    
    local distance = math.sqrt(distance_squared)
    
    local nearby_enemy = target_selector.get_target_closer(player_position, 10.0)
    if not nearby_enemy then
        return false
    end
    
    if nearby_enemy:is_boss() then
        console.print("[Necromancer] Boss detected - raising skeleton")
    elseif nearby_enemy:is_elite() then
        console.print("[Necromancer] Elite detected - raising skeleton")
    elseif nearby_enemy:is_champion() then
        console.print("[Necromancer] Champion detected - raising skeleton")
    end
    
    if cast_spell.target(corpse_to_rise, raise_skeleton_id, 0.60, false) then
        -- Success: Set delay timer
        last_raise_skeleton = current_time + delay_seconds
        console.print("[Necromancer] [SpellCast] [Raise Skeleton] Cast on corpse at distance:", string.format("%.1f", distance))
        return true
    else
        -- Failed: Still set delay timer
        last_raise_skeleton = current_time + delay_seconds
        console.print("[Necromancer] [SpellCast] [Raise Skeleton] Failed to cast on corpse")
    end

    return false
end

return {
    menu = menu,
    logics = logics,   
}