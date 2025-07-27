local my_utility = require("my_utility/my_utility")
local menu_elements_bone =
{
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean")),
    main_tree           = tree_node:new(0),
    
    -- Spell categorization trees
    active_spells_tree = tree_node:new(1),
    inactive_spells_tree = tree_node:new(1),
}

return menu_elements_bone;