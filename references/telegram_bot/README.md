# telegram-bot service

System systemd unit that keeps `bin/telegram_bot` running as `jpmelos` on
Debian Trixie. It starts at boot, restarts on failure, and stops gracefully on
`stop`.

## Install

1. Make sure `jc` serves the secrets from `~/config.json`. The file must have
   mode 600 and belong to you, or `jc` refuses it:

   ```
   jc get telegram_bot.bot_token
   jc get telegram_bot.chat_id
   ```

   The `budget_sync` task also needs `bmo.username`, `bmo.password`,
   `ynab.api_key`, and `questrade.api_key`. The unit passes no secrets itself.
   Everything comes from `jc`.

2. Install and start the unit as root. It runs as `jpmelos` and starts at boot.

   ```
   sudo cp ~/devel/dotfiles/references/telegram_bot/telegram-bot.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now telegram-bot
   ```

3. Verify:

   ```
   systemctl status telegram-bot
   journalctl -u telegram-bot -e
   ```

   Then send `/list` to the bot in the allowlisted chat.

## Operate

- Logs: `journalctl -u telegram-bot -f`.
- Restart after editing the bot itself: `sudo systemctl restart telegram-bot`.
- Editing a task needs no restart. The bot loads the file fresh on every
  `/run`.
- Stop: `sudo systemctl stop telegram-bot`. The running task is cancelled and
  its shutdown hook runs before exit.
- Installed unit differs from the reference: `systemctl cat telegram-bot`.

## Notes

- Only one process can poll one bot token. A second copy gets 409 conflicts,
  waits, and retries until the first stops.
- A bad token exits at once, so the unit lands in `failed` after a few tries
  instead of looping. Check status and logs, fix `~/config.json`, then
  `sudo systemctl restart telegram-bot`.
- Heartbeat has no `jc` key. To ping a dead-man-switch check, add
  `--heartbeat-url=` with your URL to the `ExecStart` line of the installed
  copy under `/etc/systemd/system/`, keeping the URL out of the repository.
  Then `daemon-reload` and restart.
- The host clock must be roughly correct. The bot drops backlog older than
  `--recent-window` by message date, and TLS needs a sane clock anyway. Debian
  enables time sync by default.
- If Chromium refuses to start under the hardening, comment out
  `NoNewPrivileges` and `RestrictSUIDSGID` first, then `daemon-reload` and
  restart. Those two interact with the browser sandbox. Keep the rest.
