--!nonstrict
-- One service owns audio changes, regardless of how many bars show the widget.
local analogSink = noctalia.getConfig("sink")
local analogSource = noctalia.getConfig("source")
local cardStem = analogSink:match("^alsa_output%.(.+)%.analog%-stereo$")
local cardName = cardStem and ("alsa_card." .. cardStem)
local sourceOnCard = cardStem and analogSource == ("alsa_input." .. cardStem .. ".analog-stereo")
local analogProfile = "output:analog-stereo+input:analog-stereo"
local hdmiProfile = "output:hdmi-stereo+input:analog-stereo"

local presets = {
    {
        id = "laptop", label = "Laptop", glyph = "device-laptop", profile = analogProfile,
        sink = analogSink, sinkPort = "analog-output-speaker", sinkLabel = "Laptop speakers",
        source = analogSource, sourcePort = "analog-input-internal-mic", sourceLabel = "Laptop microphone",
    },
    {
        id = "headset", label = "Headset", glyph = "headset", profile = analogProfile,
        sink = analogSink, sinkPort = "analog-output-headphones", sinkLabel = "Headphones",
        source = analogSource, sourcePort = "analog-input-headset-mic", sourceLabel = "Headset microphone",
    },
    {
        id = "standup", label = "Stand-up", glyph = "device-tv", profile = hdmiProfile,
        sink = cardStem and ("alsa_output." .. cardStem .. ".hdmi-stereo"),
        sinkPort = "hdmi-output-0", sinkLabel = "TV audio",
        source = noctalia.getConfig("webcam_source"), sourcePort = "analog-input-mic",
        sourceLabel = "Logitech webcam microphone",
    },
}

local snapshot
local lastError
local reading = false
local pendingPreset
local switching = false

local function report(message)
    lastError = message
    noctalia.notifyError("Audio Presets", message)
end

-- Bounded subprocesses and argument arrays keep the UI responsive and settings literal.
local function pactl(arguments, callback)
    local argv = { "timeout", "5s", "pactl" }
    for _, argument in ipairs(arguments) do
        table.insert(argv, argument)
    end
    local accepted = noctalia.runAsync(argv, function(result)
        if result.exitCode ~= 0 or result.timedOut or result.stdoutTruncated then
            local detail = result.stderr
            if not detail or detail == "" then
                detail = "pactl failed (exit " .. tostring(result.exitCode) .. ")."
            end
            callback(nil, detail)
        else
            callback(result.stdout or "", nil)
        end
    end)
    if not accepted then
        callback(nil, "Could not start pactl. Check that pactl and GNU timeout are installed.")
    end
end

local reads = {
    { "cards", { "--format=json", "list", "cards" } },
    { "sinks", { "--format=json", "list", "sinks" } },
    { "sources", { "--format=json", "list", "sources" } },
    { "defaults", { "--format=json", "info" } },
}

local function readState(callback)
    local state = {}
    local function read(index)
        local request = reads[index]
        if not request then
            callback(state, nil)
            return
        end
        local key, arguments = request[1], request[2]
        pactl(arguments, function(raw, err)
            if not raw then
                callback(nil, err)
                return
            end
            local ok, data = pcall(noctalia.json.decode, raw)
            if not ok or type(data) ~= "table" then
                callback(nil, "Could not decode pactl " .. key .. " JSON.")
                return
            end
            if key == "defaults" then
                state.defaults = data
            else
                state[key] = {}
                for _, device in ipairs(data) do
                    if type(device) ~= "table" or type(device.name) ~= "string" then
                        callback(nil, "Invalid pactl " .. key .. " entry.")
                        return
                    end
                    state[key][device.name] = device
                end
            end
            read(index + 1)
        end)
    end
    read(1)
end

local function findPort(device, name)
    for _, port in ipairs(device and device.ports or {}) do
        if port.name == name then return port end
    end
end

local function portError(port, label)
    if not port or port.availability == "not available" or port.availability == "no" then
        return label .. " is unavailable."
    end
    return nil -- Built-in ports may report unknown availability.
end

local function presetError(state, preset)
    local card = state.cards[cardName]
    if preset.id == "standup" and not card then
        return "HDMI audio card is unavailable."
    end

    local output = state.sinks[preset.sink]
    local input = state.sources[preset.source]
    local outputPort = findPort(output, preset.sinkPort)
    local inputPort = findPort(input, preset.sourcePort)
    if card and card.active_profile ~= preset.profile then
        local profile = (card.profiles or {})[preset.profile]
        if not profile or profile.available == false then
            return preset.label .. " audio profile is unavailable."
        end
        -- A port can be plugged in even when its profile currently hides the device.
        local cardPorts = card.ports or {}
        outputPort = cardPorts[preset.sinkPort]
        if sourceOnCard and preset.id ~= "standup" then
            inputPort = cardPorts[preset.sourcePort]
        end
    end
    return portError(outputPort, preset.sinkLabel) or portError(inputPort, preset.sourceLabel)
end

local function matches(state, preset)
    local card = state.cards[cardName]
    local output = state.sinks[preset.sink]
    local input = state.sources[preset.source]
    return (not card or card.active_profile == preset.profile)
        and state.defaults.default_sink_name == preset.sink
        and state.defaults.default_source_name == preset.source
        and output and output.active_port == preset.sinkPort
        and input and input.active_port == preset.sourcePort
end

local function activePortLabel(device, name)
    if not device then return name end
    local port = findPort(device, device.active_port)
    return (port and port.description) or device.description or name
end

local function publish()
    local view = { presets = {}, error = lastError, switching = switching }
    if snapshot then
        local sink = snapshot.defaults.default_sink_name
        local source = snapshot.defaults.default_source_name
        view.output = activePortLabel(snapshot.sinks[sink], sink)
        view.input = activePortLabel(snapshot.sources[source], source)
        view.measured = true
    end
    for _, preset in ipairs(presets) do
        local reason = not snapshot and "Audio configuration is unavailable." or nil
        if snapshot then
            reason = presetError(snapshot, preset)
            if not reason and matches(snapshot, preset) then view.active = preset.id end
        end
        table.insert(view.presets, {
            id = preset.id, label = preset.label, glyph = preset.glyph, unavailable = reason,
        })
    end
    noctalia.state.set("audioView", view)
end

local function finish(preset, switchError)
    readState(function(state, err)
        snapshot = state
        switching = false
        if switchError then
            report(switchError)
        elseif not state then
            report("Could not verify " .. preset.label .. " audio. " .. err)
        elseif not matches(state, preset) or presetError(state, preset) then
            report(preset.label .. " audio could not be verified. Check the audio settings.")
        else
            lastError = nil
        end
        publish()
    end)
end

local function selectDevices(state, preset)
    local changes = {}
    if state.sinks[preset.sink].active_port ~= preset.sinkPort then
        table.insert(changes, { "set-sink-port", preset.sink, preset.sinkPort })
    end
    if state.sources[preset.source].active_port ~= preset.sourcePort then
        table.insert(changes, { "set-source-port", preset.source, preset.sourcePort })
    end
    if state.defaults.default_sink_name ~= preset.sink then
        table.insert(changes, { "set-default-sink", preset.sink })
    end
    if state.defaults.default_source_name ~= preset.source then
        table.insert(changes, { "set-default-source", preset.source })
    end

    local function apply(index)
        local change = changes[index]
        if not change then
            finish(preset)
            return
        end
        pactl(change, function(_, err)
            if err then
                finish(preset, "Could not apply " .. preset.label .. " audio (" .. change[1] .. "). " .. err)
            else
                apply(index + 1)
            end
        end)
    end
    apply(1)
end

local function waitForProfile(preset, attempts)
    readState(function(state, err)
        if not state then
            finish(preset, "Could not read the new audio devices. " .. err)
            return
        end
        local card = state.cards[cardName]
        local unavailable = presetError(state, preset)
        if card and card.active_profile == preset.profile and not unavailable then
            selectDevices(state, preset)
            return
        end
        if attempts > 1 then
            -- PipeWire can acknowledge the profile before the replacement devices appear.
            local accepted = noctalia.runAsync({ "sleep", "0.2" }, function(result)
                if result.exitCode == 0 then
                    waitForProfile(preset, attempts - 1)
                else
                    finish(preset, "Could not wait for " .. preset.label .. " audio devices.")
                end
            end)
            if accepted then return end
        end
        finish(preset, unavailable or (preset.label .. " audio devices did not appear."))
    end)
end

local function activate(preset, err)
    local unavailable = err or presetError(snapshot, preset)
    if unavailable then
        report(unavailable)
        publish()
        return
    end
    if matches(snapshot, preset) then
        publish()
        return
    end
    switching = true
    publish()
    local card = snapshot.cards[cardName]
    if not card or card.active_profile == preset.profile then
        selectDevices(snapshot, preset)
        return
    end
    pactl({ "set-card-profile", cardName, preset.profile }, function(_, profileError)
        if profileError then
            finish(preset, "Could not switch to the " .. preset.label .. " audio profile. " .. profileError)
        else
            waitForProfile(preset, 6)
        end
    end)
end

function update()
    if reading or switching then return end
    reading = true
    readState(function(state, err)
        snapshot = state
        lastError = err
        reading = false
        local preset = pendingPreset
        pendingPreset = nil
        if preset then
            activate(preset, err)
        else
            publish()
        end
    end)
end

noctalia.state.watch("audioRequest", function(request)
    if not request then return end
    if request.action == "refresh" then
        update()
    elseif not pendingPreset and not switching then
        for _, preset in ipairs(presets) do
            if preset.id == request.action then
                pendingPreset = preset
                update()
                return
            end
        end
    end
end)
noctalia.setUpdateInterval(2000)
update()
