-- Android Emulator exposes its device and toolbar as separate XWayland
-- windows. Pair only those two windows, using PID to distinguish AVDs.
local syncing = false

local function role(w)
    if w.class ~= "Emulator" or not w.mapped then return nil end
    if w.title:match("^Android Emulator %- ") then return "device" end
    if w.title == "Emulator" then return "toolbar" end
end

local function pairs_by_pid()
    local pairs = {}
    for _, w in ipairs(hl.get_windows({ class = "Emulator", mapped = true })) do
        local kind = role(w)
        if kind then
            pairs[w.pid] = pairs[w.pid] or {}
            pairs[w.pid][kind] = w
        end
    end
    return pairs
end

-- Covers keybinds, dock actions, and dragging to another workspace/monitor.
hl.on("window.move_to_workspace", function(w, workspace)
    if syncing or not workspace or not role(w) then return end
    syncing = true
    local ok, err = pcall(function()
        for _, other in ipairs(hl.get_windows({ class = "Emulator", mapped = true })) do
            if other.pid == w.pid and other.address ~= w.address and role(other)
                and other.workspace and other.workspace.id ~= workspace.id then
                hl.dispatch(hl.dsp.window.move({
                    window = other, workspace = workspace.name, follow = false,
                }))
            end
        end
    end)
    syncing = false
    if not ok then error(err) end
end)

-- Lua has no window-position event. A lightweight compositor timer keeps the
-- toolbar attached during SUPER+drag and resizing, without shell polling.
hl.timer(function()
    for pid, pair in pairs(pairs_by_pid()) do
        local device, toolbar = pair.device, pair.toolbar
        if device and toolbar and device.floating and toolbar.floating
            and device.workspace and toolbar.workspace
            and device.workspace.id == toolbar.workspace.id
            and device.visible and toolbar.visible then
            local dx, dy = device.at.x, device.at.y
            local tx, ty = toolbar.at.x, toolbar.at.y
            local width = device.size.x
            -- Match the emulator's native one-pixel overlap at the right edge.
            local target_x, target_y = dx + width - 1, dy
            if math.abs(tx - target_x) > 1 or math.abs(ty - target_y) > 1 then
                hl.dispatch(hl.dsp.window.move({
                    window = toolbar, x = target_x, y = target_y, relative = false,
                }))
            end
        end
    end
end, { timeout = 33, type = "repeat" })
