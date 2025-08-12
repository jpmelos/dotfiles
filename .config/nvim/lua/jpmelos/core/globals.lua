vim.g.git_branch = nil

vim.g.formatters_by_ft = {
    -- BE coding.
    python = {
        "ruff_fix",
        "ruff_organize_imports",
        "ruff_format",
    },
    -- This is an exception: it's not managed by Mason. Instead, install the
    -- Rust toolchain locally.
    rust = { "rustfmt" },
    lua = { "stylua" },
    -- Shell.
    sh = { "shfmt" },
    bash = { "shfmt" },
    -- Web technologies.
    html = { "prettier" },
    css = { "prettier" },
    scss = { "prettier" },
    javascript = { "prettier" },
    typescript = { "prettier" },
    -- Writing.
    markdown = { "mdformat" },
    -- Configuration.
    yaml = { "prettier" },
    toml = { "taplo" },
    json = { "jq" },
    -- Others.
    graphql = { "prettier" },
}

vim.g.linters_by_ft = { rust = { "clippy" } }
