#!/bin/bash
import os
from os import path
import re
from enum import Enum


def _get_raw_vhdl(file_path):
    """
    Removes all VHDL comments and substitutes all whitespaces/tabs/line breaks with a single whitespace
    """
    with open(file_path, 'r') as f:
        file_str = f.read()
    # remove all VHDL comments
    file_str = re.sub(r'(\s*--).*\n?', '', file_str, flags=re.MULTILINE)
    # substitute all tabs, newlines and other whitespaces
    file_str = re.sub(r'\s+', ' ', file_str).strip()
    return file_str

def parse_entity(file_path):
    file_str = _getRawVhdl(file_path)

    # [^- ]+        match anything that is NOT a dash or a whitespace one or more times
    # \s*           zero or more whitespaces
    # (entity       begin of capture group with "entity"
    # \s+           one or more whitespaces
    # .+            any character one or more times
    # \s+           one or more whitespaces
    # is            "is"
    # .*            any character zero or more times (this is all the generics and ports)
    # end           "end"
    # \s+           one or more whitespaces
    # .*            any character zero or more times
    # ;)            end of capture group with semicolon
    # \s*           zero or more whitespaces
    # architecture  "architecture"
    m = re.search(r'[^- ]+\s*(entity\s+.+\s+is.*end\s+.*;)\s*architecture', file_str, flags=re.IGNORECASE)
    entity_str = m.group(1)

    ####

    # (port         begin of capture group with "port"
    # \s*           zero or more whitespaces
    # \(            opening parenthesis (escaped)
    # .*            any character zero or more
    # \)            closing parenthesis (escaped)
    # \s*           zero or more whitespaces
    # ;             semicolon
    # \s*           zero or more whitespaces
    # end)          end of capture group with "end"
    m = re.search(r'(port\s*\(.*\)\s*;\s*end)', entity_str, flags=re.IGNORECASE)
    port_str = m.group(1)
    # [a-z]         identifiers must begin with a letter
    # [a-z_0-9]*    any letter, underscore or digit. zero or more times
    # \s*           zero or more whitespaces
    # :             end delimiter (double colon)
    port_names = re.findall(r'([a-z][a-z_0-9]*)\s*:', port_str, flags=re.IGNORECASE)
    # :             start delimiter (double colon)
    # \s*           zero or more whitespaces
    # ([a-z]{2,})   capture group. any alphabetic character. must be at least two. shortest is "in"
    # \s+           one or more whitespaces
    port_dirs = re.findall(r':\s*([a-z]{2,})\s+', port_str, flags=re.IGNORECASE)
    # :             start delimiter (double colon)
    # \s*           zero or more whitespaces
    # [a-z]{2,}     any alphabetic character. must be at least two
    # \s+           one or more whitespaces
    # (.+?)         capture group. any character one or more times. non-greedy. match first occurence
    # \s*           zero or more whitespaces
    # (?:           non-capture group
    # ;             semicolon
    # |             or
    # \)\s*;\s*end  closing parenthesis. zero or more whitespaces. semicolon. zero or more whitespaces. "end"
    # )             end of non-capture group
    port_types = re.findall(r':\s*[a-z]{2,}\s+(.+?)\s*(?:;|(?:\)\s*;\s*end))', port_str, flags=re.IGNORECASE)
    # a list of tuples
    ports = [(x,y,z) for x,y,z in zip(port_names, port_dirs, port_types)]

    ####

    # (generic      begin of capture group with "generic"
    # \s*           zero or more whitespaces
    # \(            opening parenthesis (escaped)
    # .*            any character zero or more
    # \)            closing parenthesis (escaped)
    # \s*           zero or more whitespaces
    # ;             semicolon
    # \s*           zero or more whitespaces
    # port          "port"
    m = re.search(r'(generic\s*\(.*\)\s*;)\s*port', entity_str, flags=re.IGNORECASE)
    generic_str = m.group(1)
    # [a-z]         identifiers must begin with a letter
    # [a-z_0-9]*    any letter, underscore or digit. zero or more times
    # \s*           zero or more whitespaces
    # :             double colon
    # [^=]          any character that is not an equals sign
    generic_names = re.findall(r'([a-z][a-z_0-9]*)\s*:[^=]', generic_str, flags=re.IGNORECASE)
    # :             start delimiter (double colon)
    # \s*           zero or more whitespaces
    # (.*?)         capture group. any character zero or more times. lazy evaluation (non-greedy)
    # \s*           zero or more whitespaces
    # :=            end delimiter (double colon and equal)
    generic_types = re.findall(r':\s*(.*?)\s*:=', generic_str, flags=re.IGNORECASE)
    # :=            start delimiter (double colon and equals)
    # \s*           zero or more whitespaces
    # (.*?)         capture group. any character zero or more times. lazy evaluation (non-greedy)
    # \s*           zero or more whitespaces
    # (?:           non-capture group
    # ;             semicolon
    # |             or
    # \)\s*;        closing parenthesis. zero or more whitespaces. semicolon
    # )             end of non-capture group
    generic_def_vals = re.findall(r':=\s*(.*?)\s*(?:;|(?:\)\s*;))', generic_str, flags=re.IGNORECASE)
    # a list of tuples
    generics = [(x,y,z) for x,y,z in zip(generic_names, generic_types, generic_def_vals)]


## TBD if these classes must be used
# class Signal:
#     def __init__(self, name, type_):
#         self.name = name
#         self.type_ = type_

#     def __repr__(self):
#         return self.name + " " + self.type_

# class EntitySignal(Signal):
#     def __init__(self, name, type_, dir):
#         super(self.__class__, self).__init__(name, type_)
#         self.dir = dir

#     def __repr__(self):
#         return self.name + " : " + self.dir.name.lower() + " " + self.type_

# class Dir(Enum):
#     IN, OUT, INOUT = [2**x for x in range(3)] # 1, 2, 4


parse_entity("C:\\Users\\DE6AK018\\Documents\\TortoiseGit\\Python-FPGA-Tools\\vhdl_src_files\\cfar_os.vhd")
