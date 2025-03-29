-- Converts numbers between bases.
-- `gA` shows the four representations of the number under the cursor (or
-- selected in Visual mode).
-- `crd`, `crx`, `cro`, `crb` converts the number under the cursor to decimal,
-- hex, octal, or binary, respectively.
return {
    "glts/vim-radical",
    dependencies = { "glts/vim-magnum" },
    keys = { "crd", "crx", "cro", "crb" },
}
