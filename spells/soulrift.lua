local my_utility = require("my_utility/my_utility")

-- 菜单元素定义
local menu_elements_soulrift = 
{
    tree_tab                  = tree_node:new(1),
    enable_spell              = checkbox:new(true, get_hash(my_utility.plugin_label .. "enable_spell_soulrift")),
    min_targets               = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "min_enemies_to_cast_soulrift")),
    health_percentage         = slider_int:new(0, 100, 75, get_hash(my_utility.plugin_label .. "soulrift_health_percentage")),
    boss_range                = slider_float:new(5.0, 20.0, 10.0, get_hash(my_utility.plugin_label .. "soulrift_boss_range")),
    force_on_boss             = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_force_on_boss")),
    enable_movement           = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_enable_movement")),
    movement_enemy_threshold  = slider_int:new(3, 15, 5, get_hash(my_utility.plugin_label .. "soulrift_movement_threshold")),
    movement_range            = slider_float:new(5.0, 25.0, 15.0, get_hash(my_utility.plugin_label .. "soulrift_movement_range")),
    -- Kiting options
    enable_kiting             = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_enable_kiting")),
    kiting_enemy_threshold    = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "soulrift_kiting_threshold")),
    kiting_distance           = slider_float:new(5.0, 15.0, 8.0, get_hash(my_utility.plugin_label .. "soulrift_kiting_distance")),
    kiting_health_threshold   = slider_int:new(0, 100, 80, get_hash(my_utility.plugin_label .. "soulrift_kiting_health_threshold")),
    -- NEW: Advanced kiting options
    kiting_mode               = combo_box:new(0, get_hash(my_utility.plugin_label .. "soulrift_kiting_mode")),
    enable_stutter_step       = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_stutter_step")),
    boss_kiting_multiplier    = slider_float:new(1.0, 2.0, 1.5, get_hash(my_utility.plugin_label .. "soulrift_boss_kite_mult")),
    enable_predictive_kiting  = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_predictive_kite")),
}

-- 技能ID
local spell_id_soulrift = 1644584

-- 逻辑变量
local next_time_allowed_cast = 0.0
local last_cast_time = 0.0
local movement_target_pos = nil
local movement_start_time = 0.0
local movement_last_command_time = 0.0
local last_kite_time = 0.0
local last_attack_time = 0.0
local kiting_stuck_check_pos = nil
local kiting_stuck_check_time = 0.0

-- 菜单函数
local function menu()
    if menu_elements_soulrift.tree_tab:push("Soulrift") then
        menu_elements_soulrift.enable_spell:render("Enable Spell", "")
        
        if menu_elements_soulrift.enable_spell:get() then
            menu_elements_soulrift.min_targets:render("Min Enemies Around", "Amount of targets to cast the spell", 0)
            menu_elements_soulrift.health_percentage:render("Max Health %", "Cast when health below this %", 0)
            menu_elements_soulrift.boss_range:render("Boss Detection Range", "Range to detect boss targets", 0)
            menu_elements_soulrift.force_on_boss:render("Force Cast on Boss", "Ignore conditions when boss is present", 0)
            
            menu_elements_soulrift.enable_movement:render("Enable Movement", "Move to enemy clusters when skill is active", 0)
            if menu_elements_soulrift.enable_movement:get() then
                menu_elements_soulrift.movement_enemy_threshold:render("Movement Enemy Threshold", "Move when detecting this many enemies", 0)
                menu_elements_soulrift.movement_range:render("Movement Detection Range", "Range to search for enemy clusters", 0)
            end
            
            -- Kiting settings
            menu_elements_soulrift.enable_kiting:render("Enable Defensive Kiting", "Kite enemies when Soulrift is on cooldown", 0)
            if menu_elements_soulrift.enable_kiting:get() then
                menu_elements_soulrift.kiting_enemy_threshold:render("Kiting Enemy Threshold", "Start kiting when this many enemies nearby", 0)
                menu_elements_soulrift.kiting_distance:render("Kiting Distance", "Distance to maintain from enemies", 0)
                menu_elements_soulrift.kiting_health_threshold:render("Kiting Health %", "Only kite when health below this %", 0)
                
                -- Advanced options
                local kiting_modes = {"Smart Positioning", "Direct Retreat", "Circular Strafe", "Terrain Hugging"}
                menu_elements_soulrift.kiting_mode:render("Kiting Mode", kiting_modes, "Choose kiting behavior pattern")
                menu_elements_soulrift.enable_stutter_step:render("Stutter Step", "Attack while kiting (if possible)")
                menu_elements_soulrift.boss_kiting_multiplier:render("Boss Distance Multiplier", "Extra distance from bosses", 1)
                menu_elements_soulrift.enable_predictive_kiting:render("Predictive Movement", "Predict enemy movement patterns")
            end
        end
        
        menu_elements_soulrift.tree_tab:pop()
    end
end

-- 检查附近是否有Boss
local function has_boss_in_range(range)
    local player_pos = get_player_position()
    if not player_pos then
        return false
    end
    
    local enemies = actors_manager.get_enemy_npcs()
    for _, enemy in ipairs(enemies) do
        if enemy:is_boss() and enemy:get_current_health() > 0 then
            local enemy_pos = enemy:get_position()
            local distance_sqr = enemy_pos:squared_dist_to_ignore_z(player_pos)
            if distance_sqr <= (range * range) then
                return true
            end
        end
    end
    
    return false
end

-- 检查技能是否处于激活状态
local function is_soulrift_active()
    local local_player = get_local_player()
    if not local_player then
        return false
    end
    
    local buffs = local_player:get_buffs()
    for _, buff in ipairs(buffs) do
        if buff.spell_id == spell_id_soulrift then
            return true
        end
    end
    
    return false
end

-- 检查技能是否在冷却中
local function is_soulrift_on_cooldown()
    return not utility.is_spell_ready(spell_id_soulrift)
end

-- Calculate enemy threat score
local function get_enemy_threat_score(enemy, player_pos)
    local enemy_pos = enemy:get_position()
    local distance = math.sqrt(enemy_pos:squared_dist_to_ignore_z(player_pos))
    local base_score = 100 / (distance + 1) -- Closer enemies are more threatening
    
    -- Weight by enemy type
    if enemy:is_boss() then
        base_score = base_score * 3.0
    elseif enemy:is_champion() then
        base_score = base_score * 2.0
    elseif enemy:is_elite() then
        base_score = base_score * 1.5
    end
    
    -- Consider enemy health (healthier enemies are more threatening)
    local health_ratio = enemy:get_current_health() / enemy:get_max_health()
    base_score = base_score * (0.5 + health_ratio * 0.5)
    
    return base_score
end

-- Check if position is safe (no walls, not in danger zone)
local function is_position_safe(pos, player_pos)
    -- Check if position is reachable (no walls)
    if prediction.is_wall_collision(player_pos, pos, 1.0) then
        return false
    end
    
    -- Check if position is in evade danger zone
    if evade.is_dangerous_position(pos) then
        return false
    end
    
    -- Check if pathfinding is possible
    local path = pathfinder.get_path(pos)
    if not path or #path == 0 then
        return false
    end
    
    return true
end

-- Generate escape positions with multiple angles
local function generate_escape_positions(player_pos, threat_direction, base_distance, num_positions)
    local positions = {}
    local angle_step = math.pi / (num_positions - 1) -- 180 degree arc
    local start_angle = math.atan2(threat_direction:y(), threat_direction:x())
    
    for i = 0, num_positions - 1 do
        local angle = start_angle + (i - (num_positions - 1) / 2) * angle_step
        local x = player_pos:x() + base_distance * math.cos(angle)
        local y = player_pos:y() + base_distance * math.sin(angle)
        local test_pos = vec3.new(x, y, player_pos:z())
        
        if is_position_safe(test_pos, player_pos) then
            table.insert(positions, {
                pos = test_pos,
                angle_from_threat = math.abs((i - (num_positions - 1) / 2) * angle_step),
                distance = base_distance
            })
        end
    end
    
    return positions
end

-- Enhanced kiting position finder
local function find_best_kiting_position_advanced()
    local player_pos = get_player_position()
    if not player_pos then
        return nil
    end
    
    local enemies = actors_manager.get_enemy_npcs()
    local threat_data = {}
    local kiting_distance = menu_elements_soulrift.kiting_distance:get()
    local boss_multiplier = menu_elements_soulrift.boss_kiting_multiplier:get()
    
    -- Analyze threats
    local total_threat_x, total_threat_y = 0, 0
    local total_threat_score = 0
    local has_boss = false
    local closest_enemy_dist = math.huge
    
    for _, enemy in ipairs(enemies) do
        if enemy:get_current_health() > 0 then
            local enemy_pos = enemy:get_position()
            local distance = math.sqrt(enemy_pos:squared_dist_to_ignore_z(player_pos))
            
            -- Adjust detection range for bosses
            local check_distance = kiting_distance
            if enemy:is_boss() then
                check_distance = check_distance * boss_multiplier
                has_boss = true
            end
            
            if distance <= check_distance then
                local threat_score = get_enemy_threat_score(enemy, player_pos)
                
                -- Predictive movement
                local predicted_pos = enemy_pos
                if menu_elements_soulrift.enable_predictive_kiting:get() then
                    predicted_pos = prediction.get_future_unit_position(enemy, 0.5)
                end
                
                -- Weight threat vector by score
                local threat_vector = predicted_pos - player_pos
                threat_vector = threat_vector:normalize()
                
                total_threat_x = total_threat_x + threat_vector:x() * threat_score
                total_threat_y = total_threat_y + threat_vector:y() * threat_score
                total_threat_score = total_threat_score + threat_score
                
                closest_enemy_dist = math.min(closest_enemy_dist, distance)
                
                table.insert(threat_data, {
                    enemy = enemy,
                    pos = enemy_pos,
                    predicted_pos = predicted_pos,
                    distance = distance,
                    score = threat_score
                })
            end
        end
    end
    
    if total_threat_score == 0 then
        return nil
    end
    
    -- Calculate weighted threat direction
    local avg_threat_dir = vec3.new(-total_threat_x / total_threat_score, 
                                    -total_threat_y / total_threat_score, 0)
    avg_threat_dir = avg_threat_dir:normalize()
    
    -- Determine kiting mode behavior
    local kiting_mode = menu_elements_soulrift.kiting_mode:get()
    local best_position = nil
    
    if kiting_mode == 0 then -- Smart Positioning
        -- Generate multiple escape angles
        local escape_distance = kiting_distance
        if has_boss then
            escape_distance = escape_distance * boss_multiplier
        end
        
        local escape_positions = generate_escape_positions(player_pos, avg_threat_dir, 
                                                         escape_distance, 7)
        
        -- Score each position
        local best_score = -math.huge
        for _, escape_data in ipairs(escape_positions) do
            local pos_score = 100
            
            -- Prefer straight retreat but allow angles if blocked
            pos_score = pos_score - escape_data.angle_from_threat * 20
            
            -- Check distance from all enemies
            local min_enemy_dist = math.huge
            for _, threat in ipairs(threat_data) do
                local dist = math.sqrt(threat.predicted_pos:squared_dist_to_ignore_z(escape_data.pos))
                min_enemy_dist = math.min(min_enemy_dist, dist)
                
                -- Penalty for being too close to any enemy
                if dist < kiting_distance * 0.8 then
                    pos_score = pos_score - (kiting_distance - dist) * 10
                end
            end
            
            -- Bonus for maintaining good distance
            pos_score = pos_score + min_enemy_dist * 2
            
            if pos_score > best_score then
                best_score = pos_score
                best_position = escape_data.pos
            end
        end
        
    elseif kiting_mode == 1 then -- Direct Retreat
        local retreat_distance = kiting_distance
        if has_boss then
            retreat_distance = retreat_distance * boss_multiplier
        end
        best_position = player_pos + (avg_threat_dir * retreat_distance)
        
        -- Fallback if direct path blocked
        if not is_position_safe(best_position, player_pos) then
            local positions = generate_escape_positions(player_pos, avg_threat_dir, 
                                                      retreat_distance, 5)
            if #positions > 0 then
                best_position = positions[1].pos
            end
        end
        
    elseif kiting_mode == 2 then -- Circular Strafe
        -- Calculate perpendicular direction for strafing
        local strafe_dir = vec3.new(-avg_threat_dir:y(), avg_threat_dir:x(), 0)
        
        -- Alternate strafe direction
        local current_time = get_time_since_inject()
        if math.floor(current_time / 2) % 2 == 0 then
            strafe_dir = strafe_dir * -1
        end
        
        local strafe_distance = kiting_distance * 0.7
        best_position = player_pos + (strafe_dir * strafe_distance) + (avg_threat_dir * strafe_distance * 0.5)
        
        if not is_position_safe(best_position, player_pos) then
            -- Try opposite direction
            strafe_dir = strafe_dir * -1
            best_position = player_pos + (strafe_dir * strafe_distance) + (avg_threat_dir * strafe_distance * 0.5)
        end
        
    elseif kiting_mode == 3 then -- Terrain Hugging
        -- Find nearby walls/obstacles and use them for cover
        local test_distance = kiting_distance * 0.8
        local best_wall_pos = nil
        local best_wall_score = -math.huge
        
        -- Test positions in a circle
        for i = 0, 11 do
            local angle = (i / 12) * 2 * math.pi
            local test_x = player_pos:x() + test_distance * math.cos(angle)
            local test_y = player_pos:y() + test_distance * math.sin(angle)
            local test_pos = vec3.new(test_x, test_y, player_pos:z())
            
            -- Check if there's a wall beyond this position
            local extended_pos = test_pos + (test_pos - player_pos):normalize() * 2
            if prediction.is_wall_collision(test_pos, extended_pos, 1.0) and 
               is_position_safe(test_pos, player_pos) then
                
                -- Score based on distance from threats
                local score = 0
                for _, threat in ipairs(threat_data) do
                    local dist = math.sqrt(threat.predicted_pos:squared_dist_to_ignore_z(test_pos))
                    score = score + dist * threat.score
                end
                
                if score > best_wall_score then
                    best_wall_score = score
                    best_wall_pos = test_pos
                end
            end
        end
        
        best_position = best_wall_pos or (player_pos + avg_threat_dir * kiting_distance)
    end
    
    -- Anti-stuck mechanism
    if best_position then
        local current_time = get_time_since_inject()
        if kiting_stuck_check_pos and current_time - kiting_stuck_check_time < 2.0 then
            local moved_distance = math.sqrt(player_pos:squared_dist_to_ignore_z(kiting_stuck_check_pos))
            if moved_distance < 1.0 then
                -- We're stuck, try alternative angle
                local alt_angle = math.random() * math.pi - math.pi/2
                local alt_x = player_pos:x() + kiting_distance * math.cos(alt_angle)
                local alt_y = player_pos:y() + kiting_distance * math.sin(alt_angle)
                best_position = vec3.new(alt_x, alt_y, player_pos:z())
                console.print("Necromancer Plugin: Anti-stuck kiting activated")
            end
        else
            kiting_stuck_check_pos = player_pos
            kiting_stuck_check_time = current_time
        end
    end
    
    return best_position, #threat_data
end

-- Stutter step attack logic
local function perform_stutter_step()
    if not menu_elements_soulrift.enable_stutter_step:get() then
        return false
    end
    
    local current_time = get_time_since_inject()
    local attack_interval = 0.8 -- Adjust based on attack speed
    
    if current_time - last_attack_time < attack_interval then
        return false
    end
    
    -- Find closest enemy to attack
    local player_pos = get_player_position()
    local closest_enemy = target_selector.get_target_closer(player_pos, 10.0)
    
    if closest_enemy then
        -- Quick attack between movements
        orbwalker.set_orbwalker_mode(orb_mode.pvp)
        orbwalker.set_attack_target(closest_enemy)
        last_attack_time = current_time
        
        -- Schedule return to flee mode
        return true
    end
    
    return false
end

-- 寻找最佳的敌人聚集位置
local function find_best_enemy_cluster()
    local player_pos = get_player_position()
    if not player_pos then
        return nil
    end
    
    local enemies = actors_manager.get_enemy_npcs()
    local best_position = nil
    local max_enemies = 0
    local movement_range = menu_elements_soulrift.movement_range:get()
    
    for _, enemy in ipairs(enemies) do
        if enemy:get_current_health() > 0 then
            local enemy_pos = enemy:get_position()
            local distance_to_player = math.sqrt(enemy_pos:squared_dist_to_ignore_z(player_pos))
            
            if distance_to_player <= movement_range then
                local area_data = target_selector.get_most_hits_target_circular_area_light(enemy_pos, 3.0, 3.0, false)
                local enemy_count = area_data.n_hits
                
                if enemy_count > max_enemies then
                    max_enemies = enemy_count
                    best_position = enemy_pos
                end
            end
        end
    end
    
    if max_enemies >= menu_elements_soulrift.movement_enemy_threshold:get() then
        return best_position, max_enemies
    end
    
    return nil, 0
end

-- 移动逻辑 - 使用orbwalker clear模式或躲避模式
local function handle_movement()
    local current_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player then
        return false
    end
    
    -- Check for kiting first (higher priority than offensive movement)
    if menu_elements_soulrift.enable_kiting:get() and is_soulrift_on_cooldown() and not is_soulrift_active() then
        -- Check health threshold for kiting
        local current_health = local_player:get_current_health()
        local max_health = local_player:get_max_health()
        local health_percentage = (current_health / max_health) * 100
        
        if health_percentage <= menu_elements_soulrift.kiting_health_threshold:get() then
            -- Check nearby enemy count
            local player_pos = get_player_position()
            local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 
                menu_elements_soulrift.kiting_distance:get(), 
                menu_elements_soulrift.kiting_distance:get(), false)
            local enemy_count = area_data.n_hits
            
            if enemy_count >= menu_elements_soulrift.kiting_enemy_threshold:get() then
                -- Find kiting position with advanced logic
                local kite_pos, threat_count = find_best_kiting_position_advanced()
                
                if kite_pos then
                    -- Handle stutter stepping
                    if menu_elements_soulrift.enable_stutter_step:get() and 
                       current_time - last_attack_time > 0.5 then
                        if perform_stutter_step() then
                            last_attack_time = current_time
                            return true
                        end
                    end
                    
                    -- Perform kiting movement
                    if current_time - (last_kite_time or 0) > 0.2 then
                        orbwalker.set_orbwalker_mode(orb_mode.flee)
                        pathfinder.force_move(kite_pos)
                        last_kite_time = current_time
                        
                        local kiting_modes = {"Smart", "Direct", "Strafe", "Terrain"}
                        local mode_name = kiting_modes[menu_elements_soulrift.kiting_mode:get() + 1]
                        
                        console.print(string.format("Necromancer: KITING [%s] - %d threats, HP: %d%%", 
                            mode_name, threat_count, math.floor(health_percentage)))
                        return true
                    end
                end
            end
        end
    end
    
    -- Original offensive movement logic (only when soulrift is active)
    if not menu_elements_soulrift.enable_movement:get() then
        return false
    end
    
    if not is_soulrift_active() then
        movement_target_pos = nil
        orbwalker.set_clear_toggle(true)
        -- Reset orbwalker mode if we were kiting
        if orbwalker.get_orb_mode() == orb_mode.flee then
            orbwalker.set_orbwalker_mode(orb_mode.clear)
        end
        return false
    end
    
    local best_pos, enemy_count = find_best_enemy_cluster()
    if best_pos and enemy_count >= menu_elements_soulrift.movement_enemy_threshold:get() then
        local player_pos = get_player_position()
        if player_pos then
            local distance_to_cluster = math.sqrt(best_pos:squared_dist_to_ignore_z(player_pos))
            
            if distance_to_cluster > 3.0 then
                orbwalker.set_clear_toggle(false)
                orbwalker.set_orbwalker_mode(orb_mode.clear)
                
                if current_time - (movement_last_command_time or 0) > 0.3 then
                    pathfinder.force_move(best_pos)
                    movement_last_command_time = current_time
                    console.print("Necromancer Plugin: Moving to enemy cluster with " .. enemy_count .. " enemies (distance: " .. math.floor(distance_to_cluster) .. "m)")
                end
                
                return true
            else
                orbwalker.set_clear_toggle(true)
                orbwalker.set_orbwalker_mode(orb_mode.clear)
                return false
            end
        end
    else
        orbwalker.set_clear_toggle(true)
        return false
    end
    
    return false
end

-- 逻辑函数
local function logics()
    if not menu_elements_soulrift.enable_spell:get() then
        return false
    end

    -- Handle movement (includes both kiting and offensive movement)
    local is_moving = handle_movement()
    
    -- If kiting, don't cast
    if is_moving and is_soulrift_on_cooldown() then
        return false
    end

    local is_allowed = my_utility.is_spell_allowed(
        true,
        next_time_allowed_cast,
        spell_id_soulrift
    )

    if not is_allowed then
        return false
    end

    local local_player = get_local_player()
    if not local_player then
        return false
    end

    -- Boss priority
    if menu_elements_soulrift.force_on_boss:get() then
        local boss_range = menu_elements_soulrift.boss_range:get()
        if has_boss_in_range(boss_range) then
            if cast_spell.self(spell_id_soulrift, 0.0) then
                console.print("Necromancer Plugin: Casted Soulrift on BOSS target")
                last_cast_time = get_time_since_inject()
                next_time_allowed_cast = last_cast_time + 0.5
                return true
            end
        end
    end

    -- Regular casting conditions
    local current_health = local_player:get_current_health()
    local max_health = local_player:get_max_health()
    local health_percentage = (current_health / max_health) * 100
    
    if health_percentage > menu_elements_soulrift.health_percentage:get() then
        return false
    end

    local player_pos = get_player_position()
    if not player_pos then
        return false
    end

    local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 3.0, 3.0, false)
    local enemy_count = area_data.n_hits

    if enemy_count < menu_elements_soulrift.min_targets:get() then
        return false
    end

    if cast_spell.self(spell_id_soulrift, 0.0) then
        console.print("Necromancer Plugin: Casted Soulrift on " .. enemy_count .. " enemies")
        last_cast_time = get_time_since_inject()
        next_time_allowed_cast = last_cast_time + 0.5
        return true
    end

    return false
end

return {
    menu = menu,
    logics = logics
}
