----=====================================================================================================
---- Module Name	:	windowing
---- Company		:	SEW-Eurodrive GmbH & KG
---- Teamwork of 	:	FK-FN
---- Programmer	:	Maximilian Tosch
---- Date			:	23.01.2019
---- Function		:  TODO
----=====================================================================================================
---- TODO:
----	
----=====================================================================================================


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

use work.pktec_evalboard_def_pkg.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

--INTERFACE INFO
--windowing_enable: in contrast to the Frame_vd and Valid signals that are commonly used for control, windowing is enabled by setting the enable signal to high for at least 1 clock cycle
--i_q_data_ram_[rdaddress/q]: ports to read from the data ram implemented in the processing chain
--spi_packet_[q/i]_data_average: input of the average value of the received spi packet;used here to subtract before windowing, reduces DC value
--Frame_vd/Valid: activate further processing;both signals will stay high until the data transmission has finished
--windowed_sample_[i/q]_data: data output of windowed samples
entity windowing is
	PORT(
		clk_20_i				: in std_logic;
		reset_i				: in std_logic;
		
		en_i									: in std_logic;
		i_q_data_fifo_q_i					: in std_logic_vector(31 downto 0);
		i_q_data_ram_rdaddress_o		: out std_logic_vector(10 downto 0); -- debug signaltap
		-- TODO maybe can't use this empty flag. will have to use counter. FIFO may never be emtpy as it could be filled again during windowing calculation
		-- Windowing calculation takes >=2048 clock cycles
		--i_q_data_fifo_empty_i			: in std_logic; 
		--
		spi_packet_i_data_average_i	: in integer;
		spi_packet_q_data_average_i	: in integer;
		-- request data from FIFO
		i_q_data_fifo_rdreq_o			: out std_logic;
		
		frame_valid_o						: out std_logic;
		valid_o								: out std_logic;
		-- actual output
		windowed_sample_i_data_o		: out std_logic_vector(11 downto 0);
		windowed_sample_q_data_o		: out std_logic_vector(11 downto 0)
);

END windowing;

ARCHITECTURE behav OF windowing IS

--ROM signals
signal windowing_rom_rdaddress_s : unsigned(10 downto 0) := (others => '0');
signal windowing_rom_q_s			: std_logic_vector(15 downto 0);

-- control process (state machine)
type state_type is (idle,calculation);
signal state 		: state_type;
signal counter_s	: integer range 0 to 2047 := 0; -- SENSOR_DATA_LENGTH (frame length)

-- calculation
signal windowed_sample_i_data_temp_s	: integer := 0; -- TODO range this integer!
signal windowed_sample_q_data_temp_s	: integer := 0; -- TODO range this integer!

--I_Q_DATA_FIFO
signal i_q_data_fifo_rdreq_s				: std_logic;

--OUTPUT signals
signal frame_valid_s							: std_logic;
signal valid_s									: std_logic;
signal windowed_sample_i_data_s			: std_logic_vector(11 downto 0);
signal windowed_sample_q_data_s			: std_logic_vector(11 downto 0);

BEGIN

windowing_rom: entity work.single_port_rom_16_width_2048_length
	port map(
		clock			=> clk_20_i,
		address		=> std_logic_vector(windowing_rom_rdaddress_s),
		q				=> windowing_rom_q_s
	);
	
--windowing_rom_q_s <= std_logic_vector(to_signed(16384,16)); -- -- use for testing in ModelSim maybe

--OUTPUT wiring
frame_valid_o					<= frame_valid_s;
valid_o							<= valid_s;
i_q_data_fifo_rdreq_o		<= i_q_data_fifo_rdreq_s;

windowed_sample_i_data_o	<= windowed_sample_i_data_s;
windowed_sample_q_data_o	<= windowed_sample_q_data_s;

i_q_data_ram_rdaddress_o 	<= std_logic_vector(windowing_rom_rdaddress_s); -- debug signaltap

windowing_rom_rdaddress_s <= to_unsigned(counter_s,11); -- increment counter (ROM address)



-- WINDOWING CONTROL PROC
-- TODO
windowing_control_proc:	process(clk_20_i)
begin
if rising_edge(clk_20_i) then
		if reset_i = '1' then
			state 						<= idle;
			i_q_data_fifo_rdreq_s 	<= '0';
			counter_s					<= 0;
			frame_valid_s				<= '0';
			valid_s						<= '0';
		else
			case state is
				when idle =>
					frame_valid_s	<= '0';
					valid_s 			<= '0'; -- putting this here might not be necessary
					counter_s 		<= 0;
					if en_i = '1' then
						i_q_data_fifo_rdreq_s <= '1'; -- issue read request to FIFO (data will be available next clock cycle). No delay needed
						frame_valid_s	<= '1';
						state 			<= calculation;
					end if;
					
				when calculation =>
					valid_s	<= '1';
					counter_s <= counter_s + 1;
					if counter_s = 2047 then -- 2047 values (1 frame) have been read from FIFO, go back to idle
						i_q_data_fifo_rdreq_s 	<= '0';
						state							<= idle;
--						frame_valid_s				<= '0';
						--valid_s 						<= '0';
					end if;
					
			end case;
		end if;
end if;
end process;




--WINDOWING CALCULCATION PROCESS
--implements the state machine for windowing and the i_q_data_ram access
--idle: wait for enable signal
--calculation: do the calculation and write valid addresses to the bus
-- TODO description of the calculation!
windowing_calculation_proc: process(clk_20_i)
begin
	if rising_edge(clk_20_i) then
		if reset_i = '1' then
			windowed_sample_i_data_s			<= (others => '0');
			windowed_sample_q_data_s			<= (others => '0');
			windowed_sample_i_data_temp_s		<= 0;
			windowed_sample_q_data_temp_s		<= 0;
		else	
			case state is
				when idle =>
--					windowed_sample_i_data_s			<= (others => '0');
--					windowed_sample_q_data_s			<= (others => '0');
--					valid_s									<= '0';
--					frame_valid_s							<= '0';
				
				when calculation =>
					--SUBTRACT AVERAGE AND DO WINDOWING HERE
					--because of subtracting the average value of a signal that is only positive (0 to 4095) it is possible to reach the limits of our dynamic range
					--this is taken into account below
					windowed_sample_i_data_temp_s <= to_integer(to_signed(to_integer(unsigned(i_q_data_fifo_q_i(27 downto 16))) - spi_packet_i_data_average_i,16) * signed(windowing_rom_q_s) / to_signed(16384,16));
					windowed_sample_q_data_temp_s <= to_integer(to_signed(to_integer(unsigned(i_q_data_fifo_q_i(11 downto 0))) - spi_packet_q_data_average_i,16) * signed(windowing_rom_q_s) / to_signed(16384,16));
				
					-- I DATA
					if windowed_sample_i_data_temp_s < (-2**SENSOR_DATA_BIT_WIDTH / 2) then
						--reached lower limit, set value to lowest possible
						windowed_sample_i_data_s	<= std_logic_vector(to_signed(-2**SENSOR_DATA_BIT_WIDTH / 2, 12)); -- SENSOR_DATA_BIT_WIDTH = 12
					elsif windowed_sample_i_data_temp_s >= 2**SENSOR_DATA_BIT_WIDTH / 2 then
						--reached upper limit, set value to highest possible
						windowed_sample_i_data_s	<= std_logic_vector(to_signed(2**SENSOR_DATA_BIT_WIDTH / 2 - 1, 12));
					else
						windowed_sample_i_data_s	<= std_logic_vector(to_signed(windowed_sample_i_data_temp_s,12));
					end if;
					
					-- Q DATA
					if windowed_sample_q_data_temp_s < (-2**SENSOR_DATA_BIT_WIDTH / 2) then
						windowed_sample_q_data_s	<= std_logic_vector(to_signed(-2**SENSOR_DATA_BIT_WIDTH / 2, 12));
					elsif windowed_sample_q_data_temp_s >= 2**SENSOR_DATA_BIT_WIDTH / 2 then
						windowed_sample_q_data_s	<= std_logic_vector(to_signed(2**SENSOR_DATA_BIT_WIDTH / 2 - 1, 12));
					else
						windowed_sample_q_data_s	<= std_logic_vector(to_signed(windowed_sample_q_data_temp_s,12));
					end if;
					
			end case;
		end if;
	end if;
end process;


END ARCHITECTURE;