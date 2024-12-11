return {
    "windwp/nvim-autopairs",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
        require("nvim-autopairs").setup({})
        -- Make nvim-autopairs cooperate with nvim-cmp.
        require("cmp").event:on(
            "confirm_done",
            require("nvim-autopairs.completion.cmp").on_confirm_done()
        )
    end,
}
