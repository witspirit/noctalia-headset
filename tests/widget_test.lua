-- Exercise asynchronous callbacks, races, partial failures, and measured state.
local sink = "alsa_output.pci-0000_00_1f.3.analog-stereo"
local source = "alsa_input.pci-0000_00_1f.3.analog-stereo"
local speaker, headphones = "analog-output-speaker", "analog-output-headphones"
local internal, headset = "analog-input-internal-mic", "analog-input-headset-mic"
local passed = 0

local function host(outputPort, inputPort, availability)
    local h = { queue = {}, writes = {}, notifications = {}, fail = {}, reads = 0 }
    local function device(name, active, portA, portB)
        return { name = name, active_port = active, ports = {
            { name = portA, availability = "availability unknown" },
            { name = portB, availability = availability or "available" },
        } }
    end
    h.output = device(sink, outputPort or speaker, speaker, headphones)
    h.input = device(source, inputPort or internal, internal, headset)
    local env = setmetatable({}, { __index = _G })
    env.barWidget = {
        setText = function(value) h.text = value end,
        setGlyph = function(value) h.glyph = value end,
        setGlyphColor = function(value) h.color = value end,
        setTooltip = function(value) h.tooltip = value end,
    }
    env.noctalia = {
        setUpdateInterval = function(value) h.interval = value end,
        getConfig = function(key) return key == "sink" and sink or source end,
        notifyError = function(_, body) table.insert(h.notifications, body) end,
        json = { decode = function(raw)
            if h.badJson then error("invalid JSON") end
            if h.missing then return {} end
            return { raw == "sinks" and h.output or h.input }
        end },
        runAsync = function(argv, callback)
            assert(argv[1] == "timeout" and argv[2] == "5s" and argv[3] == "pactl")
            if h.reject then return false end
            table.insert(h.queue, function()
                local command = argv[4]
                if h.fail[command] then
                    callback({ exitCode = 1, stderr = "simulated command failure" })
                elseif command == "--format=json" then
                    h.reads = h.reads + 1
                    callback({ exitCode = 0, stdout = argv[6], stdoutTruncated = h.truncated })
                else
                    table.insert(h.writes, argv)
                    if not h.ignoreWrites then
                        if command == "set-sink-port" then h.output.active_port = argv[6]
                        elseif command == "set-source-port" then h.input.active_port = argv[6]
                        else error("Unexpected command: " .. command) end
                    end
                    callback({ exitCode = 0, stdout = "" })
                end
            end)
            return true
        end,
    }
    assert(loadfile("headset/widget.luau", "t", env))()
    function h.drain()
        local count = 0
        while #h.queue > 0 do
            count = count + 1
            assert(count < 100, "callback loop")
            table.remove(h.queue, 1)()
        end
    end
    h.env = env
    return h
end

local function test(name, run)
    run()
    passed = passed + 1
    print("PASS " .. name)
end

test("startup and external changes reflect actual ports", function()
    local h = host()
    h.env.update(); h.drain()
    assert(h.glyph == "device-laptop" and h.interval == 2000)
    h.output.active_port, h.input.active_port = headphones, headset
    h.env.update(); h.drain()
    assert(h.glyph == "headset" and h.color == "primary")
    h.output.active_port = speaker
    h.env.update(); h.drain()
    assert(h.glyph == "device-laptop" and h.tooltip:find("Mixed"))
end)

test("toggles both directions and verifies with a reread", function()
    local h = host()
    h.env.onClick(); h.drain()
    assert(h.output.active_port == headphones and h.input.active_port == headset)
    assert(h.glyph == "headset" and #h.writes == 2 and h.reads == 4)
    h.env.onClick(); h.drain()
    assert(h.output.active_port == speaker and h.input.active_port == internal)
    assert(h.glyph == "device-laptop" and #h.notifications == 0)
    for _, argv in ipairs(h.writes) do
        assert(argv[4] == "set-sink-port" or argv[4] == "set-source-port")
    end
end)

test("click preflight uses fresh state and suppresses overlapping work", function()
    local h = host()
    h.env.update(); h.drain()
    h.output.active_port, h.input.active_port = headphones, headset
    h.env.onClick(); h.env.onClick(); h.env.update(); h.drain()
    assert(#h.writes == 2 and h.output.active_port == speaker)
end)

test("mixed mode goes toward headset", function()
    local h = host(headphones, internal)
    h.env.onClick(); h.drain()
    assert(h.glyph == "headset")
end)

test("unplugged headset is rejected before any writes", function()
    local h = host(nil, nil, "not available")
    h.env.onClick(); h.drain()
    assert(#h.writes == 0 and #h.notifications == 1 and h.glyph == "device-laptop")
    assert(h.tooltip:find("unavailable"))
end)

test("missing microphone port prevents partial switch", function()
    local h = host()
    table.remove(h.input.ports, 2)
    h.env.onClick(); h.drain()
    assert(#h.writes == 0 and #h.notifications == 1)
end)

test("second command failure displays measured mixed state", function()
    local h = host()
    h.fail["set-source-port"] = true
    h.env.onClick(); h.drain()
    assert(h.output.active_port == headphones and h.input.active_port == internal)
    assert(h.glyph == "device-laptop" and h.color == "error" and h.tooltip:find("Mixed"))
    assert(#h.notifications == 1)
end)

test("first command failure does not attempt microphone change", function()
    local h = host()
    h.fail["set-sink-port"] = true
    h.env.onClick(); h.drain()
    assert(#h.writes == 0 and #h.notifications == 1 and h.reads == 4)
end)

test("successful commands do not imply a successful switch", function()
    local h = host()
    h.ignoreWrites = true
    h.env.onClick(); h.drain()
    assert(h.glyph == "device-laptop" and #h.notifications == 1)
end)

for _, failure in ipairs({ "badJson", "missing", "reject", "truncated" }) do
    test("read failure and recovery: " .. failure, function()
        local h = host()
        h[failure] = true
        h.env.update(); h.drain()
        assert(h.glyph == "alert-triangle" and #h.notifications == 0)
        h.env.onClick(); h.drain()
        assert(#h.writes == 0 and #h.notifications == 1)
        h[failure] = false
        h.env.update(); h.drain()
        assert(h.glyph == "device-laptop" and h.color == "on_surface")
    end)
end

print(tostring(passed) .. " tests passed (Lua 5.4 mock host; no live audio changes)")
