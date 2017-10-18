#!/bin/bash

# A.Mereghetti, 2017-03-07
# job file for HTCondor as replacement of LSF

# exe is filled by run_six.sh
# please do not touch these lines
exe=

# echo input parameters
echo "exe: ${exe}"

# prepare dir
rm -f fort.10.gz
gunzip fort.*.gz
cp $exe sixtrack
ls -al

# actually run
./sixtrack | tail -100

# show status after run
ls -al

# usual results for DA
if [ ! -s fort.10 ] ; then
    rm -f fort.10
    touch fort.10
fi
gzip fort.10
