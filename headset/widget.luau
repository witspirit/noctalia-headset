--!nonstrict
-- Read the audio server each time; never persist an assumed toggle state.
local modes = {
    headset = { output = "analog-output-headphones", input = "analog-input-headset-mic" },
    laptop = { output = "analog-output-speaker", input = "analog-input-internal-mic" },
}
local snapshot = nil
local busy = false
local lastError = nil

local function isHeadset(state)
    return state.output.active_port == modes.headset.output
        and state.input.active_port == modes.headset.input
end

local function paint()
    barWidget.setText("")
    if not snapshot then
        barWidget.setGlyph("alert-triangle")
        barWidget.setGlyphColor("error")
        barWidget.setTooltip(lastError or "Reading audio configuration…")
        return
    end
    local active = isHeadset(snapshot)
    local laptop = snapshot.output.active_port == modes.laptop.output
        and snapshot.input.active_port == modes.laptop.input
    barWidget.setGlyph(active and "headset" or "device-laptop")
    barWidget.setGlyphColor(lastError and "error" or (active and "primary" or "on_surface"))
    local title = active and "Headset mode" or (laptop and "Laptop mode" or "Mixed audio configuration")
    local action = active and "Click to use laptop speakers and microphone."
        or "Click to use headphones and headset microphone."
    barWidget.setTooltip(title .. "\nOutput: " .. tostring(snapshot.output.active_port)
        .. "\nInput: " .. tostring(snapshot.input.active_port)
        .. "\n" .. (busy and "Switching / refreshing…" or action)
        .. (lastError and ("\n" .. lastError) or ""))
end

local function report(message)
    lastError = message
    noctalia.notifyError("Headset Toggle", message)
end

-- All invocations are bounded. Argument arrays avoid shell interpolation of settings.
local function run(arguments, callback)
    local argv = { "timeout", "5s", "pactl" }
    for _, argument in ipairs(arguments) do
        table.insert(argv, argument)
    end
    local accepted = noctalia.runAsync(argv, function(result)
        if result.exitCode ~= 0 or result.timedOut or result.stdoutTruncated then
            local detail = result.stderr or ""
            if detail == "" then
                detail = "pactl failed (exit " .. tostring(result.exitCode) .. ")."
            end
            callback(nil, detail)
        else
            callback(result.stdout or "", nil)
        end
    end)
    if not accepted then
        callback(nil, "Could not start pactl. Install pactl and GNU timeout.")
    end
end

local function readDevice(kind, name, callback)
    run({ "--format=json", "list", kind }, function(raw, err)
        if not raw then
            callback(nil, err)
            return
        end
        local ok, devices = pcall(noctalia.json.decode, raw)
        if not ok or type(devices) ~= "table" then
            callback(nil, "Could not decode pactl " .. kind .. " JSON.")
            return
        end
        for _, device in ipairs(devices) do
            if device.name == name then
                if type(device.active_port) ~= "string" or type(device.ports) ~= "table" then
                    callback(nil, "Audio device has no analog ports: " .. name)
                    return
                end
                callback(device, nil)
                return
            end
        end
        callback(nil, "Audio device not found: " .. name)
    end)
end

local function readState(callback)
    local sink = noctalia.getConfig("sink")
    local source = noctalia.getConfig("source")
    readDevice("sinks", sink, function(output, err)
        if not output then
            callback(nil, err)
            return
        end
        readDevice("sources", source, function(input, inputError)
            if not input then
                callback(nil, inputError)
            else
                callback({ output = output, input = input }, nil)
            end
        end)
    end)
end

local function portError(device, name)
    for _, port in ipairs(device.ports) do
        if port.name == name then
            if port.availability == "not available" or port.availability == "no" then
                return (port.description or name) .. " is unavailable. Check the headset connection."
            end
            return nil -- Unknown availability is normal for built-in speakers/microphones.
        end
    end
    return "Audio port not found: " .. name
end

local function refreshAfterSwitch(target, switchError)
    readState(function(state, err)
        snapshot = state
        busy = false
        if switchError then
            report(switchError .. (err and ("\nCould not reread audio state: " .. err) or ""))
        elseif not state then
            report("Could not verify audio switch: " .. err)
        elseif state.output.active_port ~= target.output or state.input.active_port ~= target.input then
            report("The audio ports did not stay in the requested mode. Check the audio settings.")
        else
            lastError = nil
        end
        paint()
    end)
end

function update()
    noctalia.setUpdateInterval(2000)
    if busy then return end
    busy = true
    readState(function(state, err)
        snapshot = state
        busy = false
        -- Poll failures belong in the tooltip, without repeated notifications.
        lastError = err
        paint()
    end)
end

function onClick()
    if busy then return end
    busy = true
    paint()
    -- Preflight a fresh reading, so outside changes since the last tick count.
    readState(function(state, err)
        snapshot = state
        if not state then
            busy = false
            report(err)
            paint()
            return
        end
        local target = isHeadset(state) and modes.laptop or modes.headset
        local unavailable = portError(state.output, target.output) or portError(state.input, target.input)
        if unavailable then
            busy = false
            report(unavailable)
            paint()
            return
        end
        run({ "set-sink-port", state.output.name, target.output }, function(_, outputError)
            if outputError then
                refreshAfterSwitch(target, "Could not switch output: " .. outputError)
                return
            end
            run({ "set-source-port", state.input.name, target.input }, function(_, inputError)
                refreshAfterSwitch(target, inputError and ("Could not switch microphone: " .. inputError) or nil)
            end)
        end)
    end)
end

function onRightClick()
    update()
end

paint()
