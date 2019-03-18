local EXIT_SYM = "<CRASH_EXIT_5dc4715231ef4623ab32a3e6136c030b>"
local IMPORT_BLACKLIST = {
    import = true,
    from = true,
}

_ENV.Crash = {
    modules = {},
    main = nil,
}

local Globals = setmetatable({}, {__index=_ENV})
Globals._ENV = Globals
Globals._G = Globals
Crash.globals = Globals

function Globals.from(path)
    local caller = getfenv(2)
    caller.__from = Crash.load(path, caller.__module)
end

function Globals.import(...)
    local caller = getfenv(2)
    local module = caller.__from
    caller.__from = nil
    if not module then error("'import' without 'from'") end

    local names = {...}
    if #names == 1 and type(names[1]) == "table" then
        -- must be doing named imports
        names = names[1]
    end

    for as,var in pairs(names) do
        assert(module.globals[var] ~= nil,
                ("%q does not export %q"):format(module.name, var))
        assert(not (IMPORT_BLACKLIST[var] or var:sub(1,1) == "_"),
                ("don't import %q dude you might break something"):format(module.name, var))
        if type(as) == "number" then
            caller[var] = module.globals[var]
        else
            caller[as] = module.globals[var]
        end
    end
end

function Globals.exit()
    error(EXIT_SYM, 0)
end

function Crash.define(name, source)
    local module = {
        name = name,
        path = path or name,
        loading = false,
        loaded = false,
    }

    -- create module environment
    local env = setmetatable({
        __module=module,
    }, {
        __index=Crash.globals,
    })
    env._ENV = env
    module.globals = env

    if type(source) == "function" then
        setfenv(source, env)
    else
        source = load(tostring(source), name, "t", env)
    end

    function module.load(...)
        assert(not module.loading, "circular module dependency detected")
        module.loading = true
        local ret = source(...)
        module.loading = false
        module.loaded = true
        return ret
    end
    Crash.modules[name] = module

    -- set entry point with first module by default
    if not Crash.main then Crash.main = module end

    return module
end

function Crash.get(name, rel)
    local module, path
    if rel then
        path = fs.combine(fs.getDir(rel.path), name)
    else
        path = name
    end
    local module = Crash.modules[path]
    assert(module, string.format("no module named %q (%q)", name, path))
    return module
end

function Crash.load(name, rel)
    local module = Crash.get(name, rel)
    if not module.loaded then module.load() end
    return module
end

function Crash.run(name, ...)
    local args = {...}
    local module = Crash.get(name)
    local handlers = {xpcall=xpcall}
    local status, ret

    function handlers.try()
        ret = module.load(unpack(args))
        status = true
    end

    function handlers.catch(errmsg)
        if errmsg == EXIT_SYM then
            -- clean exit, pass
            status = true
        elseif Crash.error_handler then
            ret = Crash.error_handler(errmsg, 1)
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.red)
            print(errmsg)
            term.setTextColor(colors.white)
            ret = errmsg
        end
    end

    load([[xpcall(try, catch)]], "<CRASH_TRACE>", "t", handlers)()
    return status, ret
end
