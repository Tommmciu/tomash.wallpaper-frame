# Wallpaper Frame

Rounds all four desktop corners on every monitor. Configure its entry in
`~/.config/omarchy/shell.json`; saving applies changes without a shell restart.

```json
{
  "id": "tomash.wallpaper-frame",
  "radius": "auto",
  "includeGaps": true,
  "color": "bar",
  "corners": ["top-left", "top-right", "bottom-left", "bottom-right"],
  "followBar": true,
  "hideWhenTransparent": true,
  "hideWhenBarHidden": false
}
```

| Setting | Values / effect |
| --- | --- |
| `radius` | `"auto"` follows Hyprland rounding; a number such as `20` sets the final radius in logical pixels. `0` hides the frame. |
| `includeGaps` | With auto radius, add the outer window gap. Default `true`. |
| `color` | `"bar"` follows the bar's theme background; a hex color such as `"#000000"` overrides it. |
| `corners` | Keep the corner names you want; `[]` hides all corners. |
| `followBar` | `true` rounds the desktop area inside the bar's reserved edge, following bar moves, resizing and hiding. `false` uses the physical screen edges instead. |
| `hideWhenTransparent` | `true` hides the frame when the bar is transparent. Set `false` to retain it. |
| `hideWhenBarHidden` | `true` hides the frame with the bar; `false` keeps the desktop frame. |

The frame stays above the wallpaper and below application windows and the bar.
It does not intercept clicks or reserve screen space. With `followBar: false`,
the bar may cover masks on its own edge, since it is above the frame.

Theme colors and Hyprland gaps/rounding update live. A direct file watcher reads
bar transparency and frame settings after menu-bar gestures, CLI changes and
manual edits, avoiding the shell API's potentially stale bar-config snapshot.
The current shell API does not expose the bar's delayed visual transparency
transition, so synchronization follows the saved setting rather than its exact
animation frame.

Diagnostics:

```sh
omarchy-shell wallpaper-frame status
omarchy-shell wallpaper-frame refresh
```

After editing plugin QML code, use `omarchy restart shell` if Quickshell keeps a
cached component. Ordinary configuration changes do not require a restart.
