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

Classify exact output/input pairs as headset or laptop mode; every other pair is unknown and uses a question-mark icon. Clicking unknown selects laptop mode, then normal laptop/headset toggling resumes. A read failure still uses the separate warning triangle because the current ports could not be measured.

Noctalia documents asynchronous subprocess execution with argument arrays and result callbacks, so the widget can invoke `pactl` directly and inspect failures without blocking the UI or constructing shell command strings. The array form requires plugin API 24; verify compatibility with the installed release when creating the manifest.

On click, set both ports for the requested mode and reread the actual state. Do not claim success based on a click or the first successful command. If only one port changes, report the failure and show the measured state. Preserve volume, mute, device profiles, and default-device selection unless later requirements explicitly change them.

Refresh after outside changes, either through an audio event subscription or bounded polling. Confirm the appropriate lifecycle hooks before choosing the mechanism.

## References

- [Noctalia plugin development](https://docs.noctalia.dev/noctalia/plugins/development/)
- [Noctalia runtime API: subprocesses](https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/#subprocesses-and-environment)

These links track rolling documentation. Check against the 5.4.1 reference when implementing.

## Standup setup discovery (2026-11-16)

Observed with the TV powered on and connected through the USB-C adapter. These are identifiers for future development, not a completed standup profile. Audio playback and microphone capture were not physically verified during this discovery.

| Item | Observed identifier / value |
| --- | --- |
| Built-in audio card | `alsa_card.pci-0000_00_1f.3` |
| HDMI profile (also retains analog microphone input) | `output:hdmi-stereo+input:analog-stereo` |
| HDMI output port | `hdmi-output-0` (available; display product name `AAA`) |
| HDMI output sink | `alsa_output.pci-0000_00_1f.3.hdmi-stereo` |
| Analog laptop/headset profile | `output:analog-stereo+input:analog-stereo` |
| Analog sink | `alsa_output.pci-0000_00_1f.3.analog-stereo` |
| Built-in analog input | `alsa_input.pci-0000_00_1f.3.analog-stereo` |
| Webcam card | `alsa_card.usb-046d_Logitech_Webcam_C925e_AB823B7F-02` |
| Webcam microphone source | `alsa_input.usb-046d_Logitech_Webcam_C925e_AB823B7F-02.analog-stereo` |
| Webcam microphone port | `analog-input-mic` |
| TV Niri output | `DP-2`, reported as `PNP(XXX) AAA Unknown` |
| Laptop Niri output | `eDP-1`, reported as `Sharp Corporation 0x1515 Unknown` |

The TV audio was detected as available while the analog profile was active, but the HDMI sink was not exposed until the card profile was changed. The HDMI profile was selected manually and the HDMI sink was then set as the default. At capture, the default input was the built-in analog input; the webcam input was available. The desired standup microphone has not been specified.

The TV was at logical position `(0, -1080)`, 1920×1080 at 60 Hz, scale 1; the laptop was at `(1920, -1140)`, 1920×1200 at approximately 59.95 Hz, scale 1. These positions are an observed temporary layout, not a requested persistent layout. The TV is reached as DisplayPort (`DP-2`) on the laptop side despite the adapter's HDMI connector. Connector names and generic display identity may change with hardware/port; numeric PipeWire/PulseAudio indexes are transient. Re-check availability and actual names at activation.

A future standup mode would need to switch the card profile before selecting the HDMI sink; returning to laptop/headset mode may need to restore the analog profile before selecting the existing analog ports. Re-read state and handle missing TV, input choice, partial failures, and restoration explicitly. This extends the existing design decision to preserve profiles/default devices and requires behavior and tests to be updated. Display mirroring is a separate concern: Niri's documented workaround uses `wl-mirror`, not native output cloning.
