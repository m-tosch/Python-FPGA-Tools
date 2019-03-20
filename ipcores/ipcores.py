#!/bin/bash
import math
import re
import subprocess

# TODO use in future
DEVICE_FAMILY = "MAX 10"
LANGUAGE = "VHDL" # VHDL or VERILOG

def gen_fifo(params_path, bitwidth=32, numwords=1024):
    # Quartus qmegawiz constraints
    assert numwords >= 4, "Error. argument \"numwords\" must be greater or equal to 4"
    assert numwords <= 2**17, "Error. argument \"numwords\" must be smaller or equal to 2^17=131072"
    assert not (numwords & (numwords - 1)), "Error. argument \"numwords\" must be power of 2"
    valid_bit_widths = [x for x in range(1,33)] + [36,40,48,56,64,72,80,96,108,112,128,144,160,192,224,256]
    assert bitwidth in valid_bit_widths, "Error. argument \"bitwidth\" is not of a supported bit width. Supported bit widths are: " + str(valid_bit_widths)

    with open(params_path, 'r') as f:
        params_str = f.read()
    # "NUMWORDS", param numwords
    p = re.compile(r"\s*LPM_NUMWORDS\s*=\s*[0-9]+")
    params_str = p.sub(r'\nLPM_NUMWORDS=' + str(numwords), params_str)
    # "WIDTHU", log2(numwords)
    p = re.compile(r"\s*LPM_WIDTHU\s*=\s*[0-9]+")
    widthu = int(math.log(numwords,2))
    params_str = p.sub(r'\nLPM_WIDTHU=' + str(widthu), params_str)
    # "WIDTH", param bitwidth
    p = re.compile(r"\s*LPM_WIDTH\s*=\s*[0-9]+")
    params_str = p.sub(r'\nLPM_WIDTH=' + str(bitwidth), params_str)
    # TODO make full signal optional
    # TODO make empty signal optional
    with open(params_path, 'w') as f:
        f.write(params_str)

    # TODO organise + make variables. figure out paths
    qmegawiz_path = "J:\\Intel_Quartus_Prime_Lite\\quartus\\bin64\\"
    # qmegawiz_cmd = "qmegawiz.exe -silent module=scfifo -f:"+params_path+" OPTIONAL_FILES=NONE fifo.vhd"
    filename = "fifo_" + bitwidth + "_width_" + numwords + "_length" 
    qmegawiz_cmd = "qmegawiz.exe -silent module=scfifo -f:fifo_params.txt OPTIONAL_FILES=NONE " + filename + ".vhd"
    subprocess.call(qmegawiz_path + qmegawiz_cmd)


# NOTE: later maybe do FFT config manually and put .tcl file somewhere for Python to grab it
#       However, this function can be a reference for someone in the future
def gen_fft(path, length, in_width, raw=False):
    """
    raw: if .tcl script should not be changed at all
    """
    # TODO asserts
    # length pow2 ? and >= 0/1/?
    # 
    # with open(path+"fft.tcl", 'r') as f:
    with open("fft.tcl", 'r') as f:
        tcl_str = f.read()
    # TODO name? currently "fft"
    # TODO DEVICE_FAMILY
    # TODO DEVICE
    # length
    p = re.compile(r"\{\s*length\s*\}\s*\{\s*[0-9]+\s*\}")
    tcl_str = p.sub(r'{length} {' + str(length) + r'}', tcl_str)
    # in_width
    p = re.compile(r"\{\s*in_width\s*\}\s*\{\s*[0-9]+\s*\}")
    tcl_str = p.sub(r'{in_width} {' + str(in_width) + r'}', tcl_str)
    print(tcl_str)

    p = "J:\\Intel_Quartus_Prime_Lite\\quartus\\sopc_builder\\bin\\"
    # generate .qsys
    qsys_script = "qsys-script.exe"
    qsys_script_cmd = p+qsys_script + " --script="+path+"fft.tcl" # TODO check command options for output path etc.
    subprocess.call(qsys_script_cmd)
    print("what")
    # generate .qip and synthesized design files
    qsys_generate = "qsys-generate.exe"
    qsys_generate_cmd = p+qsys_generate + path+"fft.qsys" + "-syn=" + LANGUAGE # TODO check command options for output path etc.
    subprocess.call(qsys_generate_cmd) 


#gen_fifo(params_path="C:\\Users\\Maxi\\Seafile\\Seafile\\My Library\\Masterarbeit\\ipcores\\fifo\\fifo_params.txt", bitwidth=16, numwords=512)
gen_fft(path="C:\\Users\\Maxi\\Seafile\\Seafile\\My Library\\Masterarbeit\\ipcores\\fft\\", length=2048, in_width=12)