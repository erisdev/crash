from "tools" import ("prototype", "qf", "trim_ext")

_ENV.TargetSpec = prototype()

function TargetSpec:init(crashfile, name)
    local mt = getmetatable(self)
    mt.__call = self.define

    self.crashfile = crashfile
    self.name = name
    self.product = shell.resolve(name)
    self.main = nil

    self.modules = {}
    self.resources = {}
    self.deps = {}
end

function TargetSpec:resolve_file(name)
    assert(type(name) == 'string', "filename must be string")
    local path = fs.combine(self.crashfile.dirname, name)
    assert(fs.exists(path),
            qf"%q doesn't exist"(path))
    return path
end

function TargetSpec:define(t)
    for k,v in pairs(t) do
        if k == 'main' then
            assert(type(v) == 'string', "main must be a module name")
            self[k] = trim_ext(v)
        elseif k == 'product' then
            assert(type(v) == 'string', "product must be a filename")
            self[k] = shell.resolve(v)
        elseif k == 'runtime' then
            assert(type(v) == 'string', "runtime must be a filename")
            self.runtime = self:resolve_file(v)
        elseif k == 'modules' then
            self:add_modules(v)
        elseif k == 'resources' then
            self:add_resources(v)
        else
            error(qf"%q is not a target parameter"(k))
        end
    end
    return self
end

function TargetSpec:add_modules(t)
    for k,v in pairs(t) do
        if type(k) == "number" then
            self:add_module(v)
        else
            self:add_module(k,v)
        end
    end
end

function TargetSpec:add_module(name, path)
    path = self:resolve_file(name or path)
    name = trim_ext(name)
    self.modules[name] = path
    if not self.main then self.main = name end
end

function TargetSpec:add_resources(t)
    for i,name in ipairs(t) do
        self:add_resource(name)
    end
end

function TargetSpec:add_resource(name)
    self.resources[name] = self:resolve_file(path or name)
end
