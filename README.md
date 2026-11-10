# Folio

![Folio browsing a folder of pictures](docs/screenshot.png)

Folio is Omarchy's file manager: one window for finding, previewing and opening your files. It follows the Omarchy theme and language live, works from the keyboard, and never crawls your home folder in the background. Thumbnails are made when a tile needs one and shared with other apps through the standard `~/.cache/thumbnails` cache.

- **Home**: every folder in your home, with the standard ones and Dropbox drawn with their own icons; click the Home label to go home.
- **Views**: Recents (files you've used lately, in any app) and Trash.
- **Files**: right-click for open with, rename, duplicate, copy, cut, paste, compress, share (LocalSend or Taildrop) and delete to the trash. Copy and paste work with other apps, and nothing is ever overwritten.
- **Pinned**: any folder, pinned with Ctrl+D or by dragging it onto the sidebar. Pins are GTK's bookmarks, so they show up in file dialogs too.
- **Devices**: physical drives, whether plugged in or extra internal disks; the system's own partitions stay out of the way.
- **Tailnet**: the machines on your tailnet. Opening one mounts it over SFTP through GVfs and lands in the matching home folder.
- **Previews**: folders are quiet cards; photos, videos, PDFs and anything else with an installed thumbnailer show the real thing. Space opens a large preview, like Sushi or Quick Look: pictures at full size, video and audio playing, PDFs to scroll through, text and Markdown to read, with the arrows stepping through the folder. The details pane (Ctrl+I) shows a larger look, the facts, and the first lines of text files.
- **Show in folder**: Folio answers `org.freedesktop.FileManager1`, so other apps' "Show in folder" buttons open it with the file selected.

## Keyboard

| Key | Action |
| --- | --- |
| Arrow keys | Move the selection |
| Enter | Open |
| Backspace, Alt+Up | Go to the parent folder |
| Alt+Left / Alt+Right, mouse back / forward buttons | Back / forward (in the preview: previous / next file) |
| Alt+Home | Go home |
| Space | Preview the selected file (Space or Esc closes, ← → step through) |
| Ctrl+I | Show or hide the details pane |
| Ctrl+D | Pin or unpin the folder |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy, cut, paste files |
| Ctrl+Shift+C | Copy the path as text |
| F2 / Ctrl+Shift+D | Rename / duplicate |
| Ctrl+N | New window on this folder |
| Ctrl+Shift+N | New folder |
| Delete | Move to the trash |
| Tab | Switch between the sidebar and the files |
| Ctrl+L | Type a path: Enter goes there, Tab completes, Esc cancels |
| Ctrl+1 / Ctrl+2 / Ctrl+3 | Grid, list, or columns (in list and columns, → goes into a folder and ← back out) |
| S | Sort: name, kind, newest, oldest, size |
| Ctrl+H | Show hidden files |
| F5 | Reload |
| ? | Show every shortcut |
| Q | Quit |

## Build

```sh
bin/build     # build/folio
bin/test      # the Qt Test suite, offscreen
bin/install   # build the package and install it with makepkg -fsi
```

Run `build/folio [folder or file]` to try it. A file opens its folder with the file selected.

## License

MIT.
