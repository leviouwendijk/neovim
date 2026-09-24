local Suite = {}

function Suite.test(id, operation, options)
    options = options or {}

    return {
        kind = "test",
        id = id,
        title = options.title,
        tags = options.tags or {},
        skip = options.skip,
        expected_failure = options.expected_failure,
        operation = operation,
    }
end

function Suite.suite(id, nodes, options)
    options = options or {}

    return {
        kind = "suite",
        id = id,
        title = options.title,
        tags = options.tags or {},
        nodes = nodes or {},
    }
end

return Suite
