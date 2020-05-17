import unittest
import re
from regex_fun import vhdl

# TODO
# test all individual functions
# test faulty input (e.g. empty .vhd file)


class TestVHDL(unittest.TestCase):
    def setUp(self):
        with open("tests/vhdl/module.vhd", "r") as f:
            self.buffer = f.read()

    # def tearDown(self):
    #     pass

    def test_module_entity(self):
        # action
        entity = vhdl.get_entity(self.buffer)
        expected = """entity module is
                      generic(N : integer := 42;
                              M : std_logic);
                      port(  clk,clk2,clk10   : in std_logic;
                              reset : inout std_logic;
                              p1,p2  : out std_logic_vector(N-1 downto 0));
                      end module;
                   """
        expected = re.sub(r"\s+", " ", expected).strip()
        # assert
        self.assertEqual(entity, expected)
        self.assertIsNotNone(entity)

    def test_module_ports(self):
        # action
        ports = vhdl.get_ports(self.buffer)
        expected = [
            ("clk", "in", "std_logic"),
            ("clk2", "in", "std_logic"),
            ("clk10", "in", "std_logic"),
            ("reset", "inout", "std_logic"),
            ("p1", "out", "std_logic_vector(N-1 downto 0)"),
            ("p2", "out", "std_logic_vector(N-1 downto 0)"),
        ]
        # assert
        self.assertEqual(ports, expected)
        self.assertIsNotNone(ports)

    def test_module_generics(self):
        # action
        generics = vhdl.get_generics(self.buffer)
        expected = [
            ("N", "integer", "42"),
            ("M", "std_logic", None),
        ]
        # assert
        self.assertEqual(generics, expected)
        self.assertIsNotNone(generics)

    def test_empty_file(self):
        # arrange
        buffer = ""
        # action
        entity = vhdl.get_entity(buffer)
        # assert
        self.assertIsNone(entity)


if __name__ == "__main__":
    unittest.main()
