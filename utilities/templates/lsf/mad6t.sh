#!/bin/bash
export junktmp=%SIXJUNKTMP%
export iSeed=%SIXI%
export filejob=%SIXFILEJOB%
export CORR_TEST=%CORR_TEST%
export fort_34=%FORT_34%
export MADX_PATH=%MADX_PATH%
export MADX=%MADX%
export lCP=%lCP%

if ${lCP} ; then
    cp ${junktmp}/${filejob}.${iSeed} .
fi

echo "Calling madx version $MADX in $MADX_PATH"
${MADX_PATH}/${MADX} ${filejob}.${iSeed} > ${filejob}.out.${iSeed}
touch ${filejob}.out.${iSeed}
if ${lCP} ; then
    cp ${filejob}.out.${iSeed} ${junktmp}
fi

ls -l

touch fc.3
if [ -f fc.3.aper ]; then
  cat fc.3.aper >> fc.3
fi
mv fc.3 fc.3.mad

for tmpF in 2 8 16 3.mad 3.aux ; do
    touch fc.${tmpF}
    mv fc.${tmpF} fort.${tmpF}_${iSeed}
    gzip fort.${tmpF}_${iSeed}
    if ${lCP} ; then
	cp fort.${tmpF}_${iSeed}.gz ${junktmp}
    fi
done

if [ "$fort.34" != "" ] ; then
    touch fc.34
    mv fc.34 fort.34_${iSeed}
    gzip fort.34_${iSeed}
    if ${lCP} ; then
	cp fort.34_${iSeed}.gz ${junktmp}
    fi
fi
   
if [ "$CORR_TEST" -ne 0 ] ; then
    for fil in MCSSX_errors MCOSX_errors MCOX_errors MCSX_errors MCTX_errors ; do
        touch ${fil}
        mv ${fil} ${fil}_${iSeed}
        gzip ${fil}_${iSeed}
	if ${lCP} ; then
	    cp ${fil}_${iSeed}.gz ${junktmp}
	fi
    done
fi

ls -l
