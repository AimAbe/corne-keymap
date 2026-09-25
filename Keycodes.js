.pragma library

// QMK keycodes as the VIA/Vial protocol carries them (16-bit, the post-0.19
// numbering that VIA protocol 12+ and current Vial firmware use).
//
// label(code)  -> { tap, hold, name } for drawing a key cap
// parse(text)  -> code, or -1 — accepts KC_A, A, MO(1), LT(2,KC_SPC),
//                 LCTL_T(KC_A), C(KC_C), 0x1234 ...

var BASIC = {}      // code -> short cap label
var NAMES = {}      // code -> canonical QMK name
var BY_NAME = {}    // NAME (upper, with and without KC_) -> code

function def(code, name, cap) {
  NAMES[code] = name
  BASIC[code] = cap || name.replace(/^KC_/, "")
  BY_NAME[name.toUpperCase()] = code
  BY_NAME[name.toUpperCase().replace(/^KC_/, "")] = code
}

function alias(name, code) {
  BY_NAME[name.toUpperCase()] = code
  BY_NAME[name.toUpperCase().replace(/^KC_/, "")] = code
}

def(0x00, "KC_NO", "")
def(0x01, "KC_TRNS", "▽")
alias("_______", 0x01); alias("XXXXXXX", 0x00); alias("KC_TRANSPARENT", 0x01)
for (var i = 0; i < 26; i++) def(0x04 + i, "KC_" + String.fromCharCode(65 + i))
for (var n = 1; n <= 9; n++) def(0x1D + n, "KC_" + n)
def(0x27, "KC_0")
def(0x28, "KC_ENT", "Enter"); alias("KC_ENTER", 0x28)
def(0x29, "KC_ESC", "Esc")
def(0x2A, "KC_BSPC", "⌫")
def(0x2B, "KC_TAB", "Tab")
def(0x2C, "KC_SPC", "Space"); alias("KC_SPACE", 0x2C)
def(0x2D, "KC_MINS", "-")
def(0x2E, "KC_EQL", "=")
def(0x2F, "KC_LBRC", "[")
def(0x30, "KC_RBRC", "]")
def(0x31, "KC_BSLS", "\\")
def(0x32, "KC_NUHS", "#")
def(0x33, "KC_SCLN", ";")
def(0x34, "KC_QUOT", "'")
def(0x35, "KC_GRV", "`")
def(0x36, "KC_COMM", ",")
def(0x37, "KC_DOT", ".")
def(0x38, "KC_SLSH", "/")
def(0x39, "KC_CAPS", "Caps")
for (var f = 1; f <= 12; f++) def(0x39 + f, "KC_F" + f)
def(0x46, "KC_PSCR", "PrtSc")
def(0x47, "KC_SCRL", "ScrLk")
def(0x48, "KC_PAUS", "Pause")
def(0x49, "KC_INS", "Ins")
def(0x4A, "KC_HOME", "Home")
def(0x4B, "KC_PGUP", "PgUp")
def(0x4C, "KC_DEL", "Del")
def(0x4D, "KC_END", "End")
def(0x4E, "KC_PGDN", "PgDn")
def(0x4F, "KC_RGHT", "→"); alias("KC_RIGHT", 0x4F)
def(0x50, "KC_LEFT", "←")
def(0x51, "KC_DOWN", "↓")
def(0x52, "KC_UP", "↑")
def(0x53, "KC_NUM", "NumLk")
def(0x54, "KC_PSLS", "N/")
def(0x55, "KC_PAST", "N*")
def(0x56, "KC_PMNS", "N-")
def(0x57, "KC_PPLS", "N+")
def(0x58, "KC_PENT", "NEnt")
for (var p = 1; p <= 9; p++) def(0x58 + p, "KC_P" + p, "N" + p)
def(0x62, "KC_P0", "N0")
def(0x63, "KC_PDOT", "N.")
def(0x64, "KC_NUBS", "NUBS")
def(0x65, "KC_APP", "Menu")
for (var g = 13; g <= 24; g++) def(0x5B + g, "KC_F" + g)
def(0xA5, "KC_PWR", "Power")
def(0xA6, "KC_SLEP", "Sleep")
def(0xA8, "KC_MUTE", "Mute")
def(0xA9, "KC_VOLU", "Vol+")
def(0xAA, "KC_VOLD", "Vol-")
def(0xAB, "KC_MNXT", "Next")
def(0xAC, "KC_MPRV", "Prev")
def(0xAD, "KC_MSTP", "Stop")
def(0xAE, "KC_MPLY", "Play")
def(0xB2, "KC_CALC", "Calc")
def(0xB6, "KC_WBAK", "Back")
def(0xB7, "KC_WFWD", "Fwd")
def(0xBD, "KC_BRIU", "Bri+")
def(0xBE, "KC_BRID", "Bri-")
def(0xCD, "KC_MS_U", "M↑")
def(0xCE, "KC_MS_D", "M↓")
def(0xCF, "KC_MS_L", "M←")
def(0xD0, "KC_MS_R", "M→")
def(0xD1, "KC_BTN1", "Click1")
def(0xD2, "KC_BTN2", "Click2")
def(0xD3, "KC_BTN3", "Click3")
def(0xD9, "KC_WH_U", "Wh↑")
def(0xDA, "KC_WH_D", "Wh↓")
def(0xDB, "KC_WH_L", "Wh←")
def(0xDC, "KC_WH_R", "Wh→")
def(0xE0, "KC_LCTL", "Ctrl")
def(0xE1, "KC_LSFT", "Shift")
def(0xE2, "KC_LALT", "Alt")
def(0xE3, "KC_LGUI", "Super")
def(0xE4, "KC_RCTL", "RCtrl")
def(0xE5, "KC_RSFT", "RShift")
def(0xE6, "KC_RALT", "AltGr")
def(0xE7, "KC_RGUI", "RSuper")

// Quantum keycodes that aren't parameterised.
var SPECIAL = {
  0x7C00: ["QK_BOOT", "Boot"],
  0x7C01: ["QK_RBT", "Reboot"],
  0x7C03: ["EE_CLR", "EEClr"],
  0x7C73: ["CW_TOGG", "CapsWd"],
  // Tri-layer: hold Lower → layer 1, Upper → layer 2, both → layer 3 (QMK defaults).
  0x7C77: ["TL_LOWR", "Lower"],
  0x7C78: ["TL_UPPR", "Upper"],
  0x7820: ["RGB_TOG", "RGB"],
  0x7821: ["RGB_MOD", "RGB→"],
  0x7822: ["RGB_RMOD", "RGB←"],
  0x7823: ["RGB_HUI", "Hue+"],
  0x7824: ["RGB_HUD", "Hue-"],
  0x7825: ["RGB_SAI", "Sat+"],
  0x7826: ["RGB_SAD", "Sat-"],
  0x7827: ["RGB_VAI", "Bri+"],
  0x7828: ["RGB_VAD", "Bri-"]
}
for (var sc in SPECIAL) {
  NAMES[sc] = SPECIAL[sc][0]
  BY_NAME[SPECIAL[sc][0]] = Number(sc)
}
alias("QK_BOOTLOADER", 0x7C00); alias("RESET", 0x7C00); alias("QK_REBOOT", 0x7C01)
alias("CAPS_WORD", 0x7C73)
alias("QK_TRI_LAYER_LOWER", 0x7C77); alias("QK_TRI_LAYER_UPPER", 0x7C78)

// 5-bit QMK mod mask: bit0 Ctrl, bit1 Shift, bit2 Alt, bit3 GUI, bit4 = right hand.
var MOD_WRAP = { LCTL: 0x01, C: 0x01, LSFT: 0x02, S: 0x02, LALT: 0x04, A: 0x04, LOPT: 0x04,
  LGUI: 0x08, G: 0x08, LCMD: 0x08, RCTL: 0x11, RSFT: 0x12, RALT: 0x14, RGUI: 0x18,
  LCS: 0x03, LCA: 0x05, LSA: 0x06, LCAG: 0x0D, MEH: 0x07, HYPR: 0x0F, LSG: 0x0A, LAG: 0x0C }
var MOD_NAMES = { 0x01: "LCTL", 0x02: "LSFT", 0x04: "LALT", 0x08: "LGUI", 0x11: "RCTL",
  0x12: "RSFT", 0x14: "RALT", 0x18: "RGUI", 0x07: "MEH", 0x0F: "HYPR", 0x03: "LCS", 0x05: "LCA", 0x06: "LSA" }
var MOD_MASK = { MOD_LCTL: 0x01, MOD_LSFT: 0x02, MOD_LALT: 0x04, MOD_LGUI: 0x08, MOD_RCTL: 0x11,
  MOD_RSFT: 0x12, MOD_RALT: 0x14, MOD_RGUI: 0x18, MOD_MEH: 0x07, MOD_HYPR: 0x0F }

// Shifted symbols read better as the symbol than as "S(1)".
var SHIFTED = { 0x1E: "!", 0x1F: "@", 0x20: "#", 0x21: "$", 0x22: "%", 0x23: "^", 0x24: "&",
  0x25: "*", 0x26: "(", 0x27: ")", 0x2D: "_", 0x2E: "+", 0x2F: "{", 0x30: "}", 0x31: "|",
  0x33: ":", 0x34: "\"", 0x35: "~", 0x36: "<", 0x37: ">", 0x38: "?" }

function modShort(mods) {
  var right = mods & 0x10
  var parts = []
  if (mods & 0x01) parts.push("C")
  if (mods & 0x02) parts.push("S")
  if (mods & 0x04) parts.push(right ? "AGr" : "A")
  if (mods & 0x08) parts.push("G")
  if (mods === 0x07) return "Meh"
  if (mods === 0x0F) return "Hyper"
  var long = { "C": "Ctrl", "S": "Shift", "A": "Alt", "AGr": "AltGr", "G": "Super" }
  if (parts.length === 1) return (right && parts[0] !== "AGr" ? "R" : "") + long[parts[0]]
  return (right ? "R" : "") + parts.join("+")
}


// Mod mask as a MOD_* expression that parse() reads back, e.g. MOD_LCTL|MOD_LSFT.
function modExpr(mods) {
  if (mods === 0x07) return "MOD_MEH"
  if (mods === 0x0F) return "MOD_HYPR"
  var side = mods & 0x10 ? "MOD_R" : "MOD_L"
  var parts = []
  if (mods & 0x01) parts.push(side + "CTL")
  if (mods & 0x02) parts.push(side + "SFT")
  if (mods & 0x04) parts.push(side + "ALT")
  if (mods & 0x08) parts.push(side + "GUI")
  return parts.join("|")
}

function basicName(code) {
  return NAMES[code] || ("0x" + code.toString(16).toUpperCase())
}

function hex(code) {
  var s = code.toString(16).toUpperCase()
  while (s.length < 4) s = "0" + s
  return "0x" + s
}

// { tap: main legend, hold: small secondary legend, name: QMK expression }
function label(code) {
  code = Number(code) || 0
  if (code <= 0xFF) {
    var cap = BASIC[code]
    return { tap: cap === undefined ? hex(code) : cap, hold: "", name: basicName(code) }
  }
  if (code <= 0x1FFF) {                      // mods + key, e.g. S(KC_1)
    var mods = (code >> 8) & 0x1F, kc = code & 0xFF
    if (mods === 0x02 && SHIFTED[kc]) return { tap: SHIFTED[kc], hold: "", name: "S(" + basicName(kc) + ")" }
    return { tap: BASIC[kc] || hex(kc), hold: modShort(mods) + "+", name: MOD_NAMES[mods] ? MOD_NAMES[mods] + "(" + basicName(kc) + ")" : hex(code) }
  }
  if (code <= 0x3FFF) {                      // mod-tap
    var mm = (code >> 8) & 0x1F, mk = code & 0xFF
    return { tap: BASIC[mk] || hex(mk), hold: modShort(mm), name: "MT(" + modExpr(mm) + ", " + basicName(mk) + ")" }
  }
  if (code <= 0x4FFF) {                      // layer-tap
    var ll = (code >> 8) & 0x0F, lk = code & 0xFF
    return { tap: BASIC[lk] || hex(lk), hold: "L" + ll, name: "LT(" + ll + ", " + basicName(lk) + ")" }
  }
  if (code <= 0x51FF) {                      // layer + mod
    var lml = (code >> 5) & 0x0F, lmm = code & 0x1F
    return { tap: "LM" + lml, hold: modShort(lmm), name: "LM(" + lml + ", " + modExpr(lmm) + ")" }
  }
  if (code >= 0x5200 && code <= 0x52FF) {
    var kind = (code >> 5) & 0x7, layer = code & 0x1F
    var kinds = ["TO", "MO", "DF", "TG", "OSL", "OSM", "TT", "PDF"]
    if (kinds[kind] === "OSM") return { tap: "OSM", hold: modShort(layer), name: "OSM(" + modExpr(layer) + ")" }
    return { tap: kinds[kind] + "(" + layer + ")", hold: "", name: kinds[kind] + "(" + layer + ")" }
  }
  if (SPECIAL[code]) return { tap: SPECIAL[code][1], hold: "", name: SPECIAL[code][0] }
  if (code >= 0x7E00 && code <= 0x7E1F) return { tap: "USER" + (code - 0x7E00), hold: "", name: "QK_KB_" + (code - 0x7E00) }
  return { tap: hex(code), hold: "", name: hex(code) }
}

// Tap keycode of a key (the part a hold action wraps), or -1 when the key
// isn't a tap key at all (MO, TG, macros ...).
function tapPart(code) {
  if (code <= 0xFF) return code
  if (code <= 0x4FFF) return code & 0xFF
  return -1
}

// Hold part as a descriptor, for the hold-action chips.
function holdPart(code) {
  if (code >= 0x2000 && code <= 0x3FFF) return { kind: "mod", value: (code >> 8) & 0x1F }
  if (code >= 0x4000 && code <= 0x4FFF) return { kind: "layer", value: (code >> 8) & 0x0F }
  return { kind: "none", value: 0 }
}

function withHold(tap, hold) {
  if (tap < 0 || tap > 0xFF) return -1
  if (hold.kind === "mod") return 0x2000 | (hold.value << 8) | tap
  if (hold.kind === "layer") return 0x4000 | ((hold.value & 0x0F) << 8) | tap
  return tap
}

function layerKey(kind, layer) {
  var kinds = { TO: 0, MO: 1, DF: 2, TG: 3, OSL: 4, TT: 6 }
  return 0x5200 | (kinds[kind] << 5) | (layer & 0x1F)
}

function parseArg(s) {
  s = s.trim().toUpperCase()
  if (/^\d+$/.test(s)) return parseInt(s, 10)
  if (MOD_MASK[s] !== undefined) return MOD_MASK[s]
  var mods = s.split("|").map(function(p) { return MOD_MASK[p.trim()] })
  if (mods.length > 1 && mods.every(function(m) { return m !== undefined }))
    return mods.reduce(function(a, b) { return a | b }, 0)
  return parse(s)
}

function parse(text) {
  var s = String(text || "").trim()
  if (s === "") return -1
  if (/^0x[0-9a-f]{1,4}$/i.test(s)) return parseInt(s, 16)
  var up = s.toUpperCase()
  if (BY_NAME[up] !== undefined) return BY_NAME[up]
  var m = up.match(/^([A-Z_]+)\((.*)\)$/)
  if (!m) return -1
  var fn = m[1], args = m[2].split(",").map(function(a) { return a.trim() })
  var a0 = args.length > 0 ? parseArg(args[0]) : -1
  var a1 = args.length > 1 ? parseArg(args[1]) : -1
  if (["TO", "MO", "DF", "TG", "OSL", "TT"].indexOf(fn) >= 0 && args.length === 1 && a0 >= 0 && a0 < 32)
    return layerKey(fn, a0)
  if (fn === "LT" && args.length === 2 && a0 >= 0 && a0 < 16 && a1 >= 0 && a1 <= 0xFF) return 0x4000 | (a0 << 8) | a1
  if (fn === "MT" && args.length === 2 && a0 > 0 && a0 < 32 && a1 >= 0 && a1 <= 0xFF) return 0x2000 | (a0 << 8) | a1
  if (fn === "OSM" && args.length === 1 && a0 > 0 && a0 < 32) return 0x52A0 | a0
  if (fn === "LM" && args.length === 2 && a0 >= 0 && a0 < 16 && a1 > 0 && a1 < 32) return 0x5000 | (a0 << 5) | a1
  var tapMod = fn.match(/^([A-Z]+)_T$/)
  if (tapMod && MOD_WRAP[tapMod[1]] !== undefined && args.length === 1 && a0 >= 0 && a0 <= 0xFF)
    return 0x2000 | (MOD_WRAP[tapMod[1]] << 8) | a0
  if (MOD_WRAP[fn] !== undefined && args.length === 1 && a0 >= 0 && a0 <= 0x1FFF)
    return (MOD_WRAP[fn] << 8) | a0
  return -1
}

// Picker tabs. Each entry is a keycode; layer tabs are built per layer count.
function categories(layerCount) {
  function range(a, b) { var r = []; for (var i = a; i <= b; i++) r.push(i); return r }
  var shifted = [0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38]
  var layers = []
  var kinds = ["MO", "TG", "TO", "OSL", "TT", "DF"]
  for (var k = 0; k < kinds.length; k++)
    for (var l = 0; l < layerCount; l++) layers.push(layerKey(kinds[k], l))
  return [
    { name: "Letters", keys: range(0x04, 0x1D) },
    { name: "Numbers", keys: range(0x1E, 0x27).concat(range(0x3A, 0x45)).concat(range(0x68, 0x73)) },
    { name: "Symbols", keys: [0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38]
        .concat(shifted.map(function(c) { return 0x0200 | c })) },
    { name: "Editing", keys: [0x00, 0x01, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x4C, 0x49, 0x39, 0x65, 0x46, 0x47, 0x48, 0x7C73] },
    { name: "Nav", keys: [0x50, 0x51, 0x52, 0x4F, 0x4A, 0x4D, 0x4B, 0x4E] },
    { name: "Mods", keys: range(0xE0, 0xE7).concat([0x52A1, 0x52A2, 0x52A4, 0x52A8]) },
    { name: "Layers", keys: [0x7C77, 0x7C78].concat(layers) },
    { name: "Media", keys: [0xA8, 0xAA, 0xA9, 0xAC, 0xAE, 0xAB, 0xAD, 0xBE, 0xBD, 0xB2, 0xB6, 0xB7, 0xA5, 0xA6] },
    { name: "Mouse", keys: [0xCD, 0xCE, 0xCF, 0xD0, 0xD1, 0xD2, 0xD3, 0xD9, 0xDA, 0xDB, 0xDC] },
    { name: "Numpad", keys: range(0x53, 0x63) },
    { name: "Board", keys: [0x7820, 0x7821, 0x7822, 0x7823, 0x7824, 0x7825, 0x7826, 0x7827, 0x7828, 0x7C01, 0x7C00, 0x7C03] }
  ]
}

// ------------------------------------------------------------- layer tracking
// VIA can't report the active layer, so it's replayed from the switch matrix:
// each newly pressed switch is resolved against the layers active at that
// moment, like QMK does, and its layer action applied.

var TAPPING_TERM = 200   // ms; QMK default. LT/TT only count as held after it.

// What a keycode does to the layer state, or null for ordinary keys.
function layerAction(code) {
  if (code >= 0x4000 && code <= 0x4FFF) return { kind: "LT", layer: (code >> 8) & 0x0F }
  if (code >= 0x5000 && code <= 0x51FF) return { kind: "LM", layer: (code >> 5) & 0x0F }
  if (code >= 0x5200 && code <= 0x52FF) {
    var kind = ["TO", "MO", "DF", "TG", "OSL", "OSM", "TT", "PDF"][(code >> 5) & 0x7]
    if (kind === "OSM") return null
    return { kind: kind === "PDF" ? "DF" : kind, layer: code & 0x1F }
  }
  // Tri-layer keys use QMK's default layers: lower 1, upper 2, both 3.
  if (code === 0x7C77) return { kind: "TL", layer: 1 }
  if (code === 0x7C78) return { kind: "TL", layer: 2 }
  return null
}

function newLayerState() {
  return { defaultLayer: 0, toggled: [], held: {} }   // held: pos -> { code, since }
}

// Active layers, highest first.
function activeLayers(state, now) {
  var on = {}
  on[state.defaultLayer] = true
  for (var i = 0; i < state.toggled.length; i++) on[state.toggled[i]] = true
  var tri = 0
  for (var pos in state.held) {
    var h = state.held[pos], a = layerAction(h.code)
    if (!a) continue
    if (a.kind === "MO" || a.kind === "LM" || a.kind === "OSL" || a.kind === "TL") on[a.layer] = true
    else if ((a.kind === "LT" || a.kind === "TT") && now - h.since >= TAPPING_TERM) on[a.layer] = true
    if (a.kind === "TL") tri |= a.layer
  }
  if (tri === 3) on[3] = true
  return Object.keys(on).map(Number).sort(function(a, b) { return b - a })
}

function topLayer(state, now) {
  return activeLayers(state, now)[0]
}

// True while an LT/TT key is held but not yet past the tapping term, i.e.
// the layer may still switch without the matrix changing.
function pendingHold(state, now) {
  for (var pos in state.held) {
    var h = state.held[pos], a = layerAction(h.code)
    if (a && (a.kind === "LT" || a.kind === "TT") && now - h.since < TAPPING_TERM) return true
  }
  return false
}

function toggle(list, layer) {
  var i = list.indexOf(layer)
  return i >= 0 ? list.slice(0, i).concat(list.slice(i + 1)) : list.concat([layer])
}

// Apply a new set of pressed switches ("row,col" strings). keymap is the
// per-layer { "row,col": code } list. Returns a new state.
function pressKeys(state, keymap, pressed, now) {
  var s = { defaultLayer: state.defaultLayer, toggled: state.toggled.slice(), held: {} }
  var down = {}
  for (var i = 0; i < pressed.length; i++) down[pressed[i]] = true
  for (var pos in state.held) {
    var h = state.held[pos]
    if (down[pos]) { s.held[pos] = h; continue }
    var a = layerAction(h.code)
    if (a && a.kind === "TT" && now - h.since < TAPPING_TERM) s.toggled = toggle(s.toggled, a.layer)
  }
  for (var j = 0; j < pressed.length; j++) {
    var p = pressed[j]
    if (state.held[p]) continue
    var layers = activeLayers(s, now), code = 0
    for (var k = 0; k < layers.length; k++) {
      var c = keymap[layers[k]] ? keymap[layers[k]][p] : undefined
      if (c !== undefined && c !== 0x01) { code = c; break }
    }
    s.held[p] = { code: code, since: now }
    var act = layerAction(code)
    if (!act) continue
    if (act.kind === "TG") s.toggled = toggle(s.toggled, act.layer)
    else if (act.kind === "TO") s.toggled = [act.layer]
    else if (act.kind === "DF") s.defaultLayer = act.layer
  }
  return s
}
