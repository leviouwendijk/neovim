return function(context)
    local funcs = context.funcs
    local cmp = context.cmp

    -- cmp.setup({
    --     snippet = {
    --         expand = function(args)
    --             -- Neovim 0.10+ built-in
    --             vim.snippet.expand(args.body)

    --             -- If using LuaSnip instead, replace with:
    --             -- require('luasnip').lsp_expand(args.body)
    --         end,
    --     },

    --     sources = {
    --         { name = 'nvim_lsp' },
    --         { name = 'path' },
    --         { name = 'nvim_lua' },
    --     },

    --     mapping = cmp.mapping.preset.insert({
    --         ['<C-Space>'] = cmp.mapping.complete(),
    --         ['<CR>']      = cmp.mapping.confirm({ select = false }),
    --         ['<Tab>']     = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
    --         ['<S-Tab>']   = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
    --     }),

    --     completion = { autocomplete = { cmp.TriggerEvent.TextChanged } },
    -- })

    -- local cmp_ok, _ = pcall(require, "cmp")
    -- if not cmp_ok then return end

    -- local luasnip_ok, luasnip = pcall(require, "luasnip")
    -- local _, lspkind = pcall(require, "lspkind")
    -- if not luasnip_ok then
    --     -- optional: fallback if you don't have luasnip
    --     luasnip = nil
    -- end

    -- local has_words_before = function()
    --     local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    --     return col ~= 0 and vim.api.nvim_buf_get_lines(0, line-1, line, true)[1]:sub(col, col):match("%s") == nil
    -- end

    -- cmp.setup({
    --     snippet = {
    --         expand = function(args)
    --             if luasnip then
    --                 require("luasnip").lsp_expand(args.body)
    --             else
    --                 -- fallback to builtin (kept for compatibility with older setups)
    --                 if vim.snippet and vim.snippet.expand then
    --                     vim.snippet.expand(args.body)
    --                 end
    --             end
    --         end,
    --     },

    --     mapping = cmp.mapping.preset.insert({
    --         ["<C-Space>"] = cmp.mapping.complete(),
    --         ["<CR>"] = cmp.mapping.confirm({ select = false }), -- keep your prior default; set true to auto-select

    --         -- stop cycling on tabs
    --         ["<Tab>"] = cmp.mapping(function(fallback)
    --             if luasnip and luasnip.expand_or_jumpable() then
    --                 luasnip.expand_or_jump()
    --             else
    --                 fallback()
    --             end
    --         end, { "i", "s" }),

    --         ["<S-Tab>"] = cmp.mapping(function(fallback)
    --             if luasnip and luasnip.jumpable(-1) then
    --                 luasnip.jump(-1)
    --             else
    --                 fallback()
    --             end
    --         end, { "i", "s" }),

    --         -- ["<Tab>"] = cmp.mapping(function(fallback)
    --         --     if cmp.visible() then
    --         --         cmp.select_next_item()
    --         --     elseif luasnip and luasnip.expand_or_jumpable() then
    --         --         luasnip.expand_or_jump()
    --         --     elseif has_words_before() then
    --         --         cmp.complete()
    --         --     else
    --         --         fallback()
    --         --     end
    --         -- end, { "i", "s" }),

    --         -- ["<S-Tab>"] = cmp.mapping(function(fallback)
    --         --     if cmp.visible() then
    --         --         cmp.select_prev_item()
    --         --     elseif luasnip and luasnip.jumpable(-1) then
    --         --         luasnip.jump(-1)
    --         --     else
    --         --         fallback()
    --         --     end
    --         -- end, { "i", "s" }),
    --     }),

    --     sources = cmp.config.sources({
    --         { name = "nvim_lsp" },
    --         { name = "luasnip" },        -- show snippets from LuaSnip
    --         { name = "path" },
    --         { name = "nvim_lua" },       -- lua api completions
    --         { name = "buffer", keyword_length = 3 },
    --     }),

    --     formatting = {
    --         format = lspkind.cmp_format({
    --             mode = "symbol_text", -- icon + text
    --             maxwidth = 80,
    --             symbol_map = {
    --                 Text = "",
    --                 Method = "",
    --                 Function = "󰊕",
    --                 Constructor = "",
    --                 Field = "󰇽",
    --                 Variable = "",
    --                 Class = "󰠱",
    --                 Interface = "",
    --                 Module = "",
    --                 Property = "",
    --                 Unit = "",
    --                 Value = "󰎠",
    --                 Enum = "",
    --                 Keyword = "",
    --                 Snippet = "",
    --                 Color = "",
    --                 File = "",
    --                 Reference = "",
    --                 Folder = "",
    --                 EnumMember = "",
    --                 Constant = "",
    --                 Struct = "",
    --                 Event = "",
    --                 Operator = "",
    --                 TypeParameter = ""
    --             },
    --             before = function(entry, vim_item)
    --                 local menu_label = "[" .. (entry.source.name or "??") .. "]"
    --                 vim_item.menu = ({
    --                     nvim_lsp = "[LSP]",
    --                     luasnip  = "[SNIP]",
    --                     buffer   = "[BUF]",
    --                     path     = "[PATH]",
    --                 })[entry.source.name] or menu_label
    --                 return vim_item
    --             end,
    --         })
    --     },

    --     window = {
    --         completion = cmp.config.window.bordered(),
    --         documentation = cmp.config.window.bordered(),
    --     },

    --     experimental = {
    --         ghost_text = true,
    --     },
    -- })

    local luasnip = funcs.require_or_nil("luasnip", {
        message = "luasnip missing; snippet expansion will fall back to builtin snippets",
    })

    local lspkind = funcs.require_or_nil("lspkind", {
        message = "lspkind missing; cmp formatting will use defaults",
    })

    local cmp_sources = {
        { name = "nvim_lsp" },
        { name = "path" },
        { name = "nvim_lua" },
        { name = "buffer", keyword_length = 3 },
    }

    if luasnip then
        table.insert(cmp_sources, 2, { name = "luasnip" })
    end

    local cmp_formatting = nil

    if lspkind then
        cmp_formatting = {
            format = lspkind.cmp_format({
                mode = "symbol_text",
                maxwidth = 80,
                symbol_map = {
                    Text = "",
                    Method = "",
                    Function = "󰊕",
                    Constructor = "",
                    Field = "󰇽",
                    Variable = "",
                    Class = "󰠱",
                    Interface = "",
                    Module = "",
                    Property = "",
                    Unit = "",
                    Value = "󰎠",
                    Enum = "",
                    Keyword = "",
                    Snippet = "",
                    Color = "",
                    File = "",
                    Reference = "",
                    Folder = "",
                    EnumMember = "",
                    Constant = "",
                    Struct = "",
                    Event = "",
                    Operator = "",
                    TypeParameter = "",
                },
                before = function(entry, vim_item)
                    local menu_label = "[" .. (entry.source.name or "??") .. "]"
                    vim_item.menu = ({
                        nvim_lsp = "[LSP]",
                        luasnip = "[SNIP]",
                        buffer = "[BUF]",
                        path = "[PATH]",
                    })[entry.source.name] or menu_label
                    return vim_item
                end,
            }),
        }
    end

    cmp.setup({
        snippet = {
            expand = function(args)
                if luasnip then
                    luasnip.lsp_expand(args.body)
                    return
                end

                if vim.snippet and vim.snippet.expand then
                    vim.snippet.expand(args.body)
                end
            end,
        },

        mapping = cmp.mapping.preset.insert({
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<CR>"] = cmp.mapping.confirm({ select = false }),

            ["<Tab>"] = cmp.mapping(function(fallback)
                if luasnip and luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                else
                    fallback()
                end
            end, { "i", "s" }),

            ["<S-Tab>"] = cmp.mapping(function(fallback)
                if luasnip and luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                else
                    fallback()
                end
            end, { "i", "s" }),
        }),

        sources = cmp.config.sources(cmp_sources),

        formatting = cmp_formatting,

        window = {
            completion = cmp.config.window.bordered(),
            documentation = cmp.config.window.bordered(),
        },

        experimental = {
            ghost_text = true,
        },
    })
end
