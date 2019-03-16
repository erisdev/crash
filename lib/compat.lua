local exports = {}
if os and os.version and os.version():sub(1,7) == "CraftOS" then
    -- computercraft
    return {fs=fs, shell=shell}
else
    -- real lua... just implement the subset of computercraft apis
    -- that crash uses.

    -- UHH TURNS OUT I DONT WANT TO DO THIS RIGHT NOW
    error("hey sorry you gotta run this under computercraft after all")
end