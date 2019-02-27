----=====================================================================================================
---- Module Name	:	os_cfar
---- Company		:	SEW-Eurodrive GmbH & KG
---- Teamwork of 	:	FK-FN
---- Programmer		:	Maximilian Tosch	
---- Date			:	19.02.2019
---- Function		:  Calculates Ordered Statistics Constant False Alarm Rate (OS-CFAR)
----=====================================================================================================


-- Interface info
-- TODO
 --entity xy is 
	--entity xy is 
-- entity xy is
-------- entity xy is
--   ---  --- entity xy is
--entity xy is
		-entity xy is
		
-- +--------------------------------------+--------------------------------------------------+---------+
-- | Constant                             | Type                                             | Default |
-- +======================================+==================================================+=========+
-- | CFAR_GUARD_CELLS                     | integer range 0 to 20                            | 3       |
-- +--------------------------------------+--------------------------------------------------+---------+
-- | CFAR_LEADING_LAGGING_CELLS           | integer range -10 to 20                          | -5      |
-- +--------------------------------------+--------------------------------------------------+---------+
-- | CFAR_REFERENCE_CELLS                 | integer range 0 to 2* CFAR_LEADING_LAGGING_CELLS | 40      |
-- +--------------------------------------+--------------------------------------------------+---------+
-- | CFAR_OS_ALPHA_MULTIPLIER             | integer range -500 to 2000                       | 32      |
-- +--------------------------------------+--------------------------------------------------+---------+
-- | CFAR_OS_ALPHA_MULTIPLIER_LONGER_NAME | std_logic_vector(2 downto 0)                     | "010"   |
-- +--------------------------------------+--------------------------------------------------+---------+
-- | FFT_LENGTH                           | integer range 0 to 2**12                         | 2048    |
-- +--------------------------------------+--------------------------------------------------+---------+
entity cfar_os is 
	generic(
		N : integer := 32
	);
	PORT(
		clk_20_i				: in std_logic;
		reset_i				: in std_logic;
		
		en_i							: in std_logic;
		data_i						: in unsigned(N-1 downto 0);
		average_signal_noise_i	: in unsigned(N-1 downto 0);
		
		valid_o						: out std_logic;
		cfar_threshold_o			: out std_logic_vector(N-1 downto 0) -- U or X on very first run
);
END cfar_os;
--OS CFAR TESTING: +2 only for OS (@04.02 changed to +1)
signal cfar_iterator_s	: integer range -(CFAR_GUARD_CELLS + CFAR_LEADING_LAGGING_CELLS+1) to FFT_LENGTH;
--OS_CFAR
type msb_histogram_type is array(natural range<>) of integer range -2 to 2*CFAR_LEADING_LAGGING_CELLS; -- +10 cells leadging window + 10 cells lagging window

--type msb_histogram_addition_type is array(natural range<>) of integer range -2 to 2; --array to store the addition operations for the histogram of OS CFAR
type reverse_lookup_type is array(natural range<>) of integer range 0 to 31;
signal reverse_lookup_s 				: reverse_lookup_type(CFAR_REFERENCE_CELLS - 1 downto 0);

--debug
-- reference cells (sliding window)
type cfar_reference_cells_type is array(CFAR_REFERENCE_CELLS-1 downto 0) of unsigned(31 downto 0);

		
						cfar_iterator_s	<= -(CFAR_LEADING_LAGGING_CELLS + CFAR_GUARD_CELLS + 1); --  -(10+3+1) = -14
						cfar_state			<= pending;

			msb_histogram_v(0)		:= 2 * CFAR_LEADING_LAGGING_CELLS;
	
			pos3_v := reverse_lookup_s(CFAR_LEADING_LAGGING_CELLS + 2 * CFAR_GUARD_CELLS + 1);	--find position where a cell is removed (cell leaving for guard and CUT)
			
					cfar_threshold_s <= to_std_logic_vec(k_th_max_v * to_unsigned(CFAR_OS_ALPHA_MULTIPLIER,32))(31 downto 0);
			-- PYTHON TEST ONLY
			          my_param <= std_logic_vector(CFAR_OS_ALPHA_MULTIPLIER_LONGER_NAME);

			--
END architecture;