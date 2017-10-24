#!/bin/bash
export i=%SIXI%
export filejob=%SIXFILEJOB%
export CORR_TEST=%CORR_TEST%
export fort_34=%FORT_34%
export MADX_PATH=%MADX_PATH%
export MADX=%MADX%

echo "Calling madx version $MADX in $MADX_PATH"
$MADX_PATH/$MADX $filejob."$i" > $filejob.out."$i"

ls -l

touch fc.3
if [ -f fc.3.aper ]; then
  cat fc.3.aper >> fc.3
fi

for tmpF in 2 8 16 ; do
    touch fc.${tmpF}
    mv fc.${tmpF} fort.${tmpF}
    gzip fort.${tmpF}
done

if [ "$fort.34" != "" ] ; then
    touch fc.34
    mv fc.34 fort.34
    gzip fort.34
fi
   
if [ "$CORR_TEST" -ne 0 ] ; then
    for fil in MCSSX_errors MCOSX_errors MCOX_errors MCSX_errors MCTX_errors ; do
        touch ${fil}
        mv ${fil} ${fil}_${i}
        gzip ${fil}_${i}
    done
fi
