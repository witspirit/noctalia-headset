--!nonstrict
local open = false

local function render(view)
    local rows = {}
    if not view then
        table.insert(rows, ui.label({ text = "Reading audio configuration…" }))
    else
        for _, preset in ipairs(view.presets) do
            local enabled = not preset.unavailable and not view.switching
            table.insert(rows, ui.button({
                key = preset.id,
                text = preset.label,
                glyph = preset.glyph,
                variant = "ghost",
                contentAlign = "start",
                controlSize = "sm",
                enabled = enabled,
                selected = view.active == preset.id,
                tooltip = preset.unavailable,
                onClick = function()
                    if not enabled then return end
                    noctalia.state.set("audioRequest", { action = preset.id, time = noctalia.nowMs() })
                    panel.close()
                end,
            }))
        end
    end
    panel.render(ui.column({ gap = 4 }, rows))
end

function onOpen()
    open = true
    render(noctalia.state.get("audioView"))
end

function onClose()
    open = false
end

noctalia.state.watch("audioView", function(view)
    if open then render(view) end
end)
