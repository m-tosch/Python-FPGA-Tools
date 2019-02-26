#!/usr/bin/env python
import datetime
import numpy as np

# distance_rom_calculation_result_s <= std_logic_vector(to_unsigned(distance_rom_iterator_s+1,32) * to_unsigned(299792458,32) / to_unsigned(2*BANDWIDTH_KHZ,32));
# ^??

DEPTH = 1024
BANDWIDTH_KHZ = 6000000

with open('python_distance_rom_%s_ghz.mif' % str(BANDWIDTH_KHZ/1000000), 'w') as f:
    f.write('--MIF data generated with Python\n')
    f.write('--Date: ' + datetime.datetime.now().strftime("%Y-%b-%d %H:%M")+'\n\n')
    f.write('WIDTH=18;\n')
    f.write('DEPTH=%s;\n' % DEPTH)
    f.write('ADDRESS_RADIX=UNS;\n')
    f.write('DATA_RADIX=HEX;\n')
    f.write('CONTENT BEGIN\n')
    for i in range(DEPTH):
        distance_res = i * 299792458 / (2*BANDWIDTH_KHZ)
        distance_res = int(distance_res + 0.5)
        f.write("{:d} : {:05X};\n".format(i, distance_res))
    f.write('END;')