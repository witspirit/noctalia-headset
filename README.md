# Noctalia Headset

A small Noctalia plugin for switching between headset audio and the laptop's default audio setup with one click.

## Intended behavior

- Show an icon in Noctalia's tray/bar area indicating whether headset mode is active.
- When headset mode is inactive, clicking the icon activates the headset configuration.
- When headset mode is active, clicking the icon restores the default laptop audio configuration.
- Reflect the actual audio configuration, including changes made outside the plugin.

The exact Noctalia placement and integration will be confirmed during discovery. “Headset configuration” may involve output, microphone input, device profile, or a combination; the user's current setup will determine what needs to change.

## Status

Project setup and requirements captured. No plugin code yet.

See [TASKS.md](TASKS.md) for the working backlog and open questions. Keep that file updated as work progresses; record confirmed decisions there so later development has a shared reference.

## Definition of done

- The plugin can be installed and enabled in the user's Noctalia setup.
- Its icon clearly distinguishes headset mode from other audio configurations.
- A single click switches in either direction, with the actual state reflected afterward.
- External audio changes update the indicator.
- If the headset is unavailable or switching fails, the plugin reports the problem without falsely indicating success.
- Installation, configuration, and manual verification steps are documented.
