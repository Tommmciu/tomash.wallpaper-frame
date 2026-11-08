import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: root

  // Rounding and outer gap now come from the shell's central Style singleton
  // (which polls hyprctl ONCE, shared across the whole shell) instead of a
  // second, private hyprctl poll running inside this plugin. Killing that
  // duplicate keeps one source of truth for Hyprland values.
  readonly property int rounding: Style.cornerRadius
  // Style.gapsOut is HALF of Hyprland's general:gaps_out (the shell halves it
  // for panels/notifications). The frame's corner must span the FULL gap plus
  // the rounding radius to mask the wallpaper between the rounded window
  // corner and the screen edge, so we double it back.
  readonly property int gap: Style.gapsOut * 2
  readonly property int radius: settings.radius !== undefined && settings.radius !== "auto"
    && isFinite(Number(settings.radius))
    ? Math.max(0, Math.round(Number(settings.radius)))
    : rounding + (settings.includeGaps !== false ? gap : 0)
  readonly property color frameColor: settings.color && settings.color !== "bar"
    ? settings.color : Color.bar.background

  // Third-party shell.bar exposes position/size/visibility, but not live
  // transparency. shell.barConfig is a snapshot, so watch the source file
  // directly for reliable updates after bar gestures and CLI changes.
  property var shell: null
  property var settings: ({})
  property var configuredBar: ({})
  // The bar's background look: opaque (solid), glassy (see-through, blurred
  // behind), or none (fully invisible). The live bar exposes transparent +
  // glassy bools; the config snapshot stores background as a string. This is a
  // three-way distinction because glassy is a real third state that reads as
  // transparent === false — the old boolean could not tell opaque from glassy.
  readonly property string barLook: shell && shell.bar && ("transparent" in shell.bar)
    ? (shell.bar.transparent === true ? "none"
       : shell.bar.glassy === true ? "glassy"
       : "opaque")
    : (configuredBar.background === "none" ? "none"
       : configuredBar.background === "glassy" ? "glassy"
       : "opaque")
  readonly property bool barHidden: !!(shell && shell.bar && shell.bar.barHidden)
  readonly property string barPosition: shell && shell.bar ? shell.bar.position : (configuredBar.position || "top")
  // Only show the rounded corner masks when the bar is a solid opaque strip.
  // Hidden when the bar is glassy (translucent over a blurred background — the
  // masks would collide with the bar edge) or none (invisible, nothing to
  // follow). keep hideWhenTransparent for explicit opt-out of the none case.
  readonly property bool frameHidden: settings.enabled === false
    || barLook !== "opaque"
    || (settings.hideWhenBarHidden === true && barHidden)
  readonly property var corners: Array.isArray(settings.corners)
    ? settings.corners : ["top-left", "top-right", "bottom-left", "bottom-right"]

  function loadConfig(raw) {
    try {
      var config = JSON.parse(raw)
      var entries = Array.isArray(config.plugins) ? config.plugins : []
      var next = {}
      for (var i = 0; i < entries.length; ++i) {
        if (entries[i].id === "tomash.wallpaper-frame") {
          next = entries[i]
          break
        }
      }
      configuredBar = config.bar || {}
      settings = next
    } catch (error) {
      console.warn("wallpaper-frame: keeping previous settings; invalid shell.json: " + error)
    }
  }

  FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onLoaded: root.loadConfig(text())
    onFileChanged: configReload.restart()
  }
  Timer {
    id: configReload
    interval: 40
    onTriggered: configFile.reload()
  }

  // Live Hyprland edits to rounding/gaps are picked up by nudging the central
  // Style singleton: the shell only re-polls Style on theme apply, so a plain
  // `configreloaded` would otherwise leave these values stale until the next
  // theme switch or shell restart. Style re-runs hyprctl and its cornerRadius /
  // gapsOut property changes propagate into the bindings above automatically.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") Style.scheduleRefresh()
    }
  }

  IpcHandler {
    target: "wallpaper-frame"
    function refresh(): void {
      Style.scheduleRefresh()
      configFile.reload()
    }
    function status(): string {
      return JSON.stringify({
        barLook: root.barLook,
        transparent: root.barLook === "none",
        glassy: root.barLook === "glassy",
        configuredTransparent: root.configuredBar.transparent === true,
        configuredBackground: root.configuredBar.background || "opaque",
        hasLiveTransparency: !!(root.shell && root.shell.bar && ("transparent" in root.shell.bar)),
        hidden: root.frameHidden,
        barPosition: root.barPosition,
        barHidden: root.barHidden,
        followBar: root.settings.followBar !== false,
        corners: root.corners,
        color: String(root.frameColor),
        radius: root.radius
      })
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      property int cornerRadius: root.radius
      property color cornerColor: root.frameColor

      screen: modelData
      visible: !root.frameHidden && root.radius > 0 && !remapGuard.remapping
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      // Normal respects the bar's reserved edge without reserving space itself.
      // Ignore instead places the masks at the physical display corners.
      exclusionMode: root.settings.followBar !== false ? ExclusionMode.Normal : ExclusionMode.Ignore
      exclusiveZone: 0
      WlrLayershell.namespace: "omarchy-wallpaper-frame"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }

      Repeater {
        model: 4
        Shape {
          id: cornerShape
          required property int index
          readonly property bool isRight: index % 2 === 1
          readonly property bool isBottom: index >= 2
          readonly property string cornerName: (isBottom ? "bottom-" : "top-") + (isRight ? "right" : "left")
          visible: root.corners.indexOf(cornerName) !== -1
          width: panel.cornerRadius
          height: panel.cornerRadius
          x: isRight ? panel.width - panel.cornerRadius : 0
          y: isBottom ? panel.height - panel.cornerRadius : 0
          rotation: isBottom ? (isRight ? 180 : 270) : (isRight ? 90 : 0)
          preferredRendererType: Shape.CurveRenderer
          layer.enabled: true
          layer.smooth: true
          ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: panel.cornerColor
            startX: 0
            startY: 0
            PathAngleArc {
              moveToStart: false
              centerX: panel.cornerRadius
              centerY: panel.cornerRadius
              radiusX: panel.cornerRadius
              radiusY: panel.cornerRadius
              startAngle: 180
              sweepAngle: 90
            }
            PathLine { x: 0; y: 0 }
          }
        }
      }
    }
  }
}
