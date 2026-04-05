local M = {}

local function is_macos()
    return vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1
end

---Returns "dark" or "light" (nil if not macOS)
function M.get_macos_appearance()
    if not is_macos() then return nil end
    local out = vim.fn.systemlist({ "defaults", "read", "-g", "AppleInterfaceStyle" })
    if vim.v.shell_error == 0 and #out > 0 and out[1]:lower() == "dark" then
        return "dark"
    end
    return "light" -- key is absent in light mode
end

---Returns true/false for “Auto” toggle (nil if not macOS)
function M.is_auto_enabled()
    if not is_macos() then return nil end
    -- Exists (exit 0) when Auto is on; missing/err when off
    vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyleSwitchesAutomatically" })
    return vim.v.shell_error == 0
end

return M
