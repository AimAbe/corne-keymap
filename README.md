# Corne Keymap

An Omarchy shell plugin that draws your **Corne v4** in the bar and lets you remap it live.
Click a key, pick a keycode, and it's written straight to the keyboard over the VIA/Vial raw-HID
protocol. There's no firmware to compile and nothing to flash.

- Board drawn from the layout the firmware reports (Vial), or a built-in Corne v4 layout
  (46 keys, `LAYOUT_split_3x6_3_ex2`) for plain VIA firmware
- Every layer, plus mod-taps and layer-taps from one row of **Hold** chips (home-row mods in two clicks)
- Picker tabs: letters, numbers/F-keys, symbols, editing, nav, mods, layer keys, media, mouse, numpad, RGB/boot
- Free-form input: `KC_A`, `MO(1)`, `LT(2, KC_SPC)`, `LCTL_T(KC_A)`, `C(KC_C)`, `OSM(MOD_LSFT)`, `0x7C00`
- Each write is read back to confirm it. Keys Vial refuses (e.g. `QK_BOOT` on a locked board) are reported instead of faked
- Automatic backup before the first change of each session; manual Backup / Restore; Undo
- Keys light up as you press them (VIA/Vial matrix tester). A locked Vial board may hide
  the matrix, so the panel offers **Unlock**: hold the highlighted keys until it finishes
- Demo mode for trying it without a keyboard

## Install

```bash
git clone <this repo> ~/.config/omarchy/plugins/aimabe.corne-keymap
omarchy plugin enable aimabe.corne-keymap
```

Linux only lets root open raw HID devices by default. Allow your user to reach foostan (VID `4653`) boards:

```bash
sudo install -m644 udev/50-corne-keymap.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw
```

(The panel has a button that copies this command.) Needs `python3`, which Omarchy ships.

## Keys

| Key | Action |
|---|---|
| Arrows / `hjkl` | move the selection across the board |
| `0`–`9` | switch layer |
| `x` | clear key (`KC_NO` on layer 0, `▽` transparent above) |
| `u` | undo |
| Enter | type a keycode |
| Esc | close |

IPC: `omarchy-shell corne-keymap open|close|toggle`

## Helper

`bin/cornectl` is stdlib-only Python and prints JSON, so you can also script it:

```bash
bin/cornectl dump                 # layout + all layers
bin/cornectl set 0 1 0 0x2104     # layer 0, row 1, col 0 -> LCTL_T(KC_A)
bin/cornectl backup               # ~/.local/state/omarchy/corne-keymap/backups/
bin/cornectl restore [file]       # latest backup when no file given
bin/cornectl watch                # stream pressed switches as JSON lines
bin/cornectl unlock               # Vial unlock (hold the keys it names)
bin/cornectl --demo dump          # simulated board
```

Changes live in the keyboard's EEPROM, like VIA/Vial edits. A "clear EEPROM" resets
them to the firmware defaults.

## Limits

- USB only. Wireless Corne builds run ZMK, which has no live-remap protocol.
- Keycodes use the current QMK numbering (VIA protocol 12+, current Vial). Older firmware
  may show odd labels for layer/quantum keys; basic keys are unaffected.
- Macros, tap dance and combos (Vial extras) aren't edited here. Use the Vial app for those.

## Tests

```bash
python3 tests/test_cornectl.py   # protocol against a fake VIA/Vial board
node tests/keycodes.test.js      # keycode parse/label round-trips
```
