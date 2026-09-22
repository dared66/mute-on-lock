# Mute on Lock

A tiny macOS background service that mutes audio when you lock your screen or
leave your Mac idle. The default idle timeout is 15 minutes.

## Install

Requires macOS and Apple’s free Xcode Command Line Tools.

```sh
git clone https://github.com/dared66/mute-on-lock.git
cd mute-on-lock
bash install.sh
```

If the compiler is missing, run `xcode-select --install` once, then repeat the
install command. No administrator password or macOS permissions are required.
The service starts immediately and automatically after future logins.

### Set the idle timeout

Replace `15` with any value from 0.1 minutes through 7 days:

```sh
"$HOME/Library/Application Support/Mute on lock/mute-on-lock" --set-idle-minutes 15
```

The running service applies the change immediately. To inspect the current
setting and idle time:

```sh
"$HOME/Library/Application Support/Mute on lock/mute-on-lock" --status
```

## What it does

- Mutes the current default output when the screen locks.
- Checks system input inactivity every five seconds and mutes once the configured
  timeout is reached.
- Leaves audio muted when you return. It never unmutes your Mac.
- Re-arms after new keyboard or pointer input.
- Runs only inside your logged-in user session.

Audio playback does not count as user activity. Outputs that do not expose a
writable macOS mute control cannot be muted.

## Privacy and security

Mute on Lock has no networking, analytics, telemetry, update checker, elevated
privileges, or third-party dependencies. It reads only macOS’s elapsed idle time,
screen-lock notification, current output device, and its own timeout setting. It
does not record keys, pointer positions, application names, audio, or browsing
activity. Its configuration and log are readable only by the current user. See
[PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

The service uses macOS’s `com.apple.screenIsLocked` distributed notification.
Apple does not document this notification, so a future macOS release could change
it. The idle-time trigger remains independent.

## Verify

The self-test checks the idle policy and mutes the current output:

```sh
"$HOME/Library/Application Support/Mute on lock/mute-on-lock" --self-test
```

For an end-to-end lock test, unmute, press Control–Command–Q, then unlock and
confirm that audio is muted. Logs contain event type and timestamps only:
`~/Library/Logs/Mute on lock/service.log`.

## Uninstall

From the cloned repository:

```sh
bash uninstall.sh
```

This stops the service and removes its executable and login item. It preserves
your timeout setting, logs, source checkout, and current audio state. To remove
the remaining settings and logs, delete `~/Library/Application Support/Mute on
lock/config.json` and `~/Library/Logs/Mute on lock`.

## Contributing

Bug reports and focused pull requests are welcome. See
[CONTRIBUTING.md](CONTRIBUTING.md). Mute on Lock is available under the
[MIT License](LICENSE).
