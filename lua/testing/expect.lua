local uv = vim.uv or vim.loop

local Expect = {}

local Failure = {}
Failure.__index = Failure

function Failure:__tostring()
    return self.message or "test assertion failed"
end

local function source_location(stack_level)
    local info = debug.getinfo(stack_level or 3, "Sl")
    if not info then
        return nil
    end

    return {
        source = info.short_src or info.source,
        line = info.currentline,
    }
end

local function fail(fields)
    fields = fields or {}
    fields.__testing_failure = true
    fields.location = fields.location or source_location(4)
    error(setmetatable(fields, Failure), 0)
end

local function stringify(value)
    if type(value) == "string" then
        return value
    end
    return vim.inspect(value)
end

function Expect.equal(actual, expected, label)
    if actual ~= expected then
        fail({
            label = label or "equality",
            message = "values were not equal",
            actual = stringify(actual),
            expected = stringify(expected),
        })
    end
end

function Expect.not_equal(actual, expected, label)
    if actual == expected then
        fail({
            label = label or "inequality",
            message = "values were equal",
            actual = stringify(actual),
            expected = "a different value",
        })
    end
end

function Expect.truthy(value, label)
    if not value then
        fail({
            label = label or "truthy",
            message = "value was not truthy",
            actual = stringify(value),
            expected = "truthy",
        })
    end
end

function Expect.falsy(value, label)
    if value then
        fail({
            label = label or "falsy",
            message = "value was not falsy",
            actual = stringify(value),
            expected = "falsy",
        })
    end
end

function Expect.nil_value(value, label)
    if value ~= nil then
        fail({
            label = label or "nil",
            message = "value was not nil",
            actual = stringify(value),
            expected = "nil",
        })
    end
end

function Expect.not_nil(value, label)
    if value == nil then
        fail({
            label = label or "not_nil",
            message = "value was nil",
            actual = "nil",
            expected = "non-nil",
        })
    end
    return value
end

function Expect.exists(path, label)
    if not uv.fs_lstat(path) then
        fail({
            label = label or "exists",
            message = "filesystem entry did not exist",
            actual = path,
            expected = "existing path",
        })
    end
end

function Expect.not_exists(path, label)
    if uv.fs_lstat(path) then
        fail({
            label = label or "not_exists",
            message = "filesystem entry existed",
            actual = path,
            expected = "missing path",
        })
    end
end

function Expect.file_contents(path, expected, label)
    local file, open_error = io.open(path, "rb")
    if not file then
        fail({
            label = label or "file_contents",
            message = "failed to open file",
            actual = tostring(open_error),
            expected = path,
        })
    end

    local actual = file:read("*a")
    file:close()

    Expect.equal(actual, expected, label or "file_contents")
end

Expect.Failure = Failure

return Expect
