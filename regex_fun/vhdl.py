import re

# TODO
# input with no vhdl content? if group(1) else None   and return?
# maybe more detailed "classes" e.g. Entity(), Package() with parser methods
# install coverage package https://pypi.org/project/coverage/


def _get_raw_vhdl(buffer: str):
    """
    Removes all VHDL comments and substitutes all whitespaces/tabs/line breaks
    with a single whitespace
    """
    # remove all VHDL comments
    # (                 begin of capture group
    #     \s*           zero or more whitespaces
    #     --            two dashes
    # )                 end of capture group
    # .*                any character zero or more times
    # \n?               line break. lazy evaluation
    buffer = re.sub(r"(\s*--).*\n?", "", buffer, flags=re.MULTILINE)
    # substitute all tabs, newlines, whitespaces with a single whitespace
    # the .strip() removes any leading and trailing whitespaces
    # \s+               one ore more whitespaces
    buffer = re.sub(r"\s+", " ", buffer).strip()
    return buffer


def get_entity(buffer: str):
    # [^- ]             anything that is NOT a dash or whitespace
    # +                 one or more times
    # \s*               zero or more whitespaces
    # (                 begin of capture group---------------------------ENTITY
    #     entity        "entity"
    #     \s+           one or more whitespaces
    #     .+            any character one or more times
    #     \s+           one or more whitespaces
    #     is            "is"
    #     .*            any character zero or more times (->generics and ports)
    #     end           "end"
    #     \s+           one or more whitespaces
    #     .*            any character zero or more times
    #     ;             semicolon
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # architecture      "architecture"
    m = re.search(
        r"[^- ]+\s*(entity\s+.+\s+is.*end\s+.*;)\s*architecture",
        _get_raw_vhdl(buffer),
        flags=re.IGNORECASE,
    )
    if m is None:
        return None
    entity = m.group(1)
    return entity


def get_ports(buffer: str):
    # extract the entity string if it exists
    entity = get_entity(buffer)
    if entity is None:
        return None
    # (                 begin of capture group---------------------ENTITY PORTS
    #     port          "port"
    #     \s*           zero or more whitespaces
    #     \(            opening parenthesis
    #     .*            any character zero or more times
    #     \)            closing parenthesis
    #     \s*           zero or more whitespaces
    #     ;             semicolon
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # end               "end"
    m = re.search(r"(port\s*\(.*\)\s*;)\s*end", entity, flags=re.IGNORECASE)
    if m is None:
        return None
    port_str = m.group(1)
    # port variable names
    # (                 begin of capture group----------------------------NAMES
    #     [a-z]         lowercase letter (identifiers must begin with that)
    #     [a-z_0-9,]    lowercase letter/underscore/digit or comma
    #     *             zero or more times
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # :                 double colon
    _port_names = re.findall(
        r"([a-z][a-z_0-9,]*)\s*:", port_str, flags=re.IGNORECASE
    )
    # port directions (in, out, inout)
    # :                 double colon
    # \s*               zero or more whitespaces
    # (                 begin of capture group------------------------DIRECTION
    #     [a-z]{2,}     lowercase letter. two or more times (shortest is "in")
    # )                 end of capture group
    # \s+               one or more whitespaces
    _port_dirs = re.findall(
        r":\s*([a-z]{2,})\s+", port_str, flags=re.IGNORECASE
    )
    # port types (e.g. std_logic)
    # :                 double colon
    # \s*               zero or more whitespaces
    # [a-z]{2,}         lowercase letter. two or more times
    # \s+               one or more whitespaces
    # (                 begin of capture group----------------------------TYPES
    #     .+?           any character one or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # (?:               begin of non-capture group
    #     \)            closing parenthesis
    #     \s*           zero or more whitespaces
    #     ;             semicolon
    #     |             OR
    #     ;             semicolon
    # )                 end of non-capture group
    _port_types = re.findall(
        r":\s*[a-z]{2,}\s+(.+?)\s*(?:\)\s*;|;)", port_str, flags=re.IGNORECASE,
    )
    # account for  multiple port names in the same line, separated by a comma
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


def get_generics(buffer: str):
    # extract the entity string if it exists
    entity = get_entity(buffer)
    if entity is None:
        return None
    # (                 begin of capture group
    #     generic       "generic"
    #     \s*           zero or more whitespaces
    #     \(            opening parenthesis
    #     .*            any character zero or more times
    #     \)            closing parenthesis
    #     \s*           zero or more whitespaces
    #     ;             semicolon
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # port              "port"
    # \s*               zero or more whitespaces
    # \(                opening parenthesis
    m = re.search(
        r"(generic\s*\(.*\)\s*;)\s*port\s*\(", entity, flags=re.IGNORECASE
    )
    if m is None:
        return None
    generic_str = m.group(1)
    # generic variable names
    # (                 begin of capture group----------------------------NAMES
    #     [a-z]         lowercase letter (identifiers must begin with a letter)
    #     [a-z_0-9]*    lowercase letter/underscore/digit. zero or more times
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # :                 double colon
    # [^=]              any character that is not an equal sign
    generic_names = re.findall(
        r"([a-z][a-z_0-9]*)\s*:[^=]", generic_str, flags=re.IGNORECASE
    )
    # capture generic "type to end" of generic description
    # used to identify the type and default value, but the default value is
    # optional
    # :                 double colon
    # \s*               zero or more whitespaces
    # (                 begin of capture group----------------------------TYPES
    #     .*?           any character zero or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # (?:               begin of non-capture group
    #     ;             semicolon
    #     |             OR
    #     \)            closing parenthesis
    #     \s*           zero or more whitespaces
    #     ;             semicolon
    # )                 end of non-capture group
    _generic_type_to_end = re.findall(
        r":\s*(.*?)\s*(?:;|\)\s*;)", generic_str, flags=re.IGNORECASE
    )
    # generic variable types (e.g. integer)
    generic_types = [
        gtte.split(":=")[0].strip() for gtte in _generic_type_to_end
    ]
    # generic default values (e.g. 42)
    # only if one is specified with ":=", None otherwise
    generic_def_vals = []
    for gt in _generic_type_to_end:
        def_val = gt.split(":=")[1].strip() if ":=" in gt else None
        generic_def_vals.append(def_val)

    # generic names, types and default values as a list of tuples
    generics = [
        (gn, gt, gd)
        for gn, gt, gd in zip(generic_names, generic_types, generic_def_vals)
    ]
    return generics


def get_constants_from_pkg(buffer: str):
    """
    Gets all constants names from def file specified by function argument
    :param buffer:   str
    :type pkg_file_path:    str
    :return:                a tuple of str lists [name, type, default value] for every constant
    :rtype:                 TODO
    """
    buffer = _get_raw_vhdl(buffer)

    # constant          "constant"
    # \s+               one or more whitespaces
    # (                 begin of capture group
    #     [a-z]         identifiers must begin with a letter
    #     [a-z_0-9]*    any letter, underscore or digit. zero or more times
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # :                 double colon
    names = re.findall(
        r"constant\s+([a-z][a-z_0-9]*)\s*:", buffer, flags=re.IGNORECASE,
    )

    # TODO evaluate if this is needed
    # # type              "type"
    # # \s+               one or more whitespaces
    # # [a-z]             identifiers must begin with a letter
    # # [a-z_0-9]*        any letter, underscore or digit. zero or more times
    # # \s+               one or more whitespaces
    # # is                "is"
    # # \s*               zero or more whitespaces
    # # \(                opening parenthesis (escaped)
    # # \s*               zero or more whitespaces
    # # (.[^)]+)          capture group. any char one or more times that's not)
    # # \s*               zero or more whitespaces
    # # \)                closing parenthesis (escaped)
    # # \s*               zero or more whitespaces
    # # ;                 semicolon
    # state_types = re.findall(
    #     r"type\s+([a-z][a-z_0-9]*)\s+is\s*\(\s*(.[^)]+)\s*\)\s*;",
    #     buffer,
    #     flags=re.IGNORECASE,
    # )
    # # [('state_type', 'idle, calculation, finishing ')]
    # #  ^tuple access first element as state_types[0][0]

    # :                 double colon
    # \s*               zero or more whitespaces
    # (                 begin of capture group
    #     .*?           any character zero or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # :=                double colon and equals sign
    types = re.findall(r":\s*(.*?)\s*:=", buffer, flags=re.IGNORECASE)

    # :=                double colon and equals sign
    # \s*               zero or more whitespaces
    # (                 begin of capture group
    #     .*?           any character zero or more times. lazy evaluation
    # )                 end of capture group
    # \s*               zero or more whitespaces
    # ;                 semicolon
    def_vals = re.findall(r":=\s*(.*?)\s*;", buffer, flags=re.IGNORECASE)
    return (names, types, def_vals)
