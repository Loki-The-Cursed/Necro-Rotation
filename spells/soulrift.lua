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
    -- NEW: Kiting options
    enable_kiting             = checkbox:new(true, get_hash(my_utility.plugin_label .. "soulrift_enable_kiting")),
    kiting_enemy_threshold    = slider_int:new(1, 10, 3, get_hash(my_utility.plugin_label .. "soulrift_kiting_threshold")),
    kiting_distance           = slider_float:new(5.0, 15.0, 8.0, get_hash(my_utility.plugin_label .. "soulrift_kiting_distance")),
    kiting_health_threshold   = slider_int:new(0, 100, 50, get_hash(my_utility.plugin_label .. "soulrift_kiting_health_threshold")),
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
            
            -- NEW: Kiting settings
            menu_elements_soulrift.enable_kiting:render("Enable Defensive Kiting", "Kite enemies when Soulrift is on cooldown", 0)
            if menu_elements_soulrift.enable_kiting:get() then
                menu_elements_soulrift.kiting_enemy_threshold:render("Kiting Enemy Threshold", "Start kiting when this many enemies nearby", 0)
                menu_elements_soulrift.kiting_distance:render("Kiting Distance", "Distance to maintain from enemies", 0)
                menu_elements_soulrift.kiting_health_threshold:render("Kiting Health %", "Only kite when health below this %", 0)
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
        -- 使用当前生命值检查代替is_alive方法
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
    
    -- 检查玩家是否有Soulrift buff/状态
    -- 这里需要根据实际的buff ID来检查，可能需要调整
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
    
    -- 遍历所有敌人，寻找敌人最密集的区域
    for _, enemy in ipairs(enemies) do
        if enemy:get_current_health() > 0 then
            local enemy_pos = enemy:get_position()
            local distance_to_player = math.sqrt(enemy_pos:squared_dist_to_ignore_z(player_pos))
            
            -- 只考虑在移动范围内的敌人
            if distance_to_player <= movement_range then
                -- 计算这个敌人周围3米范围内的敌人数量
                local area_data = target_selector.get_most_hits_target_circular_area_light(enemy_pos, 3.0, 3.0, false)
                local enemy_count = area_data.n_hits
                
                -- 如果这个位置的敌人数量更多，更新最佳位置
                if enemy_count > max_enemies then
                    max_enemies = enemy_count
                    best_position = enemy_pos
                end
            end
        end
    end
    
    -- 只有当敌人数量达到阈值时才返回位置
    if max_enemies >= menu_elements_soulrift.movement_enemy_threshold:get() then
        return best_position, max_enemies
    end
    
    return nil, 0
end

-- NEW: 寻找最佳的躲避位置（远离敌人）
local function find_best_kiting_position()
    local player_pos = get_player_position()
    if not player_pos then
        return nil
    end
    
    local enemies = actors_manager.get_enemy_npcs()
    local nearby_enemies = {}
    local kiting_distance = menu_elements_soulrift.kiting_distance:get()
    
    -- 收集附近的敌人
    for _, enemy in ipairs(enemies) do
        if enemy:get_current_health() > 0 then
            local enemy_pos = enemy:get_position()
            local distance = math.sqrt(enemy_pos:squared_dist_to_ignore_z(player_pos))
            if distance <= kiting_distance then
                table.insert(nearby_enemies, enemy_pos)
            end
        end
    end
    
    if #nearby_enemies == 0 then
        return nil
    end
    
    -- 计算平均敌人位置
    local avg_x, avg_y, avg_z = 0, 0, 0
    for _, pos in ipairs(nearby_enemies) do
        avg_x = avg_x + pos:x()
        avg_y = avg_y + pos:y()
        avg_z = avg_z + pos:z()
    end
    avg_x = avg_x / #nearby_enemies
    avg_y = avg_y / #nearby_enemies
    avg_z = avg_z / #nearby_enemies
    
    local enemy_center = vec3.new(avg_x, avg_y, avg_z)
    
    -- 计算远离敌人中心的方向
    local direction = player_pos - enemy_center
    direction = direction:normalize()
    
    -- 计算躲避位置
    local kite_position = player_pos + (direction * 5.0)
    
    return kite_position, #nearby_enemies
end

-- 移动逻辑 - 使用orbwalker clear模式或躲避模式
local function handle_movement()
    local current_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player then
        return false
    end
    
    -- NEW: Check for kiting first (higher priority than offensive movement)
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
                -- Find kiting position
                local kite_pos, nearby_count = find_best_kiting_position()
                if kite_pos and current_time - (last_kite_time or 0) > 0.3 then
                    -- Switch to flee mode for kiting
                    orbwalker.set_orbwalker_mode(orb_mode.flee)
                    pathfinder.force_move(kite_pos)
                    last_kite_time = current_time
                    
                    console.print("Necromancer Plugin: KITING - Soulrift on CD, " .. nearby_count .. 
                        " enemies nearby, HP: " .. math.floor(health_percentage) .. "%")
                    return true
                end
            end
        end
    end
    
    -- Original offensive movement logic (only when soulrift is active)
    if not menu_elements_soulrift.enable_movement:get() then
        return false
    end
    
    -- 只有当Soulrift技能激活时才移动
    if not is_soulrift_active() then
        movement_target_pos = nil
        -- 确保clear模式在技能不活跃时正常工作
        orbwalker.set_clear_toggle(true)
        -- Reset orbwalker mode if we were kiting
        if orbwalker.get_orb_mode() == orb_mode.flee then
            orbwalker.set_orbwalker_mode(orb_mode.clear)
        end
        return false
    end
    
    -- 寻找新的移动目标
    local best_pos, enemy_count = find_best_enemy_cluster()
    if best_pos and enemy_count >= menu_elements_soulrift.movement_enemy_threshold:get() then
        local player_pos = get_player_position()
        if player_pos then
            local distance_to_cluster = math.sqrt(best_pos:squared_dist_to_ignore_z(player_pos))
            
            -- 如果距离敌人群超过3米，暂时禁用clear模式并手动移动
            if distance_to_cluster > 3.0 then
                -- 禁用clear模式，这样orbwalker不会被其他敌人分心
                orbwalker.set_clear_toggle(false)
                
                -- 设置orbwalker为clear模式但会移向目标
                orbwalker.set_orbwalker_mode(orb_mode.clear)
                
                -- 使用force_move移动到敌人群
                if current_time - (movement_last_command_time or 0) > 0.3 then
                    pathfinder.force_move(best_pos)
                    movement_last_command_time = current_time
                    console.print("Necromancer Plugin: Moving to enemy cluster with " .. enemy_count .. " enemies (distance: " .. math.floor(distance_to_cluster) .. "m)")
                end
                
                return true
            else
                -- 距离足够近，重新启用clear模式让orbwalker正常工作
                orbwalker.set_clear_toggle(true)
                orbwalker.set_orbwalker_mode(orb_mode.clear)
                return false
            end
        end
    else
        -- 没有足够的敌人聚集，确保clear模式正常
        orbwalker.set_clear_toggle(true)
        return false
    end
    
    return false
end

-- 逻辑函数
local function logics()
    -- 检查菜单是否启用
    if not menu_elements_soulrift.enable_spell:get() then
        return false
    end

    -- 处理移动逻辑 (includes both kiting and offensive movement)
    local is_moving = handle_movement()
    
    -- 如果正在躲避（kiting），不要施放技能
    if is_moving and is_soulrift_on_cooldown() then
        return false
    end

    -- 检查技能是否允许施放
    local is_allowed = my_utility.is_spell_allowed(
        true,  -- 启用检查
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

    -- BOSS检测优先逻辑
    if menu_elements_soulrift.force_on_boss:get() then
        local boss_range = menu_elements_soulrift.boss_range:get()
        if has_boss_in_range(boss_range) then
            -- 强制施放技能（忽略其他条件）
            if cast_spell.self(spell_id_soulrift, 0.0) then
                console.print("Necromancer Plugin: Casted Soulrift on BOSS target")
                last_cast_time = get_time_since_inject()
                next_time_allowed_cast = last_cast_time + 0.5
                return true
            end
        end
    end

    -- 常规条件检查（如果没有检测到BOSS或BOSS功能未启用）
    
    -- 检查生命值百分比
    local current_health = local_player:get_current_health()
    local max_health = local_player:get_max_health()
    local health_percentage = (current_health / max_health) * 100
    
    if health_percentage > menu_elements_soulrift.health_percentage:get() then
        return false
    end

    -- 获取玩家位置
    local player_pos = get_player_position()
    if not player_pos then
        return false
    end

    -- 检查玩家周围的敌人数量
    local area_data = target_selector.get_most_hits_target_circular_area_light(player_pos, 3.0, 3.0, false)
    local enemy_count = area_data.n_hits

    -- 检查是否达到最小敌人数量
    if enemy_count < menu_elements_soulrift.min_targets:get() then
        return false
    end

    -- 施放技能
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
