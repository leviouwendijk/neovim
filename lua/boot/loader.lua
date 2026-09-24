local Loader = {}
Loader.__index = Loader

local function default_notify(message, level)
    vim.notify(message, level)
end

local function copy_array(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = value
    end
    return result
end

local function assert_instance(self, operation)
    if getmetatable(self) ~= Loader then
        error(
            ("Loader:%s must be called on a Loader instance"):format(operation),
            2
        )
    end
end

function Loader.new(options)
    assert(type(options) == "table", "Loader.new requires options")
    assert(type(options.imports) == "table", "Loader.new requires imports")
    assert(type(options.order) == "table", "Loader.new requires order")

    local load = options.load or require
    local notify = options.notify or default_notify

    assert(type(load) == "function", "Loader.new requires load to be a function")
    assert(type(notify) == "function", "Loader.new requires notify to be a function")

    return setmetatable({
        imports = options.imports,
        order = copy_array(options.order),
        load = load,
        strict = options.strict == true,
        notify = notify,
        state = nil,
        loaded = nil,
    }, Loader)
end

function Loader:_load(reqpath)
    local ok, value = pcall(self.load, reqpath)
    if ok then return value end

    local message = ("Failed loading %s: %s"):format(
        reqpath,
        tostring(value)
    )

    if self.strict then
        error(message, 0)
    end

    self.notify(message, vim.log.levels.ERROR)
    return nil
end

function Loader:_load_category(setting, loaded, category, enabled)
    local ordered = self.imports[category]
    if not enabled or not ordered then return end

    setting[category] = setting[category] or {}
    loaded[category] = loaded[category] or {}

    for _, tuple in ipairs(ordered) do
        local id, reqpath = tuple[1], tuple[2]
        if enabled[id] then
            local value = self:_load(reqpath)
            setting[category][id] = value

            if value ~= nil then
                table.insert(loaded[category], value)
            end
        end
    end
end

function Loader:process(selected)
    assert_instance(self, "process")
    selected = selected or {}

    local setting = {}
    local loaded = {}
    local seen = {}

    for _, category in ipairs(self.order) do
        seen[category] = true
        self:_load_category(
            setting,
            loaded,
            category,
            selected[category]
        )
    end

    local remaining = {}
    for category in pairs(selected) do
        if not seen[category] then
            table.insert(remaining, category)
        end
    end

    table.sort(remaining)

    for _, category in ipairs(remaining) do
        self.notify(
            ("Category not in load order; loading last: %s"):format(category),
            vim.log.levels.WARN
        )

        self:_load_category(
            setting,
            loaded,
            category,
            selected[category]
        )
    end

    self.state = setting
    self.loaded = loaded
    return setting
end

function Loader:get(category, id)
    assert_instance(self, "get")

    if not self.state then return nil end
    if id == nil then return self.state[category] end
    if not self.state[category] then return nil end

    return self.state[category][id]
end

function Loader:values(category)
    assert_instance(self, "values")

    if not self.loaded then return {} end
    return copy_array(self.loaded[category] or {})
end

return Loader
