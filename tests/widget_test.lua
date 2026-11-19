-- Exercise the service, bar widget, and panel as separate plugin entries.
local cardName = "alsa_card.pci-0000_00_1f.3"
local sink = "alsa_output.pci-0000_00_1f.3.analog-stereo"
local source = "alsa_input.pci-0000_00_1f.3.analog-stereo"
local hdmi = "alsa_output.pci-0000_00_1f.3.hdmi-stereo"
local webcam = "alsa_input.usb-046d_Logitech_Webcam_C925e_AB823B7F-02.analog-stereo"
local analogProfile = "output:analog-stereo+input:analog-stereo"
local hdmiProfile = "output:hdmi-stereo+input:analog-stereo"
local speaker, headphones = "analog-output-speaker", "analog-output-headphones"
local internal, headset = "analog-input-internal-mic", "analog-input-headset-mic"
local tv, mic = "hdmi-output-0", "analog-input-mic"
local passed = 0

local function host(options)
    options = options or {}
    local h = {
        queue = {}, writes = {}, notifications = {}, fail = {}, reads = 0, waits = 0,
        defaultSink = options.sink or sink, defaultSource = options.source or source,
        analogOutput = options.sink or sink, analogInput = options.source or source,
        profile = analogProfile, connectedTV = false, connectedWebcam = false,
        outputPort = speaker, inputPort = internal, tvPort = tv, webcamPort = mic,
        jack = "available", delay = 0,
    }

    local function port(name, availability)
        return { name = name, availability = availability }
    end
    local function device(name, activePort, ports)
        return { name = name, active_port = activePort, ports = ports }
    end
    local function read(kind)
        local analogOutputs = { port(speaker, "availability unknown"), port(headphones, h.jack) }
        local analogInputs = { port(internal, "availability unknown") }
        if not h.missingHeadsetMic then table.insert(analogInputs, port(headset, h.jack)) end
        local tvPort = port(tv, h.connectedTV and "available" or "not available")
        if kind == "cards" then
            if options.customDevices then return {} end
            local ports = { [tv] = tvPort }
            for _, collection in ipairs({ analogOutputs, analogInputs }) do
                for _, entry in ipairs(collection) do ports[entry.name] = entry end
            end
            return {{
                name = cardName, active_profile = h.profile, ports = ports,
                profiles = {
                    [analogProfile] = { available = true },
                    [hdmiProfile] = { available = h.connectedTV },
                },
            }}
        elseif kind == "sinks" then
            local settling = h.profileChanged and h.waits < h.delay
            if h.profile == analogProfile and not settling then
                return { device(h.analogOutput, h.outputPort, analogOutputs) }
            elseif h.profile == hdmiProfile and not settling and not h.hideHDMISink then
                return { device(hdmi, h.tvPort, { tvPort }) }
            end
            return {}
        elseif kind == "sources" then
            local devices = { device(h.analogInput, h.inputPort, analogInputs) }
            if h.connectedWebcam then table.insert(devices, device(webcam, h.webcamPort, { port(mic, "available") })) end
            return devices
        end
        assert(kind == "defaults")
        return { default_sink_name = h.defaultSink, default_source_name = h.defaultSource }
    end

    local shared, watchers = {}, {}
    local time = 0
    local noctalia = {
        setUpdateInterval = function(value) h.interval = value end,
        getConfig = function(key)
            return ({ sink = h.analogOutput, source = h.analogInput, webcam_source = webcam })[key]
        end,
        notifyError = function(_, body) table.insert(h.notifications, body) end,
        nowMs = function()
            time = time + 1
            return time
        end,
        state = {
            get = function(key) return shared[key] end,
            set = function(key, value)
                shared[key] = value
                for _, watcher in ipairs(watchers[key] or {}) do
                    table.insert(h.queue, function() watcher(value) end)
                end
            end,
            watch = function(key, fn)
                if not watchers[key] then watchers[key] = {} end
                table.insert(watchers[key], fn)
            end,
        },
        json = { decode = function(raw)
            if h.badJson then error("invalid JSON") end
            return read(raw)
        end },
        runAsync = function(argv, callback)
            if h.reject then return false end
            table.insert(h.queue, function()
                if argv[1] == "sleep" then
                    h.waits = h.waits + 1
                    callback({ exitCode = 0 })
                    return
                end
                assert(argv[1] == "timeout" and argv[2] == "5s" and argv[3] == "pactl")
                local command, name, value = argv[4], argv[5], argv[6]
                if command == "--format=json" then
                    h.reads = h.reads + 1
                    callback({ exitCode = 0, stdout = name == "info" and "defaults" or value, stdoutTruncated = h.truncated })
                    return
                end

                table.insert(h.writes, { command, name, value })
                if h.fail[command] then
                    callback({ exitCode = 1, stderr = "simulated command failure" })
                    return
                end
                if not h.ignoreWrites then
                    if command == "set-card-profile" then
                        assert(name == cardName)
                        h.profile = value
                        h.profileChanged = true
                        if h.disconnectOnProfileChange then h.connectedWebcam = false end
                    elseif command == "set-sink-port" then
                        assert(h.waits >= h.delay)
                        if name == hdmi then h.tvPort = value
                        else h.outputPort = value end
                    elseif command == "set-source-port" then
                        if name == webcam then h.webcamPort = value
                        else h.inputPort = value end
                    elseif command == "set-default-sink" then
                        assert(h.waits >= h.delay)
                        h.defaultSink = name
                    elseif command == "set-default-source" then
                        h.defaultSource = name
                    else
                        error("Unexpected command " .. command)
                    end
                end
                callback({ exitCode = 0, stdout = "" })
            end)
            return true
        end,
    }
    local function load(entry, fields)
        fields.noctalia = noctalia
        local env = setmetatable(fields, { __index = _G })
        assert(loadfile("headset/" .. entry .. ".luau", "t", env))()
        return env
    end

    h.service = load("audio", {})
    h.panel = load("presets", {
        panel = {
            render = function(rows) h.rows = rows end,
            close = function()
                h.panelOpen = false
                h.panel.onClose()
            end,
        },
        ui = {
            label = function(props) return props end,
            button = function(props) return props end,
            column = function(_, children) return children end,
        },
    })
    noctalia.togglePanel = function(id)
        assert(id == "witspirit/headset:presets")
        h.panelOpen = not h.panelOpen
        if h.panelOpen then h.panel.onOpen()
        else h.panel.onClose() end
    end
    h.widget = load("widget", {
        barWidget = {
            setText = function() end,
            setGlyph = function(value) h.glyph = value end,
            setGlyphColor = function(value) h.color = value end,
            setTooltip = function(value) h.tooltip = value end,
        },
    })

    function h.drain()
        local count = 0
        while #h.queue > 0 do
            count = count + 1
            assert(count < 100, "callback loop")
            table.remove(h.queue, 1)()
        end
    end
    function h.row(id)
        for _, row in ipairs(h.rows) do
            if row.key == id then return row end
        end
        error("Missing preset row " .. id)
    end
    function h.select(id)
        if not h.panelOpen then h.widget.onClick(); h.drain() end
        h.row(id).onClick()
        h.drain()
    end
    return h
end

local function test(name, run)
    run()
    passed = passed + 1
    print("PASS " .. name)
end

test("bar opens the menu and external audio changes update its selection", function()
    local h = host()
    h.widget.onClick()
    h.drain()
    assert(h.panelOpen and h.row("laptop").selected and h.row("headset").enabled)
    assert(h.glyph == "device-laptop" and h.interval == 2000 and #h.writes == 0)

    h.outputPort, h.inputPort = headphones, headset
    h.widget.onRightClick(); h.drain()
    assert(h.row("headset").selected and h.glyph == "headset" and h.color == "primary")
    h.defaultSource = "another-microphone"
    h.service.update(); h.drain()
    assert(not h.row("headset").selected and h.glyph == "help-circle" and h.tooltip:find("Unknown"))
    assert(#h.writes == 0)
end)

test("laptop and headset still switch using their configured analog ports", function()
    local h = host()
    h.select("headset")
    assert(h.glyph == "headset" and h.outputPort == headphones and h.inputPort == headset)
    assert(not h.panelOpen and #h.writes == 2)
    assert(h.writes[1][1] == "set-sink-port" and h.writes[2][1] == "set-source-port")
    h.select("laptop")
    assert(h.glyph == "device-laptop" and h.outputPort == speaker and h.inputPort == internal)
    assert(#h.writes == 4 and #h.notifications == 0)
    h.select("laptop")
    assert(#h.writes == 4)
end)

test("unavailable presets are disabled and update while the menu is open", function()
    local h = host()
    h.jack = "not available"
    h.widget.onClick(); h.drain()
    assert(h.row("laptop").enabled and not h.row("headset").enabled and not h.row("standup").enabled)
    h.row("headset").onClick()
    h.row("standup").onClick()
    h.drain()
    assert(#h.writes == 0 and h.panelOpen)
    h.connectedWebcam = true
    h.service.update(); h.drain()
    assert(not h.row("standup").enabled)
    h.connectedTV, h.connectedWebcam = true, false
    h.service.update(); h.drain()
    assert(not h.row("standup").enabled and h.row("standup").tooltip:find("webcam"))
    h.connectedWebcam = true
    h.service.update(); h.drain()
    assert(h.row("standup").enabled and h.profile == analogProfile)
end)

test("stand-up awaits the HDMI sink, selects ports, and sets both defaults", function()
    local h = host()
    h.connectedTV, h.connectedWebcam = true, true
    h.tvPort, h.webcamPort = "other-hdmi", "other-mic"
    h.widget.onClick(); h.drain()
    h.delay = 2
    h.select("standup")
    assert(h.profile == hdmiProfile and h.waits == 2)
    assert(h.defaultSink == hdmi and h.defaultSource == webcam and h.glyph == "device-tv")
    assert(#h.writes == 5 and h.writes[1][1] == "set-card-profile")
    assert(h.writes[2][1] == "set-sink-port" and h.writes[2][2] == hdmi and h.tvPort == tv)
    assert(h.writes[3][1] == "set-source-port" and h.writes[3][2] == webcam and h.webcamPort == mic)
    assert(#h.notifications == 0)
end)

for _, preset in ipairs({ "laptop", "headset" }) do
    test("returning from stand-up restores " .. preset .. " audio", function()
        local h = host()
        h.connectedTV, h.connectedWebcam = true, true
        h.profile, h.defaultSink, h.defaultSource = hdmiProfile, hdmi, webcam
        h.select(preset)
        assert(h.profile == analogProfile and h.defaultSink == sink and h.defaultSource == source)
        assert(h.outputPort == (preset == "headset" and headphones or speaker))
        assert(h.inputPort == (preset == "headset" and headset or internal))
        assert(h.writes[1][1] == "set-card-profile" and h.writes[1][3] == analogProfile)
        assert(#h.notifications == 0)
    end)
end

test("selection preflights disconnected devices before changing the card profile", function()
    local h = host()
    h.connectedTV, h.connectedWebcam = true, true
    h.widget.onClick(); h.drain()
    assert(h.row("standup").enabled)
    h.connectedWebcam = false
    h.row("standup").onClick()
    h.drain()
    assert(#h.writes == 0 and #h.notifications == 1 and h.glyph == "device-laptop")
    assert(h.tooltip:find("webcam"))
end)

test("missing ports prevent a partial headset switch", function()
    local h = host()
    h.missingHeadsetMic = true
    h.select("headset")
    assert(#h.writes == 0 and #h.notifications == 0 and not h.row("headset").enabled)
end)

test("a failed card profile command stops before device writes", function()
    local h = host()
    h.connectedTV, h.connectedWebcam = true, true
    h.fail["set-card-profile"] = true
    h.select("standup")
    assert(#h.writes == 1 and #h.notifications == 1 and h.glyph == "device-laptop")
end)

test("a partial switch shows the measured mixed configuration", function()
    local h = host()
    h.connectedTV, h.connectedWebcam = true, true
    h.fail["set-default-source"] = true
    h.select("standup")
    assert(h.profile == hdmiProfile and h.defaultSink == hdmi and h.defaultSource == source)
    assert(h.glyph == "help-circle" and h.color == "error")
    assert(#h.notifications == 1 and h.notifications[1]:find("set-default-source", 1, true))
    h.select("standup")
    assert(#h.notifications == 2)
    h.fail["set-default-source"] = nil
    h.select("standup")
    assert(h.glyph == "device-tv" and h.defaultSource == webcam)
end)

test("successful commands with unchanged defaults fail verification", function()
    local h = host()
    h.profile, h.defaultSink = hdmiProfile, hdmi
    h.connectedTV, h.connectedWebcam = true, true
    h.ignoreWrites = true
    h.select("standup")
    assert(h.glyph == "help-circle" and #h.notifications == 1)
    assert(h.notifications[1]:find("could not be verified"))
end)

test("missing replacement devices time out without routing writes", function()
    local h = host()
    h.connectedTV, h.connectedWebcam, h.hideHDMISink = true, true, true
    h.select("standup")
    assert(h.profile == hdmiProfile and #h.writes == 1 and h.waits == 5 and #h.notifications == 1)
    h.select("laptop")
    assert(h.glyph == "device-laptop" and h.profile == analogProfile and #h.notifications == 1)
end)

test("disconnect after profile change is reported without routing to the missing microphone", function()
    local h = host()
    h.connectedTV, h.connectedWebcam, h.disconnectOnProfileChange = true, true, true
    h.select("standup")
    assert(h.profile == hdmiProfile and #h.writes == 1 and #h.notifications == 1)
    assert(h.notifications[1]:find("webcam"))
end)

test("a selection during polling applies once and excludes overlapping selections", function()
    local h = host()
    h.widget.onClick(); h.drain()
    h.service.update()
    local selectHeadset, selectLaptop = h.row("headset").onClick, h.row("laptop").onClick
    selectHeadset()
    selectLaptop()
    h.drain()
    assert(h.glyph == "headset" and #h.writes == 2 and #h.notifications == 0)
end)

test("existing custom analog device settings work without an ALSA card", function()
    local h = host({ sink = "custom-output", source = "custom-input", customDevices = true })
    h.select("headset")
    assert(h.glyph == "headset" and #h.writes == 2)
    assert(h.writes[1][2] == "custom-output" and h.writes[2][2] == "custom-input")
end)

for _, failure in ipairs({ "badJson", "reject", "truncated" }) do
    test("audio read failure and recovery: " .. failure, function()
        local h = host()
        h.drain()
        h[failure] = true
        h.widget.onClick(); h.drain()
        assert(h.glyph == "alert-triangle" and #h.notifications == 0)
        assert(not h.row("laptop").enabled and #h.writes == 0)
        h[failure] = false
        h.service.update(); h.drain()
        assert(h.glyph == "device-laptop" and h.color == "on_surface" and h.row("laptop").enabled)
    end)
end

print(tostring(passed) .. " tests passed (" .. _VERSION .. " mock host)")
