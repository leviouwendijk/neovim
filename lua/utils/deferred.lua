-- Reusable synchronous, demand-driven initialization.
-- Returning nil/false indicates unavailable (retry on the next invocation).
-- Errors also allow retry; a recursive invocation is rejected explicitly.
local M = {}

function M.once(initialize)
    assert(type(initialize) == "function", "deferred.once expects a function")

    local state = "pending"
    local value

    return function(...)
        if state == "ready" then
            return value
        end
        if state == "running" then
            error("deferred initializer re-entered", 2)
        end

        state = "running"
        local ok, result = pcall(initialize, ...)
        if not ok then
            state = "pending"
            error(result, 0)
        end
        if result == nil or result == false then
            state = "pending"
            return nil
        end

        value = result
        state = "ready"
        return value
    end
end

return M
