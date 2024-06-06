return {
    "hrsh7th/nvim-cmp",
    lazy = false,
    dependencies = {
        "hrsh7th/cmp-buffer", -- Source for text in buffer.
        "hrsh7th/cmp-path", -- Source for file system paths.
        "L3MON4D3/LuaSnip", -- A snippers engine.
        "saadparwaiz1/cmp_luasnip", -- For integration with `L3MON4D3/LuaSnip`.
        "onsails/lspkind.nvim", -- Pictograms inside suggestions modal.
        "kristijanhusak/vim-dadbod-completion", -- SQL completions.
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
                ["<C-k>"] = cmp.mapping.select_prev_item(),
                ["<S-Tab>"] = cmp.mapping.select_prev_item(),
                -- Next suggestion.
                ["<C-j>"] = cmp.mapping.select_next_item(),
                ["<Tab>"] = cmp.mapping.select_next_item(),
                -- Scroll documentation pane.
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                -- Scroll documentation pane.
                ["<C-f>"] = cmp.mapping.scroll_docs(4),
                -- Trigger the suggestions modal.
                ["<C-Space>"] = cmp.mapping.complete(),
                -- Close suggestions modal.
                ["<C-e>"] = cmp.mapping.abort(),
                -- Insert suggestion.
                ["<CR>"] = cmp.mapping.confirm({ select = false }),
            }),
            -- Sources for autocompletion.
            sources = cmp.config.sources({
                { name = "nvim_lsp" }, -- LSP.
                { name = "luasnip" }, -- Snippets.
                { name = "buffer" }, -- Text from the current buffer.
                -- Paths from the file system.
                { name = "path", option = { trailing_slash = true } },
                { name = "vim-dadbod-completion" },
            }),
            -- Configure pictograms from `onsails/lspkind.nvim`.
            formatting = { format = require("lspkind").cmp_format({}) },
        })
    end,
}
