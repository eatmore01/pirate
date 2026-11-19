# Pirate

Build and run: `./build.sh && open dist/Pirate.app`

Config: `~/.config/pirate/config.yml`

- `cmd + d` - delete
- `cmd + a` - create 
- `cmd + r` - rename

### `app:` accepts a Finder name (`VLC`), a bundle id (`org.videolan.vlc`), or a path to the `.app` (or a binary inside one).

```yml
show_hidden_files: false
view_mode: grid # list
icon_scale: 1.05e+0
ask_before_quit: true
file_type_associations:
- type: mp3
  app: VLC
- type: mp4
  app: VLC
- type: wav
  app: VLC
- type: avi
  app: VLC
- type: mkv
  app: VLC
- type: mov
  app: VLC
- type: flac
  app: VLC
- type: m4a
  app: VLC
```