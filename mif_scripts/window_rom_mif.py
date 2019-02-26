#!/usr/bin/env python
import datetime
import numpy as np

WINDOW_LEN = 2048
MULTIPLICATOR = 16384 # power of 2 so we can later use a shift operation instead of a dedicated divider

window = np.ceil(np.blackman(WINDOW_LEN) * MULTIPLICATOR)

for idx, i in np.ndenumerate(window.astype(int)):
    print("{:d} : {:04X};".format(idx[0],i))

with open('python_blackman_window_2048_values_1.6384_multiplicator_ceil.mif', 'w') as f:
    f.write('--MIF data generated with Python\n')
    f.write('--Date: ' + datetime.datetime.now().strftime("%Y-%b-%d %H:%M")+'\n\n')
    f.write('WIDTH=16;\n')
    f.write('DEPTH=%s;\n' % WINDOW_LEN)
    f.write('ADDRESS_RADIX=UNS;\n')
    f.write('DATA_RADIX=HEX;\n')
    f.write('CONTENT BEGIN\n')
    for idx,i in np.ndenumerate(window.astype(int)):
        f.write("{:d} : {:04X};\n".format(idx[0],i))
    f.write('END;')