# Privacy

Mute on Lock runs locally and makes no network requests. It has no analytics,
telemetry, advertising, crash reporting, account system, or update checker.

The service reads only:

- the macOS notification that indicates the screen locked;
- the number of seconds since the last system input event;
- the current default audio output, solely to set its mute control; and
- its own timeout configuration.

It does not inspect or store individual keystrokes, pointer positions, audio,
application names, documents, browser activity, or user identity. The local log
contains timestamps and service events such as “audio muted.” Configuration and
logs remain in the current user’s Library folder until that user removes them.
