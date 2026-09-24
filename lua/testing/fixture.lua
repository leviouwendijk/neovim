local uv = vim.uv or vim.loop

local Fixture = {}
Fixture.__index = Fixture

local function join(root, relative)
    if relative == nil or relative == "" then
        return root
    end
    return vim.fs.joinpath(root, relative)
end

local function ensure_directory(path)
    vim.fn.mkdir(path, "p")
end

local function remove_tree(path)
    local stat = uv.fs_lstat(path)
    if not stat then
        return
    end

    if stat.type ~= "directory" then
        local ok, err = uv.fs_unlink(path)
        if not ok then
            error("failed to remove fixture entry " .. path .. ": " .. tostring(err))
        end
        return
    end

    local handle = uv.fs_scandir(path)
    if handle then
        while true do
            local name = uv.fs_scandir_next(handle)
            if not name then
                break
            end
            remove_tree(vim.fs.joinpath(path, name))
        end
    end

    local ok, err = uv.fs_rmdir(path)
    if not ok then
        error("failed to remove fixture directory " .. path .. ": " .. tostring(err))
    end
end

function Fixture.new(spec)
    spec = spec or {}

    local root = vim.fn.tempname()
    ensure_directory(root)

    local self = setmetatable({
        root = root,
        cleaned = false,
    }, Fixture)

    for _, relative in ipairs(spec.directories or {}) do
        ensure_directory(self:path(relative))
    end

    for relative, contents in pairs(spec.files or {}) do
        local path = self:path(relative)
        ensure_directory(vim.fs.dirname(path))

        local file, err = io.open(path, "wb")
        if not file then
            self:cleanup()
            error("failed to create fixture file " .. path .. ": " .. tostring(err))
        end

        file:write(contents)
        file:close()
    end

    for relative, target in pairs(spec.symlinks or {}) do
        local path = self:path(relative)
        ensure_directory(vim.fs.dirname(path))

        local ok, err = uv.fs_symlink(target, path)
        if not ok then
            self:cleanup()
            error("failed to create fixture symlink " .. path .. ": " .. tostring(err))
        end
    end

    return self
end

function Fixture:path(relative)
    return join(self.root, relative)
end

function Fixture:cleanup()
    if self.cleaned then
        return
    end

    self.cleaned = true
    remove_tree(self.root)
end

return Fixture
