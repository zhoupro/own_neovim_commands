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



function findList(currentContent, rowNum)
    local stack = {}
    local pre_start, pre_end = string.find(currentContent , "{{[^}{]*}}")
    if (pre_start == nil ) then
        return stack
    end

    while (pre_start ~= nil) do
        item = {rowNum, pre_start, pre_end}
        local pre_start, pre_end = string.find(currentContent , "{{[^}{]*}}", pre_end)
    end
    return stack
end


function Vs(start_row,start_col,end_row, end_col)
    end_col = end_col - 1
    vim.api.nvim_win_set_cursor(0, {start_row, start_col})
    local currentContent = vim.api.nvim_get_current_line()
    skipLineFlag = true

    for i = 1, #currentContent do
        if i > start_col and string.sub(currentContent,i,i) ~= " " then
            skipLineFlag = false
        end
    end

    if skipLineFlag == true then
        vim.api.nvim_win_set_cursor(0, {start_row+1, 0})
    end

    vim.cmd('normal! v')

    while start_row < end_row-1 do
        vim.cmd('+')
        start_row = start_row + 1
    end

    local _, col = unpack(vim.api.nvim_win_get_cursor(0))
    currentContent = vim.api.nvim_get_current_line()

    col = col + 1

    while col > end_col do
        vim.cmd('normal! h')
        col = col - 1
    end

    while col < end_col do
        vim.cmd('normal! l')
        col = col + 1
    end


    skipLineFlag = true

    for i = 1, #currentContent do
        if i > start_col and string.sub(currentContent,i,i) ~= " " then
            skipLineFlag = false
        end
    end

    if skipLineFlag == true then
        print("skip last line")
        vim.cmd('normal! -')
    end
end


function findStartPos(currentContent, rowNum, col)
    stack = findList(currentContent, rowNum)

    if (#stack == 0) then
        return {nil, 0}
    end

    local find_flag = false
    local find_pos = 1

    for key, value in pairs(stack) do
        _, col_start, col_end = unpack(value)
        if col <= col_start then
            find_flag = true
            find_pos = key
            break
        end

        if col >= col_start and col <= col_end then
            find_flag = true
            find_pos = key
            break
        end

    end

    if find_flag == false then
        find_pos = #stack
    end
    return {true, find_pos}

end


function isStartTag(str)
    startTab = {"if", "define", "with", "range"}
    for _, value in pairs(startTab) do
        start_pos, end_pos = string.find(str, value)
        if start_pos ~= nil then
            return true
        end
    end
    return false
end

function isEndTag(str)
    startTab = {"end"}
    for _, value in pairs(startTab) do
        start_pos, end_pos = string.find(str, value)
        if start_pos ~= nil then
            return true
        end
    end
    return false
end

function M.Visual()
    local currentContent = vim.api.nvim_get_current_line()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local buffer = vim.api.nvim_get_current_buf()
    local findFlag, findPos = unpack(findStartPos(currentContent, row, col))
    local totalNum = vim.api.nvim_buf_line_count(0)

    while findFlag ~= true do
        row = row+1
        if row - 1 = totalNum then
            print("not found")
            return
        end
        col = 0
        currentContent = vim.api.nvim_buf_get_text(buffer, row-1, 0 , row-1, 1000,{} )
        findFlag, findPos = unpack(findStartPos(currentContent[1], row, col))
    end

    if findFlag == nil then
        print("no found tag")
        return
    end
    local start_row = row

    currentContent = vim.api.nvim_buf_get_text(buffer, row-1,0 , row-1, 1000, {})
    startNode = findList(currentContent[1], row)[findPos]
    local _, col_start, col_end = unpack(startNode)

    local stack = {}
    local curNodeStr = string.sub(currentContent[1], col_start, col_end)

    if isStartTag(curNodeStr) then
        table.insert(stack, "s")
        local nodeList = findList(currentContent[1], row)
        while #stack > 0 do
            for key, value in pairs(nodeList) do
                local value_row, value_start, value_end = unpack(value)
                if value_row == start_row then
                    if key > findPos then
                        local curNodeStr = string.sub(currentContent[1], value_start, value_end)
                        if isStartTag(curNodeStr) == true then
                            table.insert(stack, "s")
                        elseif isEndTag(curNodeStr) == true then
                            table.remove(stack)
                            if #stack == 0 then
                                local startNodeRow, startNodeColS, startNodeColE = unpack(startNode)
                                local endNodeRow, endNodeColS, endNodeColE = unpack(value)
                                Vs(startNodeRow,startNodeColE, endNodeRow, endNodeColS)
                                return
                            end
                        end
                    end
                else
                    local curNodeStr = string.sub(currentContent[1], value_start, value_end)
                    if isStartTag(curNodeStr) == true then
                        table.insert(stack, "s")
                    elseif isEndTag(curNodeStr) then
                        table.remove(stack)
                        if #stack == 0 then
                            print("found")
                            local startNodeRow, startNodeColS, startNodeColE = unpack(startNode)
                            local endNodeRow, endNodeColS, endNodeColE = unpack(value)
                            Vs(startNodeRow,startNodeColE, endNodeRow, endNodeColS)
                            return
                        end
                    end
                end
            end
            row = row + 1
            if row == totalNum+1 then
                print("not found")
                return
            end
            currentContent = vim.api.nvim_buf_get_text(buffer, row -1 , 0, row -1 , 1000, {})
            nodeList = findList(currentContent[1], row)
        end
    elseif isEndTag(curNodeStr) then
        table.insert(stack, "e")
        local nodeList = findList(currentContent[1], row)
        while #stack > 0 do
            for i = #nodeList, 1, -1 do
                local value_row, value_start, value_end = unpack(nodeList[i])
                if value_row == start_row then
                    if i < findPos then
                        local curNodeStr = string.sub(currentContent[1], value_start, value_end)
                        if isEndTag(curNodeStr) == true then
                            table.insert(stack, "e")
                        elseif isStartTag(curNodeStr) == true then
                            table.remove(stack)
                            if #stack == 0 then
                                local startNodeRow, startNodeColS, startNodeColE = unpack(nodeList[i])
                                local endNodeRow, endNodeColS, endNodeColE = unpack(startNode)
                                Vs(startNodeRow,startNodeColE, endNodeRow, endNodeColS)
                                return
                            end
                        end
                    end
                else
                    local curNodeStr = string.sub(currentContent[1], value_start, value_end)
                    if isEndTag(curNodeStr) == true then
                        table.insert(stack, "e")
                    elseif isStartTag(curNodeStr) == true then
                        table.remove(stack)
                        if #stack == 0 then
                            local startNodeRow, startNodeColS, startNodeColE = unpack(nodeList[i])
                            local endNodeRow, endNodeColS, endNodeColE = unpack(startNode)
                            Vs(startNodeRow,startNodeColE, endNodeRow, endNodeColS)
                            return
                        end
                    end

                end
            end
            row = row - 1

            if row == -1 then
                print("not found")
                return
            end

            currentContent = vim.api.nvim_buf_get_text(buffer, row -1 , 0, row -1 , 1000, {})
            nodeList = findList(currentContent[1], row)
        end

    end
end




function M.setup(user_config)
    _ = user_config

    require('own_neovim_commands.commands').setup()
end



return M
