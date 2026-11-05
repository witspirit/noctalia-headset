# Headset Toggle

A Noctalia 5.4+ Luau bar widget for the built-in analog audio device.

- **Headset icon, accent color:** Headphones and Headset Microphone are both selected. Click to select Speakers and Internal Microphone.
- **Laptop icon:** Speakers and Internal Microphone are both selected. Click to select Headphones and Headset Microphone.
- **Question-mark icon:** any other port combination is unknown. Click to select Speakers and Internal Microphone; the next click selects headset mode. The plugin never deliberately selects a mixed configuration.
- **Warning triangle:** audio state could not be read. Hover for the error.
- **Error color and notification:** a requested switch failed or a port is unavailable. The icon still represents the measured ports.

Right-click refreshes immediately. Otherwise, state refreshes every two seconds, including changes made in other audio tools. Repeated clicks during a read or switch are ignored. Reading and enabling the widget do not switch audio.

## Requirements

- Noctalia 5.4+ (development host: 5.4.1; manifest requires plugin API 24).
- `pactl` with JSON output and the GNU `timeout` utility on Noctalia's PATH.
- A running PulseAudio-compatible server, including PipeWire's PulseAudio service.

The plugin changes ports only. It leaves the chosen default devices, volumes, mute state, and card profile alone. Both ports are checked before switching. Unknown availability is allowed, but explicitly unavailable ports are rejected. If a port change fails partway through, the plugin reports the measured mixed state; it does not attempt an automatic rollback.

## Local installation

From a terminal in the graphical session:

```sh
noctalia msg plugins source add headset-dev path /home/witspirit/projects/personal/noctalia-headset
noctalia msg plugins enable witspirit/headset
```

In Noctalia's bar settings, add **Headset Toggle** beside Volume. Enabling a plugin and placing its widget are separate steps. The widget's full type is `witspirit/headset:toggle`.

This development checkout has already been registered as `headset-dev`, enabled, and placed as `headset` immediately before `volume` in `bar.default.end`. These settings are local to this machine, outside the repository. There is no need to run the installation commands again here.

The two device-name settings are available under the plugin's settings gear. Their defaults match the discovered devices on this laptop. Ports are intentionally fixed to the four analog ports described above. On a different machine, use `pactl --format=json list sinks` and `pactl --format=json list sources` to find its device names.

Luau file edits hot-reload. After a manifest edit, run `noctalia msg config-reload`.

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

The behavioral harness uses a mock Noctalia host and the system Lua 5.4 shared library. The widget deliberately uses syntax shared by Lua and Luau. These tests verify its asynchronous control flow and error handling without changing real audio; they do not substitute for verification in Noctalia's Luau runtime.

Live verification remains to be completed:

1. With the headset unplugged and the laptop ports selected, confirm the laptop icon and hover text. Clicking should report an unavailable headset and leave both ports alone.
2. Plug in the headset. Jack detection may automatically change one or both ports; the icon should catch up within about two seconds.
3. Starting in laptop mode, click once. In the audio settings, verify **Headphones** and **Headset Microphone**. Verify playback and microphone capture physically.
4. Click again. Verify **Speakers** and **Internal Microphone**, playback, and microphone capture.
5. Change either port in another audio tool to create a mixed configuration. Verify the question-mark icon and unknown tooltip appear. Click once to restore laptop mode, then again for headset mode.
6. Unplug the headset. Verify the resulting configuration is reflected and a click does not claim success for unavailable ports.

The mock tests also cover failed commands, missing devices/ports, invalid or truncated JSON, launch refusal, repeated clicks, and commands that succeed without the ports staying selected. Physical switching and visual rendering still require the live checks above.

## API references

- [Noctalia 5.4.1 entry scripts](https://docs.noctalia.dev/noctalia/v5.4.1/plugins/development/entries/)
- [Noctalia 5.4.1 runtime API](https://docs.noctalia.dev/noctalia/v5.4.1/plugins/development/runtime-api/)
- [Noctalia 5.4.1 local development workflow](https://docs.noctalia.dev/noctalia/v5.4.1/plugins/development/workflow/)
