local function gh(repo)
    return "https://github.com/" .. repo
end

local function spec(repo, opts)
    opts = opts or {}
    opts.src = gh(repo)
    opts.name = opts.name or repo:match("/([^/]+)$")
    return opts
end

-- Preserve old packer setup behavior before lazy-load
vim.g.mkdp_filetypes = { "markdown" }

-- Post-install / post-update hooks
vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
        local kind = ev.data.kind
        local name = ev.data.spec.name
        local path = ev.data.path

        if kind ~= "install" and kind ~= "update" then
            return
        end

        if name == "markdown-preview.nvim" then
            vim.system({ "npm", "install" }, { cwd = path .. "/app" }):wait()
            return
        end

        if name == "nvim-treesitter" then
            vim.schedule(function()
                pcall(vim.cmd, "TSUpdate")
            end)
        end
    end,
})

-- Always-on plugins
vim.pack.add({
    spec("nvim-lua/plenary.nvim"),

    spec("nvim-telescope/telescope.nvim", {
        -- version = "0.1.6",
    }),

    spec("rose-pine/neovim", {
        name = "rose-pine",
        version = "main",
    }),
    spec("AbdelrahmanDwedar/awesome-nvim-colorschemes"),

    spec("nvim-treesitter/nvim-treesitter"),
    -- spec("nvim-treesitter/playground"),
    spec("nvim-treesitter/nvim-treesitter-context"),

    spec("theprimeagen/harpoon", {
        version = "harpoon2",
    }),

    spec("mbbill/undotree"),
    spec("tpope/vim-fugitive"),
    spec("tpope/vim-commentary"),

    spec("VonHeikemen/lsp-zero.nvim"),
    spec("williamboman/mason.nvim"),
    spec("williamboman/mason-lspconfig.nvim"),
    spec("neovim/nvim-lspconfig"),

    spec("hrsh7th/nvim-cmp"),
    spec("hrsh7th/cmp-buffer"),
    spec("hrsh7th/cmp-path"),
    spec("saadparwaiz1/cmp_luasnip"),
    spec("hrsh7th/cmp-nvim-lsp"),
    spec("hrsh7th/cmp-nvim-lua"),
    spec("L3MON4D3/LuaSnip"),
    spec("rafamadriz/friendly-snippets"),
    spec("onsails/lspkind-nvim"),

    spec("junegunn/goyo.vim"),
    spec("junegunn/limelight.vim"),

    spec("jrop/jq.nvim"),
    spec("CRAG666/code_runner.nvim"),

    spec("lukas-reineke/indent-blankline.nvim"),
    spec("folke/zen-mode.nvim"),
    spec("gbprod/yanky.nvim"),
    spec("artemave/workspace-diagnostics.nvim"),
    spec("norcalli/nvim-colorizer.lua"),
    spec("karb94/neoscroll.nvim"),
    spec("petertriho/nvim-scrollbar"),

    spec("MunifTanjim/nui.nvim"),
    spec("nvim-neotest/nvim-nio"),
    spec("nvim-neorg/lua-utils.nvim"),
    spec("pysan3/pathlib.nvim"),
    spec("nvim-neorg/neorg"),

    spec("hat0uma/csvview.nvim"),
    spec("liuchengxu/graphviz.vim"),
    spec("lewis6991/gitsigns.nvim"),
    spec("wurli/visimatch.nvim"),
    spec("rcarriga/nvim-notify"),

    spec("rebelot/kanagawa.nvim"),
    spec("nyoom-engineering/oxocarbon.nvim"),
    spec("sainnhe/gruvbox-material"),
    spec("terrastruct/d2-vim"),

    -- open-browser can be always-on or lazy; always-on is simpler/safer
    spec("tyru/open-browser.vim"),
}, {
    load = true,
})

-- Lazy plugins: match old packer ft behavior
vim.pack.add({
    spec("iamcco/markdown-preview.nvim"),
    spec("aklt/plantuml-syntax"),
    spec("weirongxu/plantuml-previewer.vim"),
}, {
    load = false,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "markdown",
    once = true,
    callback = function()
        vim.cmd.packadd("markdown-preview.nvim")
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "plantuml", "puml" },
    once = true,
    callback = function()
        vim.cmd.packadd("plantuml-syntax")
        vim.cmd.packadd("plantuml-previewer.vim")
    end,
})
