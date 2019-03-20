----=====================================================================================================
---- Module Name	:	fft_wrapper
---- Company		:	SEW-Eurodrive GmbH & KG
---- Teamwork of 	:	FK-FN
---- Programmer	:	Maximilian Tosch	
---- Date			:	29.01.2019
---- Function		:  wrapper for fft ip core
----=====================================================================================================
---- ToDo:
----	
----=====================================================================================================

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use ieee.std_logic_unsigned.all;

use work.pktec_evalboard_def_pkg.all;
--use work.pktec_evalboard_config_pkg.all;


library fft;
use fft.all;

--INTERFACE INFO
-- TODO
entity fft_wrapper is
	PORT(
		clk_20_i				: in std_logic;
		reset_i				: in std_logic;
		
		frame_en_i						: in std_logic;
		en_i								: in std_logic;
		fft_sink_real_i				: in std_logic_vector(11 downto 0);
		fft_sink_imag_i				: in std_logic_vector(11 downto 0);
		
		fft_source_real_o				: out std_logic_vector(11 downto 0);
		fft_source_imag_o				: out std_logic_vector(11 downto 0);
		frame_valid_o					: out std_logic; -- exists because fft sometimes doesn't output it's values one every cycle
		valid_o							: out std_logic;
		
		-- DEBUG
--		fft_sink_error_o				: out std_logic_vector(1 downto 0);
		fft_source_error_o			: out std_logic_vector(1 downto 0);
		fft_sink_ready_o				: out std_logic;
		
		fft_data_out_iterator_o		: out integer
);

END fft_wrapper;


ARCHITECTURE behav OF fft_wrapper IS

-- idle: nothing to do, no data available
-- streaming: waiting for FFT to assert sink_ready;only then, we may stream data to the FFT;wait, until pipeline with the underlying memory (dp ram) is filled
-- stall: when the FFT cannot take any more data, it will deassert sink_ready;
type fft_write_state_type is (idle,streaming);--,stall);
signal fft_write_state : fft_write_state_type;
-- idle: nothing to do
-- reading: read data from fft core until all data is read
type fft_read_state_type is (idle,reading);
signal fft_read_state : fft_read_state_type;

-- counter
--signal fft_data_in_iterator_s		: integer range 0 to SENSOR_DATA_LENGTH-1;	--iterator used to control data input into the fft
signal fft_data_out_iterator_s	: integer range 0 to FFT_LENGTH;		--iterator used to control data output of the fft

--###FFT signals
signal fft_sink_valid_s		: std_logic;	--asserted by the data source that provides input to the fft
signal fft_sink_sop_s		: std_logic;	--indicate start of a new packet
signal fft_sink_eop_s		: std_logic;	--indicate end of a packet
signal fft_sink_real_s		: std_logic_vector(11 downto 0);	--real part of input data
signal fft_sink_imag_s		: std_logic_vector(11 downto 0);	--imag part of input data
--signal fft_sink_error_s		: std_logic_vector(1 downto 0);	--data source that provides input to the fft has detected an error
signal fft_source_ready_s	: std_logic;	--asserted by the downstream module if it can accept data;this would be the module storing the fft result
signal fft_sink_ready_s		: std_logic;	--FFT can accept data
signal fft_source_error_s	: std_logic_vector(1 downto 0);	--FFT has detected an error
signal fft_source_sop_s		: std_logic;	--indicate start of FFT packet
signal fft_source_eop_s		: std_logic;	--indicate end of FFT packet
signal fft_source_valid_s	: std_logic;	--FFT has valid data to deliver on its output port

---- Output SIGNALS ----
signal frame_valid_s			: std_logic;
signal valid_s					: std_logic;
signal fft_source_real_o_s	: std_logic_vector(11 downto 0);	-- i output data
signal fft_source_imag_o_s	: std_logic_vector(11 downto 0);	-- q output data

signal fft_source_real_s	: std_logic_vector(11 downto 0);	-- i output data
signal fft_source_imag_s	: std_logic_vector(11 downto 0);	-- q output data


---- Input SIGNALS ----
signal frame_en_delay_s	: std_logic;

signal reset_inv : std_logic;


BEGIN

--OUTPUT
frame_valid_o				<= frame_valid_s;
valid_o 						<= valid_s;
--fft_source_valid_o		<= fft_source_valid_s;
--fft_source_sop_o		<= fft_source_sop_s;
fft_source_real_o			<= fft_source_real_o_s;
fft_source_imag_o			<= fft_source_imag_o_s;

--fft_sink_error_o 		<= fft_sink_error_s;
fft_source_error_o 		<= fft_source_error_s;
fft_sink_ready_o			<= fft_sink_ready_s;
--debug
fft_data_out_iterator_o	<= fft_data_out_iterator_s;

reset_inv <= not reset_i;

--FFT WRITE PROCESS
--write data to the fft engine ports when new data is available
--start streaming and set sop (startofpacket) and eop (endofpacket) accordingly, until all values have been sent
--currently, we do not test whether the fft engine stalls during write operation; we only wait for the first sink_ready and assume 
--that it will be ready until all data has been sent: this is a valid assumption
fft_write_proc: process(clk_20_i)
begin
	if rising_edge(clk_20_i) then
		if reset_i = '1' then
			fft_sink_valid_s			<= '0';
			fft_sink_sop_s				<= '0';
			fft_sink_eop_s				<= '1';
			fft_sink_real_s			<= (others => '0');
			fft_sink_imag_s			<= (others => '0');
			fft_write_state			<= idle;
			frame_en_delay_s			<= '0';
		else
		
			frame_en_delay_s  <= frame_en_i;
			
			case fft_write_state is
				when idle =>
					fft_sink_valid_s		<= '0';
					fft_sink_sop_s			<= '0';
					fft_sink_eop_s			<= '0';
					
					--if fft_enable_s = '1' and fft_sink_ready_s = '1' then	--it could be necessary to test whether the fft engine is ready to receive data
					if frame_en_delay_s = '0' and frame_en_i = '1' then -- rising edge
						fft_sink_sop_s		<= '1';
						fft_sink_valid_s	<= '1';
						fft_sink_real_s	<= fft_sink_real_i;
						fft_sink_imag_s	<= fft_sink_imag_i;
						fft_write_state	<= streaming;
					end if;
					
				when streaming =>
					fft_sink_sop_s	<= '0';
					
					-- this if-else is here to support an uncontinuous data input stream (currently not the case)
					if en_i = '1' then
						fft_sink_valid_s	<= '1';
						fft_sink_real_s	<= fft_sink_real_i;
						fft_sink_imag_s	<= fft_sink_imag_i;
					else
						fft_sink_valid_s	<= '0';
					end if;
					
					if frame_en_delay_s = '1' and frame_en_i = '0' then -- falling edge
						fft_write_state	<= idle;
						fft_sink_eop_s		<= '1';
					else
						
					end if;
					
--				when stall => 
					-- enter this when fft_sink_ready goes to '0'. currently not implemented
				
			end case;
		end if;
	end if;
end process;


--FFT READ PROCESS
--process for the fft engine output
--is controlled by the output of the fft engine signals
fft_read_proc: process(clk_20_i)
begin
	if rising_edge(clk_20_i) then
		if reset_i = '1' then
			fft_read_state					<= idle;
			fft_source_ready_s			<= '0';
			valid_s							<= '0';
			fft_data_out_iterator_s		<= 0;
		else
		
			case fft_read_state is
				when idle =>
					--FFT engine can start delivering valid data when source_valid and source_start-of-packet is high
					if fft_source_valid_s = '1' and fft_source_sop_s = '1' then
						frame_valid_s					<= '1'; -- frame valid is high one cycle before valid and the actual data output
						fft_data_out_iterator_s		<= 1;
						fft_source_ready_s			<= '1'; --indicates that we're ready to read data. MAYBE ONE CYCLE LATER?
						fft_read_state 				<= reading;
					end if;
					
				when reading =>
					valid_s <= '0';
					--
					if fft_data_out_iterator_s = FFT_LENGTH / 2 then
						frame_valid_s <= '0';
					end if;
					
					-- end of packet (1 frame)
					if fft_source_eop_s = '1' then --fft_data_out_iterator_s = FFT_LENGTH / 2 then
						fft_read_state 		<= idle;
						fft_source_ready_s 	<= '0';
					else
						-- fft core output data is available (valid)
						if fft_source_valid_s = '1' then --and fft_data_out_iterator_s < FFT_LENGTH / 2 then --/ 2 then
							-- NOTE: fft_source_valid_s will stay high for the second half of the spectrum too (full FFT LENGTH)
							-- fft_sink_ready_s will be asserted high only after the the full length was delivered by the core
							-- this is why fft_source_ready_s (set by the user) will stay high for the entire FFT LENGTH
							if fft_data_out_iterator_s < FFT_LENGTH / 2 then 
								fft_source_real_o_s 	<= fft_source_real_s;
								fft_source_imag_o_s 	<= fft_source_imag_s;
								valid_s					<= '1';
							end if;
							fft_data_out_iterator_s	<= fft_data_out_iterator_s + 1;
						end if;
					end if;
					
			end case;
		end if;
	end if;
end process;


--FFT INSTANCE
fft_inst: entity fft.fft
port map(
	-- INPUTS --
	clk				=> clk_20_i,
	reset_n			=> reset_inv,--reset_inv_new,
	sink_valid		=> fft_sink_valid_s,  -- set this to high first before feeding data to fft
	sink_ready		=> fft_sink_ready_s,  -- indicates wether fft engine is ready to receive data or not
--	sink_error		=> "00",--fft_sink_error_s,
	sink_sop			=> fft_sink_sop_s, 	 -- sop: start of packet
	sink_eop			=> fft_sink_eop_s, 	 -- eop: end of packet. Set this to high after one frame! (2048 samples)
	sink_real		=> fft_sink_real_s,   -- I-data input
	sink_imag		=> fft_sink_imag_s, 	 -- Q-data input
-- inverse			=> (others => '0'),
	source_ready	=> fft_source_ready_s,-- set this to high when ready to receive data
	-- OUTPUTS --
	source_valid	=> fft_source_valid_s,-- high when data is available on the fft outputs
	source_error	=> fft_source_error_s,
	source_sop		=> fft_source_sop_s,  -- marks the start of the outgoing FFT frame. Only valid when source_valid is asserted
	source_eop		=> fft_source_eop_s,
	source_real		=> fft_source_real_s, -- I-data output
	source_imag		=> fft_source_imag_s, -- Q-data output
	source_exp		=> open--fft_source_exp_s   -- signed block exponent;accounts for scaling of internal signal values during FFT computation. stays constant within one frame
);

END architecture;