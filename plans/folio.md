# Folio: Omarchy's own file manager

## Why

Omarchy ships Nautilus, and Nautilus hard-depends on LocalSearch, GNOME's indexer. The first time someone opens the file manager, LocalSearch starts crawling all of `$HOME`, model weights and build trees included, and opens every file it can parse in-process. On 2026-11-10 that crashed `localsearch-extractor-3` (SIGSEGV in gupnp-dlna's audio profile guesser) on a voice memo Dropbox had just synced. On Hyprland it buys little: faster Nautilus search and full-text search, both of which Omarchy users rarely reach for.

Nautilus is also the one big GTK app in an otherwise Qt Quick and terminal desktop. It doesn't follow the Omarchy theme the way the shell and the Omarchy apps do, and its extension points (nautilus-python) are how Omarchy bolts on LocalSend and transcoding.

Folio replaces it with an app built the way Hype, Monologue, Omacut and Signed are: C++ and Qt Quick, one window, keyboard-first, following the theme and language live, installed as a package.

## Principles

- **Nothing in the background.** No indexer, no crawler, no daemon. Folders are listed when opened, thumbnails are made when a tile needs one.
- **Share with the desktop, don't duplicate it.** Thumbnails go in the freedesktop cache (`~/.cache/thumbnails`) using the installed thumbnailers. Remote and removable storage go through GVfs/GIO. Search by name uses the `plocate` database Omarchy already maintains.
- **Airy and quiet.** Design 1 ("Places") from the design canvas: sidebar, breadcrumbs, a roomy grid with real previews, a preview pane. Square corners unless Hyprland rounds windows; colors from the whole Omarchy palette.
- **Keyboard first, mouse friendly.** Every action has a key; `?` lists them.
- **Careful with data.** Never destroy without a way back: delete means trash, every file operation can be undone, conflicts are asked about, never silently overwritten.
- **Say what's wrong.** A failed mount, a missing thumbnailer or a permission error shows in the window.

## Where it stands (0.1.0, scaffold)

Done, tested (19 Qt Test cases), and verified offscreen:

- Folder model listing off the UI thread, folders first, natural sort, name or newest-first, hidden files toggle, live reload on change.
- Folder tiles as plain cards, selection shown as color on the item itself; file tiles with real thumbnails (in-process for common images, installed thumbnailers for video, PDF, HEIC, office files), drawn stand-ins otherwise.
- Shared thumbnail cache per the spec, with failure markers so broken files aren't retried.
- Three views, remembered between launches: grid (Ctrl+1), list with name, kind, size and date (Ctrl+2, Name and Modified headings sort), and Finder-style columns (Ctrl+3).
- Preview pane: large preview, the system's type name, size, modified, dimensions, opening lines of text files, Open.
- Sidebar: a Home section (its label goes home) listing every folder in home (XDG folders and Dropbox with their own glyphs, `omarchy` shown as Omarchy); Pinned folders (Ctrl+D or drag onto the sidebar) stored as GTK bookmarks; Dropbox (with `dropbox-cli` sync status), Trash, physical drives (removable and extra internal disks, not the system's own), online tailnet machines from `tailscale status --json`.
- Tailnet machines open over SFTP through GIO, landing in the matching home folder; GVfs's questions (host key on first connection, password) are asked in the window.
- Mouse back/forward buttons move through history (in the preview: previous/next file).
- Space opens a large preview in its own process (`folio preview`), like Sushi: pictures at full size with zoom, animated GIF/WebP, video and audio playing (Qt Multimedia's FFmpeg backend), PDFs scrolling (Qt PDF), text and rendered Markdown, folders with their pictures, and the largest cached thumbnail for anything else. Arrows step through the folder and the grid follows; a crash in the preview is reported in the Folio window. Ctrl+I toggles the details pane.
- `org.freedesktop.FileManager1` for "Show in folder"; `folio <file>` opens its folder with the file selected.
- Whole-palette theme following, Hyprland rounding, the Omarchy translator, `?` overlay.

## Phases

### 0. Foundations (from the Codex review, before file operations)

- Identify files by GIO URI rather than local path, so SFTP, MTP and Trash entries behave the same as local ones once operations exist.
- Design operation safety first: the queue, undo log and conflict handling in phase 1 build on it.
- Trash is a view over the freedesktop Trash spec (`files/` plus `info/`), not an ordinary folder.
- Run thumbnailers in a separate, resource-limited process, the way the preview already runs apart.
- Thumbnail cache fixes: validate `Thumb::URI` on a cache hit, version the failure directory (`fail/folio-<version>`), and don't record a missing thumbnailer as a failure.
- Responsiveness: summarize subfolders lazily (visible tiles first), and move `details()` off the UI thread.

### Previews, finishing the Sushi replacement

- Office documents: LibreOffice headless conversion to PDF, cached under `~/.cache/folio/previews`, thumbnail shown while it converts.
- Fonts: a sample sheet. Archives: the file list from `bsdtar -tf`.
- Syntax highlighting for code (KDE syntax-highlighting) and better Markdown spacing.
- PDF search (Ctrl+F) and text selection with copy.
- A window rule in Omarchy floating `folio-preview`, the way `org.gnome.NautilusPreviewer` floats today.

### 1. File operations (makes it usable as a daily driver)

- Select many: Shift/Ctrl+click, Shift+arrows, Ctrl+A, rubber-band selection.
- Copy, cut, paste through the Wayland clipboard as `text/uri-list` plus `x-special/gnome-copied-files`, so pasting between Folio and other apps works both ways.
- Rename in place (F2), new folder (Ctrl+Shift+N), trash (Delete) per the freedesktop Trash spec, restore and empty in Trash, permanent delete only from Trash and only after asking.
- An operation queue in C++ on a worker thread: progress in the status bar, cancel, and a conflict prompt (replace, keep both, skip, apply to all).
- Undo and redo (Ctrl+Z / Ctrl+Shift+Z) for rename, move, copy, trash and new folder.
- Drag and drop within Folio and with other apps (`text/uri-list`), move by default on the same filesystem, copy across.
- Open with…: list apps from the MIME database's desktop entries, remember nothing beyond what `xdg-mime` already stores.

### 2. Finding things

- Type-to-filter in the current folder (instant, no index).
- Search everywhere by name with `plocate`, scoped to the current folder and below, with a live fallback walk for folders `updatedb` doesn't cover (new files, mounts).
- No full-text search. If it's ever wanted, it runs on demand (`rg` under the current folder), never as an index.
- Path entry (Ctrl+L) with completion.

### 3. Actions menu

- `:` opens the actions menu from design 3, filtered as you type: Compress, Extract, Copy path, Open terminal here, Open with…, Send with LocalSend, Transcode, Set as background, Send to a tailnet machine (Taildrop).
- These replace Omarchy's nautilus-python extensions (`localsend.py`, `transcode.py`) by calling the same commands (`localsend`, `omarchy-transcode` through `omarchy-launch-floating-terminal-with-presentation`).
- Actions are plain data (label, MIME filter, command) so Omarchy can add its own without code changes, from a directory under `$OMARCHY_PATH` and one under `~/.config/folio`.

### 4. Remote and removable storage

- Tailnet machines' first-connection host key question is accepted automatically (Tailscale already authenticated the peer); other servers are asked, and GVfs shows their fingerprint as "???", so show the real one (from `ssh-keyscan`) next to the question.
- Unmount and eject (removable drives, SFTP mounts) from the sidebar.
- Taildrive shares listed under their machine once the tailnet's ACLs grant `drive:share`/`drive:access`; mounted as WebDAV through GVfs.
- SMB/NFS/MTP keep working through the GVfs backends Omarchy already installs (`gvfs-smb`, `gvfs-nfs`, `gvfs-mtp`); MTP phones appear under Devices.

### 5. Agents and scripts

- `folio list|info|thumbnail|trash|restore` with `--json`, no display needed, exit 0/1, errors on stderr, following Hype's `src/cli.cpp`.
- `folio skill install` installs a short agent skill bundled in the binary.

### 6. Shipping in Omarchy

- Repository `omacom/folio`, tagged releases, package in `omacom/omarchy-pkgs` under `pkgbuilds/folio/` with an upstream watch.
- `install/omarchy-base.packages`: add `folio`; drop `nautilus`, `nautilus-python` and `sushi` once the previews phase is done (`folio preview` covers Sushi's job). Keep the `gvfs-*` backends.
- Rename `bin/omarchy-launch-nautilus` and `-cwd` to `omarchy-launch-file-manager` and `-cwd`, keeping the old names as wrappers for a release; update the Super+Shift+F bindings, `omarchy-theme-bg-install`, `omarchy-install-gaming-retroarch`, the menu example, and the `omarchy dock` example.
- Make Folio the default for `inode/directory` in Omarchy's mimeapps defaults.
- Window rules: replace `org.gnome.Nautilus` and `org.gnome.NautilusPreviewer` with `folio` where a rule should still apply (transparency, floating).
- Dropbox: `omarchy-install-service-dropbox` stops adding `nautilus-dropbox`; Folio shows sync status itself.
- `install/config/theme-system.sh` links Nautilus action icons; drop it with the extensions.
- A migration for existing installs: install Folio, set the default, and offer (not force) removing Nautilus, since some people will want to keep it.
- Until Folio ships, mask LocalSearch for every user (`/etc/systemd/user/localsearch-3.service` → `/dev/null` from `omarchy-settings`, plus a migration), so Nautilus stops crawling home folders now.

### 7. Polish that's part of done

- Translations for all 50 Omarchy languages, `.desktop` `Name[...]`/`Comment[...]` included; check long words in Danish and German, and right-to-left in Arabic.
- Screen-reader names on every control; full keyboard reach of the sidebar (Ctrl+F6 cycles panes).
- Large-folder performance: 50,000 entries listing in under a second locally, thumbnails never blocking scrolling, SFTP folders listing progressively.
- Real audio waveforms or embedded cover art instead of the decorative stand-in; video durations from `ffprobe` on the preview pane.

## Open questions

- **Name.** "Folio" is a working name.
- **File chooser.** Open/save dialogs in other apps come from `xdg-desktop-portal-gtk`, not Nautilus, so they keep working. Should Folio later provide the portal's FileChooser so dialogs look and behave like Folio?
- **Nautilus as an option.** Offer `omarchy-install-nautilus` for people who want it back (with LocalSearch masked)?
- **Trash across drives.** The spec's per-volume `.Trash-$uid` directories: support from phase 1, or home trash only at first?
- **Thumbnail sizes on HiDPI.** Request `x-large` (512) on scaled outputs, or keep `large` and accept softer tiles?
