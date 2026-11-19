# Noctalia Headset

A Noctalia bar plugin that switches between laptop, headset, and stand-up audio presets. Click the bar icon to open the preset menu. It highlights the active preset and greys out presets when their hardware is unavailable.

| Preset | Output | Input |
| --- | --- | --- |
| Laptop | Laptop speakers | Internal microphone |
| Headset | Wired headphones | Headset microphone |
| Stand-up | TV via HDMI | Logitech C925e webcam microphone |

Stand-up enables the HDMI audio profile and selects the TV and webcam as the system defaults. Selecting Laptop or Headset restores the analog profile and sets the corresponding ports and defaults. The bar icon also reflects changes made in other audio tools.

The plugin targets Noctalia 5.4+ and is registered in the local shell beside Volume. See [the plugin guide](headset/README.md) for installation and verification, [audio discovery](docs/audio-discovery.md) for device identifiers, and [the project tracker](TASKS.md) for progress.
