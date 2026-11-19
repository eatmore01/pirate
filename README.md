# Pirate

Build and run: `./build.sh && open dist/Pirate.app`

Config: `~/.config/pirate/config.yml`

- cmd + a - create 
- cmd + r - rename

`app:` accepts a Finder name (`VLC`), a bundle id (`org.videolan.vlc`), or a path to the `.app` (or a binary inside one).

```yml
show_hidden_files: false
view_mode: grid # list
icon_scale: 9e-1
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
```