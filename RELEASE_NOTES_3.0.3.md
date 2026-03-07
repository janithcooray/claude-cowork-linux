<div align="center">

# v3.0.3 &mdash; Cross-Distro Polish &amp; Stub Hardening

**2026-03-07**

</div>

---

> [!NOTE]
> This is a quality release: no breaking changes. All improvements are backwards-compatible
> and require only running `./install.sh` to apply.

---

## What Changed

<table>
<thead>
<tr>
<th>Area</th>
<th>Change</th>
<th>Why</th>
</tr>
</thead>
<tbody>
<tr>
<td><strong>Binary&nbsp;resolution</strong></td>
<td>Added <abbr title="Linuxbrew system and user paths, mise shims, asdf shims">Linuxbrew, mise, asdf</abbr> candidates to both the Swift stub and <code>sdk_bridge.js</code></td>
<td>Users managing Node.js via version managers had the CLI silently not found</td>
</tr>
<tr>
<td><strong>openSUSE&nbsp;install</strong></td>
<td><code>zypper</code> now installs <code>7zip</code> + <code>nodejs-default</code> (not <code>p7zip</code> / <code>nodejs</code>)</td>
<td>Correct package names for openSUSE &mdash; old names caused install failure</td>
</tr>
<tr>
<td><strong>7z&nbsp;exit&nbsp;codes</strong></td>
<td>Exit code 2 (&ldquo;Dangerous link path&rdquo;) treated as non-fatal warning, not an error</td>
<td>macOS DMGs include an <code>/Applications</code> symlink; 7z flags it as dangerous on Linux but extraction succeeds &mdash; see <a href="https://github.com/johnzfitch/claude-cowork-linux/issues/35">#35</a></td>
</tr>
<tr>
<td><strong>i18n&nbsp;validation</strong></td>
<td>Pre-creates <code>resources/i18n/</code> before moving JSON files; warns if empty after extraction</td>
<td>Edge-case extraction orders left the dir missing, causing <code>ENOENT</code> on startup &mdash; see <a href="https://github.com/johnzfitch/claude-cowork-linux/issues/33">#33</a></td>
</tr>
<tr>
<td><strong>App&nbsp;icon</strong></td>
<td><code>setup_icon()</code> extracts <abbr title="128&times;128, 256&times;256, 512&times;512, 1024&times;1024">PNG chunks</abbr> from <code>electron.icns</code> into the hicolor icon theme; <code>.desktop</code> file uses theme name <code>claude</code> instead of a raw <code>.icns</code> path</td>
<td>Most launchers and taskbars don&rsquo;t render <code>.icns</code> files; the app appeared without an icon on KDE and Hyprland</td>
</tr>
<tr>
<td><strong>Terminal&nbsp;detach</strong></td>
<td><code>claude-desktop</code> launcher now uses <code>nohup</code> + <code>disown</code></td>
<td>Closing the terminal that launched Claude killed the app; now the process survives independently</td>
</tr>
<tr>
<td><strong>Hardcoded&nbsp;path&nbsp;removed</strong></td>
<td><code>sdk_bridge.js</code> <code>HOME</code> fallback changed from <code>"/home/zack"</code> to <code>os.homedir()</code></td>
<td>Developer artifact that silently broke binary resolution for everyone else</td>
</tr>
<tr>
<td><strong>Swift&nbsp;stub&nbsp;methods</strong></td>
<td>Added <code>quickAccess.overlay</code>, <code>quickAccess.dictation</code>, and <code>api.setCredentials()</code> stubs</td>
<td>Newer asar builds call these methods; missing stubs caused <code>TypeError: ... is not a function</code> on session start &mdash; see <a href="https://github.com/johnzfitch/claude-cowork-linux/issues/34">#34</a></td>
</tr>
<tr>
<td><strong>Dead&nbsp;code&nbsp;removed</strong></td>
<td>Dropped the non-functional <code>BrowserWindow</code> subclass patch from <code>frame-fix-wrapper.js</code></td>
<td><code>BrowserWindow</code> is non-writable on Electron&rsquo;s module export; the subclass swap never fired. Menu-bar hiding via <code>setApplicationMenu</code> interception is the path that actually works and is kept.</td>
</tr>
<tr>
<td><strong>Script&nbsp;renames</strong></td>
<td><code>test-launch.sh</code> &rarr; <code>launch.sh</code>, <code>test-launch-devtools.sh</code> &rarr; <code>launch-devtools.sh</code>, <code>test-flow.sh</code> &rarr; <code>validate.sh</code>, <code>patches/enable-cowork.py</code> &rarr; <code>enable-cowork.py</code>, <code>tools/fetch-dmg.py</code> &rarr; <code>fetch-dmg.py</code></td>
<td>The <code>test-</code> prefix implied these were temporary; they&rsquo;re stable tooling. Helper scripts moved to root for discoverability.</td>
</tr>
</tbody>
</table>

---

## Compatibility

| Distro | Desktop | Status |
|:-------|:--------|:-------|
| **Arch Linux** | Hyprland / KDE / GNOME | Tested &amp; Expected |
| **Ubuntu 22.04+** | GNOME / X11 | Expected |
| **Fedora 39+** | GNOME / KDE | Expected |
| **Debian 12+** | Any | Expected |
| **openSUSE** | Any | Expected (package names corrected this release) |
| **NixOS** | Any | Untested |

<details>
<summary><strong>Known caveats</strong></summary>

- GNOME Wayland: no global shortcuts (<abbr title="xdg-desktop-portal-gnome has not implemented the GlobalShortcuts portal">upstream limitation</abbr>) &mdash; set a custom shortcut in GNOME Settings instead.
- Without a <abbr title="e.g. gnome-keyring, KeePassXC, KDE Wallet">SecretService provider</abbr>, credentials fall back to <code>--password-store=basic</code> (stored on disk).
- The <code>/sessions</code> root symlink requires <code>sudo</code> once during install.

</details>

---

## Binary Resolution Order

The stub now checks these paths in order:

<dl>
<dt><code>$CLAUDE_CODE_PATH</code></dt>
<dd>Explicit override &mdash; set this to bypass all auto-detection.</dd>
<dt><kbd>~/.config/Claude/claude-code-vm/{version}/claude</kbd></dt>
<dd>Downloaded by Claude Desktop automatically.</dd>
<dt><kbd>~/.local/bin/claude</kbd> / <kbd>~/.npm-global/bin/claude</kbd></dt>
<dd>Standard npm/bun global install locations.</dd>
<dt><kbd>/usr/local/bin/claude</kbd> / <kbd>/usr/bin/claude</kbd></dt>
<dd>System-wide installs.</dd>
<dt><kbd>/home/linuxbrew/.linuxbrew/bin/claude</kbd> / <kbd>~/.linuxbrew/bin/claude</kbd></dt>
<dd><strong>New in v3.0.3.</strong> Linuxbrew system and user installs.</dd>
<dt><kbd>~/.local/share/mise/shims/claude</kbd> / <kbd>~/.asdf/shims/claude</kbd></dt>
<dd><strong>New in v3.0.3.</strong> Version manager shims (mise, asdf).</dd>
</dl>

---

## Install / Upgrade

<dl>
<dt><kbd>install.sh</kbd> (recommended)</dt>
<dd>

```bash
# Fresh install
git clone https://github.com/johnzfitch/claude-cowork-linux.git
cd claude-cowork-linux && ./install.sh

# Upgrade
cd ~/.local/share/claude-desktop && git pull && ./install.sh
```

</dd>
<dt><kbd>AUR</kbd> (Arch Linux)</dt>
<dd>

```bash
yay -S claude-cowork-linux
```

</dd>
<dt><kbd>curl</kbd> pipe</dt>
<dd>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/johnzfitch/claude-cowork-linux/master/install.sh)
```

</dd>
</dl>

After upgrading, run preflight to confirm everything is healthy:

```bash
claude-desktop --doctor
```

---

## Commits since v3.0.2

| Commit | Summary |
|:-------|:--------|
| `aa87b26` | refactor(frame-fix): remove non-functional BrowserWindow patch |
| `8be7071` | revert: remove update.sh &mdash; out of scope, security concern |
| `9e2a41b` | feat: icon fix, terminal detach, update script |
| `603fc9c` | docs: add alpham8 as contributor |
| `54e826c` | chore: delete internal PR automation script |
| `73e13ea` | Merge pull request #36 |
| `62719dc` | fix: harden stubs and cross-distro compatibility (review round 2) |
| `113ab91` | fix: address issues #28, #33, #34, #35 and incorporate PR #32 improvements |
| `4449da3` | docs: remove Max plan requirement from README |
| `832a1a8` | docs: update README with accurate v3.0.2 details |

---

## Contributors

Thanks to everyone whose work landed in this release:

- **[@alpham8](https://github.com/alpham8)** &mdash; openSUSE package name fixes, binary resolution paths for Linuxbrew/mise/asdf, Swift stub method stubs ([PR&nbsp;#32](https://github.com/johnzfitch/claude-cowork-linux/pull/32), [#36](https://github.com/johnzfitch/claude-cowork-linux/pull/36))

---

<div align="center">

**[Full diff](https://github.com/johnzfitch/claude-cowork-linux/compare/v3.0.2...v3.0.3)** &middot; **[README](https://github.com/johnzfitch/claude-cowork-linux#readme)** &middot; **[Issues](https://github.com/johnzfitch/claude-cowork-linux/issues)**

MIT License &mdash; See [LICENSE](LICENSE) for details.

</div>
