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

function M.getFuncName()
    local oldLine = vim.api.nvim_win_get_cursor(0)[1]
    vim.cmd(' execute "normal yaf"')
    vim.cmd('execute "'.. oldLine ..'"')
    local bufferRaw = vim.fn.getreg('@')
    local _,_, typeName, funcName = string.find(bufferRaw, 'func +%([a-zA-Z0-9_]+ +%*?([a-zA-Z0-9_]+)%) +([a-zA-Z0-9_]*)')
    if not typeName then
        _,_,  funcName = string.find(bufferRaw, 'func +([a-zA-Z0-9_]*)')
        return nil, funcName
    end
    return typeName, funcName
end

function M.GoLogger()
    local retStr = ""
    local prefix = os.getenv("LOG_PREFIX")
    if prefix then
        retStr = retStr .. prefix
    end
    local typeName, funcName = M.getFuncName()
    if typeName then
        retStr = retStr .. "[" .. typeName .. "]"
        retStr = retStr .. "[" .. funcName .. "]"
    else
        retStr = retStr .. "[" .. funcName .. "]"
    end
    local logStr = 'logger.Infof(ctx, "'.. retStr ..'")'
    vim.cmd('normal o'.. logStr)
end




function M.setup(user_config)
    _ = user_config

    require('own_neovim_commands.commands').setup()
end



return M
