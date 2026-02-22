# OAuth Compliance & Token Handling — Addendum

> **Applicable to**: Claude Cowork for Linux (unofficial compatibility layer)
> **Last updated**: 2026-02-20
> **Goal**: Full OAuth handling stays in unmodified Anthropic applications (Claude Desktop + Claude Code)

---

## Executive Summary

This project is a Linux compatibility layer for Claude Desktop's Cowork feature. It stubs macOS-native modules so the unmodified Electron app can run on Linux. **This layer does not implement, intercept, store, or forward any OAuth authentication.** All authentication is handled entirely by Anthropic's own applications:

| Component | Handles Auth? | Source |
|-----------|--------------|--------|
| Claude Desktop (Electron renderer) | **Yes** — manages OAuth flow with Anthropic servers | Unmodified Anthropic code |
| Claude Code CLI | **Yes** — authenticates independently via `claude login` | Unmodified Anthropic binary |
| This compatibility layer (stubs) | **No** — satisfies IPC contracts only | This repository |

---

## Architecture: Where OAuth Lives

```
┌──────────────────────────────────────────────────────────────────┐
│  Claude Desktop (Unmodified Anthropic Renderer)                   │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  OAuth flow → Anthropic servers → Token stored in renderer  │ │
│  │  (We never see this token)                                  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                          │ IPC                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  Our Stubs (this repo)                                      │ │
│  │  ├─ Auth_$_doAuthInBrowser: opens browser only              │ │
│  │  ├─ AuthRequest: opens browser only, isAvailable()→false    │ │
│  │  ├─ addApprovedOauthToken: no-op (token discarded)          │ │
│  │  ├─ filterEnv: blocks credential-like env vars              │ │
│  │  └─ sdk_bridge: allowlisted env vars only                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                          │ spawn                                  │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  Claude Code CLI (Unmodified Anthropic Binary)              │ │
│  │  └─ Authenticates independently via `claude login`          │ │
│  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## Detailed Code Audit

### 1. `addApprovedOauthToken` — Token Deliberately Discarded

**File**: `stubs/@ant/claude-swift/js/index.js` (lines 1011-1035)

**What the official macOS version does**: Stores the OAuth token inside the sandboxed VM so Claude Code can use the consumer plan's credentials.

**What our stub does**: Accepts the IPC call (required by the contract), immediately returns `{ success: true }`, and **never reads, stores, or forwards the token**.

```javascript
addApprovedOauthToken: async (_token) => {
  trace('vm.addApprovedOauthToken() called — token intentionally discarded');
  return { success: true };
},
```

**How this meets expectations**:
- The `_token` parameter uses JavaScript's underscore convention to signal "unused"
- The token is never assigned to any variable, written to disk, or passed to any function
- The trace log records that the call happened, but the token value is never logged
- Claude Code CLI authenticates independently — it does not receive this token

---

### 2. `filterEnv` — Credential-Bearing Env Vars Blocked

**File**: `stubs/@ant/claude-swift/js/index.js` (lines 99-122)

**Risk**: The Claude Desktop renderer passes `additionalEnv` vars when spawning processes. If any of these contain OAuth tokens, our original code would forward them blindly via `Object.assign`.

**Mitigation**: A regex pattern blocks any env var key matching credential-related names:

```javascript
const BLOCKED_ENV_KEY_PATTERN = /oauth|bearer|token|refresh|secret|credential|session_?cookie/i;
```

Any key matching this pattern is logged as blocked and excluded from the subprocess environment.

**How this meets expectations**:
- Even if Anthropic's renderer starts passing OAuth tokens via env vars in a future update, our code will automatically block them
- The allowlist (`ENV_ALLOWLIST`) only includes system and Claude configuration variables — never auth credentials
- Blocked keys are logged for auditability (values are never logged)

---

### 3. SDK Bridge Environment — Allowlist Replaces Full Spread

**File**: `cowork/sdk_bridge.js` (lines 19-54, 318-323)

**Risk**: The SDK bridge previously copied the entire `process.env` to subprocesses:
```javascript
// BEFORE (unsafe):
const env = { ...process.env, CLAUDE_CODE_SESSION_ID: sessionId };
```

If the Electron main process had OAuth tokens in its environment (which is possible after auth), they would leak to Claude Code.

**Mitigation**: Replaced with an explicit allowlist:

```javascript
// AFTER (safe):
const env = filterEnvForSubprocess(process.env, {
  CLAUDE_CODE_SESSION_ID: sessionId,
});
```

The `SDK_ENV_ALLOWLIST` contains only system variables, display variables, and Claude configuration keys. OAuth tokens, session cookies, and other credentials are structurally excluded.

**How this meets expectations**:
- Claude Code receives only the minimum environment it needs to function
- No path exists for OAuth tokens to flow from the Electron process to Claude Code through our code
- The allowlist is easy to audit — every allowed variable is explicitly named

---

### 4. `AuthRequest` — Browser-Only, No Callback Handling

**File**: `stubs/@ant/claude-native/index.js` (lines 154-199)

**What it does**:
- `start(url)` → Opens `url` in the system browser via `xdg-open`
- `isAvailable()` → Returns `false`
- Never registers a protocol handler (no `claude://` deep link)
- Never processes, parses, or intercepts the OAuth callback

**What it does NOT do**:
- Capture the callback URL or token
- Register any HTTP listener or deep-link handler
- Communicate with any server
- Store any authentication state

`isAvailable() → false` tells the renderer that no native auth window exists, so the renderer handles the entire OAuth flow (including the callback) through its own built-in logic — code we do not modify.

**How this meets expectations**:
- Our code is functionally equivalent to the user clicking a link in their browser
- The OAuth callback goes directly to the unmodified Claude Desktop renderer
- This stub is purely a browser-opener; it cannot intercept any credentials

---

### 5. `Auth_$_doAuthInBrowser` — Origin-Validated Browser Open

**File**: `linux-loader.js` (lines 927-957)

**What it does**: Opens the OAuth URL in the user's default browser. The URL is validated against an allowlist of Anthropic domains before being opened.

```javascript
const ALLOWED_AUTH_ORIGINS = [
  'https://claude.ai',
  'https://auth.anthropic.com',
  'https://accounts.anthropic.com',
  'https://console.anthropic.com',
];
```

**How this meets expectations**:
- Only Anthropic-owned domains can be opened through this handler
- Uses `execFile` (not `exec`) to prevent command injection
- The handler returns `{ success: true }` after opening the browser — it never receives or processes any token
- Even if a malicious script tried to abuse this IPC channel, it could only open Anthropic URLs

---

### 6. `redactForLogs` — Defense-in-Depth Log Sanitization

**File**: `stubs/@ant/claude-swift/js/index.js` (lines 54-74)

Even though our stubs don't handle tokens, trace logs could theoretically capture tokens from subprocess output. The `redactForLogs` function strips:

| Pattern | Example | Replacement |
|---------|---------|-------------|
| `Authorization: Bearer <token>` | HTTP headers | `[REDACTED]` |
| `"access_token": "<value>"` | JSON responses | `[REDACTED]` |
| `"refresh_token": "<value>"` | OAuth refresh | `[REDACTED]` |
| `"api_key": "<value>"` | API keys | `[REDACTED]` |
| `ANTHROPIC_API_KEY=<value>` | Env var leaks | `[REDACTED]` |
| `cookie: <value>` | Session cookies | `[REDACTED]` |

**How this meets expectations**:
- Even in the worst case (a subprocess accidentally printing a token to stdout), the token is stripped before it reaches log files
- Log files are written with `0o600` permissions (owner-only)

---

## Summary: What Our Code Never Does

| Action | Status | Enforcement |
|--------|--------|-------------|
| Store OAuth tokens | **Never** | `addApprovedOauthToken` is a documented no-op |
| Forward OAuth tokens to subprocesses | **Never** | `filterEnv` blocks credential env vars; SDK bridge uses allowlist |
| Intercept OAuth callbacks | **Never** | `AuthRequest.isAvailable()` returns `false`; no protocol handler registered |
| Process authentication credentials | **Never** | All auth handled by unmodified Anthropic code |
| Log tokens | **Never** | `redactForLogs` strips all credential patterns |
| Open non-Anthropic auth URLs | **Never** | `ALLOWED_AUTH_ORIGINS` allowlist enforced |

---

## What IS Modified vs. Unmodified

| Component | Modified? | Purpose |
|-----------|-----------|---------|
| `stubs/@ant/claude-swift/js/index.js` | **Our code** | VM emulation for Linux (process spawn, path translation) |
| `stubs/@ant/claude-native/index.js` | **Our code** | Platform shims (notifications, keyboard, etc.) |
| `cowork/sdk_bridge.js` | **Our code** | CLI bridge for SDK-mode sessions |
| `linux-loader.js` | **Our code** | Electron main process bootstrap + IPC handlers |
| `app/.vite/build/index.js` | **Anthropic's code** (3 one-line patches) | Platform gate bypass only |
| Claude Desktop renderer | **Unmodified** | Handles all OAuth, UI, API communication |
| Claude Code binary | **Unmodified** | Handles its own authentication |

---

## Verification

To verify these claims, audit the following specific locations:

```bash
# 1. Confirm addApprovedOauthToken is a no-op (token param named _token, never used)
grep -n 'addApprovedOauthToken' stubs/@ant/claude-swift/js/index.js

# 2. Confirm filterEnv blocks credential-like keys
grep -n 'BLOCKED_ENV_KEY_PATTERN' stubs/@ant/claude-swift/js/index.js

# 3. Confirm SDK bridge uses allowlist, not ...process.env
grep -n 'filterEnvForSubprocess\|process\.env' cowork/sdk_bridge.js

# 4. Confirm AuthRequest never handles callbacks
grep -n 'isAvailable\|callback\|token' stubs/@ant/claude-native/index.js

# 5. Confirm auth URL origin validation
grep -n 'ALLOWED_AUTH_ORIGINS' linux-loader.js

# 6. Confirm log redaction is active
grep -n 'redactForLogs' stubs/@ant/claude-swift/js/index.js
```
