# Virtual Redditor

Virtual Redditor is a desktop-first moderation daemon for Reddit communities.
It runs a persistent POSIX `sh` patrol loop, uses Reddit OAuth refresh tokens,
asks a local Ollama model for adjudication, and performs autonomous replies and
moderation actions with full undo support.

## What It Does

- Reads `/r/{subreddit}/comments` incrementally using `last_seen.txt`
- Builds per-comment adjudication context:
  - parent and grandparent context
  - sibling tone sample
  - author recent/top/downvoted activity
  - author subreddit-local history plus global history
- Injects doctrine from:
  - `manifesto.md` (constitutional)
  - `norms.jsonl` (statutory)
- Runs mode-aware adjudication via Ollama (`judicial`, `capricious`, `mixed`)
- Performs enforcement ritual for bans: `reply -> randomized delay -> ban`
- Logs moderation events in JSONL with immediate undo capabilities
- Supports nightly statute extraction through `extract_norms.sh`

## Runtime Files

Default state directory:

- `~/.local/state/wizardry/virtual-redditor`

Key files:

- `reddit.env`: Reddit credentials and subreddit targeting
- `bot.env`: mode and patrol settings
- `manifesto.md`: constitutional doctrine
- `norms.jsonl`: accepted statutory norms
- `actions.jsonl`: all enforcement actions and undo events
- `bans.jsonl`: ban-specific enforcement events
- `replies.jsonl`: bot replies and apologies
- `last_seen.txt`: incremental patrol watermark

## Credentials

Use **Connect...** in the app to run the guided browser-first OAuth flow:

- opens Reddit login/signup in your browser
- opens `https://www.reddit.com/prefs/apps`
- tells you exactly how to create the app (`script` type + loopback redirect)
- captures callback automatically via `http://127.0.0.1:8765/vr/callback`
- exchanges code for refresh token and writes credentials to `reddit.env`

Manual values in `reddit.env` are:

- `REDDIT_CLIENT_ID`
- `REDDIT_CLIENT_SECRET`
- `REDDIT_REFRESH_TOKEN`
- `REDDIT_USER_AGENT`
- `REDDIT_USERNAME`
- `SUBREDDIT`

## Backend Commands

The desktop UI calls:

- `.apps/virtual-redditor/scripts/virtual-redditor-backend.sh`

Main actions:

- `status`
- `start` / `stop` / `restart`
- `run-once`
- `list-actions` / `list-replies`
- `undo ACTION_ID`
- `apologize ACTION_ID [MESSAGE]`
- `extract-norms`
- `oauth-begin CLIENT_ID CLIENT_SECRET [SUBREDDIT] [USERNAME_HINT]`
- `oauth-status`
- `oauth-submit-callback CALLBACK_URL_OR_QUERY`
- `oauth-finish`
- `oauth-cancel`

## launchd Supervision

The daemon script can install a user LaunchAgent:

- `.apps/virtual-redditor/scripts/virtual-redditor-daemon.sh launchd-install`

It runs:

- `.apps/virtual-redditor/scripts/virtual-redditor-daemon.sh run`

with `KeepAlive` and log files under the state directory.

## Dependencies

- POSIX `sh`
- `curl`
- `jq`
- `nc` (optional but recommended for automatic localhost OAuth callback capture)
- Ollama local HTTP API

No database or non-shell runtime is required.
