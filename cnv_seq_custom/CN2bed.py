#!/usr/bin/env python
import sys
from optparse import OptionParser

def interval_to_bedpe(size, call, sv_type, i):
    half = size/2
    chrom,interval = call.split(':')
    start,end = [int(x) for x in interval.split('-')]
    length = end-start

    bedpe = '\t'.join([chrom,
                      str( max(1,start-half)),
                      str( start+half),
                      chrom,
                      str( max(1,end-half)),
                      str( end+half),
                      str(i),
                      str(length),
                      '+',
                      '+',
                      'TYPE:' + sv_type])

    return bedpe

parser = OptionParser()

parser.add_option("-c",
    "--cnv_calls",
    dest="cnv_calls",
    help="Output file from CNVanator")

parser.add_option("-o",
    "--out",
    dest="out",
    help="Deletion output bedpe file name")


(options, args) = parser.parse_args()

if not options.cnv_calls:
    parser.error('CNVanator calls not given')

if not options.out:
    parser.error('Deletion output file not given')

f = open(options.cnv_calls,'r')

del_f = open(options.out,'w')


breakpoint_size = 500

i = 1
for l in f:
    A = l.rstrip().split('\t')

    if i == 1 and A[0] == 'cnv': continue

    if A[5] == 'Inf': continue
    if A[5] == '-Inf': continue

    FC = float(A[5])

    if abs(FC) < 0.2: continue

    if FC > 0:
        ev = 'DUPLICATION'

    # check the log2 change.
    if FC < 0:
        ev = 'DELETION'

    chrom = A[1][3:]
  
    start = A[2]
    end = A[3]

    call = chrom + ":" + start + "-" + end

    bedpe = interval_to_bedpe(breakpoint_size, call, ev, i)

    assert ev in ("DUPLICATION", "DELETION"), ev

    del_f.write(bedpe + '\n')

    i += 1

f.close()
del_f.close()
