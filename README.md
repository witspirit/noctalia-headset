# Noctalia Headset

A small Noctalia plugin for switching between headset audio and the laptop's default audio setup with one click.

## Intended behavior

- Show an icon in Noctalia's tray/bar area indicating whether headset mode is active.
- When laptop mode is active, clicking the icon activates the headset configuration.
- When headset mode is active, clicking the icon restores the default laptop audio configuration.
- Any other port combination shows an unknown-state icon; clicking restores laptop mode, after which clicks alternate between headset and laptop.
- Reflect the actual audio configuration, including changes made outside the plugin.

Target: Noctalia 5.4+ (locally verified: 5.4.1), using a Luau bar widget and a `plugin.toml` manifest.

Both modes use the same **Built-in Audio Analog Stereo** device, with a headset connected through the audio jack:

| Mode | Output port | Input port |
| --- | --- | --- |
| Headset | Headphones | Headset Microphone |
| Laptop | Speakers | Internal Microphone |

Each known mode requires both of its ports to match. Any other combination is unknown and has its own question-mark icon. Clicking from unknown selects laptop mode. Unknown is an observed state, never a configuration the plugin deliberately selects. No device profile change is requested.

## Status

The first widget is implemented in [headset/](headset/), registered with the local Noctalia instance, and placed immediately before the volume widget. Plugin lint and 15 mock-host behavioral tests pass. Live visual and physical audio verification are pending.

See [headset/README.md](headset/README.md) for installation, behavior, and verification, and [docs/audio-discovery.md](docs/audio-discovery.md) for the discovered device names.

See [TASKS.md](TASKS.md) for the working backlog and open questions. Keep that file updated as work progresses; record confirmed decisions there so later development has a shared reference.

## Definition of done

- The plugin can be installed and enabled in the user's Noctalia setup.
- Its icon clearly distinguishes headset mode from other audio configurations.
- A single click switches in either direction, with the actual state reflected afterward.
- External audio changes update the indicator.
- If the headset is unavailable or switching fails, the plugin reports the problem without falsely indicating success.
- Installation, configuration, and manual verification steps are documented.
