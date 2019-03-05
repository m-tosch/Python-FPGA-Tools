package p is
--TESTTTTTTTTTTTTTTTTTTTTTT
    -- CFAR OS
    constant   	 CFAR_GUARD_CELLS                     :   integer	range 0 to 20 := 3;--constant CFAR_GUARD_CELLSS :   integer	range 0 to 20 := 3;
    constant 		CFAR_LEADING_LAGGING_CELLS           :   integer  range  -10 to 20 := -5;
	constant   CFAR_REFERENCE_CELLS    :	 integer range 0 to 2* CFAR_LEADING_LAGGING_CELLS
			:= 40; 
        constant CFAR_OS_ALPHA_MULTIPLIER   :   integer range  -500 to  2000 := 32;
    constant 		CFAR_OS_ALPHA_MULTIPLIER_LONGER_NAME   :   std_logic_vector(2 downto 0) := "010";

    -- FFT
    constant   FFT_LENGTH      
				: integer range 0 to 2**12 := 2048;
				
    constant   NEW_CONSTANT           : std_logic_vector
		(12 downto 0) := "110";
	
	--constant 
	--						: std_logic := '0';
    type RAMP_MODE_type is (SAWTOOTH, TRIANGULAR);
    type CFAR_ALGORITHM_type is (SOCA,CA,OS);
	
    constant PLL_RAMP_MODE			: RAMP_MODE_type			:= SAWTOOTH;
	

    
	
end package;


