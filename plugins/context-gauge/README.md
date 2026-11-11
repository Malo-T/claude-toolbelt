# context-gauge

Every request re-reads the whole context, and the prompt cache that makes it cheap expires when you
step away. This plugin keeps one line under the prompt so you see both without asking:

```
🟢 ctx 12k/200k (6%) · session 8min
⚠️ ctx 162k/1M (16%) · 🌞 cache 54min · session 1h12
🛑 ctx 410k/1M (41%) · ⏳ cache  7min · session 2h40
   ctx 180k/1M (18%) · 🧊 cache froid · session 3h05
```

| Part | Meaning |
|---|---|
| `🟢` / `⚠️` / `🛑` | Context under 15% of the window, past the warning threshold, past the critical one. No icon in between. |
| `🌞` / `⏳` / `🧊` | Cache warm, about to expire (10 minutes, at most half its life), expired. |
| `session` | Time since the session started; `/clear` restarts it. |

The cache countdown starts at the end of each main-thread turn and stays hidden under 50k tokens,
where a cold cache costs little. A mod redraws the line after each turn and every 30 seconds.

## Settings

| Option | Default | |
|---|---|---|
| `warnTokens` | `0` | `0` = 150k, capped at 60% of the model's window |
| `critTokens` | `0` | `0` = 400k, capped at 80% of the model's window |
| `cacheTtlMinutes` | `60` | 60 on a subscription, 5 on an API key; `0` hides the countdown |

Use it with `compact-nudge`, which acts on the same two signals: it suggests `/compact` or `/clear`
past a size, and holds a prompt once when the cache has gone cold. Past the critical icon, `handoff`
carries the work into a fresh session.

The mod API (the `claude-code` module) is early access and may change between Claude Code releases.

## Install

```
/plugin install context-gauge --marketplace Malo-T/claude-toolbelt
```
