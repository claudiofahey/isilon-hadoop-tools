#!/usr/bin/env python
import sys
a = "123456789 abcdefghi\n"
size = int(sys.argv[1])
for i in range(1,size,len(a)):
        sys.stdout.write(a)

