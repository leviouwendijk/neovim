local imports = require("boot.imports")

local loader = {}

local category_loading_order = {
    "config",
    "packages",
    "core",
    "customizations",
    "extensions",
    "utils",
}

local function load_module(reqpath)
    local ok, mod = pcall(require, reqpath)
    if not ok then
        vim.notify(("Failed loading %s: %s"):format(reqpath, mod), vim.log.levels.ERROR)
        return nil
    end
    return mod
end

function loader.process(selected)
    local setting = {}
    local seen = {}

    -- 1) walk categories in the specified order
    for _, category in ipairs(category_loading_order) do
        local enabled = selected[category]
        local ordered = imports[category]           -- array: { {id, req}, ... }
        if enabled and ordered then
            seen[category] = true
            setting[category] = setting[category] or {}
            -- deterministic: follow declaration order in imports via ipairs()
            for _, tuple in ipairs(ordered) do
                local id, req = tuple[1], tuple[2]
                if enabled[id] then
                    setting[category][id] = load_module(req)
                end
            end
        end
    end

    -- 2) load any categories not listed in category_loading_order (append at end)
    for category, enabled in pairs(selected) do
        if not seen[category] then
            vim.notify(("Category not in load order; loading last: %s"):format(category), vim.log.levels.WARN)
            local ordered = imports[category]
            if enabled and ordered then
                setting[category] = setting[category] or {}
                for _, tuple in ipairs(ordered) do
                    local id, req = tuple[1], tuple[2]
                    if enabled[id] then
                        setting[category][id] = load_module(req)
                    end
                end
            end
        end
    end

    loader.state = setting
    return setting
end

function loader.get(category, id)
    if not loader.state then
        return nil
    end

    if id == nil then
        return loader.state[category]
    end

    if not loader.state[category] then
        return nil
    end

    return loader.state[category][id]
end

return loader
