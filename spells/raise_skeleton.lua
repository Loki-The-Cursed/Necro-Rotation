local my_utility = require("my_utility/my_utility")

local menu_elements = {
    raise_skeleton_submenu     = tree_node:new(1),
    enable_skill              = checkbox:new(true, get_hash("raise_skeleton_enable_skill_base")),
    auto_buff_boolean         = checkbox:new(true, get_hash("raise_skeleton_auto_buff_boolean_base")),
    auto_buff_cast_time       = slider_int:new(1, 10, 3, get_hash("raise_skeleton_auto_buff_cast_time_base")),
    raise_skeleton_ranged     = checkbox:new(true, get_hash("raise_skeleton_ranged_base")),
    max_skeletons_slider      = slider_int:new(1, 14, 12, get_hash("raise_skeleton_max_skeletons_base")),
}

-- Skeleton skin name constants
local skeleton_ranged_shadow_name = "necro_skeletonMage_shadow"
local skeleton_ranged_cold_name = "necro_skeletonMage_cold"
local skeleton_ranged_sacrifice_name = "necro_skeletonMage_sacrifice"

local function menu()
    if menu_elements.raise_skeleton_submenu:push("Raise Skeleton") then
        -- MASTER TOGGLE
        menu_elements.enable_skill:render("Enable Skill", "Master toggle for all Raise Skeleton functionality")
        
        if menu_elements.enable_skill:get() then
            -- PHASE 2: SPAM MODE - Instant casting to reach max
            menu_elements.raise_skeleton_ranged:render("Enable Spam Mode", "Instantly cast skeletons until max is reached")
            
            if menu_elements.raise_skeleton_ranged:get() then
                menu_elements.max_skeletons_slider:render("Max Skeletons", "Maximum skeletons for spam mode (1-14)")
            end
            
            -- PHASE 5: MAINTENANCE MODE - Continuous casting for empower buff
            menu_elements.auto_buff_boolean:render("Enable Buff Maintenance", "Keep casting for 8-second empower buff even at max skeletons")
            
            if menu_elements.auto_buff_boolean:get() then
                menu_elements.auto_buff_cast_time:render("Buff Cast Interval", "Cast interval for empower buff maintenance (seconds)")
            end
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

local function get_current_skeletons_ranged_list()
    local list = {}
    local actors = actors_manager.get_ally_actors()
    
    for _, object in ipairs(actors) do
        if object then
            local skin_name = object:get_skin_name()
            local is_ranged = skin_name == skeleton_ranged_shadow_name 
                or skin_name == skeleton_ranged_cold_name 
                or skin_name == skeleton_ranged_sacrifice_name
            
            if is_ranged then
                table.insert(list, object)
            end
        end
    end
    
    return list
end

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

local last_successful_cast = 0.0

local function attempt_cast_skeleton(mode, current_count, max_count)
    local player_position = get_player_position()
    local nearby_enemy = target_selector.get_target_closer(player_position, 10.0)
    if not nearby_enemy then
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
    local distance = corpse_position:dist_to(player_position)
    
    if distance > raise_skeleton_spell_data.range then
        return false
    end
    
    if cast_spell.target(corpse_to_rise, raise_skeleton_id, 0.60, false) then
        return true
    else
        return false
    end
end

local function logics()
    local skill_enabled = menu_elements.enable_skill:get()
    if skill_enabled == nil then skill_enabled = true end
    
    if not skill_enabled then
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

    local current_skeletons = get_current_skeletons_ranged_list()
    local skeleton_count = #current_skeletons

    local ranged_toggle = menu_elements.raise_skeleton_ranged:get()
    if ranged_toggle == nil then ranged_toggle = true end
    
    if ranged_toggle then
        local max_skeletons = menu_elements.max_skeletons_slider:get()
        if max_skeletons == nil then max_skeletons = 12 end
        
        if skeleton_count < max_skeletons then
            return attempt_cast_skeleton("SPAM", skeleton_count, max_skeletons)
        end
    end

    local auto_buff = menu_elements.auto_buff_boolean:get()
    if auto_buff == nil then auto_buff = true end
    
    if auto_buff then
        local cast_interval = menu_elements.auto_buff_cast_time:get()
        if cast_interval == nil then cast_interval = 3 end
        
        local current_time = get_time_since_inject()
        local time_since_last_cast = current_time - last_successful_cast
        
        if time_since_last_cast < cast_interval then
            return false
        end
        
        local max_skeletons = 12
        if ranged_toggle then
            max_skeletons = menu_elements.max_skeletons_slider:get() or 12
        end
        
        if skeleton_count > 0 then
            if attempt_cast_skeleton("MAINTENANCE", skeleton_count, max_skeletons) then
                last_successful_cast = current_time
                return true
            else
                return false
            end
        end
    end

    return false
end

return {
    menu = menu,
    logics = logics,   
}
