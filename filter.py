#!/usr/bin/env python3

"""
filter.py
filter a hosts file, removing useless lines
"""

import os
import socket
import sys


def get_cli_params():
    """
    Check for presence of a CLI parameter
    """
    if len(sys.argv) != 2:
        sys.exit(0)
    # 1 parameter required = filename to be processed
    return sys.argv[1]

def read_file(file_to_read_from):
    """
    Return the contents of a file if it exists
    Abort if it doesn't exists
    """
    if not os.path.isfile(file_to_read_from):
        sys.exit(0)
    with open(file_to_read_from, 'r') as f:
        # read the inputfile
        return f.read().splitlines()

def write_file(file_to_write_to, lines_to_write):
    """
    Output <lines_to_write> to the file <file_to_write_to>
    Will overwrite existing file
    """
    with open(file_to_write_to, 'w') as fo:
        for line in lines_to_write:
            fo.write('{0}\n'.format(line))

def main():
    """
    Main loop
    """
    newlines = []
    ifile = get_cli_params()
    lines = read_file(ifile)
    for line in lines:
        # remove any leading or trailing whitespace
        s = line.strip()
        # check if there is something left
        if s:
            si = s.split()
            if si:
                try:
                    socket.inet_aton(si[0])
                    # OK: the first cell will be be the IP-address
                    if len(si) > 1:
                        sit = si[1]
                except socket.error:
                    # NOK: the first cell is not an IP-address
                    sit = si[0]
            else:
                # lines consisting of pure whitespace are replaced by "#"
                # not to worry. "#" are removed later
                sit = "#"
        else:
            # empty lines are replaced by "#"
            # not to worry. "#" are removed later
            sit = "#"
        # output the result; excluding "#"
        if sit[0] != "#":
            site = sit
            newlines.append(site)
    newlines.sort()

    with open(ifile, 'w') as fo:
        for site in newlines:
            fo.write('{0}\n'.format(site))


if __name__ == '__main__':
    main()
