# Project tracker

Last updated: 2026-11-04

## Milestone 0 — Project foundation

- [x] Capture the requested behavior and completion criteria.
- [x] Create a version-controlled local project tracker.
- [x] Initialize the Git repository.

## Milestone 1 — Discover the integration

- [ ] Inspect the installed Noctalia version and its plugin interfaces/documentation.
- [ ] Confirm how a clickable status icon should be added to the tray/bar.
- [ ] Inspect the audio stack and identify the headset and laptop audio devices.
- [ ] Record the exact headset and laptop configurations: output, input, and any device profiles.
- [ ] Define how to recognize headset mode and how to handle mixed configurations.
- [ ] Choose the smallest implementation supported by the installed setup.

## Milestone 2 — Build the first usable plugin

- [ ] Add the plugin structure and any configuration it needs.
- [ ] Detect and display the current audio mode.
- [ ] Toggle between the confirmed headset and laptop configurations on click.
- [ ] Refresh the indicator when audio changes outside the plugin.
- [ ] Handle an unavailable headset and failed switches with clear feedback.

## Milestone 3 — Verify and document

- [ ] Verify laptop → headset and headset → laptop switching on the user's setup.
- [ ] Verify external audio changes, headset disconnection, and switching failures.
- [ ] Document installation, configuration, and manual verification.

## Open questions

- Which Noctalia version is installed, and where are its plugins loaded from?
- Which headset should be selected, and is it wired, USB, or Bluetooth?
- Does headset mode switch both playback and microphone input?
- Which laptop output and microphone should be restored?
- Are any special audio profiles needed?

Resolve these from the local setup where possible; ask the user for preferences that cannot be inferred.

## Confirmed decisions

- 2026-11-04: Use one status icon and one-click toggling between headset and default laptop audio.
- 2026-11-04: Track project progress locally in this file alongside the source code.

## Progress log

- 2026-11-04: Captured the initial scope, acceptance criteria, discovery tasks, and implementation backlog.
