#!/usr/bin/env python3

import os
import socket
import sys

DEBUG=False

if len(sys.argv) == 2:
  ifile = sys.argv[1]
else:
  sys.exit(0)

if os.path.isfile(ifile):
  with open(ifile, 'r') as f:
    # read the inputfile
    lines = f.read().splitlines()

  newlines = []

  for line in lines:
    if DEBUG:
      print("  ",line)
    # remove any leading or trailing whitespace
    s = line.strip()
    if DEBUG:
      print("   ",s)
    # check if there is something left
    if len(s)>0:
      si = s.split()
      if DEBUG:
        print("    ",si)
      if len(si) > 0:
        try:
          socket.inet_aton(si[0])
          # OK: the first cell will be be the IP-address
          if len(si)>1:
            sit = si[1]
        except socket.error:
          # NOK: the first cell is not an IP-address
          sit = si[0]
      else:
        sit="#"
    else:
      # empty lines are replaced by "#"
      sit = "#"
    if DEBUG:
      print("     ",sit)
    if sit[0] is not "#":
      site = sit
      if DEBUG:
        print(">>>> ",site)
      newlines.append(site)
    if DEBUG:
      print("")
      print("")
  newlines.sort()

  with open(ifile, 'w') as fo:
    for site in newlines:
      fo.write('{0}\n'.format(site))
