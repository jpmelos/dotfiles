return {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-buffer", -- Source for text in buffer.
        "hrsh7th/cmp-path", -- Source for file system paths.
        { "L3MON4D3/LuaSnip", version = "v2.*" },
        "saadparwaiz1/cmp_luasnip", -- For integration with `L3MON4D3/LuaSnip`.
        "onsails/lspkind.nvim", -- Pictograms inside suggestions modal.
    },
    config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")
        local lspkind = require("lspkind")

        cmp.setup({
            completion = {
                completeopt = "menu,menuone,preview,noselect",
            },
            -- Configure the snippet engine. This is required, otherwise
            -- `nvim-cmp` may show weird behavior.
            snippet = {
                expand = function(args)
                    luasnip.lsp_expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({
                -- Previous suggestion.
                ["<C-k>"] = cmp.mapping.select_prev_item(),
                -- Next suggestion.
                ["<C-j>"] = cmp.mapping.select_next_item(),
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
                { name = "nvim_lsp" },
                { name = "luasnip" }, -- Snippets.
                { name = "buffer" }, -- Text from the current buffer.
                { name = "path" }, -- Paths from the file system.
            }),
            -- Configure pictograms from `onsails/lspkind.nvim`.
            formatting = {
                format = lspkind.cmp_format({
                    maxwidth = 50,
                    ellipsis_char = "...",
                }),
            },
        })
    end,
}
