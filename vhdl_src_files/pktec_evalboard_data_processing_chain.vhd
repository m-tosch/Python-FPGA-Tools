----=====================================================================================================
---- Module Name	:	pktec_evalboard_data_processing_chain
---- Company		:	SEW-Eurodrive GmbH & KG
---- Teamwork of 	:	FK-FN
---- Programmer	:	Maximilian Tosch	
---- Date			:	22.01.2019
---- Function		:  Glues together the elements in the processing chain
----=====================================================================================================
---- TODO:
----	
----=====================================================================================================


LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
--use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.pktec_evalboard_def_pkg.all;
--use work.pktec_evalboard_config_pkg.all;

--INTERFACE INFO
--pktec_evalboard_spi_receive_[frame_valid/packet_valid/packet]: receive interface for transmission from pktec_evalboard to processing chain in PHY;more information in pktec_evalboard.vhd
--distance_rom_[q/read_enable]: distance rom is instantiated only once, this interface serves to read data without writing an address;when read_enable is set to high, a process in PHY_layer begins reading from address 0
--Frame_vd/Valid: indicates that output of processing chain is valid;both are high for a single clock cycle, indicating that peak_detected[_/_distance/_vector] is valid
--peak_detected: a peak/target was detected within the range we have specified (in pktec_evalboard_def_pkg)
--peak_detected_distance: closest distance where a target was detected
--peak_detected_vector: indicates all bins within the valid distance bin range (as specified in pktec_evalboard_def_pkg) where a target has been detected;is therefore DETECTION_EVALUATION_UPPER_BIN_LIMIT bits wide

entity pktec_evalboard_data_processing_chain is
	PORT ( 
		clk_20_i			: in std_logic;
		--clk_50_i			: in std_logic;

		reset_i			: in std_logic;
	
		pktec_evalboard_spi_receive_frame_en_i			: in std_logic;
		pktec_evalboard_spi_receive_packet_en_i		: in std_logic;
		pktec_evalboard_spi_receive_packet_i			: in std_logic_vector(31 downto 0);
		
		sensor_state_i											: in sensor_state_type;
		
		distance_rom_q_i										: in std_logic_vector(17 downto 0);
		distance_rom_read_enable_o							: out std_logic;
		
		valid_o													: out std_logic;
		
		peak_detected_o										: out std_logic;
		peak_detected_distance_o							: out std_logic_vector(17 downto 0);
		peak_detected_vector_o								: out std_logic_vector(DETECTION_EVALUATION_UPPER_BIN_LIMIT-1 downto 0)
);

END pktec_evalboard_data_processing_chain;

ARCHITECTURE struc OF pktec_evalboard_data_processing_chain IS

-- SIGNALS BETWEEN PIPELINE STAGES
-- pktec receive
signal pktec_receive_inst_average_en_s						: std_logic;
-- data average	
signal data_average_inst_valid_s								: std_logic;
signal data_average_inst_spi_packet_i_data_average_s	: integer; -- TODO DEFINATELY range this!
signal data_average_inst_spi_packet_q_data_average_s	: integer; -- 32 bit is too much
-- windowing
signal windowing_inst_frame_valid_s							: std_logic;
signal windowing_inst_valid_s									: std_logic;
signal windowing_inst_windowed_sample_i_data_s			: std_logic_vector(11 downto 0);
signal windowing_inst_windowed_sample_q_data_s			: std_logic_vector(11 downto 0);
-- FFT wrapper
signal fft_wrapper_inst_frame_valid_s 						: std_logic;
signal fft_wrapper_inst_valid_s 								: std_logic;
signal fft_wrapper_inst_fft_source_real_s					: std_logic_vector(11 downto 0);
signal fft_wrapper_inst_fft_source_imag_s					: std_logic_vector(11 downto 0);
--signal fft_wrapper_inst_fft_source_exp_s				: std_logic_vector(5 downto 0);
-- FFT post-processing (square add)
--signal fft_post_processing_inst_valid_s 				: std_logic;
--signal fft_post_processing_inst_data_s					: std_logic_vector(31 downto 0);
signal square_add_inst_frame_valid_s			 			: std_logic;
signal square_add_inst_valid_s			 					: std_logic;
signal square_add_inst_data_s				 					: unsigned(24 downto 0);
-- cfar
signal cfar_inst_valid_s										: std_logic;
signal cfar_inst_fft_processed_data_s						: std_logic_vector(24 downto 0);
signal cfar_inst_cfar_threshold_s							: std_logic_vector(31 downto 0);
signal cfar_inst_average_signal_noise_s					: std_logic_vector(24 downto 0);
-- maximum detection
signal maximum_detection_inst_valid_s						: std_logic;
signal maximum_detection_inst_local_maxium_s				: std_logic;
--signal maximum_detection_inst_maximum_gain_s			: std_logic_vector(2 downto 0);
-- average signal noise
signal average_signal_noise_inst_valid_s					: std_logic;
signal average_signal_noise_inst_data_s					: unsigned(24 downto 0);

-- peak evaluation
signal peak_en_s															: std_logic;
signal peak_evaluation_inst_valid_s									: std_logic;
--signal peak_evaluation_inst_signal_classification_s			: signal_classification_type;
--signal peak_evaluation_inst_cfar_peak_detected_raw_s			: std_logic;
--signal peak_evaluation_inst_cfar_peak_detected_s				: std_logic;
--signal peak_evaluation_inst_cfar_peak_detected_validated_s	: std_logic;
--signal peak_evaluation_inst_maximum_gain_s						: std_logic_vector(2 downto 0);
-- decider
signal decider_inst_valid_s											: std_logic;
signal decider_inst_peak_detected_s									: std_logic;
signal decider_inst_peak_detected_distance_s						: std_logic_vector(17 downto 0);
signal decider_inst_peak_detected_vector_s						: std_logic_vector(DETECTION_EVALUATION_UPPER_BIN_LIMIT-1 downto 0);	
signal decider_inst_peak_near_range_vd_s							: std_logic := '0';	--feedback signal from decider to fft to block data input into the NRL filter once a target has been detected within the specified range (pktec_evalboard_def_pkg)

--DISTANCE ROM
--signals to the in and out ports to trigger reading from the externally instantiated distance rom
signal distance_rom_read_enable_s									: std_logic;

-- FIFO SIGNALS --
--DP FIFO signals
--ram for received data sent to the PHY layer by the pktec evalboard instance
signal pktec_receive_inst_i_q_data_fifo_data_s					: std_logic_vector(31 downto 0);
signal pktec_receive_inst_i_q_data_fifo_wrreq_s					: std_logic;
signal windowing_inst_i_q_data_fifo_rdreq_s						: std_logic;
signal i_q_data_fifo_q_s												: std_logic_vector(31 downto 0);
signal i_q_data_fifo_full												:	std_logic;

--signaltap debug RAM .mif
signal pktec_receive_inst_i_q_data_ram_data_s					: std_logic_vector(31 downto 0);
signal windowing_inst_i_q_data_ram_rdaddress_s					: std_logic_vector(10 downto 0);
signal pktec_receive_inst_i_q_data_ram_wraddress_s				: std_logic_vector(10 downto 0);
signal pktec_receive_inst_i_q_data_ram_wren_s					: std_logic;
signal i_q_data_ram_q_s													: std_logic_vector(31 downto 0);
-----


-- FFT_PROCESSED_DATA_FIFO
signal fft_processed_data_fifo_data_s								: std_logic_vector(24 downto 0);
signal fft_processed_data_fifo_full_s								: std_logic;
signal fft_processed_data_fifo_rdreq_s								: std_logic;
-- CFAR_DATA_FIFO
signal cfar_threshold_fifo_data_s									: std_logic_vector(24 downto 0);
signal cfar_threshold_fifo_full_s									: std_logic;
signal cfar_threshold_fifo_rdreq_s									: std_logic;
-- MAXIMUM_DETECTION_DATA_FIFO
signal maximum_detection_fifo_data_s								: std_logic;
signal maximum_detection_fifo_full_s								: std_logic;
signal maximum_detection_fifo_rdreq_s								: std_logic;



BEGIN


--peak_en_s						<= cfar_inst_valid_s and maximum_detection_inst_valid_s;
peak_en_s						<= fft_processed_data_fifo_full_s and cfar_threshold_fifo_full_s and maximum_detection_fifo_full_s;

--OUTPUT
distance_rom_read_enable_o	<= distance_rom_read_enable_s;
valid_o							<= decider_inst_valid_s;
peak_detected_o				<= decider_inst_peak_detected_s;
peak_detected_distance_o	<= decider_inst_peak_detected_distance_s;
peak_detected_vector_o		<= decider_inst_peak_detected_vector_s;


 --OLD (debug)
--I_Q_DATA_RAM: stores data received from the pktec evalboard;
--this is necessary because we only receive 1 bit during a clock cycle via SPI
--since the clock for SPI is limited to 10 MHz, we need to store data before we feed it into the data processing chain, 
--which is runs at 20 MHz processes 32bit during 1 clock cycle 
--i_q_data_ram: entity work.dual_port_ram_32_width_2048_length
--	port map(
--		clock 		=> clk_20_i,
--		data			=> pktec_receive_inst_i_q_data_ram_data_s,
--		rdaddress	=> windowing_inst_i_q_data_ram_rdaddress_s,
--		wraddress	=> pktec_receive_inst_i_q_data_ram_wraddress_s,
--		wren			=> pktec_receive_inst_i_q_data_ram_wren_s,
--		q				=> i_q_data_ram_q_s
--	);

---- NEW
---- I_Q_DATA_FIFO: stores data received from the pktec evalboard
i_q_data_fifo: entity work.fifo_32_width_2048_length
	port map(
		clock		=>	clk_20_i,
		sclr		=> reset_i,
		data		=> pktec_receive_inst_i_q_data_fifo_data_s,
		wrreq		=> pktec_receive_inst_i_q_data_fifo_wrreq_s,
		rdreq		=> windowing_inst_i_q_data_fifo_rdreq_s,
		empty		=> open,
		full		=> i_q_data_fifo_full,
		q			=> i_q_data_fifo_q_s
	);
	
-- FFT_PROCESSED_DATA_FIFO:
-- stores fft data after post processing with i²+q² (square add)
fft_processed_data_fifo: entity work.fifo_25_width_1024_length
	port map(
		clock		=>	clk_20_i,
		sclr		=> reset_i,
		data		=> std_logic_vector(square_add_inst_data_s),
		wrreq		=> square_add_inst_valid_s,
		rdreq		=> '0',
		empty		=> open,
		full		=> fft_processed_data_fifo_full_s,
		q			=> fft_processed_data_fifo_data_s
	);
	
-- CFAR_DATA_FIFO
-- stores one cfar threshold data for every bin in the spectrum
cfar_threshold_fifo: entity work.fifo_25_width_1024_length
	port map(
		clock		=>	clk_20_i,
		sclr		=> reset_i,
		data		=> cfar_inst_cfar_threshold_s(24 downto 0),
		wrreq		=> cfar_inst_valid_s,
		rdreq		=> '0',
		empty		=> open,
		full		=> cfar_threshold_fifo_full_s,
		q			=> cfar_threshold_fifo_data_s
	);
	
-- MAXIMUM_DETECTION_DATA_FIFO
-- stores either '1' or '0' for all values indicating if this value is a local maximum (i.e. it's greater than it's direct neighbors)
local_maximum_fifo: entity work.fifo_1_width_1024_length
	port map(
		clock		=>	clk_20_i,
		sclr		=> reset_i,
		data(0)	=> maximum_detection_inst_local_maxium_s, -- data(0) to associate one element. this will assign the whole vector since the input width for this fifo is 1 (std_logic_vector(0 downto 0))
		wrreq		=> maximum_detection_inst_valid_s,
		rdreq		=> '0',
		empty		=> open,
		full		=> maximum_detection_fifo_full_s,
		q(0)		=> maximum_detection_fifo_data_s
	);
	


--PKTEC RECEIVE INSTANCE
--receive data from pktec evalboard instance and store it in the I_Q_DATA_RAM
--after a successful transmission, activate windowing, which will read data from the RAM
pktec_receive_inst: entity work.pktec_receive
	port map(
		clk_20_i		=> clk_20_i,
		reset_i		=> reset_i,
		
		pktec_evalboard_spi_frame_en_i	=> pktec_evalboard_spi_receive_frame_en_i,	
		pktec_evalboard_spi_packet_en_i	=> pktec_evalboard_spi_receive_packet_en_i,
		pktec_evalboard_spi_packet_i		=> pktec_evalboard_spi_receive_packet_i,
		
		--i_q_data_ram_wraddress_o			=> pktec_receive_inst_i_q_data_ram_wraddress_s,
		i_q_data_fifo_data_o					=> pktec_receive_inst_i_q_data_fifo_data_s,
		i_q_data_fifo_wrreq_o				=> pktec_receive_inst_i_q_data_fifo_wrreq_s,
		valid_o									=> pktec_receive_inst_average_en_s
	);

-- DATA AVERAGE INSTANCE
-- receive data from pktec receive instance and calculates the average of a frame
-- outputs this average for both i and q into the windowing module
data_average_inst : entity work.data_average
	port map(
		clk_20_i		=> clk_20_i,
		reset_i		=> reset_i,
		
		i_q_data_i								=> pktec_receive_inst_i_q_data_fifo_data_s,
		i_q_data_en_i							=> pktec_receive_inst_i_q_data_fifo_wrreq_s,
		en_i										=> pktec_receive_inst_average_en_s,
		
		valid_o									=> data_average_inst_valid_s, -- maybe let the FIFOs "full" signal do this
		spi_packet_i_data_average_o		=> data_average_inst_spi_packet_i_data_average_s,
		spi_packet_q_data_average_o		=> data_average_inst_spi_packet_q_data_average_s
	);

--WINDOWING INSTANCE
--activated by the receive instance;read data from IQ FIFO Block
--subtract the average value so that the signal oscillates around 0
--then apply a window to limit the leakage
--once valid data is available, set Frame_vd and Valid and output data via the 'windowed_sample_[i/q]_data'
windowing_inst: entity work.windowing
	port map(
		clk_20_i		=> clk_20_i,
		reset_i		=> reset_i,
		
		i_q_data_fifo_q_i					=> i_q_data_fifo_q_s, -- data from FIFO block -- i_q_data_ram_q_s, -- debug signaltap
		
		--i_q_data_fifo_empty_i			=> i_q_data_fifo_empty_s,
		en_i									=> i_q_data_fifo_full, --and data_average_inst_valid_s,--data_average_inst_valid_s, -- '1'
		spi_packet_i_data_average_i	=> data_average_inst_spi_packet_i_data_average_s,
		spi_packet_q_data_average_i	=> data_average_inst_spi_packet_q_data_average_s,
		
		i_q_data_ram_rdaddress_o		=> open,--windowing_inst_i_q_data_ram_rdaddress_s, -- debug signaltap
		i_q_data_fifo_rdreq_o			=> windowing_inst_i_q_data_fifo_rdreq_s, -- read from FIFO block
		-- actual outputs
		frame_valid_o						=> windowing_inst_frame_valid_s,
		valid_o								=> windowing_inst_valid_s,
		windowed_sample_i_data_o		=> windowing_inst_windowed_sample_i_data_s,
		windowed_sample_q_data_o		=> windowing_inst_windowed_sample_q_data_s
	);

	
--FFT WRAPPER INSTANCE
--activated through windowing;receives windowed samples from windowing
--contains the fft engine (2048 x 12 bit)
--this instance feeds data into the fft engine 
--i.a., this post-processing includes scaling, squaring, averaging, NRL filter
--once data is available, Frame_vd and Valid are set to activate cfar_calculation and maximum_detection
fft_wrapper_inst: entity work.fft_wrapper
	port map(
		clk_20_i		=> clk_20_i,
		--clk_50_i	=> clk_50_i,
		reset_i		=> reset_i,
		frame_en_i						=> windowing_inst_frame_valid_s,
		en_i								=> windowing_inst_valid_s,
		
		fft_sink_real_i				=> windowing_inst_windowed_sample_i_data_s,
		fft_sink_imag_i				=> windowing_inst_windowed_sample_q_data_s,
		
		frame_valid_o					=> fft_wrapper_inst_frame_valid_s,
		valid_o							=> fft_wrapper_inst_valid_s,
		fft_source_real_o				=> fft_wrapper_inst_fft_source_real_s,
		fft_source_imag_o				=> fft_wrapper_inst_fft_source_imag_s,
		
		--debug
		fft_source_error_o			=> open,
		fft_sink_ready_o				=> open,
		fft_data_out_iterator_o		=> open
	);
	

-- FFT POST PROCESSING
-- currently square add only
	-- square_add real & imag (I² + Q²)
square_add_inst : entity work.square_add
	generic map(
		N	=>	12, -- input bit width (e.g. 12)
		M	=> 25  -- output bit width (e.g. 32) -- TODO this can be calculated from input bit width N
	)
	port map(
		clk_20_i			=> clk_20_i,
		reset_i			=> reset_i,
		frame_en_i		=> fft_wrapper_inst_frame_valid_s,
		en_i				=> fft_wrapper_inst_valid_s,
		data_real_i		=> signed(fft_wrapper_inst_fft_source_real_s),
		data_imag_i		=> signed(fft_wrapper_inst_fft_source_imag_s),
		frame_valid_o	=> square_add_inst_frame_valid_s,
		valid_o			=> square_add_inst_valid_s,
		data_o			=> square_add_inst_data_s
	);


--
--SIGNAL AVERAGING INSTANCE ( + NRL)
-- post processing data from after the FFT
--signal_averaging_inst : entity work.signal_averaging
--	port map(
--		-- TODO
--	);
--
	
----CFAR CALCULATION INSTANCE
----receives data from fft_calculation and calculates a cfar threshold from this data dynamically
----implemented are OS, CA and SOCA CFAR algorithms; as default, we use OS to achieve best results regarding target masking
----to minimize calculation effort, the sorting algorithm implemented only calculates the approximate results
----is activated by Frame_vd and Valid by the fft_calculation
----average_signal_noise is derived from the signal to derive the signal level in comparison to this noise level (signal classification in peak_evaluation)
--cfar_inst : entity work.cfar
--	generic map(
--		N => 32
--	)
--	port map(
--		clk_20_i		=> clk_20_i,
--		reset_i		=> reset_i,
--		
--		en_i					=> square_add_inst_valid_s,--fft_post_processing_inst_valid_s,
--		data_i				=> square_add_inst_data_s,--fft_post_processing_inst_data_s,
--		
--		valid_o				=> cfar_inst_valid_s,	
--		cfar_threshold_o	=> cfar_inst_cfar_threshold_s		
--	);


-- AVERAGE SIGNAL NOISE INSTANCE
average_signal_noise_inst : entity work.average_signal_noise
	generic map(
		N => 25
	)
	port map(
		clk_20_i						=>	clk_20_i,
		reset_i						=>	reset_i,
		frame_en_i					=> square_add_inst_frame_valid_s,
		en_i							=>	square_add_inst_valid_s,
		data_i 						=>	square_add_inst_data_s,
		valid_o						=>	open,--average_signal_noise_inst_valid_s,
		average_signal_noise_o	=> average_signal_noise_inst_data_s
	);
	

--OS CFAR cALCULATION INSTANCE
cfar_os_inst : entity work.cfar_os
	generic map(
		N => 32
	)
	port map(
		clk_20_i		=> clk_20_i,
		reset_i		=> reset_i,
		
		frame_en_i					=> square_add_inst_frame_valid_s,
		en_i							=> square_add_inst_valid_s,--fft_post_processing_inst_valid_s,
		data_i						=> "0000000" & square_add_inst_data_s,--fft_post_processing_inst_data_s,
		average_signal_noise_i	=> "0000000" & average_signal_noise_inst_data_s,
		
		valid_o						=> cfar_inst_valid_s,	
		cfar_threshold_o			=> cfar_inst_cfar_threshold_s		
	);

-- MAXIMUM DETECTION INSTANCE
-- detects a local maximum (peak) in a data set
-- Holds a shift register of 2 values, checks on incoming data if the new value is higher than the old one. if yes, the new value is now the local maximum
-- this continues until an incoming value is lower than the previous one. Then, the previous value is a maximum
maximum_detection_inst : entity work.maximum_detection
	generic map(
		N => 25
	)
	port map(
		clk_20_i					=>	clk_20_i,
		reset_i					=>	reset_i,
		
		frame_en_i				=> square_add_inst_frame_valid_s,
		en_i						=>	square_add_inst_valid_s,
		data_i 					=>	square_add_inst_data_s,
		
		--debug
		data_o					=> open,

		valid_o					=>	maximum_detection_inst_valid_s,
		maximum_detected_o	=> maximum_detection_inst_local_maxium_s
	);
	

-- dummy for future peak evaluation
peak_evaluation2_inst: entity work.peak_evaluation2
	generic map(
		N => 25
	)
	port map(
		clk_20_i 						=> clk_20_i,
		reset_i							=> reset_i,
		
		en_i								=> peak_en_s,
		fft_processed_data_i			=> fft_processed_data_fifo_data_s,
		average_signal_noise_i		=> std_logic_vector(average_signal_noise_inst_data_s),
		cfar_threshold_i				=> cfar_threshold_fifo_data_s,
		local_maximum_i				=> maximum_detection_fifo_data_s,
		
		valid_o							=> open
	);

----GAIN DETECTION INSTANCE
----receives data from fft_calculation
----in order to make out peaks/maxima in the fft spectrum, the requirement is set that left and right to a possible peak, there has to be a certain slope within a pre-determined bin range
----this slope is characterised by setting a maximum_gain; this is sent to the peak_evaluation when Frame_vd and Valid are set to high
----to account for the time difference in processing between cfar and maximum detection, there is and additional delay process implemented
--gain_detection_inst: entity work.gain_detection
--	generic map(
--		N => 32
--	)
--	port map(
--		clk_20_i => clk_20_i,
--		reset_i	=> reset_i,
--	
--		en_i								=> square_add_inst_valid_s,
--		fft_processed_data_i			=> square_add_inst_data_s,
--		
--		valid_o							=> maximum_detection_inst_valid_s,
--		gain_o							=> maximum_detection_inst_maximum_gain_s,
--
--		--DEBUG
--		maximum_back_gain_o			=> open,
--		maximum_front_gain_o			=> open,
--		local_maximum_valid_o		=> open,
--		fft_shifted_data_o			=> open
--		--DEBUG
--	);


	
----PEAK EVALUATION INSTANCE
----peak evaluation receives all relevant data from the previous data processing stageS
----in detail, these are the results by the cfar_calculation (threshold and average noise) and maximum_detection (maximum_gain) as well as fft (fft_processed_data)
----the evaluation then applies several algorithms comparing the fft spectrum against the calculated cfar threshold, classifying the signal in comparison to the average noise,
----and validating cfar vs fft spectrum comparison
----these results are forwarded to the decider which implements the intelligence to assess these results
--peak_evaluation_inst: entity work.peak_evaluation
--	generic map(
--		N => 32
--	)
--	port map(
--		clk_20_i 								=> clk_20_i,
--		reset_i									=> reset_i,
--		
--		en_i										=> peak_en_s,
--		fft_processed_data_i					=> cfar_inst_fft_processed_data_s,
--		cfar_threshold_i						=> cfar_inst_cfar_threshold_s,
--		average_signal_noise_i				=> cfar_inst_average_signal_noise_s,
--		maximum_gain_i							=> maximum_detection_inst_maximum_gain_s,
--		
--		valid_o									=> peak_evaluation_inst_valid_s,
--		signal_classification_o				=> peak_evaluation_inst_signal_classification_s,
--		cfar_peak_detected_raw_o			=> peak_evaluation_inst_cfar_peak_detected_raw_s,
--		cfar_peak_detected_o					=> peak_evaluation_inst_cfar_peak_detected_s,
--		cfar_peak_detected_validated_o	=> peak_evaluation_inst_cfar_peak_detected_validated_s,
--		maximum_gain_o							=> peak_evaluation_inst_maximum_gain_s
--	);
--	
--
--	
----DECIDER INSTANCE
----receive results from the peak evaluation
----for decider operation, it is required to read the respective distance from the distance rom to decide whether any detections have to be considered for a warning/distance display
----outputs are the detection state (detection within range or not), which distance has been detected, and a vector which outputs a '1' for all bins where a peak has been detected, and
----a '0' for no detection
----at last, the decision process also includes the output of the peak_near_range_vd signal which indicates to the fft_calculation to not update its NRL filter since a detection
----has been encountered
--decider_inst: entity work.decider
--	port map(
--		clk_20_i 								=> clk_20_i,
--		reset_i									=> reset_i,
--		
--		en_i										=> peak_evaluation_inst_valid_s,
--		signal_classification_i 			=> peak_evaluation_inst_signal_classification_s,
--		cfar_peak_detection_raw_i 			=> peak_evaluation_inst_cfar_peak_detected_raw_s,
--		cfar_peak_detection_i 				=> peak_evaluation_inst_cfar_peak_detected_s,
--		cfar_peak_detection_validated_i 	=> peak_evaluation_inst_cfar_peak_detected_validated_s,
--		maximum_gain_i 						=> peak_evaluation_inst_maximum_gain_s,
--		
--		-- distance ROM
--		distance_rom_q_i						=> distance_rom_q_i,
--		distance_rom_read_enable_o			=> distance_rom_read_enable_s,
--		
--		valid_o 									=> decider_inst_valid_s,
--		peak_detected_o 						=> decider_inst_peak_detected_s,
--		peak_detected_distance_o 			=> decider_inst_peak_detected_distance_s,
--		peak_detected_vector_o				=> decider_inst_peak_detected_vector_s,
--		-- NRL filter...
--		peak_near_range_vd_o 				=> decider_inst_peak_near_range_vd_s	
--	);

END ARCHITECTURE;