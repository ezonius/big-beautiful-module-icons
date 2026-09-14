if mods.pypostprocessing then return end -- This code already exists in py

local function collision_box(machine)
    local collision_box = machine.selection_box or machine.collision_box
    if not collision_box then return nil end

    local left_top = collision_box[1] or collision_box.left_top
    local right_bottom = collision_box[2] or collision_box.right_bottom
    if not left_top or not right_bottom then return nil end

    local x1, y1 = left_top[1] or left_top.x, left_top[2] or left_top.y
    local x2, y2 = right_bottom[1] or right_bottom.x, right_bottom[2] or right_bottom.y
    if not x1 or not y1 or not x2 or not y2 then return nil end

    return x1, y1, x2, y2
end

local function scale_module_alt_icons(machine, inventory_index)
    local already_has_icons = false
    -- if the machine already has defined some custom icons positioning, remove them and replace with ours
    local new_icons_positioning = {}
    if machine.icons_positioning and type(machine.icons_positioning) == "table" then
        for _, positioning in pairs(machine.icons_positioning) do
            if positioning.inventory_index ~= inventory_index then
                table.insert(new_icons_positioning, positioning)
            else
                already_has_icons = true
            end
        end
    end

    local x1, y1, x2, y2 = collision_box(machine)
    if not x1 then return end
    local full_width, height = x2 - x1, y2 - y1 -- full rectangular box width, used for row capacity
    local width = full_width
    if math.abs(width - height) > 0.5 then
        if already_has_icons then return end -- we skip manually defined rectangular machines
        -- Layout math uses the min(width, height) square as the bound for scale/height so
        -- vertical fit is guaranteed; only row capacity uses the full rectangular width.
        -- The real box bottom (y2) stays the shift anchor, so the stack never spills below.
        width = math.min(width, height)
        height = width
    end
    local area = width * height

    if machine.type == "lab" and area <= 16 then return end

    local module_slots = machine.module_slots
    if not module_slots or module_slots == 0 then return end

    local cap = settings.startup["bbmi-max-rendered-module-icons"].value
    ---@cast cap number
    if cap > 0 then
        if cap > 20 then cap = 20 end -- hardcoded maximum, matching the setting's allowed range
        module_slots = math.min(module_slots, cap)
    end -- cap == 0: feature off, no capping (all module icons rendered)

    -- Wide-grid layout. Enumerate the canonical row packings (for each row count the packing
    -- yields the minimal column count that still holds all icons, cols = ceil(slots / rows);
    -- duplicate non-canonical packings are skipped) and for each grid compute the single
    -- uniform scale that makes the rows x columns grid fit inside the bounding box in BOTH
    -- dimensions -- the tighter of the two constraints:
    --   scale = min(box_width / (cols * 1.1), max_grid_height / (rows * 1.1))
    -- The vertical budget is only the bottom ~1/3 of the box for machines that draw an
    -- active-recipe icon: the game draws the grid BOTTOM-ANCHORED (first row at the shift
    -- point, further rows stacking DOWNWARD from it), so the grid occupies the band ending
    -- at the box bottom, and the upper
    -- part of the box must stay free for that recipe icon. Mining drills draw no recipe
    -- icon, so their vertical budget is (nearly) the FULL box height instead.
    --
    -- Preference: the WIDEST grid that fits. Every candidate grid fits by construction (the
    -- scale above is exactly the largest scale at which it fits both dimensions), so the old
    -- square-ish "largest scale wins" enumeration and its 0.4 area-coverage guard are gone:
    -- the fitting math above is the sole rejection authority. Instead, the qualifying grid
    -- with the MOST columns wins (tie-break: larger scale). Widening is not unbounded -- a
    -- grid qualifies when its scale stays at least half of the largest scale any grid could
    -- achieve (largest_scale / 2); anything wider would render the icons at under half their
    -- maximum possible size. Counts that don't split evenly into the winning grid simply
    -- leave a partially filled last row. If no candidate grid qualifies (only possible when
    -- largest_scale == 0, i.e. no slots), no entry is written.
    local largest_scale = 0
    for num_module_rows = 1, math.ceil(module_slots / 2) do
        local cols = math.ceil(module_slots / num_module_rows)
        if math.ceil(module_slots / cols) == num_module_rows then -- skip duplicate non-canonical packings
            local max_grid_height = height * 0.325
            if machine.type == "mining-drill" then max_grid_height = height end
            local scale = math.min(width / (cols * 1.1), max_grid_height / (num_module_rows * 1.1))
            if scale > largest_scale then largest_scale = scale end
        end
    end

    local best_scale, best_cols
    local min_scale = largest_scale * 0.5 - 1e-9
    for num_module_rows = 1, math.ceil(module_slots / 2) do
        local cols = math.ceil(module_slots / num_module_rows)
        if math.ceil(module_slots / cols) == num_module_rows then -- skip duplicate non-canonical packings
            local max_grid_height = height * 0.325
            if machine.type == "mining-drill" then max_grid_height = height end
            local scale = math.min(width / (cols * 1.1), max_grid_height / (num_module_rows * 1.1))
            if scale >= min_scale and (not best_cols or cols > best_cols) then
                best_scale = scale
                best_cols = cols
            end
        end
    end

    if best_scale then
        -- The engine anchors the first row at the shift point and stacks further rows
        -- DOWNWARD from it, so the whole grid is placed by lowering the shift by the
        -- rendered grid height: the last row's bottom ends flush with the box bottom
        -- and the stack grows upward inside the box.
        local module_alt_mode_width = 1.1 * best_scale

        -- Maximize the icons per row at the chosen scale to fill the machine's FULL rectangular
        -- box width (more columns means fewer rows, which only shrinks the used band height).
        -- The square min(width, height) bound still governs scale/height, so vertical fit holds:
        -- cols * 1.1 * scale <= full width and rows * 1.1 * scale <= vertical budget
        -- (full box height for mining drills, else height * 0.325).
        -- Never drop below the winning enumerated grid's columns: fewer columns would add a row
        -- and exceed the vertical budget that scale was computed for. A floating-point floor at
        -- an exact-fit boundary (floor(2.7 / 0.54) == 4) would otherwise do exactly that, hence
        -- the tiny epsilon and the max() with best_cols.
        local max_icons_per_row = math.max(best_cols,
            math.min(module_slots, math.floor(full_width / module_alt_mode_width + 1e-9)))

        -- Rows actually rendered by the engine (slots are already capacity-capped; a partial last row counts as a full one).
        local rows = math.ceil(module_slots / max_icons_per_row)
        local y = y2 - rows * module_alt_mode_width
        local shift = {0, y}

        if machine.type == "beacon" then shift = {0, 0} end

        table.insert(new_icons_positioning,
            {inventory_index = inventory_index, shift = shift, scale = best_scale, max_icons_per_row = max_icons_per_row})
        machine.icons_positioning = new_icons_positioning
    end
end

-- 2.1.7 removed defines.inventory.assembling_machine_modules / furnace_modules /
-- rocket_silo_modules: every crafting machine's module inventory is defines.inventory.crafter_modules now.
for prototype_name, inventory_index in pairs {
    ["mining-drill"] = defines.inventory.mining_drill_modules,
    ["assembling-machine"] = defines.inventory.crafter_modules,
    ["furnace"] = defines.inventory.crafter_modules,
    ["lab"] = defines.inventory.lab_modules,
    ["rocket-silo"] = defines.inventory.crafter_modules,
    ["beacon"] = defines.inventory.beacon_modules,
} do
    for _, machine in pairs(data.raw[prototype_name] or {}) do
        scale_module_alt_icons(machine, inventory_index)
    end
end

if data.raw["assembling-machine"]["electromagnetic-plant"] then
    data.raw["assembling-machine"]["electromagnetic-plant"].icon_draw_specification.scale = 1.8
end

for _, lab in pairs(data.raw.lab) do
    for _, positioning in pairs(lab.icons_positioning or {}) do
        if positioning.inventory_index == defines.inventory.lab_input then
            local scale = 1

            local x1, y1, x2, y2 = collision_box(lab)
            if not x1 then return end
            local width, height = x2 - x1, y2 - y1
            local area = width * height

            local module_alt_mode_width = positioning.separation_multiplier or 1.1 -- width and height of the module icon in tiles
            positioning.max_icons_per_row = positioning.max_icons_per_row or 6
            scale = math.min(1.5, (width * 0.8) / module_alt_mode_width / positioning.max_icons_per_row)

            positioning.shift = {0, -0.5 * scale}
            positioning.scale = scale
        end
    end
end
