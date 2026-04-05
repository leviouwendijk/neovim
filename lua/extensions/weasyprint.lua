local M = {}

local function notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "WeasyPrint" })
end

local function write_temp_css(orientation)
    local css

    if orientation == "landscape" then
        css = [[
@page {
    size: A4 landscape !important;
    margin: 20mm !important;
}
]]
    else
        css = [[
@page {
    size: A4 portrait !important;
    margin: 20mm !important;
}
]]
    end

    local css_file = vim.fn.tempname() .. ".css"
    vim.fn.writefile(vim.split(css, "\n", { plain = true }), css_file)

    return css_file
end

local function render_html_to_pdf(opts)
    opts = opts or {}

    if vim.bo.filetype ~= "html" then
        notify("Current buffer is not an HTML file.", vim.log.levels.WARN)
        return
    end

    if vim.fn.executable("weasyprint") ~= 1 then
        notify("`weasyprint` was not found in PATH.", vim.log.levels.ERROR)
        return
    end

    local input_file = vim.fn.expand("%:p")
    if input_file == "" then
        notify("No file path found for current buffer.", vim.log.levels.ERROR)
        return
    end

    if vim.bo.modified then
        vim.cmd("write")
    end

    local orientation = opts.orientation or "portrait"
    local output_file = opts.output_file or (vim.fn.fnamemodify(input_file, ":r") .. ".pdf")
    local base_url = vim.fn.fnamemodify(input_file, ":h")
    local css_file = write_temp_css(orientation)

    local cmd = {
        "weasyprint",
        "--base-url", base_url,
        "--stylesheet", css_file,
        input_file,
        output_file,
    }

    local result = vim.system(cmd, { text = true }):wait()

    vim.fn.delete(css_file)

    if result.code ~= 0 then
        local err = (result.stderr and result.stderr ~= "") and result.stderr or "Unknown error"
        notify("Failed to generate PDF:\n" .. err, vim.log.levels.ERROR)
        return
    end

    notify("PDF generated: " .. output_file)
end

function M.render_portrait()
    render_html_to_pdf({
        orientation = "portrait",
    })
end

function M.render_landscape()
    render_html_to_pdf({
        orientation = "landscape",
    })
end

function M.setup()
    vim.api.nvim_create_user_command("HtmlPdf", function()
        M.render_portrait()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("HtmlPdfLandscape", function()
        M.render_landscape()
    end, { nargs = 0 })
end

return M

-- -- Function to run py script
-- -- WeasyPrint is apparantly contingent on Python 3.11
-- -- Function to run py script for portrait orientation
-- local function render_html_to_pdf_portrait()
--     -- Get the current file's full path
--     local current_file = vim.fn.expand("%:p")
--     -- Define the output file
--     local output_file = "output.pdf"
--     -- Dynamically resolve the Python script path
--     local python_script = os.getenv("HOME") .. "/myworkdir/programming/scripts/html-to-pdf/html-to-pdf.py"
--     -- Define the Python command to execute
--     local command = string.format("!python3.11 %s %s orientation-portrait %s", python_script, current_file, output_file)
--     -- Execute the command
--     vim.api.nvim_command(command)
-- end

-- -- Create a custom command that can be run with :HtmlPdf
-- vim.api.nvim_create_user_command(
--     'HtmlPdf',
--     render_html_to_pdf_portrait,
--     { nargs = 0 }
-- )

-- -- Function to run py script for landscape orientation
-- local function render_html_to_pdf_landscape()
--     -- Get the current file's full path
--     local current_file = vim.fn.expand("%:p")
--     -- Define the output file
--     local output_file = "output.pdf"
--     -- Dynamically resolve the Python script path
--     local python_script = os.getenv("HOME") .. "/myworkdir/programming/scripts/html-to-pdf/html-to-pdf.py"
--     -- Define the Python command to execute
--     local command = string.format("!python3.11 %s %s orientation-landscape %s", python_script, current_file, output_file)
--     -- Execute the command
--     vim.api.nvim_command(command)
-- end

-- -- Create a custom command that can be run with :HtmlPdf
-- vim.api.nvim_create_user_command(
--     'HtmlPdfLandscape',
--     render_html_to_pdf_landscape,
--     { nargs = 0 }
-- )
