local M = {}

function M.CopyToRemote()
    local uv = vim.loop
    local buffer_raw = vim.fn.getreg('@')
    vim.fn.writefile(vim.fn.split(buffer_raw, "\n", 1), "/tmp/copy.txt", "b")

    uv.spawn('curl', {
        args={'-H "Content-Type:text/plain"', '--data-binary','@/tmp/copy.txt', 'http://192.168.56.1:8377/setclip'}
    },function ()
        print("sync clip done")
    end)
end


function M.setup(user_config)
    _ = user_config

    require('own_neovim_commands.commands').setup()
end


return M
