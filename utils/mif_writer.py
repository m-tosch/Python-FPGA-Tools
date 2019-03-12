#!/usr/bin/env python
import datetime
import numpy as np

# debug
# for idx, i in np.ndenumerate(window.astype(int)):
#     print("{:d} : {:04X};".format(idx[0],i))

def window_rom(dest_folder):
    # TODO make WINDOW_LEN etc function parameters
    WINDOW_LEN = 2048
    MULTIPLICATOR = 16384 # power of 2 so we can later use a shift operation instead of a dedicated divider
    window = np.ceil(np.blackman(WINDOW_LEN) * MULTIPLICATOR)
    with open(dest_folder+'python_blackman_window_2048_values_1.6384_multiplicator_ceil.mif', 'w') as f:
        f.write('--MIF data auto generated with Python\n')
        f.write('--Date: ' + datetime.datetime.now().strftime("%Y-%b-%d %H:%M")+'\n\n')
        f.write('WIDTH=16;\n')
        f.write('DEPTH=%s;\n' % WINDOW_LEN)
        f.write('ADDRESS_RADIX=UNS;\n')
        f.write('DATA_RADIX=HEX;\n')
        f.write('CONTENT BEGIN\n')
        for idx,i in np.ndenumerate(window.astype(int)):
            f.write("{:d} : {:04X};\n".format(idx[0],i))
        f.write('END;')



# distance_rom_calculation_result_s <= std_logic_vector(to_unsigned(distance_rom_iterator_s+1,32) * to_unsigned(299792458,32) / to_unsigned(2*BANDWIDTH_KHZ,32));
# ^??
def distance_rom(dest_folder, bandwidth_khz=6000000):
    # TODO make DEPTH etc function parameters
    DEPTH = 1024
    # BANDWIDTH_KHZ = 6000000
    with open(dest_folder+'python_distance_rom_%s_ghz.mif' % str(bandwidth_khz/1000000), 'w') as f:
        f.write('--MIF data auto generated with Python\n')
        f.write('--Date: ' + datetime.datetime.now().strftime("%Y-%b-%d %H:%M")+'\n\n')
        f.write('WIDTH=18;\n')
        f.write('DEPTH=%s;\n' % DEPTH)
        f.write('ADDRESS_RADIX=UNS;\n')
        f.write('DATA_RADIX=HEX;\n')
        f.write('CONTENT BEGIN\n')
        for i in range(DEPTH):
            distance_res = i * 299792458 / (2*bandwidth_khz)
            distance_res = int(distance_res + 0.5)
            f.write("{:d} : {:05X};\n".format(i, distance_res))
        f.write('END;')