-- sequence_manager.lua - FINAL VERSION with all features
local sequence_manager = {}

-- Advanced sequence state tracking
local sequence_state = {
    active = false,
    step = 0,  -- 0: none, 1: tendrils cast, 2: prison cast, 3: blight cast
    target_position = nil,
    corpse_used = nil,
    start_time = 0,
    last_step_time = 0,
    step_timings = {
        tendril_to_prison = 0.3,  -- Wait 0.3s after tendrils before prison
        prison_to_blight = 0.2,   -- Wait 0.2s after prison before blight
        sequence_timeout = 3.0    -- Total sequence timeout
    }
}

-- Helper function: Check wall collision for a position
local function check_wall_collision_at_position(player_position, target_position, distance)
    -- Since target_selector.is_wall_collision requires a target object,
    -- we use alternative approaches for position-based collision checking
    
    -- Method 1: Get enemies at that position and check collision to them
    local enemies_at_position = utility.get_units_inside_circle_list(target_position, 1.0)
    if #enemies_at_position > 0 then
        -- Check collision to the first enemy at that position
        local is_collision = target_selector.is_wall_collision(player_position, enemies_at_position[1], distance or 0.20)
        return is_collision
    end
    
    -- Method 2: If no enemies at position, assume no collision
    -- (The position was already validated by corpse tendrils)
    return false
end

-- Initialize sequence with corpse tendrils
function sequence_manager.start_sequence(corpse_position, corpse_object)
    sequence_state.active = true
    sequence_state.step = 1
    sequence_state.target_position = corpse_position
    sequence_state.corpse_used = corpse_object
    sequence_state.start_time = get_time_since_inject()
    sequence_state.last_step_time = sequence_state.start_time
    
    console.print("[Sequence] Starting Tendrils -> Prison -> Blight combo", 1)
end

-- Check wall collision for a position (helper function)
local function check_wall_collision_at_position(player_position, target_position, distance)
    -- Since we can't check collision directly to a position,
    -- we use a different approach based on available API
    
    -- Method 1: Get enemies at that position and check collision to them
    local enemies_at_position = utility.get_units_inside_circle_list(target_position, 1.0)
    if #enemies_at_position > 0 then
        -- Check collision to the first enemy at that position
        local is_collision = target_selector.is_wall_collision(player_position, enemies_at_position[1], distance or 0.20)
        return is_collision
    end
    
    -- Method 2: If no enemies at position, assume no collision
    -- (The position was already validated by corpse tendrils)
    return false
end
function sequence_manager.should_cast_next_step(spell_type)
    if not sequence_state.active then
        return false
    end
    
    local current_time = get_time_since_inject()
    local total_elapsed = current_time - sequence_state.start_time
    local step_elapsed = current_time - sequence_state.last_step_time
    
    -- Timeout check
    if total_elapsed > sequence_state.step_timings.sequence_timeout then
        console.print("[Sequence] Timeout - resetting sequence", 1)
        sequence_manager.reset_sequence()
        return false
    end
    
    -- Check timing for each step
    if spell_type == "bone_prison" and sequence_state.step == 1 then
        -- Check if enough time passed since tendrils
        if step_elapsed >= sequence_state.step_timings.tendril_to_prison then
            return true
        end
    elseif spell_type == "blight" and sequence_state.step == 2 then
        -- Check if enough time passed since prison
        if step_elapsed >= sequence_state.step_timings.prison_to_blight then
            return true
        end
    end
    
    return false
end

-- Advance to next step
function sequence_manager.advance_step()
    sequence_state.step = sequence_state.step + 1
    sequence_state.last_step_time = get_time_since_inject()
    
    if sequence_state.step > 3 then
        console.print("[Sequence] Combo completed successfully!", 1)
        sequence_manager.reset_sequence()
    end
end

-- Get target position for sequence
function sequence_manager.get_sequence_position()
    return sequence_state.target_position
end

-- Check if sequence is active
function sequence_manager.is_sequence_active()
    return sequence_state.active
end

-- Get current sequence step (for debugging)
function sequence_manager.get_current_step()
    return sequence_state.step
end

-- Get sequence info (for debugging)
function sequence_manager.get_sequence_info()
    if not sequence_state.active then
        return "Sequence: Inactive"
    end
    
    local current_time = get_time_since_inject()
    local elapsed = current_time - sequence_state.start_time
    local step_names = {"", "Tendrils", "Prison", "Blight"}
    
    return string.format("Sequence: Step %d (%s) - %.1fs elapsed", 
                        sequence_state.step, 
                        step_names[sequence_state.step + 1] or "Complete", 
                        elapsed)
end

-- Force reset sequence (emergency)
function sequence_manager.reset_sequence()
    sequence_state.active = false
    sequence_state.step = 0
    sequence_state.target_position = nil
    sequence_state.corpse_used = nil
    sequence_state.start_time = 0
    sequence_state.last_step_time = 0
end

-- Configure timing (optional - for advanced users)
function sequence_manager.set_timing(tendril_to_prison, prison_to_blight, timeout)
    if tendril_to_prison then
        sequence_state.step_timings.tendril_to_prison = tendril_to_prison
    end
    if prison_to_blight then
        sequence_state.step_timings.prison_to_blight = prison_to_blight
    end
    if timeout then
        sequence_state.step_timings.sequence_timeout = timeout
    end
end

-- Get current timings
function sequence_manager.get_timings()
    return sequence_state.step_timings
end

-- Check wall collision for position (public function)
function sequence_manager.check_wall_collision(player_position, target_position, distance)
    return check_wall_collision_at_position(player_position, target_position, distance)
end

return sequence_manager