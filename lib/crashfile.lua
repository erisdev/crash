from "tools" import (
    "ImmutableProxy", "bind", "capture_stack", "print_stack", "prototype", "qf")
from "target-spec" import "TargetSpec"

-- global functions that may be needed by Crashfile scripts.
-- notably missing are computercraft apis and i/o.
local essentials = {
    error = function(message) error(message, 0) end,
    ipairs = ipairs,
    math = math,
    pairs = pairs,
    string = string,
    table = table,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    unpack = unpack,
}

_ENV.Crashfile = prototype()

function Crashfile:init(filename)
    local path = shell.resolve(filename)
    assert(fs.exists(path), qf"%q doesn't exist"(path))
    self.targets = {}
    self.default_target = nil
    self.filename = path
    self.dirname = fs.getDir(path)

    -- create execution environment
    local env = setmetatable({
        CRASHFILE = self.filename,
        PROJECT_DIR = self.dirname,
        TARGETS = ImmutableProxy(self.targets, "targets"),

        -- include = bind(self, 'dsl_include'),
        build = bind(self, 'dsl_build'),
        task = bind(self, 'dsl_task'),
    }, {__index=essentials})
    env._G = env
    env._ENV = env

    local script = loadfile(self.filename, env)
    script()
end

function Crashfile:dsl_build(name)
    local target = self.targets[name]
    if not target then
        target = TargetSpec(self, name)
        self.targets[name] = target
    end
    if not self.default_target then
        self.default_target = name
    end
    return target
end

function Crashfile:dsl_task(name)
    error("yo chill it's not implemented yet")
end

function Crashfile:list_targets()
    print("Targets:")
    for name,target in pairs(self.targets) do
        if #target.deps > 0 then
            print(qf" - %s => %s"(
                    target.name, table.concat(target.deps, ", ")))
        else
            print(qf" - %s"(target.name))
        end
    end
end

function Crashfile:get_target(name)
    name = name or self.default_target
    assert(name, "there is no default target")
    local target = self.targets[name or self.default_target]
    assert(target, qf"%q isn't a known target"(name))
    return target
end

function Crashfile:run_target(name, opts)
    local target = self:get_target(name)
    assert(target.main, qf"target %q has no entry point"(target.name))

    local sandbox = setmetatable({}, {__index=_ENV})
    sandbox._ENV = sandbox
    sandbox._G = sandbox

    -- load resources
    local resources = {}
    sandbox.Resources = resources
    for name,path in pairs(target.resources) do
        local infile = fs.open(path, "r")
        local data = infile.readAll()
        infile.close()
        resources[name] = data
    end

    -- load runtime
    local func, status, err
    if target.runtime then
        func, err = loadfile(target.runtime, sandbox)
    else
        func, err = load(Resources["lib/runtime.lua"], "<CRASH_RUNTIME>", "t", sandbox)
    end
    if not func then error(err, 0) end

    status, err = xpcall(func, capture_stack)
    if not status then
        print_stack(opts, err)
        exit()
    end

    -- load modules
    local runtime = sandbox.Crash
    for name,path in pairs(target.modules) do
        local file = fs.open(path, "r")
        func, err = load(file.readAll(), name, "t", sandbox)
        file.close()
        if not func then
            local lineno, msg = err:match("%]:(%d+): (.+)$")
            error(qf"%s:%d: %s"(name,lineno,msg), 0)
        end
        runtime.define(name, func)
    end

    -- run it!!!
    runtime.error_handler = capture_stack
    status, err = runtime.run(target.main, unpack(opts.args))
    if not status then
        print_stack(opts, err)
        exit()
    end
end


local function copy_lines(outfile, infile)
    local line = infile.readLine()
    while line do
        outfile.write(line)
        outfile.write("\n")
        line = infile.readLine()
    end
end

function Crashfile:build_target(name, opts)
    local target = self:get_target(name)
    assert(target.main, qf"target %q has no entry point"(target.name))

    local outfile = fs.open(target.product, "w")

    -- write resources
    outfile.write("Resources = {\n")
    for name,path in pairs(target.resources) do
        local infile = fs.open(path, "r")
        local data = textutils.serialize(infile.readAll()):gsub("\\\n", "\\n")
        infile.close()
        outfile.write(qf"[%q]=%s,\n"(name, data))
    end
    outfile.write("}\n")

    -- write runtime
    if target.runtime then
        local infile = fs.open(target.runtime, "r")
        copy_lines(outfile, infile)
        infile.close()
    else
        outfile.write(Resources["lib/runtime.lua"])
    end

    -- write modules
    outfile.write("\n")
    for name,path in pairs(target.modules) do
        outfile.write(qf"Crash.define(%q, function(...)\n"(name))
        local infile = fs.open(path, "r")
        copy_lines(outfile, infile)
        outfile.write("end)\n")
    end
    outfile.write(qf"Crash.run(%q, ...)"(target.main))
    outfile.close()
end
