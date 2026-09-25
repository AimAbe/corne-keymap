"""Protocol tests against a fake VIA/Vial board: python3 tests/test_cornectl.py"""
import importlib.machinery, importlib.util, json, lzma, os, sys, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
loader = importlib.machinery.SourceFileLoader("cornectl", os.path.join(HERE, "..", "bin", "cornectl"))
spec = importlib.util.spec_from_loader("cornectl", loader)
cornectl = importlib.util.module_from_spec(spec)
loader.exec_module(cornectl)

# Two-key board with a rotated thumb cluster and a layout option to skip.
KLE = [["0,0", {"x": 1}, "0,1"],
       [{"r": 15, "rx": 4, "ry": 3, "y": -0.5}, "1,0\n\n\n0,0", "1,1\n\n\n0,1"],
       [{"d": True}, "9,9"]]


class FakeBoard:
    def __init__(self, vial=True):
        self.vial = vial
        self.keys = {}
        self.pressed = set()      # (row, col)
        self.unlocked = False
        self.unlock_counter = 3
        blob = lzma.compress(json.dumps({"matrix": {"rows": 2, "cols": 2}, "layouts": {"keymap": KLE}}).encode())
        self.defn = blob

    def xfer(self, p):
        p = list(p) + [0] * (32 - len(p))
        out = bytearray(p)
        if p[0] == 0x01:
            out[1:3] = (12).to_bytes(2, "big")
        elif p[0] == 0x11:
            out[1] = 4
        elif p[0] == 0x04:
            out[4:6] = self.keys.get(tuple(p[1:4]), 0).to_bytes(2, "big")
        elif p[0] == 0x05:
            self.keys[tuple(p[1:4])] = p[4] << 8 | p[5]
        elif p[0] == 0x02 and p[1] == 0x03:
            for r, c in self.pressed:
                out[2 + r] |= 1 << c
        elif p[0] == 0xFE and not self.vial:
            out[0] = 0xFF
        elif p[0] == 0xFE and p[1] == 0x00:
            out[0:12] = (6).to_bytes(4, "little") + b"\x01" * 8
        elif p[0] == 0xFE and p[1] == 0x01:
            out[0:4] = len(self.defn).to_bytes(4, "little")
        elif p[0] == 0xFE and p[1] == 0x02:
            page = p[2] | p[3] << 8
            chunk = self.defn[page * 32:page * 32 + 32]
            out = bytearray(chunk + b"\x00" * (32 - len(chunk)))
        elif p[0] == 0xFE and p[1] == 0x05:
            out = bytearray([int(self.unlocked), 0, 0, 0, 0, 1] + [0xFF] * 26)
        elif p[0] == 0xFE and p[1] == 0x07:
            self.unlock_counter -= 1
            self.unlocked = self.unlock_counter == 0
            out[0:3] = bytes([int(self.unlocked), 1, self.unlock_counter])
        return bytes(out)


class Tests(unittest.TestCase):
    def test_vial_layout_from_device(self):
        kb = cornectl.Keyboard(FakeBoard())
        kb.set(0, 1, 0, 0x5221)
        d = cornectl.cmd_dump(kb)
        self.assertEqual(d["layoutSource"], "vial")
        self.assertEqual([(k["row"], k["col"]) for k in d["layout"]], [(0, 0), (0, 1), (1, 0)])
        self.assertEqual(d["layout"][1]["x"], 2)
        thumb = d["layout"][2]
        self.assertEqual((thumb["x"], thumb["y"], thumb["r"], thumb["rx"]), (4, 2.5, 15, 4))
        self.assertEqual(d["keymap"][0]["1,0"], 0x5221)
        self.assertEqual(len(d["keymap"]), 4)

    def test_plain_via_uses_builtin_corne(self):
        d = cornectl.cmd_dump(cornectl.Keyboard(FakeBoard(vial=False)))
        self.assertEqual(d["layoutSource"], "builtin")
        self.assertEqual(len(d["layout"]), 46)
        self.assertEqual(len({(k["row"], k["col"]) for k in d["layout"]}), 46)

    def test_set_and_restore(self):
        with tempfile.TemporaryDirectory() as tmp:
            cornectl.BACKUP_DIR = tmp
            kb = cornectl.Keyboard(FakeBoard(vial=False))
            kb.set(0, 0, 0, 0x04)
            path = cornectl.cmd_backup(kb)["path"]
            cornectl.cmd_set(kb, ["0", "0", "0", "0x2c"])
            self.assertEqual(kb.get(0, 0, 0), 0x2C)
            self.assertEqual(cornectl.cmd_restore(kb, path)["written"], 1)
            self.assertEqual(kb.get(0, 0, 0), 0x04)

    def test_matrix_bits(self):
        board = FakeBoard()
        board.pressed = {(0, 1), (1, 0)}
        self.assertEqual(cornectl.Keyboard(board).matrix(2, 2), ["0,1", "1,0"])

    def test_watch_reports_lock_and_changes(self):
        board = FakeBoard()
        board.pressed = {(1, 1)}
        lines = []
        cornectl.emit = lines.append
        cornectl.cmd_watch(cornectl.Keyboard(board), interval=0, polls=2)
        self.assertEqual(lines[0], {"event": "hello", "rows": 2, "cols": 2,
                                    "locked": True, "unlockKeys": [[0, 0], [0, 1]]})
        self.assertEqual(lines[1:], [{"event": "keys", "pressed": ["1,1"]}])  # unchanged 2nd poll not repeated

    def test_unlock_polls_until_unlocked(self):
        lines = []
        cornectl.emit = lines.append
        out = cornectl.cmd_unlock(cornectl.Keyboard(FakeBoard()), interval=0)
        self.assertTrue(out["unlocked"])
        self.assertEqual([l["counter"] for l in lines], [None, 2, 1])

    def test_demo_keymap_covers_layout(self):
        positions = {"%d,%d" % (k["row"], k["col"]) for k in cornectl.fallback_layout()}
        for layer in cornectl.demo_keymap():
            self.assertEqual(set(layer), positions)


if __name__ == "__main__":
    unittest.main()
