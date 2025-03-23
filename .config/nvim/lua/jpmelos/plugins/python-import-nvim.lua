return {
    "kiyoon/python-import.nvim",
    build = "pipx install . --force",
    config = function()
        local K = vim.keymap.set
        local api = vim.api

        local python_import = require("python_import")
        local python_import_api = require("python_import.api")

        python_import.setup({
            extend_lookup_table = {
                statement_after_imports = {
                    logger = {
                        "import structlog",
                        "",
                        "logger = structlog.get_logger()",
                    },
                },
            },
        })

        api.nvim_create_autocmd("FileType", {
            pattern = "python",
            callback = function()
                K(
                    { "n", "i" },
                    "<C-Enter>",
                    python_import_api.add_import_current_word_and_notify,
                    { desc = "Insert Python import", buffer = true }
                )
                K(
                    "v",
                    "<C-Enter>",
                    python_import_api.add_import_current_selection_and_notify,
                    { desc = "Insert Python import", buffer = true }
                )
            end,
        })
    end,
}
