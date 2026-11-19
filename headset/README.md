# Audio Presets

Click the icon beside Volume to open the preset menu. Select **Laptop** for the built-in speakers and microphone, **Headset** for the wired headphones and headset microphone, or **Stand-up** for the HDMI TV and Logitech webcam microphone. Right-click the bar icon to refresh immediately. The widget also refreshes every two seconds.

Unavailable presets are greyed out. Stand-up requires a connected TV on the captured HDMI port and the webcam microphone. The bar icon and the highlighted menu row reflect the measured audio configuration. A question mark indicates a different or mixed configuration. A warning icon indicates that the audio server couldn't be read.

When switching, the plugin checks the devices again before making changes. It changes the card profile as needed, waits for the playback and recording devices to appear, and selects their ports and system defaults. If a step fails, Noctalia shows an error and the widget reports the resulting audio configuration. Select an available preset to recover from a partial switch. Teams can use the selected devices when its speaker and microphone are set to the system defaults.

## Requirements

- Noctalia 5.4+ and plugin API 24.
- A PulseAudio-compatible server such as PipeWire's PulseAudio service.
- `pactl` with JSON output, GNU `timeout`, and `sleep` on Noctalia's PATH.

## Local installation

From a terminal in the graphical session:

```sh
noctalia msg plugins source add headset-dev path /home/witspirit/projects/personal/noctalia-headset
noctalia msg plugins enable witspirit/headset
```

In Noctalia's bar settings, add **Audio Presets** beside Volume. Its widget type is `witspirit/headset:toggle`. The development checkout is already registered and the widget is already placed on this machine. The plugin and widget IDs also work with existing bar configuration.

The plugin's settings gear exposes the built-in sink, built-in microphone, and stand-up webcam source names. The defaults use the [captured hardware](../docs/audio-discovery.md). Stand-up uses the built-in card associated with the configured ALSA analog sink and the `hdmi-output-0` port. Use `pactl --format=json list cards`, `list sinks`, and `list sources` to identify devices.

Noctalia hot-reloads Luau edits. After changing the manifest, run `noctalia msg config-reload`.

To disable, remove the bar widget in settings, then run:

```sh
noctalia msg plugins disable witspirit/headset
noctalia msg plugins source remove headset-dev
```

## Verification

From the project root:

```sh
noctalia plugins lint headset
python tests/run.py
```

The tests use a mock Noctalia host and the system Lua 5.4 or 5.5 shared library. They cover menu availability, external changes, profile transitions, device appearance and disconnection, and failed or partial switches.

1. With the TV and webcam unplugged, open the menu and confirm **Stand-up** is greyed out. Plug in both devices and confirm it becomes selectable.
2. Select **Stand-up**. Check for the HDMI TV output and Logitech webcam input in the system audio settings, then test playback and microphone capture in Teams.
3. Select **Laptop**. Check that the analog profile, speakers and internal microphone return. With the wired headset plugged in, repeat from **Stand-up** to **Headset** and check both wired ports.
4. Unplug a device or change a default in the system audio settings. Confirm the menu and bar icon update within about two seconds.

## API references

- [Noctalia 5.4.1 entry scripts](https://docs.noctalia.dev/noctalia/v5.4.1/plugins/development/entries/)
- [Noctalia 5.4.1 runtime API](https://docs.noctalia.dev/noctalia/v5.4.1/plugins/development/runtime-api/)
- [Noctalia 5.4.1 declarative UI](https://docs.noctalia.dev/noctalia/v5.4.1/plugins/development/declarative-ui/)
