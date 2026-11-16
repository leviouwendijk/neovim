local repository = "https://github.com/leviouwendijk/tree-sitter-grammars"

local function parser(name)
    return {
        install_info = {
            url = repository,
            branch = "master",
            location = name,
            queries = name .. "/queries",
        },
        filetype = name,
    }
end

return {
    frame = parser("frame"),
}
