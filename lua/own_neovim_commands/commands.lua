
local M = {}

function M.setup()
    vim.api.nvim_create_user_command('CopyToRemote', require('own_neovim_commands').CopyToRemote, {})
    vim.api.nvim_set_keymap('n', '<Leader>y',  [[<Cmd>lua require('own_neovim_commands').CopyToRemote()<CR>]], { noremap = true, silent = true })
end
return M
