import unittest
from regex_fun import vhdl

# TODO
# test all individual functions
# test faulty input (e.g. empty .vhd file)


class TestVHDL(unittest.TestCase):
    def setUp(self):
        with open("tests/module.vhd", "r") as f:
            self.buffer = f.read()

    # def tearDown(self):
    #     pass

    def test_module_entity(self):
        pass

    def test_module_ports(self):
        # action
        ports = vhdl.get_ports(self.buffer)
        print(ports)
        ret = [
            ("clk", "in", "std_logic"),
            ("reset", "in", "std_logic"),
            ("var", "out", "std_logic_vector(6 downto 0)"),
        ]
        # assert
        self.assertEqual(ports, ret)

    def test_module_generics(self):
        pass


if __name__ == "__main__":
    unittest.main()
