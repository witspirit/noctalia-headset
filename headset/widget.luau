--!nonstrict
local function paint(view)
    barWidget.setText("")
    if not view or not view.measured then
        barWidget.setGlyph("alert-triangle")
        barWidget.setGlyphColor("error")
        barWidget.setTooltip(view and view.error or "Reading audio configuration…")
        return
    end

    local title = "Unknown audio configuration"
    local glyph = "help-circle"
    for _, preset in ipairs(view.presets) do
        if preset.id == view.active then
            title = preset.label .. " audio"
            glyph = preset.glyph
            break
        end
    end
    barWidget.setGlyph(glyph)
    barWidget.setGlyphColor(view.error and "error" or (view.active and view.active ~= "laptop" and "primary" or "on_surface"))
    barWidget.setTooltip(title .. "\nOutput: " .. (view.output or "None")
        .. "\nInput: " .. (view.input or "None")
        .. "\n" .. (view.switching and "Switching audio…" or "Click to choose an audio preset.")
        .. (view.error and ("\n" .. view.error) or ""))
end

function onRightClick()
    noctalia.state.set("audioRequest", { action = "refresh", time = noctalia.nowMs() })
end

function onClick()
    noctalia.togglePanel("witspirit/headset:presets")
    onRightClick()
end

noctalia.state.watch("audioView", paint)
paint(noctalia.state.get("audioView"))
