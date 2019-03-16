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

function Crash.define(name, func)
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
    setfenv(func, env)

    function module.load(...)
        assert(not module.loading, "circular module dependency detected")
        module.loading = true
        local ret = func(...)
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
    local dir = fs.getDir(rel.path)
    local path = fs.combine(dir, name)
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
    local module = Crash.modules[name]
    return module.load(...)
end
