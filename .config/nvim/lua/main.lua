-- Set colorscheme to tokyonight
vim.cmd[[colorscheme tokyonight]]

-- Set highlight on search
vim.o.hlsearch = true

-- Make line numbers hybrid
vim.wo.number = true
vim.wo.relativenumber = true

-- Enable mouse mode
vim.o.mouse = "a"

-- Enable unnamed clipboard.
vim.o.clipboard = "unnamed"

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 150
vim.o.timeout = true
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- Turn on term gui colors
vim.o.termguicolors = true
