import os
import shutil
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))

from gen_data import filter_data, render_lua  # noqa: E402


def m(id_, name, instance_type="1"):
    return {"ID": str(id_), "MapName_lang": name, "InstanceType": instance_type}


def e(id_, map_id, name, order=0, difficulty=0, flags=1024):
    return {
        "ID": str(id_),
        "MapID": str(map_id),
        "Name_lang": name,
        "OrderIndex": str(order),
        "DifficultyID": str(difficulty),
        "Flags": str(flags),
    }


class FilterTests(unittest.TestCase):
    def test_keeps_only_dungeons(self):
        data = filter_data(
            [m(36, "Deadmines"), m(409, "Molten Core", "2")],
            [e(2747, 36, "Edwin VanCleef"), e(1, 409, "Lucifron")],
        )
        self.assertIn(36, data)
        self.assertNotIn(409, data)

    def test_drops_non_zero_difficulty(self):
        data = filter_data(
            [m(48, "Blackfathom Deeps")],
            [
                e(2913, 48, "Lorgus Jett"),
                e(9001, 48, "SoD A", difficulty=198),
                e(9002, 48, "SoD B", difficulty=201),
                e(9003, 48, "SoD C", difficulty=215),
            ],
        )
        self.assertEqual([x["id"] for x in data[48]["encounters"]], [2913])

    def test_drops_world_and_test_maps(self):
        data = filter_data(
            [m(0, "Eastern Kingdoms"), m(13, "Test Dungeon"), m(36, "Deadmines")],
            [e(1, 0, "World"), e(2, 13, "Test"), e(3, 3002, "Orphan"), e(4, 36, "Rhahk'Zor")],
        )
        self.assertEqual(sorted(data), [36])

    def test_sorts_by_order_including_negative(self):
        data = filter_data(
            [m(48, "Blackfathom Deeps")],
            [e(1, 48, "A", order=-3000), e(2, 48, "B", order=-6000), e(3, 48, "C", order=1000)],
        )
        self.assertEqual([x["order"] for x in data[48]["encounters"]], [-6000, -3000, 1000])


class RenderTests(unittest.TestCase):
    def sample(self):
        return filter_data(
            [m(209, "Zul'Farrak"), m(36, "Deadmines")],
            [e(5, 209, 'Zul\'Farrak "X" \\ é'), e(2747, 36, "Edwin VanCleef", order=6000)],
        )

    def test_render_escapes(self):
        out = render_lua(self.sample(), "1.60.1.70938")
        self.assertIn('"Zul\'Farrak \\"X\\" \\\\ é"', out)
        luajit = shutil.which("luajit")
        if not luajit:
            self.skipTest("luajit not on PATH")
        proc = subprocess.run(
            [luajit, "-e", 'local ns = {} assert(loadstring(io.read("*a")))("x", ns) assert(ns.Encounters[5].map == 209)'],
            input=out.encode("utf-8"),
            capture_output=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr.decode())

    def test_render_is_stable(self):
        a = render_lua(self.sample(), "b")
        b = render_lua(self.sample(), "b")
        self.assertEqual(a, b)
        self.assertLess(a.index("[36]"), a.index("[209]"))


if __name__ == "__main__":
    unittest.main()
