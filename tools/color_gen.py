#! /usr/bin/env python3

import argparse
import re
import sys

import yaml

DEFAULT_COLOR = ('default', 0x01)

COLORS = {
    'engine 1':    0x01,
    'engine 2':    0x02,
    'engine 3':    0x03,
    'engine 4':    0x04,
    'engine 5':    0x05,
    'engine 6':    0x06,
    'engine 7':    0x07,
    'engine 8':    0x08,
    'engine 9':    0x09,
    'engine 10':   0x0A,
    'engine 11':   0x0B,
    'engine 12':   0x0C,
    'engine 13':   0x0D,
    'engine 14':   0x0E,
    'engine 15':   0x0F,
    'engine 16':   0x10
    }

TAB = "    "

HEADER = (
    "//\n" +
    "// This file was generated with color_gen.py and should not be used outside of colorlib.inc\n" +
    "//\n" +
    "// Do not edit! Regenerate this file with color_gen.py\n" +
    "//\n" +
    "\n" +
    "#if defined _colorlib_map_included\n" +
    TAB + "#endinput\n" +
    "#endif\n" +
    "#define _colorlib_map_included\n" +
    "\n"
    )

FOOTER = (
    "\n"
    )

ENUM_DEF = (
    "enum CL_Colors\n" +
    "{{\n" +
    "{}" +
    "}};\n"
    )

ENUM_ENTRY_DEF = TAB + "{} = {},\n"

COLOR_FUNCTION_DEF = (
    "CL_Colors _CL_ColorMap(char color[16])\n" +
    "{{\n" +
    "{}" +
    "\n" +
    "{}" +
    "}}\n"
    )

IF_DEF = [
    TAB + "if (color[{}] == {})\n",
    TAB + "{{\n",
    TAB + "{}",
    TAB + "}}\n"
    ]

ELIF_DEF = [
    TAB + "else if (color[{}] == {})\n",
    TAB + "{{\n",
    TAB + "{}",
    TAB + "}}\n"
    ]

ELSE_DEF = [
    TAB + "else\n",
    TAB + "{{\n",
    TAB + "{};",
    TAB + "}}\n"
    ]

CHAR_DEF = "\'{}\'"

RETURN_DEF = TAB + "return {};\n"

colors = []
color_enum_names = {}

def get_indent(i : int) -> str:
    """Returns indentation to a given level."""
    if i < 1: # no indentation needed
        return ""
    
    indent = TAB
    for i in range(1, i):
        indent = indent + TAB

    return indent

def get_hex(i : int) -> str:
    """Returns a hex representation of a char."""
    return '0x' + '{:02x}'.format(i).upper()

def get_indented_def(i : int, definition : str, first : bool = True) -> str:
    """Returns an indented definition string."""
    # if the first definition in a set do not indent the first line
    if first:
        indented_def = definition[0]
    else:
        indented_def = get_indent(i) + definition[0]

    # indent the remaining lines
    for line in range(1, len(definition)):
        indented_def = indented_def + get_indent(i) + definition[line]

    return indented_def

def group_till_unique(in_group : list, i : int = 0) -> dict:
    """
    Recursively splits a list into a tree,
    where each node is a char in the leafs.
    """
    if (len(in_group) <= 1):
        return in_group

    groups = {}
    for (key, group) in group_by_char_at(in_group, i).items():
        groups[key] = group_till_unique(group, i + 1)

    return groups

def group_by_char_at(colors : list, i : int = 0) -> dict:
    """
    Returns a dictionary of strings from a list,
    grouped by the char at \'i\'.
    """

    # construnct a dictionary of strings
    # examples:
    # colors = ['default', 'darkred', 'red']
    # group_by_char_at(colors, 0)
    # { 'd': ['default', 'darkred'], 'r': ['red'] }
    #
    # colors = ['grey', 'grey2']
    # group_by_char_at(colors, 4)
    # { 0: ['grey'], '2': ['grey2'] }

    groups = {}
    for color in colors:
        if len(color) == i:
            # index greater than length of string so use null terminator
            groups[0] = [color]
        elif color[i] in groups:
            groups[color[i]].append(color)
        else:
            groups[color[i]] = [color]

    return groups

def skip_redundant_decisions(group : dict, indent : int, depth : int) -> str:
    """Optimisation step which skips none defining values."""

    # example:
    # colors = ['default','darkblue', 'darkred']
    # group = { d: { a: { r: { k: { b: ['darkblue'], r: ['darkred'] } } } }, e: ['default'] }
    # # for the given case we only need to check indexs [0,1] and then [4]
    # # to uniquely identify a color
    # # ['d', 'a', 'b'], ['d', 'a', 'r'], ['d', 'e']

    if len(group) == 1:
        for (_, value) in  group.items():
            body = skip_redundant_decisions(value, indent, depth + 1)
    else:
        body = create_decisions(group, indent, depth)

    return body

def create_enum() -> str:
    """Creates the definition for the enum for the mapping function."""
    ev = []
    for color in colors:
        name = 'CL_Color_' + color[0].replace(' ', '_').capitalize()
        value = get_hex(color[1])
        color_enum_names[color[0]] = name
        ev.append(ENUM_ENTRY_DEF.format(name, value))

    enums = ""
    for enum in ev:
        enums = enums + enum

    return ENUM_DEF.format(enums)

def create_return(color : str) -> str:
    """Creates a return statement."""
    return RETURN_DEF.format(color_enum_names[color])

def create_statement(definition : str,
                     indent : int,
                     index : int,
                     key,
                     ret : str,
                     first : bool = True) -> str:
    """Creates a statement (\'if\', \'else if\')."""
    if isinstance(key, str):
        char = CHAR_DEF.format(key)
    else:
        char = hex(key)

    return get_indented_def(
        indent,
        definition,
        first
        ).format(index, char, ret)

def create_if(indent : int, index : int, key, ret : str) -> str:
    """Creates an \'if\' statement."""
    return create_statement(IF_DEF, indent, index, key, ret, True)

def create_elif(indent : int, index : int, key, ret : str) -> str:
    """Creates an \'else if\' statement."""
    return create_statement(ELIF_DEF, indent, index, key, ret, False)

def create_decisions(group : dict, indent : int = 0, depth : int = 0) -> str:
    """Creates the decisions for the mapping function."""
    decisions = ""
    for i, (key, value) in enumerate(group.items()):
        if isinstance(value, dict):
            if len(value) == 1:
                body = skip_redundant_decisions(value, indent + 1, depth + 1)
            else:
                body = create_decisions(value, indent + 1, depth + 1)
        else:
            body = create_return(value[0])
        
        if i == 0:
            decisions = create_if(indent, depth, key, body)
        else:
            decisions = decisions + create_elif(indent, depth, key, body)

    return decisions


def create_map() -> str:
    """Creates the mapping function."""
    groups = group_till_unique([c[0] for c in colors])

    return COLOR_FUNCTION_DEF.format(
        create_decisions(groups), 
        create_return('default')
        )

def parse_config(file, include_ref_colors : bool):
    """Parses ColorGen's the YAML config file."""
    cfg = yaml.load(file, Loader=yaml.Loader)

    ref_colors = {}
    if 'ref_colors' in cfg:
        for (key, value) in cfg['ref_colors'].items():
            if isinstance(value, int):
                ref_colors[key] = value
            else:
                assert value not in COLORS, 'value is not a default engine color or integer value' 
                ref_colors[key] = COLORS[value]

    for (key, value) in cfg['colors'].items():
        if isinstance(value, int):
            colors.append((key, value))
        else:
            if value in ref_colors:
                colors.append((key, ref_colors[value]))
            elif value in COLORS:
                colors.append((key, COLORS[value]))
    
    if include_ref_colors:
        for (key, value) in ref_colors.items():
            colors.append((key, value))


def add_default_colors():
    for (key, value) in COLORS.items():
            colors.append((key, value))

def main():
    parser = argparse.ArgumentParser(description='ColorLib color map creator.')
    parser.add_argument(
        '-e',
        '--include-engine-colors',
        action="store_true",
        dest='include_engine_colors'
        )
    parser.add_argument(
        '-r',
        '--include-ref-colors',
        action="store_true",
        dest='include_ref_colors'
        )
    parser.add_argument(
        '--config',
        dest='config',
        type=argparse.FileType('r', encoding='UTF-8'),
        help='config path \'{path to config dir}/color_conf.yaml\''
        )
    parser.add_argument(
        'out',
        type=argparse.FileType('w', encoding='UTF-8'),
        help='output path \'{path to include dir}/colorlib_map.inc\''
        )

    args = parser.parse_args()

    if args.config != None:
        parse_config(args.config, args.include_ref_colors)
    else:
        colors.append(DEFAULT_COLOR)
    
    if args.include_engine_colors or args.config == None:
        add_default_colors()

    args.out.write(HEADER)
    args.out.write(create_enum())
    args.out.write('\n')
    args.out.write(create_map())
    args.out.write(FOOTER)
    
    args.out.close()

if __name__ == '__main__':
    main()
