import unittest
from regex_fun import vhdl


class TestVHDL(unittest.TestCase):
    def setUp(self):
        with open("./seven_segment_display.vhd", "r") as f:
            self.buffer = f.read()

    # def tearDown(self):
    #     pass

    def test_something(self):
        # arrange
        # action
        entity_str = vhdl.get_entity(self.buffer)
        print(entity_str)
        # assert
        self.assertEqual(0, 0)


if __name__ == "__main__":
    unittest.main()
