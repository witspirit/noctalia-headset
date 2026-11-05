# Project tracker

Last updated: 2026-11-04

## Milestone 0 — Project foundation

- [x] Capture the requested behavior and completion criteria.
- [x] Create a version-controlled local project tracker.
- [x] Initialize the Git repository.

## Milestone 1 — Discover the integration

- [x] Inspect the installed Noctalia version and its plugin interfaces/documentation.
- [x] Confirm how a clickable status icon should be added to the tray/bar.
- [x] Inspect the audio stack and identify the headset and laptop audio devices.
- [x] Record the exact headset and laptop configurations: output, input, and any device profiles.
- [x] Define how to recognize headset mode and how to handle mixed configurations.
- [x] Choose the smallest implementation supported by the installed setup.

## Milestone 2 — Build the first usable plugin

- [x] Add the plugin structure and any configuration it needs.
- [x] Detect and display the current audio mode.
- [x] Toggle between the confirmed headset and laptop configurations on click.
- [x] Refresh the indicator when audio changes outside the plugin.
- [x] Handle an unavailable headset and failed switches with clear feedback.

Implementation is checked with plugin lint and a mock-host harness; these checkboxes do not imply physical audio verification.

## Milestone 3 — Verify and document

- [ ] Verify laptop → headset and headset → laptop switching on the user's setup.
- [ ] Verify external audio changes, headset disconnection, and switching failures.
- [x] Document installation, configuration, and manual verification.
- [x] Register and enable the local plugin and place it beside Volume.
- [ ] Confirm the icon and tooltip render correctly in the live bar.

## Open questions

- No remaining requirements questions. Headset connection is needed for physical verification of both modes.

Resolve these from the local setup where possible; ask the user for preferences that cannot be inferred.

## Confirmed decisions

- 2026-11-04: Use one status icon and one-click toggling between headset and default laptop audio.
- 2026-11-04: Track project progress locally in this file alongside the source code.
- 2026-11-04: Target Noctalia 5.4+ with Luau; installed version verified as 5.4.1.
- 2026-11-04: Switch ports on Built-in Audio Analog Stereo: Headphones + Headset Microphone for headset mode; Speakers + Internal Microphone for laptop mode. The headset uses the audio jack.
- 2026-11-04: Each known mode requires both ports to match. All other combinations show an unknown state with a question-mark icon. Clicking unknown restores laptop mode; further clicks alternate headset and laptop. This supersedes the initial behavior of toggling mixed configurations toward headset.
- 2026-11-04: Use a Luau bar widget (API 24) invoking `pactl` through argument arrays, with five-second command timeouts and two-second polling. Keep default devices, volumes, mute state, and device profiles unchanged.

## Progress log

- 2026-11-04: Captured the initial scope, acceptance criteria, discovery tasks, and implementation backlog.
- 2026-11-04: Read local PipeWire/PulseAudio device metadata and recorded exact ports in `docs/audio-discovery.md`. Current state was laptop mode; no audio settings changed.
- 2026-11-04: Implemented `witspirit/headset:toggle`, its device-name settings, failure feedback, and measured-state verification. Noctalia lint: zero errors/warnings. All 13 mock-host tests passed under Lua 5.4 (not the Luau runtime).
- 2026-11-04: Registered the checkout as path source `headset-dev`, enabled `witspirit/headset`, and inserted widget `headset` before Volume while preserving existing bar items. Noctalia reports the plugin enabled and the shell healthy; no matching plugin errors appeared in the recent user journal. Visual confirmation and physical switching remain pending. No audio port writes were invoked during development.
- 2026-11-04: Added explicit unknown-state detection and a separate question-mark icon for mixed/other ports. Unknown clicks restore laptop mode, including when the headset is unavailable. Updated regression tests: all 15 pass; plugin lint has zero errors/warnings. Luau edits are covered by the existing local-source hot reload.
