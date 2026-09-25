// node tests/keycodes.test.js
const fs = require("fs"), path = require("path"), assert = require("assert")
const src = fs.readFileSync(path.join(__dirname, "..", "Keycodes.js"), "utf8").replace(".pragma library", "")
const K = new Function(src + "; return { label, parse, tapPart, holdPart, withHold, categories }")()

const cases = { "KC_A": 0x04, "a": 0x04, "MO(1)": 0x5221, "TG(3)": 0x5263, "TO(0)": 0x5200,
  "LT(2, KC_SPC)": 0x422C, "LCTL_T(KC_A)": 0x2104, "MT(MOD_LSFT, KC_F)": 0x2209,
  "S(KC_1)": 0x021E, "TL_LOWR": 0x7C77, "TL_UPPR": 0x7C78, "LCTL(KC_C)": 0x0106, "OSM(MOD_LSFT)": 0x52A2, "QK_BOOT": 0x7C00,
  "0x1234": 0x1234, "_______": 1, "MT(MOD_LCTL|MOD_LSFT, KC_A)": 0x2304, "nonsense": -1 }
for (const [text, code] of Object.entries(cases)) assert.strictEqual(K.parse(text), code, text)

// Every label's name must parse back to the same code.
for (const code of [0x04, 0x5221, 0x422C, 0x2104, 0x021E, 0x0106, 0x52A2, 0x7C00, 0x2304, 0x7820])
  assert.strictEqual(K.parse(K.label(code).name), code, K.label(code).name)
for (const cat of K.categories(4)) for (const code of cat.keys)
  assert.strictEqual(K.parse(K.label(code).name), code, cat.name + " " + K.label(code).name)

assert.deepStrictEqual(K.label(0x2104), { tap: "A", hold: "Ctrl", name: "MT(MOD_LCTL, KC_A)" })
assert.strictEqual(K.label(0x021E).tap, "!")
assert.strictEqual(K.withHold(K.tapPart(0x2104), { kind: "layer", value: 2 }), 0x4204)
assert.strictEqual(K.withHold(0x04, { kind: "none" }), 0x04)
console.log("keycodes ok")

// Layer tracking: tri-layer, MO resolved through the active layer, TG, LT after the tapping term.
{
  const L = new Function(src + "; return { pressKeys, topLayer, newLayerState, pendingHold }")()
  const km = [{ "a": 0x7C77, "b": 0x7C78, "c": 0x5262, "d": 0x4104, "e": 0x04 },
              { "a": 0x01, "b": 0x01, "c": 0x01, "d": 0x01, "e": 0x5225 },
              {}, {}, {}, {}]
  let s = L.newLayerState()
  s = L.pressKeys(s, km, ["a"], 0);        assert.strictEqual(L.topLayer(s, 0), 1)
  s = L.pressKeys(s, km, ["a", "b"], 10);  assert.strictEqual(L.topLayer(s, 10), 3)
  s = L.pressKeys(s, km, ["a"], 20);       assert.strictEqual(L.topLayer(s, 20), 1)
  s = L.pressKeys(s, km, ["a", "e"], 30);  assert.strictEqual(L.topLayer(s, 30), 5)   // MO(5) found on layer 1
  s = L.pressKeys(s, km, [], 40);          assert.strictEqual(L.topLayer(s, 40), 0)
  s = L.pressKeys(s, km, ["c"], 50);       s = L.pressKeys(s, km, [], 60)
  assert.strictEqual(L.topLayer(s, 60), 2)                                          // TG(2) stays on
  s = L.pressKeys(s, km, ["c"], 70);       s = L.pressKeys(s, km, [], 80)
  assert.strictEqual(L.topLayer(s, 80), 0)
  s = L.pressKeys(s, km, ["d"], 100)
  assert.strictEqual(L.topLayer(s, 150), 0); assert.ok(L.pendingHold(s, 150))
  assert.strictEqual(L.topLayer(s, 300), 1)                                         // LT(1) held
  console.log("layers ok")
}
