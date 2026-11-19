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

## Standup setup discovery (2026-11-16)

Observed with the TV powered on and connected through the USB-C adapter. Playback and microphone capture in Teams still need a hardware test.

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

The TV port showed as available in `pactl --format=json list cards` while the analog profile was active. The HDMI sink appeared after switching the card profile manually. The Stand-up preset selects this HDMI sink and the available Logitech webcam microphone as the system defaults. With the TV unplugged on 2026-11-19, the HDMI port reported `not available` and the HDMI profile reported `available: false`.

The TV was at logical position `(0, -1080)`, 1920×1080 at 60 Hz, scale 1; the laptop was at `(1920, -1140)`, 1920×1200 at approximately 59.95 Hz, scale 1. These positions are an observed temporary layout, not a requested persistent layout. The TV is reached as DisplayPort (`DP-2`) on the laptop side despite the adapter's HDMI connector. Connector names and generic display identity may change with hardware/port; numeric PipeWire/PulseAudio indexes are transient. Re-check availability and actual names at activation.
