
function qf(fmt)
    return function(...)
        return string.format(fmt, ...)
    end
end


function prototype()
    local function new(proto, ...)
        local inst = setmetatable({}, {__index=proto})
        if inst.init then inst:init(...) end
        return inst
    end
    return setmetatable({}, {__call=new})
end


function bind(self, k)
    local method = self[k]
    return function(...) 
        return method(self, ...)
    end
end


function trim_ext(name)
    if name:sub(-4) == ".lua" then
        return name:sub(1, -5)
    else
        return name
    end
end


function ImmutableProxy(t, name)
    local mt = {
        __index = t,
        __metatable = nil,
    }

    function mt:__newindex(k,v)
        error(qf"%s is read-only"(name))
    end

    return setmetatable({}, mt)
end

function capture_stack(opts, func, ...)
    local handlers = {xpcall=xpcall}
    local args = {...}

    local status
    local ret

    function handlers.try()
        if args then
            ret = func(unpack(args))
        else
            ret = func()
        end
        status = true
    end

    function handlers.catch(errmsg)
        local stack = {errmsg:match(": (.+)$") or errmsg}
        local atend = false
        local maxdepth = math.huge
        local level = 1
        repeat
            local _,sentinel = pcall(error, "@", level+2)
            local chunk = sentinel:match("^(.-):")
            if chunk == "<CRASH_TRACE>" then
                -- reached the end
                table.remove(stack) -- capture_stack
                table.remove(stack) -- catch
                atend = true
                break
            elseif chunk == "<CRASH_RUNTIME>" then
                -- don't show this one
            else
                table.insert(stack,
                        "  at "..sentinel:match("^(.+): @$"))
            end
            level = level + 1
        until #stack == maxdepth

        if not atend then table.insert(stack, "  ...") end

        if opts.clear_screen then
            term.setBackgroundColor(color.black)
            term.setTextColor(color.white)
            term.clear()
        end

        term.setTextColor(colors.red)
        for i,line in ipairs(stack) do
            print(line)
        end
        term.setTextColor(colors.white)

        if opts.log_file then
            local fd = fs.open(opts.log_file, "w")
            for i,line in ipairs(stack) do
                fd.print(line)
            end
            fd.close()
        end
    end

    load([[xpcall(try,catch)]], "<CRASH_TRACE>", "t", handlers)()
    return status, ret
end
