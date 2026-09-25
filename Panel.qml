import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Keycodes.js" as KC

// Visual keymap editor for the Corne v4. The board is drawn from the layout
// the firmware reports (Vial) or a built-in Corne v4 layout (plain VIA);
// clicking a key and then a keycode writes it to the keyboard immediately
// through bin/cornectl, which speaks the VIA raw-HID protocol.
Panel {
  id: root
  moduleName: "aimabe.corne-keymap"
  ipcTarget: "corne-keymap"

  // Last `cornectl dump`, or an error object ({ connected: false, error, hint }).
  property var board: null
  property var keymap: []          // per layer: { "row,col": code }
  property int activeLayer: 0          // layer shown and edited
  property int chosenLayer: 0          // last layer picked in the panel; shown while the board sits on its base layer
  property int selected: -1        // index into board.layout
  property int pickerTab: 0
  property bool loading: false
  property bool sessionDemo: false
  readonly property bool demo: sessionDemo || setting("demo", false) === true

  // Writes are queued so rapid clicks never race each other on the device.
  property var pendingWrites: []
  property bool backedUp: false
  property var undoStack: []
  property bool restoreArmed: false

  property string statusMessage: ""
  property string statusKind: "info"   // info | warn | error

  // Live key presses from `cornectl watch` (the Vial/VIA matrix tester).
  property var pressedKeys: ({})       // "row,col" -> true
  property bool boardLocked: false
  property var unlockKeys: []          // [[row, col], ...]
  property bool sawPress: false        // any press seen while "locked"? then the lock doesn't hide the matrix
  property bool unlocking: false
  property var unlockCounter: null
  // The board's own layer, replayed from the matrix (VIA can't report it).
  property var layerState: KC.newLayerState()
  property int boardLayer: 0
  property int unlockCounterStart: 0
  // The watcher shares the device with every other helper call; pause it
  // while they run so replies don't cross.
  readonly property bool helperBusy: dumpProc.running || setProc.running || backupProc.running
                                     || restoreProc.running || unlockProc.running
  readonly property bool wantWatch: opened && connected && !demo && !helperBusy

  readonly property color fg: root.bar ? root.bar.foreground : Color.popups.text
  readonly property color dim: Util.alpha(fg, 0.45)
  readonly property string uiFont: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return url.replace(/\/$/, "")
  }
  readonly property string helper: pluginDir + "/bin/cornectl"

  readonly property bool connected: !!(board && board.connected && board.layout)
  readonly property var layout: connected ? board.layout : []
  readonly property int layerCount: connected ? board.layers : 0
  readonly property var selectedKey: selected >= 0 && selected < layout.length ? layout[selected] : null
  readonly property int selectedCode: selectedKey ? codeAt(activeLayer, selectedKey) : -1
  readonly property var categories: KC.categories(Math.max(1, layerCount))

  // ------------------------------------------------------------- data

  function helperCommand(args) {
    return [root.helper].concat(root.demo ? ["--demo"] : []).concat(args)
  }

  function refresh() {
    if (dumpProc.running) return
    loading = true
    dumpProc.command = helperCommand(["dump"])
    dumpProc.running = true
  }

  function adoptDump(text) {
    loading = false
    var parsed
    try { parsed = JSON.parse(text) } catch (e) {
      parsed = { connected: false, error: "helper", message: "Helper failed", hint: "Run bin/cornectl dump in a terminal to see why." }
    }
    board = parsed
    keymap = parsed.keymap || []
    if (activeLayer >= layerCount) activeLayer = 0
    if (selected >= layout.length) selected = -1
  }

  function posKey(k) { return k.row + "," + k.col }

  function codeAt(l, k) {
    var m = keymap[l]
    if (!m) return 0
    var c = m[posKey(k)]
    return c === undefined ? 0 : c
  }

  // Keymap is a plain JS array; rebuild the touched layer so bindings update.
  function putLocal(l, k, code) {
    var next = keymap.slice()
    var copy = {}
    for (var p in next[l]) copy[p] = next[l][p]
    copy[posKey(k)] = code
    next[l] = copy
    keymap = next
  }

  function assign(code, keepHold) {
    if (!selectedKey) { setStatus("Pick a key on the board first.", "warn"); return }
    if (code < 0 || code > 0xFFFF) { setStatus("That isn't a keycode I understand.", "error"); return }
    var old = selectedCode
    // Picking a plain key onto a mod-tap/layer-tap keeps the hold action,
    // so home-row mods can have their letter swapped in one click.
    if (keepHold && code <= 0xFF) {
      var hold = KC.holdPart(old)
      if (hold.kind !== "none") code = KC.withHold(code, hold)
    }
    if (code === old) return
    write(activeLayer, selectedKey, code, old, true)
  }

  function write(l, k, code, old, recordUndo) {
    putLocal(l, k, code)
    if (recordUndo) {
      var stack = undoStack.slice()
      stack.push({ layer: l, key: k, code: old })
      if (stack.length > 100) stack.shift()
      undoStack = stack
    }
    var q = pendingWrites.slice()
    q.push([String(l), String(k.row), String(k.col), String(code)])
    pendingWrites = q
    flushWrites()
  }

  function flushWrites() {
    if (setProc.running || pendingWrites.length === 0) return
    var args = ["set"]
    if (!backedUp) args.push("--backup-first")
    for (var i = 0; i < pendingWrites.length; i++) args = args.concat(pendingWrites[i])
    pendingWrites = []
    setProc.command = helperCommand(args)
    setProc.running = true
  }

  function adoptSet(text) {
    var out
    try { out = JSON.parse(text) } catch (e) { out = { ok: false, message: "Helper failed" } }
    if (!out.ok) {
      setStatus((out.message || "Write failed") + (out.hint ? " — " + out.hint : ""), "error")
      refresh()   // re-read so the board shows what the keyboard really has
      return
    }
    if (out.backup) {
      backedUp = true
      setStatus("Saved a backup of the original keymap before the first change.", "info")
    }
    var rejected = out.rejected || []
    if (rejected.length > 0) {
      for (var i = 0; i < rejected.length; i++) {
        var r = rejected[i]
        putLocal(r.layer, { row: r.row, col: r.col }, r.actual)
      }
      var name = KC.label(rejected[0].wanted).name
      setStatus("The keyboard refused " + name + ". Vial blocks some keys (like QK_BOOT) until the board is unlocked in the Vial app.", "warn")
    }
    flushWrites()
  }

  function undo() {
    if (undoStack.length === 0) { setStatus("Nothing to undo.", "info"); return }
    var stack = undoStack.slice()
    var last = stack.pop()
    undoStack = stack
    write(last.layer, last.key, last.code, 0, false)
    viewLayer(last.layer)
    for (var i = 0; i < layout.length; i++)
      if (layout[i].row === last.key.row && layout[i].col === last.key.col) selected = i
    setStatus("Undid the last change.", "info")
  }

  function clearSelected() {
    assign(activeLayer === 0 ? 0x00 : 0x01, false)
  }

  function setHold(hold) {
    var tap = KC.tapPart(selectedCode)
    if (tap < 0) { setStatus("Hold actions need a plain tap key (a letter, Space, Enter…).", "warn"); return }
    assign(KC.withHold(tap, hold), false)
  }

  function applyCustom(text) {
    var code = KC.parse(text)
    if (code < 0) { setStatus("Couldn't parse \"" + text + "\". Try KC_A, MO(1), LT(2, KC_SPC), LCTL_T(KC_A) or 0x7C00.", "error"); return }
    assign(code, false)
  }

  function runBackup() {
    if (backupProc.running) return
    backupProc.command = helperCommand(["backup"])
    backupProc.running = true
  }

  function runRestore() {
    if (!restoreArmed) {
      restoreArmed = true
      setStatus("Click Restore again to write the latest backup back to the keyboard.", "warn")
      restoreDisarm.restart()
      return
    }
    restoreArmed = false
    restoreProc.command = helperCommand(["restore"])
    restoreProc.running = true
  }

  function syncWatch() {
    if (wantWatch && !watchProc.running) {
      watchProc.command = [root.helper, "watch"]
      watchProc.running = true
    } else if (!wantWatch && watchProc.running) {
      watchProc.running = false
    }
  }

  function adoptWatchLine(line) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (msg.event === "hello") {
      boardLocked = msg.locked
      unlockKeys = msg.unlockKeys || []
    } else if (msg.event === "keys") {
      var next = {}
      for (var i = 0; i < msg.pressed.length; i++) next[msg.pressed[i]] = true
      if (msg.pressed.length > 0) sawPress = true
      pressedKeys = next
      layerState = KC.pressKeys(layerState, keymap, msg.pressed, Date.now())
      followBoardLayer()
    }
  }

  function viewLayer(l) {
    activeLayer = l
    chosenLayer = l
  }

  // Show the layer the keyboard is on; back on its base layer, return to the
  // one picked in the panel.
  function followBoardLayer() {
    var now = Date.now()
    var top = Math.min(KC.topLayer(layerState, now), Math.max(0, layerCount - 1))
    if (KC.pendingHold(layerState, now)) holdTimer.restart()
    if (top === boardLayer) return
    boardLayer = top
    activeLayer = top === layerState.defaultLayer ? chosenLayer : top
  }

  function startUnlock() {
    if (unlockProc.running) return
    unlocking = true
    unlockCounter = null
    unlockCounterStart = 0
    unlockProc.command = [root.helper, "unlock"]
    unlockProc.running = true
  }

  function adoptUnlockLine(line) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (msg.event === "unlock") {
      if (msg.keys) unlockKeys = msg.keys
      unlockCounter = msg.counter
      if (msg.counter !== null && unlockCounterStart === 0) unlockCounterStart = msg.counter + 1
      return
    }
    unlocking = false
    if (msg.ok) {
      boardLocked = false
      setStatus("Unlocked. Key presses now light up the board until you unplug it.", "info")
    } else {
      setStatus((msg.message || "Unlock failed") + (msg.hint ? " " + msg.hint : ""), "error")
    }
  }

  function unlockKeyNames() {
    var names = []
    for (var i = 0; i < unlockKeys.length; i++)
      names.push(KC.label(codeAt(0, { row: unlockKeys[i][0], col: unlockKeys[i][1] })).tap)
    return names.join(" + ")
  }

  function isUnlockKey(k) {
    for (var i = 0; i < unlockKeys.length; i++)
      if (unlockKeys[i][0] === k.row && unlockKeys[i][1] === k.col) return true
    return false
  }

  function setStatus(message, kind) {
    statusMessage = message
    statusKind = kind || "info"
    if (message === "") statusTimer.stop()
    else statusTimer.restart()
  }

  // Spatial selection: the nearest key whose centre lies in the pressed
  // direction, weighting off-axis distance so rows and columns feel straight.
  function moveSelection(dx, dy) {
    if (layout.length === 0) return
    if (selected < 0) { selected = 0; return }
    var from = centre(layout[selected])
    var best = -1, bestScore = 1e9
    for (var i = 0; i < layout.length; i++) {
      if (i === selected) continue
      var c = centre(layout[i])
      var along = dx !== 0 ? (c.x - from.x) * dx : (c.y - from.y) * dy
      var across = dx !== 0 ? Math.abs(c.y - from.y) : Math.abs(c.x - from.x)
      if (along < 0.3) continue
      var score = along + across * 2.5
      if (score < bestScore) { bestScore = score; best = i }
    }
    if (best >= 0) selected = best
  }

  function centre(k) {
    return rotate(k.x + k.w / 2, k.y + k.h / 2, k)
  }

  function rotate(px, py, k) {
    if (!k.r) return { x: px, y: py }
    var a = k.r * Math.PI / 180
    var dx = px - k.rx, dy = py - k.ry
    return { x: k.rx + dx * Math.cos(a) - dy * Math.sin(a), y: k.ry + dx * Math.sin(a) + dy * Math.cos(a) }
  }

  // Bounding box of every (rotated) key corner, in key units.
  readonly property var bounds: {
    var b = { x0: 1e9, y0: 1e9, x1: -1e9, y1: -1e9 }
    for (var i = 0; i < layout.length; i++) {
      var k = layout[i]
      var corners = [[k.x, k.y], [k.x + k.w, k.y], [k.x, k.y + k.h], [k.x + k.w, k.y + k.h]]
      for (var j = 0; j < 4; j++) {
        var p = rotate(corners[j][0], corners[j][1], k)
        b.x0 = Math.min(b.x0, p.x); b.y0 = Math.min(b.y0, p.y)
        b.x1 = Math.max(b.x1, p.x); b.y1 = Math.max(b.y1, p.y)
      }
    }
    if (layout.length === 0) b = { x0: 0, y0: 0, x1: 1, y1: 1 }
    return b
  }

  onOpenedChanged: if (opened) refresh()
  onWantWatchChanged: syncWatch()
  onDemoChanged: { backedUp = false; undoStack = []; refresh() }

  Timer {
    id: statusTimer
    interval: 7000
    onTriggered: root.statusMessage = ""
  }

  Timer {
    id: restoreDisarm
    interval: 5000
    onTriggered: root.restoreArmed = false
  }

  // Poll only while open and waiting for a board to appear.
  Timer {
    interval: 3000
    repeat: true
    running: root.opened && !root.connected && !root.loading
    onTriggered: root.refresh()
  }

  // A held layer-tap switches layer after the tapping term with no matrix change.
  Timer {
    id: holdTimer
    interval: 210
    onTriggered: root.followBoardLayer()
  }

  // Restart the watcher if it dies (unplug, firmware hiccup) while wanted.
  Timer {
    interval: 1500
    repeat: true
    running: root.wantWatch && !watchProc.running
    onTriggered: root.syncWatch()
  }

  // ------------------------------------------------------------- processes

  Process {
    id: watchProc
    stdout: SplitParser {
      onRead: function(line) { root.adoptWatchLine(line) }
    }
    onRunningChanged: if (!running) root.pressedKeys = ({})
  }

  Process {
    id: unlockProc
    stdout: SplitParser {
      onRead: function(line) { root.adoptUnlockLine(line) }
    }
    onRunningChanged: if (!running) root.unlocking = false
  }

  Process {
    id: dumpProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.adoptDump(text)
    }
  }

  Process {
    id: setProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.adoptSet(text)
    }
  }

  Process {
    id: backupProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = {}
        try { out = JSON.parse(text) } catch (e) {}
        if (out.ok) root.setStatus("Backup saved: " + out.path.replace(Quickshell.env("HOME"), "~"), "info")
        else root.setStatus(out.message || "Backup failed.", "error")
      }
    }
  }

  Process {
    id: restoreProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = {}
        try { out = JSON.parse(text) } catch (e) {}
        if (out.ok) root.setStatus("Restored " + out.written + " keys from " + out.path.replace(/.*\//, ""), "info")
        else root.setStatus(out.message || "Restore failed.", "error")
        root.undoStack = []
        root.refresh()
      }
    }
  }

  // ------------------------------------------------------------- bar button

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌌"
    onPressed: function(b) { root.toggle() }
  }

  // ------------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(780))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: customField.activeFocus
      onMoveRequested: function(dx, dy) { root.moveSelection(dx, dy) }
      onActivateRequested: customField.forceActiveFocus()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onDeleteRequested: root.clearSelected()
      onTextKey: function(t) {
        if (/^[0-9]$/.test(t) && Number(t) < root.layerCount) root.viewLayer(Number(t))
        else if (t === "u") root.undo()
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: root.connected ? root.board.name : "Corne v4"
            meta: root.connected
              ? (root.board.vial ? "Vial" : "VIA") + " · " + root.layerCount + " layers · "
                + (root.board.layoutSource === "vial" ? "layout from firmware" : "built-in Corne v4 layout")
              : (root.loading ? "Looking for the keyboard…" : "Not connected")
            foreground: root.fg
            fontFamily: root.uiFont
            iconOpacity: root.connected ? 1.0 : 0.5
            iconComponent: Component {
              Text {
                text: "󰌌"
                color: root.fg
                font.family: root.uiFont
                font.pixelSize: Style.font.display
              }
            }
          }

          // ---------- Not connected ----------
          Column {
            width: parent.width
            spacing: Style.spacing.rowGap
            visible: !root.connected && !!root.board

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.fg
              font.family: root.uiFont
              font.pixelSize: Style.font.body
              text: root.board ? (root.board.message || "") : ""
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.dim
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              text: root.board ? (root.board.hint || "") : ""
            }
            Row {
              spacing: Style.spacing.sm
              ActionButton {
                visible: root.board && root.board.error === "permission"
                text: "Copy udev install command"
                onClicked: {
                  Quickshell.execDetached(["wl-copy", "sudo install -m644 " + root.pluginDir
                    + "/udev/50-corne-keymap.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw"])
                  root.setStatus("Copied. Paste it into a terminal, then replug the Corne.", "info")
                }
              }
              ActionButton { text: "Retry"; onClicked: root.refresh() }
              ActionButton { text: "Try demo mode"; onClicked: root.sessionDemo = true }
            }
          }

          // ---------- Layer tabs ----------
          Flow {
            width: parent.width
            spacing: Style.spacing.sm
            visible: root.connected

            Repeater {
              model: root.layerCount
              delegate: ActionButton {
                required property int index
                text: "Layer " + index
                selected: root.activeLayer === index
                onClicked: root.viewLayer(index)
              }
            }
          }

          // ---------- The board ----------
          Item {
            id: boardArea
            width: parent.width
            visible: root.connected
            readonly property real unit: Math.min(Style.space(50), width / Math.max(1, root.bounds.x1 - root.bounds.x0))
            readonly property real pad: Math.max(1, unit * 0.06)
            height: (root.bounds.y1 - root.bounds.y0) * unit

            Repeater {
              model: root.layout
              delegate: KeyCap {
                required property var modelData
                required property int index
                keyData: modelData
                keyIndex: index
                unit: boardArea.unit
                pad: boardArea.pad
              }
            }
          }

          // ---------- Unlock for live key presses ----------
          Row {
            width: parent.width
            spacing: Style.spacing.sm
            visible: root.connected && !root.demo && (root.unlocking || (root.boardLocked && !root.sawPress))

            Text {
              width: parent.width - (unlockButton.visible ? unlockButton.width + parent.spacing : 0)
              anchors.verticalCenter: parent.verticalCenter
              wrapMode: Text.WordWrap
              color: root.unlocking ? Color.accent : root.dim
              font.family: root.uiFont
              font.pixelSize: Style.font.caption
              text: root.unlocking
                ? "Hold " + root.unlockKeyNames() + " together until it unlocks"
                  + (root.unlockCounter !== null && root.unlockCounterStart > 0
                     ? " (" + Math.round(100 * (1 - root.unlockCounter / root.unlockCounterStart)) + "%)" : "…")
                : "Vial is locked, so key presses may not show. Unlock to see them (and to allow keys like QK_BOOT)."
            }
            ActionButton {
              id: unlockButton
              visible: !root.unlocking
              anchors.verticalCenter: parent.verticalCenter
              text: "Unlock"
              onClicked: root.startUnlock()
            }
          }

          // ---------- Selection details + hold actions ----------
          Column {
            width: parent.width
            spacing: Style.spacing.rowGap
            visible: root.connected

            Text {
              width: parent.width
              color: root.selectedKey ? root.fg : root.dim
              font.family: root.uiFont
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              text: root.selectedKey
                ? "Layer " + root.activeLayer + " · row " + root.selectedKey.row + ", col " + root.selectedKey.col
                  + "  →  " + KC.label(root.selectedCode).name
                : "Click a key to remap it. Arrows/hjkl move, 0–9 switch layer, x clears, u undoes, Enter types a keycode."
            }

            Flow {
              width: parent.width
              spacing: Style.spacing.sm
              visible: !!root.selectedKey
              readonly property var hold: KC.holdPart(root.selectedCode)
              readonly property bool canHold: KC.tapPart(root.selectedCode) >= 0

              Text {
                text: "Hold:"
                color: root.dim
                font.family: root.uiFont
                font.pixelSize: Style.font.caption
                height: Style.spacing.controlHeight
                verticalAlignment: Text.AlignVCenter
              }
              Repeater {
                model: {
                  var chips = [{ label: "Nothing", hold: { kind: "none", value: 0 } },
                               { label: "Ctrl", hold: { kind: "mod", value: 0x01 } },
                               { label: "Shift", hold: { kind: "mod", value: 0x02 } },
                               { label: "Alt", hold: { kind: "mod", value: 0x04 } },
                               { label: "Super", hold: { kind: "mod", value: 0x08 } },
                               { label: "AltGr", hold: { kind: "mod", value: 0x14 } }]
                  for (var l = 1; l < Math.min(root.layerCount, 16); l++)
                    chips.push({ label: "Layer " + l, hold: { kind: "layer", value: l } })
                  return chips
                }
                delegate: ActionButton {
                  required property var modelData
                  text: modelData.label
                  enabled: parent.canHold
                  selected: parent.canHold && parent.hold.kind === modelData.hold.kind && parent.hold.value === modelData.hold.value
                  onClicked: root.setHold(modelData.hold)
                }
              }
            }
          }

          // ---------- Keycode picker ----------
          Column {
            width: parent.width
            spacing: Style.spacing.rowGap
            visible: root.connected

            Flow {
              width: parent.width
              spacing: Style.spacing.sm
              Repeater {
                model: root.categories
                delegate: ActionButton {
                  required property var modelData
                  required property int index
                  text: modelData.name
                  selected: root.pickerTab === index
                  onClicked: root.pickerTab = index
                }
              }
            }

            Flow {
              width: parent.width
              spacing: Style.spacing.xs
              Repeater {
                model: root.categories[Math.min(root.pickerTab, root.categories.length - 1)].keys
                delegate: PickerKey {
                  required property var modelData
                  code: modelData
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.spacing.sm

              TextField {
                id: customField
                width: parent.width - applyButton.width - parent.spacing
                foreground: root.fg
                font.family: root.uiFont
                font.pixelSize: Style.font.bodySmall
                placeholderText: "Any keycode: KC_A, MO(1), LT(2, KC_SPC), LCTL_T(KC_A), C(KC_C), 0x7C00"
                onAccepted: { root.applyCustom(text); keyCatcher.forceActiveFocus() }
                Keys.onEscapePressed: keyCatcher.forceActiveFocus()
                Connections {
                  target: root
                  function onSelectedCodeChanged() {
                    if (!customField.activeFocus) customField.text = root.selectedKey ? KC.label(root.selectedCode).name : ""
                  }
                }
              }
              ActionButton {
                id: applyButton
                text: "Apply"
                anchors.verticalCenter: customField.verticalCenter
                onClicked: root.applyCustom(customField.text)
              }
            }
          }

          // ---------- Actions + status ----------
          Flow {
            width: parent.width
            spacing: Style.spacing.sm
            visible: root.connected

            ActionButton { text: "Undo"; enabled: root.undoStack.length > 0; onClicked: root.undo() }
            ActionButton { text: "Reload"; onClicked: root.refresh() }
            ActionButton { text: "Backup"; onClicked: root.runBackup() }
            ActionButton { text: root.restoreArmed ? "Confirm restore" : "Restore"; selected: root.restoreArmed; onClicked: root.runRestore() }
            ActionButton {
              visible: root.demo
              text: "Exit demo"
              enabled: root.sessionDemo
              tooltipText: root.sessionDemo ? "" : "Demo mode is on in the widget settings"
              onClicked: root.sessionDemo = false
            }
          }

          Text {
            width: parent.width
            visible: root.statusMessage !== ""
            wrapMode: Text.WordWrap
            color: root.statusKind === "error" ? Color.urgent : (root.statusKind === "warn" ? Color.accent : root.dim)
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
            text: root.statusMessage
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- components

  component ActionButton: Button {
    fontSize: Style.font.caption
    foreground: root.fg
    fontFamily: root.uiFont
    horizontalPadding: Style.spacing.sm
    verticalPadding: Style.spacing.controlPaddingY
    bordered: true
    opacity: enabled ? 1.0 : 0.4
  }

  // One key on the board, placed and rotated from its KLE geometry.
  component KeyCap: Rectangle {
    id: cap
    property var keyData
    property int keyIndex
    property real unit
    property real pad

    readonly property int code: root.codeAt(root.activeLayer, keyData)
    readonly property var legend: KC.label(code)
    readonly property bool isSelected: root.selected === keyIndex
    readonly property bool quiet: code === 0 || code === 1
    readonly property bool pressed: !!root.pressedKeys[root.posKey(keyData)]
    readonly property bool unlockHint: root.unlocking && root.isUnlockKey(keyData)

    x: (keyData.x - root.bounds.x0) * unit + pad
    y: (keyData.y - root.bounds.y0) * unit + pad
    width: keyData.w * unit - pad * 2
    height: keyData.h * unit - pad * 2
    radius: Math.max(Style.cornerRadius, unit * 0.12)
    color: pressed ? Util.alpha(Color.accent, 0.55)
         : isSelected ? Style.selectedFillFor(root.fg, Color.accent)
         : capMouse.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
         : Style.normalFillFor(root.fg, Color.accent)
    border.width: isSelected || pressed || unlockHint ? Math.max(1, Style.space(2)) : Style.normalBorderWidth
    border.color: isSelected || pressed || unlockHint ? Color.accent : Style.normalBorderFor(root.fg, Color.accent)
    // Fast in, slower out, so even a quick tap is visible.
    Behavior on color { ColorAnimation { duration: cap.pressed ? 40 : 180 } }

    transform: [
      Scale {
        origin.x: cap.width / 2
        origin.y: cap.height / 2
        xScale: cap.pressed ? 0.9 : 1.0
        yScale: xScale
        Behavior on xScale { NumberAnimation { duration: cap.pressed ? 40 : 140; easing.type: Easing.OutCubic } }
      },
      Rotation {
        origin.x: (cap.keyData.rx - cap.keyData.x) * cap.unit - cap.pad
        origin.y: (cap.keyData.ry - cap.keyData.y) * cap.unit - cap.pad
        angle: cap.keyData.r || 0
      }
    ]

    SequentialAnimation on opacity {
      running: cap.unlockHint
      loops: Animation.Infinite
      onRunningChanged: if (!running) cap.opacity = 1.0
      NumberAnimation { to: 0.45; duration: 500 }
      NumberAnimation { to: 1.0; duration: 500 }
    }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: cap.legend.hold ? -cap.height * 0.12 : 0
      width: parent.width - Style.space(4)
      horizontalAlignment: Text.AlignHCenter
      text: cap.legend.tap
      color: cap.quiet ? root.dim : root.fg
      font.family: root.uiFont
      font.pixelSize: Math.max(8, cap.unit * (text.length <= 2 ? 0.34 : text.length <= 4 ? 0.24 : 0.19))
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: 7
    }

    Text {
      visible: cap.legend.hold !== ""
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.max(1, cap.height * 0.08)
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width - Style.space(4)
      horizontalAlignment: Text.AlignHCenter
      text: cap.legend.hold
      color: Color.accent
      font.family: root.uiFont
      font.pixelSize: Math.max(7, cap.unit * 0.17)
      fontSizeMode: Text.HorizontalFit
      minimumPixelSize: 6
    }

    MouseArea {
      id: capMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.selected = cap.keyIndex
        keyCatcher.forceActiveFocus()
      }
    }
  }

  // A keycode tile in the picker.
  component PickerKey: Rectangle {
    id: pk
    property int code
    readonly property var legend: KC.label(code)
    readonly property bool current: root.selectedCode === code

    width: Math.max(Style.space(40), tapText.implicitWidth + Style.space(12))
    height: Style.space(34)
    radius: Style.cornerRadius
    color: current ? Style.selectedFillFor(root.fg, Color.accent)
         : pkMouse.containsMouse ? Style.hoverFillFor(root.fg, Color.accent)
         : Style.normalFillFor(root.fg, Color.accent)
    border.width: current ? Math.max(1, Style.space(2)) : Style.normalBorderWidth
    border.color: current ? Color.accent : Style.normalBorderFor(root.fg, Color.accent)
    opacity: root.selectedKey ? 1.0 : 0.55

    Text {
      id: tapText
      anchors.centerIn: parent
      anchors.verticalCenterOffset: pk.legend.hold ? -Style.space(5) : 0
      text: pk.code === 0 ? "None" : pk.legend.tap
      color: root.fg
      font.family: root.uiFont
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      visible: pk.legend.hold !== ""
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(2)
      text: pk.legend.hold
      color: Color.accent
      font.family: root.uiFont
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: pkMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.assign(pk.code, true)
    }

    PanelToolTip {
      visible: pkMouse.containsMouse
      text: pk.legend.name
    }
  }
}
