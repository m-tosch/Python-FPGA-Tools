#!/bin/bash
import vhdl_parser

# file_path = "C:\\Users\\Maxi\\Seafile\\Seafile\\My Library\\Masterarbeit\\Python-FPGA-Tools\\vhdl_src_files\\pktec_evalboard_data_processing_chain.vhd"
# file_path = "C:\\Users\\Maxi\\Seafile\\Seafile\\My Library\\Masterarbeit\\Python-FPGA-Tools\\vhdl_src_files\\cfar_os.vhd"
file_path_windowing = "C:\\Users\\Maxi\\Seafile\\Seafile\\My Library\\Masterarbeit\\Python-FPGA-Tools\\vhdl_src_files\\windowing.vhd"
file_path_fft = "C:\\Users\\Maxi\\Seafile\\Seafile\\My Library\\Masterarbeit\\Python-FPGA-Tools\\vhdl_src_files\\fft_wrapper.vhd"
# [1] parse/read all entities
d = dict()
generics, ports = vhdl_parser.parse_entity(file_path_windowing)
d["windowing"] = (generics, ports)
generics, ports = vhdl_parser.parse_entity(file_path_fft)
d["fft_wrapper"] = (generics, ports)
# for k,v in d.items():
#     print("%s: %s" % (k,v))

# [2] make connections between entities
## windowing   -> fft_wrapper -> square_add
## fft_wrapper -> square_add  -> avg_signal_noise
##                square_add  -> cfar
##                square_add  -> max
##                square_add  -> fifo_fft
##
## maybe use lookup table for connections
# lookup1 = ["windowing", 
#           "fft_wrapper",
#           "square_add",
#           ["avg_signal_noise", "cfar", "max", "fifo_fft"],
#           "..."]
# lookup2 = { 
#             "fft_wrapper": ["windowing", "square_add"], ### ["INPUT", "OUTPUT(S)"]
#             "square_add":  ["fft_wrapper", ["avg_signal_noise", "cfar", "max", "fifo_fft"]],
#             "..."  }
# lookup3 = { 
#             "fft_wrapper":      "square_add",
#             "square_add":       ["avg_signal_noise", "cfar", "max", "fifo_fft"],
#             "avg_signal_noise": "cfar",
#             "cfar":             "fifo_cfar"
#             "max":              "fifo_max"
#             "fifo_fft":         "peak_eval"
#             "fifo_cfar":        "peak_eval"
#             "fifo_max":         "peak_eval"
#             "..."  }
##
## TODO port signals in entities can have generics in them. How to handle?
# create signals (to be put in pktec_evalboard_data_processing_chain)
ports = d["fft_wrapper"][1]
max_port_len = len(max([p[0] for p in ports], key=len)) + 1 # find longest port name
max_signal_len = max_port_len + len("fft_wrapper") + len("_inst_")
signals = []
for p in ports:
    if p[1] == "out":
        print(p)
        # signal = "signal " + "fft_wrapper" + "_inst_" + p_out[0][:-1]+ "s" + " : " + p_out[2] + ";" # TODO replace fft_wrapper
        signal_name = "fft_wrapper" + "_inst_" + p[0][:-1] + "s"
        signal = "signal " + "{1:<{0:}} {2:<1} {3:<3}".format(max_signal_len, signal_name, ":", p[2]) + ";"
        signals.append(signal)
print("--")
for s in signals:
    print(s)


generic_values = []
port_signals = ["clk_20_i", "reset_i", "TODO", "TODO", "TODO", "TODO", "TODO", "TODO", "TODO", "TODO", "TODO", "TODO", "TODO", ]


# [3] create all instances
inst_str = vhdl_parser.get_entity_inst("fft_wrapper", generics, ports, generic_values, port_signals)
# print()
# print(inst_str)

## pktec_receive
## fifo_32_width_2048_length & data_average
## windowing
## fft_wrapper
## square_add
## avg_signal_noise & cfar & maximum_detection & fifo_25_width_1024_length(fft_post_processing)
## fifo_25_width_1024_length(cfar) & fifo_1_width_1024_length(max)
## peak_evaluation

## windowing["frame_valid_o"] & ffr_wrapper["frame_en_i"]

# [4] bring everything together. write vhdl file