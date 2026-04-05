local Log = {}
local acc = require("accessor")

Log.output_file = acc.paths.log_file

function Log.log(msg)
    local f = io.open(Log.output_file, "a")
    if not f then
        f = io.open(Log.output_file, "w")
        if not f then
            print("Error: Could not create log file: " .. tostring(Log.output_file))
            return
        end
        f:write("=== Log File Created ===\n")
        f:close()
        f = io.open(Log.output_file, "a")
        if not f then
            print("Error: Could not open newly created log file: " .. tostring(Log.output_file))
            return
        end
    end

    f:write(msg .. "\n")
    f:close()
end

function Log.copy_log_to_clipboard()
    local log_content = {}
    local copy_mode = false

    for line in io.lines(Log.output_file) do
        if line:find("================START================") then
            copy_mode = true
            log_content = {}
        end
        if copy_mode then
            table.insert(log_content, line)
        end
        if line:find("================END================") then
            copy_mode = false
        end
    end

    local log_text = table.concat(log_content, "\n")
    vim.fn.setreg("+", log_text)
end

return Log
