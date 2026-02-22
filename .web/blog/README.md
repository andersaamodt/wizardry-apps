# Personal Blog Template

A single-author blog template for wizardry web with optional Nostr bridge support for post authorship, version selection, and local-first mirrored comments.

## Features

- **Full admin panel**: Compose, edit, delete, schedule, drip-queue, and publish
- **Smart Markdown editing**: Selection-aware toolbar + live preview
- **Autosave drafts**: Debounced autosave with draft persistence
- **Global drip queue**: Publish one queued post per global interval (optional jitter)
- **Scheduled release**: Per-draft exact release datetime
- **Media workflow**: Drag/drop image upload + markdown embed insertion
- **Content-addressed posts**: SHA-256 hash per published post
- **Public discovery**: Index, tags, search, RSS, Atom, sitemap
- **Archive index**: Month-grouped archive view with per-month counts
- **Post context UX**: Read-time card, tags, and automatic older/newer links
- **Passkey auth**: SSH identity + WebAuthn passkeys (challenge/response)

## Post Model

Posts are stored as `.md` files in `site/pages/posts/` with YAML front-matter:

```markdown
---
title: "My First Post"
published_at: "2024-01-15T10:30:00Z"
content_hash: "a1b2c3d4e5f6..."
tags: ["tech", "tutorial"]
author: "Your Name"
summary: "A brief introduction to my blog"
visibility: "public"
license: "CC BY 4.0"
---

# My First Post

Your post content here...
```

## Metadata Fields

### Required
- **title**: Post title
- **published_at**: ISO 8601 timestamp
- **content_hash**: Immutable post identifier (SHA-256 of content)
- **tags**: Array of tags (Nostr-compatible)
- **author**: Author name (extensible to multi-author)

### Optional
- **previous_hash**: Links to prior version (for edits)
- **summary**: Brief description for index/feeds
- **visibility**: Mapped to UNIX permissions (default: public)
- **license**: Content license (e.g., CC BY 4.0)

## Lifecycle States

Posts have system-understood states:
- **draft**: Local only, not published
- **published**: Canonical public state
- **replaced**: Superseded by newer version
- **deleted**: Tombstoned (marked for deletion)

States are inferred from metadata and filesystem visibility.

## Blog Structure

```
blog/
├── site/
│   ├── nostr/
│   │   ├── events/          # Canonical mirrored/signed event JSON files
│   │   ├── derived/         # Disposable indexes generated from events
│   │   └── state/           # Authors, relays, blocklist, hidden posts, key
│   └── pages/
│       ├── index.md         # Blog homepage
│       ├── about.md         # About page
│       ├── tags.md          # Tag index
│       └── posts/           # Blog posts
│           ├── 2024-01-15-welcome.md
│           └── 2024-01-20-second-post.md
└── static/
    └── style.css            # Blog styling
```

## Navigation

- **Homepage**: Chronological reverse-ordered post listing with pagination (10 posts per page)
- **Archive page**: All posts grouped by month
- **Tag index**: Global tag list with post counts
- **Tag pages**: Posts filtered by tag
- **Search**: Full-text search across titles, tags, summaries, and content
- **Post navigation**: Previous/next links within posts
- **Revision history**: Shows version lineage for edited posts

## Search

Full-text search via CGI:
- Search across post titles, tags, summaries, and content
- Case-insensitive matching
- Excludes draft posts from results
- Accessible via `/cgi/blog-search?q=query`

## Pagination

Blog index automatically paginates:
- 10 posts per page
- Previous/Next navigation
- Page counter (e.g., "Page 2 of 5")
- URL parameter: `?page=N`

## Draft Visibility

Posts with `visibility: "draft"` are hidden from:
- Blog homepage (index)
- Tag listings
- Search results

Drafts are only visible when accessed directly by URL, allowing you to work on posts locally before publishing.

To publish a draft:
```yaml
visibility: "public"  # Change from "draft"
```

## Static Pages

- **About**: Required static page (linked from navigation)
- Additional static pages can be added as `.md` files

## Interaction Model

- Blog rendering is deterministic from local files only.
- When the Nostr bridge is enabled, canonical post state is local Nostr event JSON under `site/nostr/events/`.
- Comments are read from locally mirrored events only.
- “Refresh comments” runs an explicit mirror action; render paths never perform live relay fetches.

## Nostr Bridge (Phase 2)

- Posts publish as kind `30023` events with slug-only `d` identity.
- Post markdown is stored directly in event `.content`.
- Latest rendered version is selected by newest `created_at` per (`pubkey`, `kind`, `d`) with event-id tie-break.
- Mirroring uses `nak`; signing/verification prefer `nostril` and fall back to `nak verify` when needed.
- Relay and author allowlist are file-backed:
  - `site/nostr/state/relays.txt`
  - `site/nostr/state/authors.txt`
- Local moderation and hide controls are file-backed:
  - `site/nostr/state/blocklist.txt`
  - `site/nostr/state/hidden_posts.txt`
- Bridge enablement is explicit in `site.conf` via `nostr_bridge_enabled=true|false`.

## Quick Start

```sh
# Create a blog site
web-wizardry create myblog blog

# Edit content
vim ~/sites/myblog/site/pages/posts/2024-01-15-welcome.md

# Build
web-wizardry build myblog

# Serve
web-wizardry serve myblog
```

Visit http://localhost:8080

To enable Nostr bridge for a site, turn on “Enable Nostr Bridge” in `/pages/admin.html#settings`, then configure:

- `site/nostr/state/secret.key` (hex private key for signing)
- `site/nostr/state/authors.txt`
- `site/nostr/state/relays.txt`

## MUD Integration & Authentication

The blog template integrates with the wizardry MUD player system to provide unified authentication and admin access control.

### Key Features

- **MUD Player Accounts**: Blog uses existing MUD player SSH keys
- **WebAuthn Authentication**: Passwordless login with biometrics/security keys
- **UNIX Group Permissions**: Admin access via `blog-admin` group
- **Admin Panel**: Compose, publish, and manage posts
- **Markdown Editor**: Live preview for easy writing
- **Draft Management**: Save work-in-progress, publish when ready
- **Configurable Registration**: Enable/disable new user registration

### Quick Start for Admins

1. **Create MUD Player** (on server as root):
   ```sh
   sudo add-player
   # Enter player name and SSH public key
   ```

2. **Grant Admin Access**:
   ```sh
   sudo groupadd blog-admin  # Create group if needed
   sudo usermod -aG blog-admin <username>
   ```

3. **Register on Blog**: Visit `/ssh-auth.html`, enter player name

4. **Access Admin Panel**: Visit `/admin.html` to compose and publish

### For Single-Author Blogs

After creating your account and giving yourself admin access:

1. Login to admin panel
2. Go to Settings
3. Uncheck "Enable User Registration"
4. Save Settings

This prevents new users from registering while keeping your access.

### Admin Capabilities

- **Compose & Edit**: Smart markdown toolbar + live preview
- **Autosave**: Draft autosaving while typing
- **Queue Scheduling**: Exact publish datetime or drip queue mode
- **Publish Control**: Publish now, scheduled, or drip
- **Draft CRUD**: Create/load/delete drafts from GUI
- **Media Uploads**: Drag/drop images to upload + insert markdown embeds
- **Global Queue Settings**: Drip interval + optional random jitter
- **Feed Settings**: Full-text feeds toggle + feed item count
- **Manage Settings**: Site title, registration toggle, themes

### Authentication Flow

```
MUD Player (UNIX user with SSH key)
    ↓
Register on blog (uses SSH fingerprint)
    ↓
Create WebAuthn credential (biometric, security key)
    ↓
Login with WebAuthn (no SSH needed)
    ↓
Access admin panel (if in blog-admin group)
```

### Demo Pages

- `/ssh-auth.html` - Authentication and registration
- `/admin.html` - Admin panel (requires admin permissions)

### CGI Scripts

**Authentication:**
- `ssh-auth-register-mud` - Register using MUD player account
- `ssh-auth-register` - Manual SSH key registration (demo/testing)
- `ssh-auth-bind-webauthn` - Bind WebAuthn credential to SSH fingerprint
- `ssh-auth-login-begin` - Start passkey login challenge
- `ssh-auth-login-finish` - Verify signed assertion and create session
- `ssh-auth-check-session` - Validate session and permissions
- `ssh-auth-logout` - Destroy current session
- `ssh-auth-list-delegates` - List all WebAuthn delegates
- `ssh-auth-revoke-delegate` - Revoke a WebAuthn delegate

**Blog Management (Admin Only):**
- `blog-get-config` - Get site configuration
- `blog-update-config` - Update site settings
- `blog-list-drafts` - List draft posts
- `blog-get-draft` - Load draft content for editing
- `blog-save-post` - Save/autosave/queue/publish posts
- `blog-delete-draft` - Delete draft
- `blog-list-queue` - List scheduled + drip queue
- `blog-run-scheduler` - Trigger scheduler tick
- `blog-nostr-mirror` - Mirror Nostr posts/comments from configured relays
- `blog-upload-media` - Upload images for markdown embedding
- `blog-archive` - Render month-grouped archive listing
- `blog-post-context` - Return post metadata + older/newer navigation context

**Public Nostr Read/Refresh Endpoints:**
- `blog-comments` - Return local mirrored comments for a post
- `blog-refresh-comments` - Explicitly mirror latest comments for a post
- `blog-submit-comment` - Store a signed Nostr comment event locally for a post

### Data Storage

```
~/sites/myblog/
├── site.conf                  # Site configuration
├── site/
│   ├── nostr/
│   │   ├── events/            # Canonical event store
│   │   ├── derived/           # Rebuildable indexes
│   │   └── state/
│   │       ├── authors.txt
│   │       ├── relays.txt
│   │       ├── blocklist.txt
│   │       ├── hidden_posts.txt
│   │       └── secret.key     # Local signing key (not committed)
│   └── pages/
│       └── posts/
│           ├── slug.md        # Generated/derived render projection
│           └── slug-2.md
└── .sitedata/
    └── myblog/
        ├── ssh-auth/
        ├── blog/
        │   └── drafts/
        └── uploads/
```

### Security Model

- **Root Identity**: SSH public key fingerprint (never changes)
- **Delegates**: WebAuthn credentials (revocable, multi-device)
- **Permissions**: UNIX group membership (`blog-admin`)
- **Session Validation**: Every admin action checks permissions
- **Phishing-Resistant**: WebAuthn bound to domain

See `.github/MUD_BLOG_INTEGRATION.md` for complete documentation.

## Design Principles

1. **Filesystem as database**: Posts are files, versions are immutable
2. **Content-addressable**: Identity based on content hash
3. **Append-only**: Edits create new versions, old versions preserved
4. **UNIX permissions**: Visibility through filesystem semantics
5. **Nostr-aligned**: Optional decentralized social layer with local canonical event storage
6. **Simple & transparent**: No hidden state, all data in files

## License

Part of the wizardry project.
