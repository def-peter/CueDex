# CueDex

CueDex is a macOS-native attention router for coding assistants. It turns selected coding-assistant lifecycle events into local cues without retaining prompt or response content.

## Language

**Attention Router**:
The product boundary for CueDex: it routes matching coding-assistant lifecycle events to attention cues. It is not a chat client, hook editor, task manager, or general automation platform.
_Avoid_: Completion notifier, hook manager, agent platform

**Attention Cue**:
A local visual, sound, or spoken signal that asks the user to return their attention to a coding assistant.
_Avoid_: Alert, message, task

**Attention Source**:
The coding assistant whose lifecycle event calls for an attention cue, such as Codex or OpenCode. The source is the assistant application, not the model or model provider it uses.
_Avoid_: Model, provider

**Cue Profile**:
A source's independent cue choices: enabled effects, glow colors and animation, sound selection, and speech voice and message. Application language, pause, and quiet hours are global; glow intensity and duration are fixed rather than configurable, and audio follows the system volume.
_Avoid_: Shared defaults with overrides, source-specific settings schema
