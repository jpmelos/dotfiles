return {
    "nvim-telescope/telescope-smart-history.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        local telescope = require("telescope")
        telescope.load_extension("smart_history")
    end,
}
