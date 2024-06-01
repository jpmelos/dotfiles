return {
    "zapling/mason-lock.nvim",
    lazy = false,
    config = function()
        require("mason-lock").setup()
    end,
}
