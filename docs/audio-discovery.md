# Audio discovery

Verified locally on 2026-11-04. Noctalia reports `v5.4.1`. The audio server reports PipeWire via the PulseAudio interface, and `pactl` is installed.

## Device and port mapping

Both playback and capture have the description `Built-in Audio Analog Stereo`.

| Role | Stable device name |
| --- | --- |
| Output (sink) | `alsa_output.pci-0000_00_1f.3.analog-stereo` |
| Input (source) | `alsa_input.pci-0000_00_1f.3.analog-stereo` |

| Mode | Sink port | Source port |
| --- | --- | --- |
| Headset | `analog-output-headphones` | `analog-input-headset-mic` |
| Laptop | `analog-output-speaker` | `analog-input-internal-mic` |

The separate input port `analog-input-headphone-mic` is labeled “Microphone” and is not the requested Headset Microphone port.

At discovery, the active ports were Speakers and Internal Microphone. Both headset ports reported `not available`; availability must be checked again with the headset connected. Only read operations were performed.

## Proposed implementation

Use a Luau bar widget. Read `pactl --format=json list sinks` and `pactl --format=json list sources` and compare the selected devices' `active_port` fields. Do not use transient numeric device indexes or the monitor source.

Noctalia documents asynchronous subprocess execution with argument arrays and result callbacks, so the widget can invoke `pactl` directly and inspect failures without blocking the UI or constructing shell command strings. The array form requires plugin API 24; verify compatibility with the installed release when creating the manifest.

On click, set both ports for the requested mode and reread the actual state. Do not claim success based on a click or the first successful command. If only one port changes, report the failure and show the measured state. Preserve volume, mute, device profiles, and default-device selection unless later requirements explicitly change them.

Refresh after outside changes, either through an audio event subscription or bounded polling. Confirm the appropriate lifecycle hooks before choosing the mechanism.

## References

- [Noctalia plugin development](https://docs.noctalia.dev/noctalia/plugins/development/)
- [Noctalia runtime API: subprocesses](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/#subprocesses-and-environment)

These links track rolling documentation. Check against the 5.4.1 reference when implementing.
