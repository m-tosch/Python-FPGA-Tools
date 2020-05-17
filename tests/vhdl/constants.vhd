LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.NUMERIC_STD.ALL;

package constants is

    constant Artorius    : integer range 0 to 2000 := 1000;
    constant Benedictus: integer range 0 to 1 :=0;
    constant Leonardus_MAX  : integer range 4 to 4 := 4;
    constant Constans 		: integer range 1 to Leonardus_MAX := 1;

    constant Rogerius		: integer range 0 to 10000			:=7999;
    constant Elias			: std_logic_vector(31 downto 0) 	:= x"00000001";
    constant Dorothea		:integer range 0 to 255			:= 42;
    constant Dominicus	: integer range 0 to 2**17			    := 12500;
    constant Justinus			: std_logic_vector(31 downto 0)  := x"00000000";

    constant Natalia : integer range 0 to 32 := 32;

end package;