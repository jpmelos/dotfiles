vim.g.disable_autoformat = false

local conform = require("conform")
conform.formatters_by_ft = {
	python = { "ruff_fix", "ruff_organize_imports", "black" },
}
