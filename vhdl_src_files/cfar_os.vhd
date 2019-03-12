----=====================================================================================================
---- Module Name	:	os_cfar
---- Company		:	SEW-Eurodrive GmbH & KG
---- Teamwork of 	:	FK-FN
---- Programmer	:	Maximilian Tosch	
---- Date			:	19.02.2019
---- Function		:  Calculates Ordered Statistics Constant False Alarm Rate (OS-CFAR)
----=====================================================================================================
---- ToDo: 
----	
----=====================================================================================================


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use work.pktec_evalboard_def_pkg.all;
--use work.pktec_evalboard_config_pkg.all;

-- +['CFAR_GUARD_CELLS', 'integer range 0 to 20', '3']
-- ['CFAR_LEADING_LAGGING_CELLS', 'integer range -10 to 20', '-5']
-- ['CFAR_REFERENCE_CELLS', 'integer range 0 to 2* CFAR_LEADING_LAGGING_CELLS', '40']
-- ['CFAR_OS_ALPHA_MULTIPLIER', 'integer range -500 to 2000', '32']
-- ['CFAR_OS_ALPHA_MULTIPLIER_LONGER_NAME', 'std_logic_vector(2 downto 0)', '"010"']
-- ['FFT_LENGTH', 'integer range 0 to 2**12', '2048']---+
entity cfar_os is
	generic(
		N : integer := 32
	);
	PORT(
		clk_20_i					: in std_logic;
		reset_i						: in std_logic ;
		
		en_i						: in std_logic;
		data_i						: in unsigned(N-1 downto 0) ;
		average_signal_noise_i		: in unsigned(N-1 downto 0);
		
		valid_o						: out std_logic;
		cfar_threshold_o			: out std_logic_vector(N-1 downto 0)
		--valid_o						: out integer
 );
END cfar_os;

ARCHITECTURE behav OF cfar_os IS

-- state machine
type cfar_state_type is (idle, pending, calculation);
signal cfar_state : cfar_state_type;

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
signal cfar_reference_cells_s 					: cfar_reference_cells_type;
			


--INPUT
signal en_delay_s							: std_logic;
--OUTPUT
signal valid_s								: std_logic;
signal cfar_threshold_s					: std_logic_vector(31 downto 0);

signal bin_value_s						: unsigned(31 downto 0);-- := (others => '1'); -- either the actual fft input data or an average noise value

--debug
signal msb_histogram_s									: msb_histogram_type(31 downto 0) := (others => 0);
signal n_exp_v_s											: integer range 0 to 31;
signal k_th_max_v_s										: unsigned(31 downto 0);
signal find_k_top_v_s, find_k_bottom_v_s			: integer range 0 to 31 := 0;
--signal sorted_histogram_s							: msb_histogram_type(31 downto 0) := (others => 0);
type sorted_idx_type is array(natural range<>) of integer range -1 to 31;
--signal sorted_idx_s									: sorted_idx_type(31 downto 0);


function find_k( 
	msb_histogram_input : msb_histogram_type(31 downto 0); k : integer range 1 to 2 * CFAR_LEADING_LAGGING_CELLS := 1 )
	return integer is
variable sorted_histogram  : msb_histogram_type(31 downto 0) := msb_histogram_input;
variable sorted_idx 			: sorted_idx_type(31 downto 0);
variable tmp, tmp2 	 		: integer range 0 to 31;
begin
	-- init
	for i in 0 to 31 loop
		sorted_idx(i)	:= i;
	end loop;
	-- bubble sort
	-- kind of a DIY dictionary. key:value -> sorted_idx:sorted_histogram
	for i in 0 to 31 loop
		for j in 1 to 30 - i loop
			if sorted_histogram(j-1) < sorted_histogram(j) then
				tmp	 						:= sorted_histogram(j-1);
				sorted_histogram(j-1)	:= sorted_histogram(j);
				sorted_histogram(j)		:= tmp;
				tmp2							:= sorted_idx(j-1);
				sorted_idx(j-1)			:= sorted_idx(j);
				sorted_idx(j)				:= tmp2;
			end if;
		end loop;
	end loop;
	-- k-th element
	return sorted_idx(k-1); -- k-th greatest value
end function;

--FIND POS
--find highest bit/MSB
function find_pos(
	input_vector : unsigned(31 downto 0) )
	return integer is
begin
	for i in 31 downto 0 loop
		if input_vector(i) = '1' then
			return i;
		end if;
	end loop;
	return 0;
end function find_pos;

-- so ModelSim is happy
function to_std_logic_vec( v : unsigned) return std_logic_vector is
begin
	return std_logic_vector(v);
end function to_std_logic_vec;


BEGIN


--OUTPUT
valid_o						<= valid_s;
cfar_threshold_o			<= cfar_threshold_s;




cfar_state_proc: process(clk_20_i)
begin
	if rising_edge(clk_20_i) then
		if reset_i = '1' then
			cfar_state 					<= idle;
			cfar_iterator_s 			<= 0;
			en_delay_s					<= '0';
		else
			en_delay_s 	<= en_i;
			
			case cfar_state is
				when idle =>
					if en_delay_s = '0' and en_i = '1' then -- rising edge
						cfar_iterator_s	<= -(CFAR_LEADING_LAGGING_CELLS + CFAR_GUARD_CELLS + 1); --  -(10+3+1) = -14
						cfar_state			<= pending;
					end if;
	
				when pending =>
					--just waiting for pipeline to be half-filled
					cfar_iterator_s 	<= cfar_iterator_s + 1;
					if cfar_iterator_s = 0 then	--at this time, the pipeline is half-filled; we begin assigning the threshold for the cells for which no valid cfar threshold can be calculated (LEADING and GUARD cells); once the pipeline is filled completely, the actual calculation will start seamlessy afterwards
						cfar_state	<= calculation;
					end if;
	
				when calculation =>
					if en_delay_s = '1' and en_i = '0' then -- falling edge
						cfar_state <= idle; -- TODO finishing state where the last 13 cells are evaluated and their threshold is calculated
					end if;
							
			end case;
		end if;
	end if;
end process;



--CFAR CALCULATION PROCESS
cfar_calculation_proc: process(clk_20_i) 
-- OS
variable pos1_v,pos2_v,pos3_v,pos4_v 					: integer range 0 to 31;
variable msb_histogram_v									: msb_histogram_type(31 downto 0) := (0 => 2 * CFAR_LEADING_LAGGING_CELLS, others => 0); --at start/boot, there are 2 * CFAR_LEADING_LAGGING_CELLS within the cfar reference cells
variable n_exp_v												: integer range 0 to 31;
variable k_th_max_v											: unsigned(31 downto 0);

variable avg_noise_msb	: integer range 0 to 31;

begin
	if rising_edge(clk_20_i) then
		if reset_i = '1' then
			valid_s						<= '0';
			bin_value_s					<= (others => '0');
			
			-- OS CFAR
			reverse_lookup_s			<= (others => 0);
			pos1_v						:= 0;
			pos2_v						:= 0;
			pos3_v						:= 0;
			pos4_v						:= 0;
			msb_histogram_v 			:= (others => 0);
			msb_histogram_v(0)		:= 2 * CFAR_LEADING_LAGGING_CELLS;
			n_exp_v						:= 0;
			k_th_max_v					:= (others => '0');
			
			--debug
			msb_histogram_s 			<= (others => 0);
			n_exp_v_s					<= 0;
			k_th_max_v_s				<= (others => '0');

		else

		
			bin_value_s	<= data_i;

			-- debug
			-- shift reg for the cfar reference cells (sliding window)
			for i in 1 to CFAR_REFERENCE_CELLS-1 loop
				cfar_reference_cells_s(i-1)	<=	cfar_reference_cells_s(i);
			end loop;
			-- assign newest bin
			cfar_reference_cells_s(CFAR_REFERENCE_CELLS-1)	<=	bin_value_s;
		
			--for OS, find k-th cell in sorted set
			pos1_v := find_pos(bin_value_s);	--find highest bit of new input
			pos2_v := reverse_lookup_s(CFAR_LEADING_LAGGING_CELLS);
			pos3_v := reverse_lookup_s(CFAR_LEADING_LAGGING_CELLS + 2 * CFAR_GUARD_CELLS + 1);	--find position where a cell is removed (cell leaving for guard and CUT)
			pos4_v := reverse_lookup_s(0);	--find position where a cell is removed (cell leaving reference/lagging window)
			
			--do the shift for the reverse lookup table
			for i in 1 to CFAR_REFERENCE_CELLS - 1 loop
				reverse_lookup_s(i-1)	<= reverse_lookup_s(i);
			end loop;
			
			--assign the position of the newest cell to the highest/newest cell of the reverse lookup table
			reverse_lookup_s(CFAR_REFERENCE_CELLS - 1)	<= pos1_v;
			
			-- increment histogram with cell MSB entering the leading/lagging window
			-- decrement histogram with cell MSB leaving the leading/lagging window
			msb_histogram_v(pos3_v) := msb_histogram_v(pos3_v) - 1; -- cell leaving the leading window
			msb_histogram_v(pos4_v) := msb_histogram_v(pos4_v) - 1; -- cell leaving the lagging window
			msb_histogram_v(pos1_v) := msb_histogram_v(pos1_v) + 1; -- cell entering the leading window
			msb_histogram_v(pos2_v) := msb_histogram_v(pos2_v) + 1; -- cell entering the lagging window
			
			
			case cfar_state is
				when idle =>
					valid_s		<= '0';
					if en_delay_s = '0' and en_i = '1' then -- rising edge

						-- debug
						for i in 0 to CFAR_REFERENCE_CELLS-1 loop
							cfar_reference_cells_s(i)	<=	average_signal_noise_i;
						end loop;
						-- set all elements in lookup table to MSB index of average noise input
						avg_noise_msb := find_pos(average_signal_noise_i);
						for i in 0 to CFAR_REFERENCE_CELLS - 1 loop
							reverse_lookup_s(i)	<= avg_noise_msb;
						end loop;
						-- reset histogram and set the MSB for average noise input to 2*CFAR_LEADING_LAGGING_CELLS
						for i in 0 to N-1 loop
							msb_histogram_v(i) := 0;
						end loop;
						msb_histogram_v(avg_noise_msb) := 2*CFAR_LEADING_LAGGING_CELLS;
						
					end if;
	
				when pending =>
					-- waiting for the shift reg to be half filled
	
				when calculation =>
					valid_s	<= '1';
					n_exp_v	:= find_k(msb_histogram_v, 1);--1 --find_k(msb_histogram_v, CFAR_OS_K) -- k-th greatest cell
					
					--assign the n_exp_v_s-th value of k_th_max_v to high;indicates the index of the MSB of the k-th greatest cell
					--will be evaluated in the following
					k_th_max_v 				:= (others => '0');
					k_th_max_v(n_exp_v) 	:= '1';
	
					-- threshold
					--use MSB of k-th largest cell and multiply with dedicated OS-CFAR multiplier
					cfar_threshold_s <= to_std_logic_vec(k_th_max_v * to_unsigned(CFAR_OS_ALPHA_MULTIPLIER,32))(31 downto 0);
					
			end case;
			
			-- PYTHON TEST ONLY
			my_param <= std_logic_vector(CFAR_OS_ALPHA_MULTIPLIER_LONGER_NAME);
			--
			
			
			-- debug
			k_th_max_v_s 		<= k_th_max_v;
			msb_histogram_s	<= msb_histogram_v;
			n_exp_v_s			<= n_exp_v;
			--sorted_histogram_s<= sorted_histogram_v;
			--sorted_idx_s		<= sorted_idx_v;
			
		end if;
	end if;
end process;

END architecture;