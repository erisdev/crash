from "lib/crashfile" import "Crashfile"

local Help = {}

Help.crash = [[
    Smash multiple lua files together into a
    single executable for easy distribution.

Commands:
    run <target>
    build <target>
    targets

Options:
    -h [<command>]
            Show help for <command>.
]]

Help.run = [[
    Run a target directly. Crash will capture the
    stack in the "unlikely" event that an error
    occurs.

Usage:
    crash run [<target>]

Options:
    -x      Reset the terminal before printing
            the stack trace. Useful for full-
            screen programs.
    -l <file>
            Log the stack trace to <file>.
]]

Help.build = [[
    Do the main thing.

Usage:
    crash build [<target>]
]]

Help.targets = [[
    List all available targets.

Usage:
    crash targets
]]

local Flags = {}

function Flags.h(opts, args)
    local cmd = args[1] or opts.command
    if cmd and Help[cmd] then
        print(Help[cmd])
    else
        print(Help.crash)
    end
    opts.exit = true
end

Flags['help'] = Flags.h
Flags['-help'] = Flags.h

function Flags.F(opts, args)
    opts.filename = table.remove(args, 1)
    assert(opts.filename, "missing argument to -F")
end

function Flags.x(opts, args)
    opts.clear_screen = true
end

function Flags.l(opts, args)
    opts.error_log = table.remove(args, 1)
    assert(opts.error_log, "missing argument to -l")
end

function main(...)
    local opts = {
        filename = "Crashfile",
        command = nil,
        target = nil,

        -- these options technically only make sense for the run command
        clear_screen = false,
        log_file = nil,

        -- gdi why is there no exit function
        exit = false
    }

    local args = {...}
    while #args > 0 do
        local arg = table.remove(args, 1)
        if arg == "--" then
            break
        elseif arg:sub(1,1) == "-" then
            local flagfunc = Flags[arg:sub(2)]
            assert(flagfunc, qf"%q is not a recognized flag"(arg))
            flagfunc(opts, args)
        elseif not opts.command then
            opts.command = arg
        elseif not opts.target then
            opts.target = arg
            break
        end

        if opts.exit then break end
    end
    opts.args = args

    -- ok
    if opts.exit then return end

    if opts.command == "run" then
        Crashfile(opts.filename):run_target(opts.target, opts)
    elseif opts.command == "build" then
        Crashfile(opts.filename):build_target(opts.target)
    elseif opts.command == "targets" then
        Crashfile(opts.filename):list_targets()
    else
        print(Help.crash)
    end
end

main(...)

-- vim: set ft=lua
