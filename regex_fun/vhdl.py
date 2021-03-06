import re
from typing import Tuple, List, Optional
from functools import wraps


def _raw(func):
    """Decorator for removing VHDL comments and whitespace characters

    The input is expected to be a function with one argument that is a string
    representing vhdl file content.

    Two processing steps are executed:

    - All valid VHDL comments are removed\n
    - All whitespaces/tabs/new lines are replaced by a single whitespace\n

    Args:
        func ([type]): input function to decorate
    """

    @wraps(func)
    def inner(*args, **kwargs):
        assert len(args) == 1, "number of arguments must be 1"
        assert type(*args) is str, "argument type must be string"
        # remove all VHDL comments
        # (                 begin of capture group
        #     --            two dashes
        # )                 end of capture group
        # .*?               any character zero or more times. lazy evaluation
        # \n                new line
        buffer = re.sub(r"(--).*?\n", "", *args)
        # substitute all tabs, newlines, whitespaces with a single whitespace
        # the .strip() removes any leading and trailing whitespace characters
        # \s+               one or more whitespace characters
        buffer = re.sub(r"\s+", " ", buffer).strip()
        # add back to args
        args = list(args)
        args[0] = buffer
        # call function
        return func(*args, **kwargs)

    return inner


@_raw
def get_entity(buffer: str) -> Optional[str]:
    """Parses the entity out of an input string

    The input is expected to be a string representing vhdl file content. If an
    entity is defined within this content, the entity block is parsed if one is
    found. If nothing is found that could be parsed, the function returns
    None. If the entity could be parsed, it is returned as a string beginning
    with "entity" and ending on "end <name>;" or "end entity;"

    Args:
        buffer (str): input string

    Returns:
        Optional[str]: entity string
    """
    # (                 begin of capture group---------------------------ENTITY
    #     entity        "entity"
    #     \s+           one or more whitespace characters
    #     \w+           one or more word characters
    #     \s+           one or more whitespace characters
    #     is            "is"
    #     .+?           any character one or more times. lazy evaluation
    #     end           "end"
    #     \s+           one or more whitespace characters
    #     \w+           one or more word characters
    #     \s*           zero or more whitespace characters
    #     ;             semicolon
    # )                 end of capture group
    m = re.search(
        r"(entity\s+\w+\s+is.+?end\s+\w+\s*;)",
        buffer,
        flags=re.IGNORECASE | re.DOTALL,  # the DOTALL may not be necessary..
    )
    if m is None:
        return None
    entity = m.group(1)
    return entity


@_raw
def get_generics(buffer: str) -> Optional[List[Tuple[str, str, str]]]:
    """Parses entity generics out of an input string

    The input is expected to be a string representing vhdl file content. If an
    entity is defined within this content, a generic block is parsed if one is
    found. If nothing is found that could be parsed, the function returns
    None. If the generic parameters could be parsed, they are returned with
    their individual properties.

    A generic parameter consists of the following properties:

    - name\n
    - type\n
    - default value (optional)\n

    Args:
        buffer (str): input string

    Returns:
        List[Tuple[str, str, str]]: generic names, types and default values
    """
    # (                 begin of capture group------------------ENTITY GENERICS
    #     generic       "generic"
    #     \s*           zero or more whitespace characters
    #     \(            opening parenthesis
    #     .*?           any character zero or more times. lazy evaluation
    #     \)            closing parenthesis
    #     \s*           zero or more whitespace characters
    #     ;             semicolon
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # port              "port"
    # \s*               zero or more whitespace characters
    # \(                opening parenthesis
    m = re.search(
        r"(generic\s*\(.*?\)\s*;)\s*port\s*\(", buffer, flags=re.IGNORECASE,
    )
    if m is None:
        return None
    generic_str = m.group(1)
    # generic variable names
    # (                 begin of capture group----------------------------NAMES
    #     [a-z]         lowercase letter (identifiers must begin with a letter)
    #     [a-z_0-9]     lowercase letter/underscore/digit or comma
    #     *             zero or more times
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # :                 double colon
    # [^=]              any character that is not an equal sign
    _generic_names = re.findall(
        r"([a-z][a-z_0-9,]*)\s*:[^=]", generic_str, flags=re.IGNORECASE
    )
    # capture generic "type to end" of generic description
    # used to identify the type and default value, but the default value is
    # optional
    # :                 double colon
    # \s*               zero or more whitespace characters
    # (                 begin of capture group-----------TYPES & DEFAULT VALUES
    #     .*?           any character zero or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # (?:               begin of non-capture group
    #     ;             semicolon
    #     |             OR
    #     \)            closing parenthesis
    #     \s*           zero or more whitespace characters
    #     ;             semicolon
    # )                 end of non-capture group
    __generic_type_to_end = re.findall(
        r":\s*(.*?)\s*(?:;|\)\s*;)", generic_str, flags=re.IGNORECASE
    )
    # generic variable types (e.g. integer)
    _generic_types = [
        gtte.split(":=")[0].strip() for gtte in __generic_type_to_end
    ]
    # generic default values (e.g. 42)
    # only if one is specified with ":=", None otherwise
    _generic_def_vals = []
    for gt in __generic_type_to_end:
        def_val = gt.split(":=")[1].strip() if ":=" in gt else None
        _generic_def_vals.append(def_val)

    # account for multiple generic names in the same line, separated by comma
    count = [_gn.count(",") + 1 for _gn in _generic_names]
    # correct generic names list. every generic variable is an entry in a list
    generic_names = [gn for _gn in _generic_names for gn in _gn.split(",")]
    # correct generic types and default values. expand lists depending on count
    generic_types, generic_def_vals = [], []
    for c, _gt, _gd in zip(count, _generic_types, _generic_def_vals):
        generic_types.extend([_gt] * c)
        generic_def_vals.extend([_gd] * c)

    # generic names, types and default values as a list of tuples
    generics = [
        (gn, gt, gd)
        for gn, gt, gd in zip(generic_names, generic_types, generic_def_vals)
    ]
    return generics


@_raw
def get_ports(buffer: str) -> Optional[List[Tuple[str, str, str]]]:
    """Parses entity ports out of an input string

    The input is expected to be a string representing vhdl file content. If an
    entity is defined within this content, the port block is parsed if one is
    found. If nothing is found that could be parsed, the function returns
    None. If the ports could be parsed, they are returned with
    their individual properties.

    A port consists of the following properties:

    - name\n
    - direction\n
    - type\n

    Args:
        buffer (str): input string

    Returns:
        Optional[List[Tuple[str, str, str]]]: port names, direction and types
    """
    # (                 begin of capture group---------------------ENTITY PORTS
    #     port          "port"
    #     \s*           zero or more whitespace characters
    #     \(            opening parenthesis
    #     .*?           any character zero or more times. lazy evaluation
    #     \)            closing parenthesis
    #     \s*           zero or more whitespace characters
    #     ;             semicolon
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # end               "end"
    m = re.search(r"(port\s*\(.*?\)\s*;)\s*end", buffer, flags=re.IGNORECASE)
    if m is None:
        return None
    port_str = m.group(1)
    # port variable names
    # (                 begin of capture group----------------------------NAMES
    #     [a-z]         lowercase letter (identifiers must begin with that)
    #     [a-z_0-9,]    lowercase letter/underscore/digit or comma
    #     *             zero or more times
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # :                 double colon
    _port_names = re.findall(
        r"([a-z][a-z_0-9,]*)\s*:", port_str, flags=re.IGNORECASE
    )
    # port directions (in, out, inout, buffer)
    # :                 double colon
    # \s*               zero or more whitespace characters
    # (                 begin of capture group------------------------DIRECTION
    #     [a-z]{2,}     lowercase letter. two or more times (shortest is "in")
    # )                 end of capture group
    # \s+               one or more whitespace characters
    _port_dirs = re.findall(
        r":\s*([a-z]{2,})\s+", port_str, flags=re.IGNORECASE
    )
    # port types (e.g. std_logic)
    # :                 double colon
    # \s*               zero or more whitespace characters
    # [a-z]{2,}         lowercase letter. two or more times
    # \s+               one or more whitespace characters
    # (                 begin of capture group----------------------------TYPES
    #     .+?           any character one or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # (?:               begin of non-capture group
    #     \)            closing parenthesis
    #     \s*           zero or more whitespace characters
    #     ;             semicolon
    #     |             OR
    #     ;             semicolon
    # )                 end of non-capture group
    _port_types = re.findall(
        r":\s*[a-z]{2,}\s+(.+?)\s*(?:\)\s*;|;)", port_str, flags=re.IGNORECASE,
    )

    # account for  multiple port names in the same line, separated by comma
    count = [_pn.count(",") + 1 for _pn in _port_names]
    # correct port names list. every port variable is an entry in the list
    port_names = [pn for _pn in _port_names for pn in _pn.split(",")]
    # correct port dirs, types list. expand lists depending on no. of ports
    port_dirs, port_types = [], []
    for c, _pd, _pt in zip(count, _port_dirs, _port_types):
        port_dirs.extend([_pd] * c)
        port_types.extend([_pt] * c)

    # port names, directions and types as a list of tuples
    ports = [
        (pn, pd, pt) for pn, pd, pt in zip(port_names, port_dirs, port_types)
    ]
    return ports


@_raw
def get_architecture(buffer: str) -> Optional[str]:
    """Parses the architecture out of an input string

    The input is expected to be a string representing vhdl file content. If an
    architecture is defined within this content, the architecture block is
    parsed if one is found. If nothing is found that could be parsed, the
    function returns None. If the architecture could be parsed, it is returned
    as a string beginning with "architecture" and ending on
    "end <name>;" or "end architecture;"

    Args:
        buffer (str): input string

    Returns:
        Optional[str]: architecture string
    """
    # (                 begin of capture group---------------------ARCHITECTURE
    #     architecture  "architecture"
    #     \s+           one or more whitespace characters
    #     \w+           one or more word characters
    #     \s+           one or more whitespace characters
    #     of            "of"
    #     \s+           one or more whitespace characters
    #     \w+           one or more word characters
    #     \s+           one or more whitespace characters
    #     is            "is"
    #     .*            any character zero or more times
    #     end           "end"
    #     \s+           one or more whitespace characters
    #     \w+           one or more word characters
    #     \s*           zero or more whitespace characters
    #     ;             semicolon
    # )                 end of capture group
    m = re.search(
        r"(architecture\s+\w+\s+of\s+\w+\s+is.*end\s+\w+\s*;)",
        buffer,
        flags=re.IGNORECASE,
    )
    if m is None:
        return None
    architecture = m.group(1)
    return architecture


@_raw
def get_constants(buffer: str) -> Optional[List[Tuple[str, str, str]]]:
    """Parses constants out of an input string 43

    The input is expected to be a string representing vhdl file content.
    Specifically, one where constants are defined. If constants are defined in
    the input, they are parsed. If nothing is found that could be parsed, the
    function returns None. If the generic parameters could be parsed, they are
    returned with their individual properties.

    A constant consists of the following properties:

    - name\n
    - type\n
    - default value\n

    Args:
        buffer (str): input string

    Returns:
        List[Tuple[str, str, str]]: constants names, types and default values
    """
    # constant          "constant"
    # \s+               one or more whitespace characters
    # (                 begin of capture group----------------------------NAMES
    #     [a-z]         identifiers must begin with a letter
    #     [a-z_0-9,]    lowercase letter/underscore/digit or comma
    #     *             zero or more times
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # :                 double colon
    _constant_names = re.findall(
        r"constant\s+([a-z][a-z_0-9,]*)\s*:", buffer, flags=re.IGNORECASE,
    )
    if _constant_names == []:
        return None
    # :                 double colon
    # \s*               zero or more whitespace characters
    # (                 begin of capture group----------------------------TYPES
    #     .*?           any character zero or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # :=                double colon and equals sign
    _constant_types = re.findall(
        r":\s*(.*?)\s*:=", buffer, flags=re.IGNORECASE
    )
    # :=                double colon and equals sign
    # \s*               zero or more whitespace characters
    # (                 begin of capture group-------------------DEFAULT VALUES
    #     .*?           any character zero or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespace characters
    # ;                 semicolon
    _constant_def_vals = re.findall(
        r":=\s*(.*?)\s*;", buffer, flags=re.IGNORECASE
    )

    # account for multiple constant names in the same line, separated by comma
    count = [_cn.count(",") + 1 for _cn in _constant_names]
    # correct constant names list. every constant is an entry in a list
    constant_names = [cn for _cn in _constant_names for cn in _cn.split(",")]
    # correct constant types and default values. expand lists depending oncount
    constant_types, constant_def_vals = [], []
    for c, _ct, _cd in zip(count, _constant_types, _constant_def_vals):
        constant_types.extend([_ct] * c)
        constant_def_vals.extend([_cd] * c)

    # constant names, types and default values as a list of tuples
    constants = [
        (cn, ct, cd)
        for cn, ct, cd in zip(
            constant_names, constant_types, constant_def_vals
        )
    ]
    return constants
