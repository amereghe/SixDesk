#!/bin/bash
export junktmp=%SIXJUNKTMP%
export iSeed=%SIXI%
export filejob=%SIXFILEJOB%
export CORR_TEST=%CORR_TEST%
export fort_34=%FORT_34%
export MADX_PATH=%MADX_PATH%
export MADX=%MADX%
export lCP=%lCP%
# for single-turn sixtrack jobs
export lOneTurnJobs=false
export SIXTRACKEXESINGLETURN=sixtrack
export tunesXX=()
export tunesYY=()
export inttunesXX=()
export inttunesYY=()
export e0=7000
export bunch_charge=1.15E11
export chrom=0
export chrom_eps=0.000001
export chromx=2
export chromy=2
export TUNEVAL='/'
export CHROVAL='/'
junkFolder='junk'

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

touch fc.3.mad
if [ -f fc.3.aper ]; then
  cat fc.3.aper >> fc.3.mad
fi

for tmpF in 2 8 16 3.mad 3.aux ; do
    touch fc.${tmpF}
    mv fc.${tmpF} fort.${tmpF}
done

if ${lOneTurnJobs} ; then
    source ./dot_profile
    __myLen=`grep -v '/' fort.3.aux | grep -A1 SYNC | tail -1 | awk '{print ($5)}'`
    sed -e "s/%length/${__myLen}/g" fort.3.mother1.tmp > fort.3.mother1
    sed -e "s/%length/${__myLen}/g" fort.3.mother2.tmp > fort.3.mother2
    sixdeskmess -1 "...updated fort.3.mother? with accelerator length: ${__myLen}"
    # comment out SUB block (in case)
    sed -i -e 's/%SUB/\//g' ./fort.3.mother2
    __currDir=$PWD
    for (( iTuneY=0 ; iTuneY<${#tunesYY[@]} ; iTuneY++ )) ; do
    	if ${lSquaredTuneScan} ; then
    	    # squared scan: for a value of Qy, explore all values of Qx
    	    jmin=0
    	    jmax=${#tunesXX[@]}
    	else
    	    # linear scan: for a value of Qy, run only one value of Qx
    	    jmin=$iTuneY
    	    let jmax=$jmin+1
    	fi
	for (( iTuneX=$jmin; iTuneX<$jmax ; iTuneX++ )) ; do
	    # - tunes
    	    tunexx=${tunesXX[$iTuneX]}
    	    tuneyy=${tunesYY[$iTuneY]}
            # - name:
            sixdesktunes=${tunexx}_${tuneyy}
            # - output dir
            outDir=oneTurnJobs_${iSeed}/${sixdesktunes}
            ! [ -d ${outDir} ] || rm -rf ${outDir}
            mkdir -p ${outDir}
            # - junk dir (temporary one-turn jobs run)
            ! [ -d ${junkFolder} ] || rm -rf ${junkFolder}
            mkdir ${junkFolder}
	    # - int tunes (used in fort.3 for post-processing)
	    inttunexx=${inttunesXX[$iTuneX]}
	    inttuneyy=${inttunesYY[$iTuneY]}
            # - notify user
    	    sixdeskmess -1 "Tunescan $sixdesktunes"
    	    # - run jobs (in dir of tune)
            cp fort.3.mad ${junkFolder}
            cd ${junkFolder}
    	    if [ $chrom -eq 0 ] ; then
    	    	sixdeskmess  1 "Running two `basename $SIXTRACKEXESINGLETURN` (one turn) jobs to compute chromaticity"
    	    	sixdeskSubmitChromaJobs ${__currDir}/${outDir} ${__currDir} ${__currDir}
    	    else
    	    	sixdeskmess -1 "Using Chromaticity specified as $chromx $chromy"
    	    fi
    	    sixdeskmess  1 "Running `basename $SIXTRACKEXESINGLETURN` (one turn) to get beta values"
    	    sixdeskSubmitBetaJob ${__currDir}/${outDir} ${__currDir} ${__currDir}
            cd ${__currDir}
        done
    done
fi

for tmpF in 2 8 16 3.mad 3.aux ; do
    gzip -c fort.${tmpF} > fort.${tmpF}_${iSeed}.gz
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

