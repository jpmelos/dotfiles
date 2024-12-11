return {
    "hrsh7th/nvim-cmp",
    dependencies = {
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-nvim-lsp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "onsails/lspkind.nvim",
        "kristijanhusak/vim-dadbod-completion",
        "folke/lazydev.nvim",
    },
    config = function()
        local cmp = require("cmp")

        cmp.setup({
            completion = {
                completeopt = "menu,menuone,preview,noselect",
            },
            -- Configure the snippet engine. This is required, otherwise
            -- `nvim-cmp` may show weird behavior.
            snippet = {
                expand = function(args)
                    require("luasnip").lsp_expand(args.body)
                end,
            },
            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
            },
            mapping = cmp.mapping.preset.insert({
                -- Previous suggestion.
                ["<S-Tab>"] = cmp.mapping.select_prev_item(),
                -- Next suggestion.
                ["<Tab>"] = cmp.mapping.select_next_item(),
                -- Scroll documentation pane up.
                ["<C-f>"] = cmp.mapping.scroll_docs(-4),
                -- Scroll documentation pane down.
                ["<C-d>"] = cmp.mapping.scroll_docs(4),
                -- Trigger the suggestions modal.
                ["<C-Space>"] = cmp.mapping.complete(),
                -- Close suggestions modal.
                ["<C-e>"] = cmp.mapping.abort(),
                ["<C-c>"] = cmp.mapping.abort(),
                -- Insert suggestion.
                ["<CR>"] = cmp.mapping.confirm({ select = false }),
            }),
            -- Sources for autocompletion.
            sources = cmp.config.sources({
                { name = "nvim_lsp" },
                { name = "buffer" },
                { name = "path", option = { trailing_slash = true } },
                { name = "luasnip" },
                { name = "vim-dadbod-completion" },
                { name = "lazydev" },
            }),
            -- Configure pictograms from `onsails/lspkind.nvim`.
            formatting = { format = require("lspkind").cmp_format({}) },
        })

        -- SQL specific completion.
        cmp.setup.filetype({ "sql" }, {
            sources = {
                { name = "vim-dadbod-completion" },
                { name = "buffer" },
            },
        })
    end,
}
