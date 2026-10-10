local testing = require("testing")
local expect = testing.expect
local deferred = require("utils.deferred")

return testing.suite("deferred startup", {
    testing.test("once_caches_success_and_forwards_initial_arguments", function()
        local count = 0
        local ensure = deferred.once(function(value)
            count = count + 1
            return { value = value }
        end)
        local first = ensure("first")
        assert(first ~= nil, "deferred initializer must return a value")
        expect.equal(ensure("second"), first)
        expect.equal(first.value, "first")
        expect.equal(count, 1)
    end),

    testing.test("once_retries_unavailable_and_error_initializers", function()
        local count = 0
        local ensure = deferred.once(function()
            count = count + 1
            if count == 1 then return false end
            if count == 2 then return nil end
            if count == 3 then error("temporary failure") end
            return true
        end)
        expect.nil_value(ensure())
        expect.nil_value(ensure())
        local ok, err = pcall(ensure)
        expect.falsy(ok)
        expect.truthy(tostring(err):find("temporary failure", 1, true))
        expect.equal(ensure(), true)
        expect.equal(ensure(), true)
        expect.equal(count, 4)
    end),

    testing.test("once_rejects_recursive_initialization", function()
        local ensure = function() return nil end
        ensure = deferred.once(function() return ensure() end)
        local ok, err = pcall(ensure)
        expect.falsy(ok)
        expect.truthy(tostring(err):find("re-entered", 1, true))
    end),
})
