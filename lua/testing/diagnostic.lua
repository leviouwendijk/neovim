local Diagnostic = {}

function Diagnostic.message(message)
    return {
        kind = "message",
        message = tostring(message),
    }
end

function Diagnostic.field(name, value)
    return {
        kind = "field",
        name = tostring(name),
        value = tostring(value),
    }
end

function Diagnostic.section(name, lines)
    return {
        kind = "section",
        name = tostring(name),
        lines = lines or {},
    }
end

return Diagnostic
