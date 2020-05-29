import unittest
import re
from regex_fun import vhdl


class TestVHDLmodule(unittest.TestCase):
    def setUp(self):
        with open("tests/vhdl/module.vhd", "r") as f:
            self.module = f.read()

    def test_entity(self):
        # action
        entity = vhdl.get_entity(self.module)
        expected = """entity module is
                      generic(N : integer := 42;
                              M,O : std_logic);
                      port(  clk,clk2,clk10   : in std_logic;
                              reset : inout std_logic;
                              p1,p2  : out std_logic_vector(N-1 downto 0));
                      end module;
                   """
        expected = re.sub(r"\s+", " ", expected).strip()
        # assert
        self.assertEqual(entity, expected)
        self.assertIsNotNone(entity)

    def test_generics(self):
        # action
        generics = vhdl.get_generics(self.module)
        expected = [
            ("N", "integer", "42"),
            ("M", "std_logic", None),
            ("O", "std_logic", None),
        ]
        # assert
        self.assertEqual(generics, expected)
        self.assertIsNotNone(generics)

    def test_ports(self):
        # action
        ports = vhdl.get_ports(self.module)
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

    def test_architecture(self):
        # action
        architecture = vhdl.get_architecture(self.module)
        # assert
        smoke = "architecture behavioral of module is" in architecture
        self.assertTrue(smoke)

    def test_no_input(self):
        # arrange
        nothing = ""
        # action
        entity = vhdl.get_entity(nothing)
        ports = vhdl.get_ports(nothing)
        generics = vhdl.get_generics(nothing)
        architecture = vhdl.get_architecture(nothing)
        # assert
        self.assertIsNone(entity)
        self.assertIsNone(ports)
        self.assertIsNone(generics)
        self.assertIsNone(architecture)


class TestVHDLpackage(unittest.TestCase):
    def setUp(self):
        with open("tests/vhdl/constants.vhd", "r") as f:
            self.constants = f.read()

    def test_constants(self):
        # action
        constants = vhdl.get_constants(self.constants)
        expected = [
            ("A", "integer range 0 to 2000", "1000"),
            ("B", "integer range 0 to 2000", "1000"),
            ("C", "integer range 0 to 2000", "1000"),
            ("Benedictus", "integer range 0 to 1", "0"),
            ("Leonardus_MAX", "integer range 4 to 4", "4"),
            ("Constans", "integer range 1 to Leonardus_MAX", "1"),
            ("Rogerius", "integer range 0 to 10000", "7999"),
            ("Elias", "std_logic_vector(31 downto 0)", 'x"00000001"'),
            ("D", "std_logic_vector(31 downto 0)", 'x"00000001"'),
            ("F", "std_logic_vector(31 downto 0)", 'x"00000001"'),
            ("Dorothea", "integer range 0 to 255", "42"),
            ("Dominicus", "integer range 0 to 2**17", "12500"),
            ("Justinus", "std_logic_vector(31 downto 0)", 'x"00000000"'),
            ("Natalia", "integer range 0 to 32", "32"),
            ("state_selected", "state_type", "opt1"),
        ]
        # assert
        self.assertEqual(constants, expected)

    def test_no_input(self):
        # arrange
        nothing = ""
        # action
        constants = vhdl.get_constants(nothing)
        # assert
        self.assertIsNone(constants)
