# telegram-bot service

User systemd unit that keeps `bin/telegram_bot` running on Debian Trixie. It
starts at boot, restarts on failure, and stops gracefully on `stop`.

## Install

1. Create the environment file with the bot token. Only the owner can read it:

   ```
   mkdir -p ~/.config/telegram-bot
   printf 'TELEGRAM_BOT_TOKEN=%s\n' '123456:ABC...' > ~/.config/telegram-bot/env
   chmod 600 ~/.config/telegram-bot/env
   ```

   Optional extra lines in the same file:

   ```
   TELEGRAM_CHAT_ID=123456789
   TELEGRAM_TASKS_DIR=/home/user/tasks
   TELEGRAM_STATE_DIR=/home/user/.local/state/telegram_bot
   TELEGRAM_HEARTBEAT_URL=https://hc-ping.com/your-uuid-here
   ```

   Anything not set falls back to `jc get` keys and built-in defaults. See
   `telegram_bot --help`.

2. Create the tasks directory if it does not exist, and put `<name>.py` task
   files there. The unit defaults to `~/telegram_tasks`. To serve the tasks
   from the dotfiles checkout instead, switch the `ExecStart` line to the
   commented alternative in the unit.

3. Install and start the unit:

   ```
   mkdir -p ~/.config/systemd/user
   cp ~/devel/dotfiles/references/telegram_bot/telegram-bot.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now telegram-bot
   ```

4. Run at boot without login:

   ```
   sudo loginctl enable-linger "$USER"
   ```

5. Verify:

   ```
   systemctl --user status telegram-bot
   journalctl --user -u telegram-bot -e
   ```

   Then send `/list` to the bot in the allowlisted chat.

## Operate

- Logs: `journalctl --user -u telegram-bot -f`.
- Restart after editing the bot itself:
  `systemctl --user restart telegram-bot`.
- Editing a task needs no restart. The bot loads the file fresh on every
  `/run`.
- Stop: `systemctl --user stop telegram-bot`. The running task is cancelled and
  its shutdown hook runs before exit.
- Installed unit differs from the reference:
  `systemctl --user cat telegram-bot`.

## Notes

- Only one process can poll one bot token. A second copy gets 409 conflicts,
  waits, and retries until the first stops.
- A bad token exits at once, so the unit lands in `failed` after a few tries
  instead of looping. Check status and logs, fix the env file, then
  `systemctl --user restart telegram-bot`.
- Set `TELEGRAM_HEARTBEAT_URL` to a dead-man-switch check so a silent stop
  pages you. The bot pings it every five minutes by default.
- The host clock must be roughly correct. The bot drops backlog older than
  `--recent-window` by message date, and TLS needs a sane clock anyway. Debian
  enables time sync by default.
- If Chromium refuses to start under the hardening, comment out
  `NoNewPrivileges` and `RestrictSUIDSGID` first, then `daemon-reload` and
  restart. Those two interact with the browser sandbox. Keep the rest.
