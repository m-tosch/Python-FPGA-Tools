#!/bin/bash
from typing import List
import re
import dashtable

# TODO
# constants that refer to other constants in their value
# 1. Get all constant names from def_pkg 
# 2. search all .vhd files for constants occurrences
# 3. build and add dashtable to top of entity with constants names, types and default values
#    - replace old table if one exists

# ---- 1 ----
with open("const_def_pkg.vhd", 'r') as f:
    constants_file_str = f.read()
# print(constants_file_str)

# REMOVE ALL VHDL COMMENTS --
# (\s*--)     any capture group (substring) starting with zero or more whitespaces followed by two dashes
# .*          any character
# \n?         line break at the end. lazy evaluation
constants_file_str = re.sub(r'(\s*--).*\n?', '', constants_file_str, flags=re.MULTILINE)
# print(constants_file_str)

# substitute all tabs, newlines and other whitespaces
# the .strip() removes any leading and trailing whitespaces
# \s+         one ore more whitespaces
constants_file_str = re.sub(r'\s+', ' ', constants_file_str).strip()
# print(constants_file_str)

# \s+         one or more whitespaces 
# [a-z]       identifiers must begin with a letter
# [a-z_0-9]*  any letter, underscore or digit. zero or more times
# \s*         zero or more whitespaces 
# :           end delimiter (double colon)
names = re.findall(r'constant\s+([a-z][a-z_0-9]*)\s*:', constants_file_str, flags=re.IGNORECASE)
# print(names)

# :           start delimiter (double colon)
# \s*         zero or more whitespaces
# (.*?)       capture group. any character zero or more times. lazy evaluation
# \s*         zero or more whitespaces
# :=          end delimiter (double colon and equal)
types = re.findall(r':\s*(.*?)\s*:=', constants_file_str, flags=re.IGNORECASE)
# print(types)

# :=          start delimiter (double colon and equal)
# \s*         zero or more whitespaces
# (.*?)       capture group. any character zero or more times. lazy evaluation
# \s*         zero or more whitespaces
# ;           end delimiter (semicolon)
def_vals = re.findall(r':=\s*(.*?)\s*;', constants_file_str, flags=re.IGNORECASE)
# print(def_vals)


# ---- 2 ----
#vhdl_files = ["cfar_os.vhd", ...]
constants_occur = set()
with open("cfar_os.vhd") as f: # 'r+' (read and override)
    for line in f:
        # remove VHDL comments (they could contain constants names) 
        line = re.sub(r'(\s*--).*\n?', '', line, flags=re.MULTILINE)
        # print(line, end='')
        for n in names:
            # match the exact name
            if re.search(r'\b'+n+r'\b', line):
                constants_occur.add(n)
# print(constants_occur)

header = [ ["Constant", "Type", "Default"] ]
# constants_list = [ [n,t,d] if n in constants_occur for (n,t,d) in zip(names, types, def_vals) ] # doesn't work..
constants_list = []
for n,t,d in zip(names, types, def_vals):
    if n in constants_occur:
        constants_list.append([n,t,d])
# print(constants_list)
constants_dash_table = dashtable.data2rst(header + constants_list)
# add leading -- in every line to make the table a VHDL comment
# solution [1]
# constants_dash_table_vhdl = ["-- "]
# for c in constants_dash_table:
#     constants_dash_table_vhdl.append(c)
#     if c == '\n':
#         constants_dash_table_vhdl.append('-- ')
# solution [2]
constants_dash_table_vhdl = [c if c != '\n' else "\n--" for c in "--" + constants_dash_table]
# join list of str back to table
constants_dash_table_vhdl = ''.join(constants_dash_table_vhdl)
print(constants_dash_table_vhdl)

# TODO add dash table to top of file