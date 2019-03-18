
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


local HIDE_CHUNKS = {
    pcall=true,
    xpcall=true,
    ["<CRASH_RUNTIME>"]=true,
}
function capture_stack(errmsg, offset)
    local stack = {errmsg:match(": (.+)$") or errmsg}
    local atend = false
    local maxdepth = 10
    local level = 1
    offset = offset or 0
    repeat
        local _,sentinel = pcall(error, "@", level+offset+2)
        local chunk = sentinel:match("^(.-):")
        if chunk == "<CRASH_TRACE>" then
            -- reached the end
            atend = true
            break
        elseif not HIDE_CHUNKS[chunk] then
            table.insert(stack,
                    "  at "..sentinel:match("^(.+): @$"))
        end
        level = level + 1
    until #stack == maxdepth

    if not atend then table.insert(stack, "  ...") end
    return table.concat(stack, "\n")
end


function print_stack(opts, stack)
    if opts.clear_screen then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
    end

    term.setTextColor(colors.red)
    print(stack)
    term.setTextColor(colors.white)

    if opts.log_file then
        local fd = fs.open(opts.log_file, "w")
        fd.print(stack)
        fd.close()
    end
end
