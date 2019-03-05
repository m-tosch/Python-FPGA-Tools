#!/bin/bash
import os
from os import path
import re
# import dashtable
import datetime


def remove_table(file_str):
    """ 
    Removes the table from the file content string if one exists 
    :param file_str:    the whole file content as a string
    :type file_str:     str
    :return:            the new file content as a string
    :rtype:             str
    """
    # vhdl_file_str = re.sub(r'^(--DASHTABLE.*)', '', vhdl_file_str, flags=re.MULTILINE)
    # -{2,}     dash, two or more times
    # \s*       zero or more whitespaces
    # \+        plus character
    # .*        any character zero or more times
    # ---\+     three dashes followed by plus character. Even the smallest possible dashtable always satisfies this condition
    # \n{1}     one line breaks that was previously added. remove itm to not add additional line breaks every time
    return re.sub(r'(-{2,}\s*\+)(.*)(---\+)\n{1}', '', file_str, flags=re.MULTILINE|re.DOTALL)


def add_table(file_str, dash_table):
    """
    Adds the specified table to the (specified. currently above entity) position
    :param file_str:    the whole file content as a string
    :type file_str:     str
    :param dash_table:  the dash table
    :type dash_table:   str 
    :return:            the new file content as a string
    :rtype:             str
    """
    # [^- ]+        match anything that is NOT a dash or a whitespace one or more times
    # (\s*entity)   zero or more whitespaces followed by "entity". capture group. idx = 1
    # \s+           one or more whitespaces
    # .+            any character one or more times
    # \s+           one or more whitespaces
    # is            "is"
    # \s*?          zero or more whitespaces. lazy evaluation
    m = re.search(r'[^- ]+(\s*entity)\s+.+\s+is\s*?', file_str, re.IGNORECASE)
    pos = m.start(1) # start of capture group with idx = 1
    # TODO catch error if nothing is found
    return file_str[:pos] + dash_table + "\n" +  file_str[pos:]


def get_constants_from_pkg(pkg_file_path):
    """
    Gets all constants names from def file specified by function argument
    :param pkg_file_path:   path to the def_pkg file with all constants
    :type pkg_file_path:    str
    :return:                a tuple of str lists [name, type, default value] for every constant
    :rtype:                 TODO
    """
    with open(pkg_file_path, 'r') as f:
        constants_file_str = f.read()
    ## remove all VHDL comments
    # (\s*--)     any capture group starting with zero or more whitespaces followed by two dashes
    # .*          any character
    # \n?         line break at the end. lazy evaluation
    constants_file_str = re.sub(r'(\s*--).*\n?', '', constants_file_str, flags=re.MULTILINE)

    ## substitute all tabs, newlines and other whitespaces
    # the .strip() removes any leading and trailing whitespaces
    # \s+         one ore more whitespaces
    constants_file_str = re.sub(r'\s+', ' ', constants_file_str).strip()

    # constant    "constant"
    # \s+         one or more whitespaces 
    # [a-z]       identifiers must begin with a letter
    # [a-z_0-9]*  any letter, underscore or digit. zero or more times
    # \s*         zero or more whitespaces 
    # :           end delimiter (double colon)
    names = re.findall(r'constant\s+([a-z][a-z_0-9]*)\s*:', constants_file_str, flags=re.IGNORECASE)
    print(names)

    # type        "type"
    # \s+         one or more whitespaces 
    # [a-z]       identifiers must begin with a letter
    # [a-z_0-9]*  any letter, underscore or digit. zero or more times
    # \s+         one or more whitespaces
    # is          "is"
    # \s*         zero or more whitespaces
    # \(          opening parenthesis (escaped)
    # \s*         zero or more whitespaces
    # (.[^)]+)    capture group. any character one or more times that is not )
    # \s*         zero or more whitespaces
    # \)          closing parenthesis (escaped)
    # \s*         zero or more whitespaces
    # ;           end delimiter (semicolon)
    state_types = re.findall(r'type\s+([a-z][a-z_0-9]*)\s+is\s*\(\s*(.[^)]+)\s*\)\s*;', constants_file_str, flags=re.IGNORECASE)
    print(state_types) # [('state_type', 'idle, calculation, finishing ')]  <- tuple access first element as state_types[0][0]

    # :           start delimiter (double colon)
    # \s*         zero or more whitespaces
    # (.*?)       capture group. any character zero or more times. lazy evaluation
    # \s*         zero or more whitespaces
    # :=          end delimiter (double colon and equal)
    types = re.findall(r':\s*(.*?)\s*:=', constants_file_str, flags=re.IGNORECASE)

    # :=          start delimiter (double colon and equal)
    # \s*         zero or more whitespaces
    # (.*?)       capture group. any character zero or more times. lazy evaluation
    # \s*         zero or more whitespaces
    # ;           end delimiter (semicolon)
    def_vals = re.findall(r':=\s*(.*?)\s*;', constants_file_str, flags=re.IGNORECASE)
    return names, types, def_vals


def get_constants_in_file(file_path, constants_names):
    """
    Searches the specified file for constants use and returns a list of constants that are being used
    :param file_path:       path to the file
    :type file_path:        str
    :param constants_names: list of constants names
    :type constants_names:  list of str
    :return:                TODO
    :rtype:                 list of str
    """
    constants_occur = set()
    with open(file_path, 'r') as f:
        for line in f:
            # remove VHDL comments (they could contain constants names) 
            line = re.sub(r'(\s*--).*\n?', '', line, flags=re.MULTILINE)
            for n in constants_names:
                # search for an exact match (constants names could partially contain other constants names)
                if re.search(r'\b'+n+r'\b', line, re.IGNORECASE):
                    constants_occur.add(n)
    return list(constants_occur)

def build_dash_table_vhdl(table_content, header=[[]], prefix="-- "):
    """
    Builds the dash table from input parameters and adds two dashes -- in front of every line
    to be a VHDL comment
    :param table:   table content
    :type table:    list of list of str
    :param table:   header content
    :type table:    list of list of str
    :return:        dash table as str
    :rtype:         str
    """
    # build dash table
    dash_table_ = dashtable.data2rst(header + table_content)
    # heading w/time
    # now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    # heading = "--DASHTABLE. AUTO GENERATED @" + now + "\n"
    # add leading -- in every line of dash table to make the table a VHDL comment
    dash_table_vhdl = [c if c != '\n' else "\n"+prefix for c in prefix+dash_table_]#heading+dash_table]
    # make list of characters list of lines again
    dash_table_vhdl = ''.join(dash_table_vhdl)
    # print(dash_table_vhdl)
    return dash_table_vhdl

def build_table_test(table_content):
    """
    debug
    """
    return table_content




def run(src_folder, def_pkg_path):
    """
    TODO
    src_folder = folder with VHDL files to go through
    def_pkg_path = constants def package file
    """
    ## source files
    vhdl_src_files = [src_folder+f for f in os.listdir(src_folder) if path.isfile(src_folder+f) and f.endswith(".vhd")]
    # print(vhdl_src_files)

    ## constants names, types and default values from def pkg
    names, types, def_vals = get_constants_from_pkg(def_pkg_path)

    for vhdl_file in vhdl_src_files:
        ## 1. read VHDL file, remove old table
        with open(vhdl_file, 'r') as f:
            vhdl_file_str = f.read()
        vhdl_file_str = remove_table(vhdl_file_str)

        ## 2. list constants in the VHDL file 
        constants_occur = get_constants_in_file(vhdl_file, names)
        
        ## 2.1 no constants used in this file, no need to build table
        if len(constants_occur) > 0:
            
            ## 3. build new dash table
            header = [ ["Constant", "Type", "Default"] ]
            constants_list = [ [n,t,d] for (n,t,d) in zip(names, types, def_vals) if n in constants_occur ]
            # dash_table_vhdl = build_dash_table_vhdl(constants_list, header, "-- ")
            dash_table_vhdl = "-- +" + '\n-- '.join(map(str, build_table_test(constants_list))) + "---+" # debug
            # print(dash_table_vhdl)

            ## 4. add dash table to file str
            vhdl_file_str = add_table(vhdl_file_str, dash_table_vhdl)
            #print(vhdl_file_str)
        
        ## 5. write back to VHDL file
        with open(vhdl_file, 'w') as f:
            f.write(vhdl_file_str)
        # print(vhdl_file_str)