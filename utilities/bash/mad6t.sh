#!/bin/bash

function how_to_use() {
    cat <<EOF

   `basename $0` [action] [option]
   to manage madx jobs for generating input files for sixtrack

   actions (mandatory, one of the following):
   -c      check
   -s      submit
              in this case, madx jobs are submitted to lsf/htcondor
   -r      post-process
   -w      submit wrong seeds
              NB: the list of wrong seeds must be generated beforehand,
                  by calling `basename $0` -c
   -U      unlock dirs necessary to the script to run
           PAY ATTENTION when using this option, as no check whether the lock
              belongs to this script or not is performed, and you may screw up
              processing of another script

   options (optional):
   -I      madx is run interactively (ie on the node you are locally
              connected to, no submission to lsf at all)
           option available only for submission, not for checking
   -d      study name (when running many jobs in parallel)
   -p      platform name (when running many jobs in parallel)
           this option allows to override the value in sixdeskenv, with no need
              for the user to manually change the corresponding variable. Similarly,
              the variable is NOT automatically updated by the script
   -P      python path
   -o      define output (preferred over the definition of sixdesklevel in sixdeskenv)
               0: only error messages and basic output 
               1: full output
               2: extended output for debugging

EOF
}

function preliminaryChecksM6T(){
    # some sanity checks
    local __lerr=0
    
    if [ ! -s $maskFilesPath/$LHCDescrip.mask ] ; then
	# error: mask file not present
	sixdeskmess -1 "$LHCDescrip.mask is required in sixjobs/mask !!! "
	let __lerr+=1
    fi
    if [ ! -d "$sixtrack_input" ] ; then
	# error: $sixtrack_input directory does not exist
	sixdeskmess -1 "The $sixtrack_input directory does not exist!!!"
	let __lerr+=1
    fi
    if test "$beam" = "" -o "$beam" = "b1" -o "$beam" = "B1" ; then
	appendbeam=''
    elif test "$beam" = "b2" -o "$beam" = "B2" ; then
	appendbeam='_b2'
    else
	# error: unrecognised beam option
	sixdeskmess -1 "Unrecognised beam option $beam : must be null, b1, B1, b2 or B2!!!"
	let __lerr+=1
    fi
    if [ ${__lerr} -gt 0 ] ; then
	sixdeskmess -1 "error in preliminaryChecksM6T - error: ${__lerr}"
	exit
    fi
    
    return $__lerr
}

function submit(){
    # useful echo
    # - madx version and path
    sixdeskmess  1 "Using madx Version $MADX in $MADX_PATH"
    # - Study, Runtype, Seeds, platform, queue
    echo
    sixdeskmess -1 "STUDY          ${LHCDescrip}"
    sixdeskmess -1 "RUNTYPE        ${runtype}"
    if ! ${lwrong} ; then
	sixdeskmess -1 "SEEDS          [${istamad}:${iendmad}]"
    fi
    sixdeskmess -1 "PLATFORM       ${sixdeskplatform}"
    if [ "$sixdeskplatform" == "lsf" ] ; then
	sixdeskmess -1 "QUEUE          ${madlsfq}"
    elif [ "$sixdeskplatform" == "htcondor" ] ; then
	sixdeskmess -1 "QUEUE          ${madHTCq}"
    fi
    echo
    # - interactive madx
    if ${linter}  ; then
	sixdeskmess 1 "Interactive MADX runs"
    fi

    # copy templates...
    cp $controlFilesPath/fort.3.mother1_${runtype} $sixtrack_input/fort.3.mother1.tmp
    cp $controlFilesPath/fort.3.mother2_${runtype}${appendbeam} $sixtrack_input/fort.3.mother2.tmp

    # ...and make sure we set the optional value for the proton mass
    sed -i -e 's?%pmass?'$pmass'?g' \
	   -e 's?%emit_beam?'$emit_beam'?g' \
	   $sixtrack_input/fort.3.mother1.tmp

    # ...take care of crossing angle in bbLens, in case appropriate
    xing_rad=0
    if [ -n "${xing}" ] ; then 
	# variable is defined
	xing_rad=`echo "$xing" | awk '{print ($1*1E-06)}'`
	sixdeskmess  1 " --> crossing defined: $xing ${xing_rad}"
	sed -i -e 's?%xing?'$xing_rad'?g' \
  	    -e 's?/ bb_ho5b1_0?bb_ho5b1_0?g' \
	    -e 's?/ bb_ho1b1_0?bb_ho5b1_0?g' $sixtrack_input/fort.3.mother1.tmp
    else
	sed -i -e 's?^bb_ho5b1_0?/ bb_ho5b1_0?g' \
	       -e 's?^bb_ho1b1_0?/ bb_ho5b1_0?g' $sixtrack_input/fort.3.mother1.tmp
    fi
     
    # Clear flags for checking
    for tmpFile in CORR_TEST ERRORS WARNINGS ; do
	rm -f $sixtrack_input/$tmpFile
    done

    if ${lwrong} ; then

	junktmp=`dirname ${lastJobsList}`
	cd ${junktmp}
	sixdeskmess 1 "Using junktmp: $junktmp"

    else

	sixdeskmktmpdir mad $sixtrack_input
	export junktmp=$sixdesktmpdir
	sixdeskmess 1 "Using junktmp: $junktmp"
	
	cd $junktmp
	filejob=$LHCDescrip
	cp $maskFilesPath/$filejob.mask .

	# remove any previous list of jobs
	if [ "$sixdeskplatform" == "htcondor" ] ; then
	    rm -f jobs.list
	fi

	# use AFS absolute paths
	local __lCP=false
	if ${linter} || [ "$sixdeskplatform" == "lsf" ] ; then
	    local __lCP=true
	fi
        
        # in case, create .previous files
        for tmpFile in fort.3.mad fort.3.aux ; do
            if [ -e ${sixtrack_input}/${tmpFile} ] ; then
                mv ${sixtrack_input}/${tmpFile} ${sixtrack_input}/${tmpFile}.previous
            fi
        done
        
        cp -p ${lsfFilesPath}/mad6t.sh ${sixtrack_input}
        cp -p ${SCRIPTDIR}/templates/htcondor/mad6t.sub ${sixtrack_input}
        
	# Loop over seeds
	for (( iMad=$istamad ; iMad<=$iendmad ; iMad++ )) ; do
	    
	    # in case, create .previous files
            for tmpFile in fort.2 fort.8 fort.16 fort.34 MCSSX_errors MCOSX_errors MCOX_errors MCSX_errors MCTX_errors ; do
                if [ -e ${sixtrack_input}/${tmpFile}_$iMad.gz ] ; then
                    mv ${sixtrack_input}/${tmpFile}_$iMad.gz ${sixtrack_input}/${tmpFile}_$iMad.previous.gz
                fi
            done
	    
	    sed -e 's?%NPART?'$bunch_charge'?g' \
		-e 's?%EMIT_BEAM?'$emit_beam'?g' \
		-e 's?%XING?'$xing'?g' \
		-e 's?%SEEDSYS?'$iMad'?g' \
		-e 's?%SEEDRAN?'$iMad'?g' $filejob.mask > $filejob."$iMad"
	    sed -e 's?%SIXJUNKTMP%?'$junktmp'?g' \
		-e 's?%SIXI%?'$iMad'?g' \
		-e 's?%SIXFILEJOB%?'$filejob'?g' \
		-e 's?%CORR_TEST%?'$CORR_TEST'?g' \
		-e 's?%FORT_34%?'$fort_34'?g' \
		-e 's?%MADX_PATH%?'$MADX_PATH'?g' \
		-e 's?%MADX%?'$MADX'?g' \
		-e "s?%lCP%?${__lCP}?g" ${sixtrack_input}/mad6t.sh > mad6t_"$iMad".sh
	    chmod 755 mad6t_"$iMad".sh
	    
	    if ${linter} ; then
		sixdeskmktmpdir batch ""
		cd $sixdesktmpdir
		../mad6t_"$iMad".sh 2>&1 | tee $junktmp/"${LHCDescrip}_mad6t_$iMad".log
		cd ../
		rm -rf $sixdesktmpdir
	    else
		if [ "$sixdeskplatform" == "lsf" ] ; then
		    read BSUBOUT <<< $(bsub -q $madlsfq -o $junktmp/"${LHCDescrip}_mad6t_$iMad".log -J ${workspace}_${LHCDescrip}_mad6t_$iMad mad6t_"$iMad".sh)
		    tmpString=$(printf "Seed %2i        %40s\n" ${iMad} "${BSUBOUT}")
		    sixdeskmess -1 "${tmpString}"
		elif [ "$sixdeskplatform" == "htcondor" ] ; then
		    echo "${iMad}" >> jobs.list
		fi
	    fi
	done
    fi
	
    if [ "$sixdeskplatform" == "htcondor" ] && ! ${linter} ; then
	sed -i -e "s#^+JobFlavour =.*#+JobFlavour = \"${madHTCq}\"#" \
               -e "s#%filejob%#$filejob#" \
               ${sixtrack_input}/mad6t.sub
        local __transferOutputFiles="transfer_output_files = \$(filejob).out.\$(seedID),fort.3.mad_\$(seedID).gz,fort.3.aux_\$(seedID).gz,fort.2_\$(seedID).gz,fort.8_\$(seedID).gz,fort.16_\$(seedID).gz"
        if [ "$fort_34" != "" ] ; then
            __transferOutputFiles="${__transferOutputFiles},fort.34_\$(seedID).gz"
        fi
        if [ $CORR_TEST -ne 0 ] && [ ! -s CORR_TEST ] ; then
            __transferOutputFiles="${__transferOutputFiles},MCSSX_errors_\$(seedID).gz,MCOSX_errors_\$(seedID).gz,MCOX_errors_\$(seedID).gz,MCSX_errors_\$(seedID).gz,MCTX_errors_\$(seedID).gz"
        fi
	sed -i -e "s#^transfer_output_files.*#${__transferOutputFiles}#" \
               ${sixtrack_input}/mad6t.sub
	condor_submit -spool -batch-name "mad/$workspace/$LHCDescrip" ${sixtrack_input}/mad6t.sub
	if [ $? -eq 0 ] ; then
	    rm -f jobs.list
	fi
    fi

    # End loop over seeds
    cd $sixdeskhome
}

function check_output_option(){
    local __selected_output_valid
    __selected_output_valid=false
    
    case ${OPTARG} in
    ''|*[!0-2]*) __selected_output_valid=false ;;
    *)           __selected_output_valid=true  ;;
    esac

    if ! ${__selected_output_valid}; then
	echo "ERROR: Option -o requires the following arguments:"
	echo "    0: only error messages and basic output [default]"
	echo "    1: full output"
	echo "    2: extended output for debugging"
	exit 1
    else
	loutform=true
	sixdesklevel_option=${OPTARG}
    fi
    
}


function check(){
    sixdeskmess 1 "Checking MADX runs for study $LHCDescrip in ${sixtrack_input}"
    local __lerr=0
    # accepted discrepancy in file dimensions [%]
    local __factor=1
    local __njobs
    local __currdir=$PWD
    local __lwarn=false

    cd $sixtrack_input
    
    # check errors/warnings
    if [ -s ERRORS ] ; then
	sixdeskmess -1 "There appear to be some MADX errors!"
	sixdeskmess -1 "If these messages are annoying you and you have checked them carefully then"
	sixdeskmess -1 "just remove sixtrack_input/ERRORS or rm sixtrack_input/* and rerun `basename $0` -s!"
	echo "ERRORS"
	cat ERRORS
	let __lerr+=1
    fi
    if [ -s WARNINGS ] ; then
	sixdeskmess -1 "There appear to be some MADX result warnings!"
	sixdeskmess -1 "Some files are being changed; details in sixtrack_input/WARNINGS"
	sixdeskmess -1 "If these messages are annoying you and you have checked them carefully then"
	sixdeskmess -1 "just remove sixtrack_input/WARNINGS"
	echo "WARNINGS"
	cat WARNINGS
	let __lerr+=1
    fi

    # check generated files
    let __njobs=$iendmad-$istamad+1
    iForts="2 8 16"
    if [ "$fort_34" != "" ] ; then
	iForts="${iForts} 34"
    fi
    iMadsResubmit=""
    for iFort in ${iForts} ; do
	# - the expected number of files have been generated
	nFort=0
	local __fileNames=""
	sixdeskmess 1 "Checking that a fort.${iFort}_??.gz exists for each MADX seed requested..."
	for (( iMad=${istamad}; iMad<=${iendmad}; iMad++ )) ; do
	    if [ `ls -1 fort.${iFort}_${iMad}.gz 2> /dev/null | wc -l` -eq 1 ] ; then
		let nFort+=1
		__fileNames="${__fileNames} fort.${iFort}_${iMad}.gz"
	    else
		iMadsResubmit="${iMadsResubmit}\n${iMad}"
	    fi
	done
	if [ ${nFort} -ne ${__njobs} ] ; then
	    sixdeskmess -1 "...discrepancy!!! Found ${nFort} fort.${iFort}_??.gz (expected $__njobs)"
	    let __lerr+=1
	    continue
	else
	    sixdeskmess -1 "...found ${nFort} fort.${iFort}_??.gz (as expected)"
	fi
        # - files are all of comparable dimensions
	tmpFilesDimensions=`\gunzip -l ${__fileNames} 2> /dev/null | grep -v -e compressed -e totals | awk '{print ($2,$4)}'`
	tmpFiles=`echo "${tmpFilesDimensions}" | awk '{print ($2)}'`
	tmpFiles=( ${tmpFiles} )
	tmpDimens=`echo "${tmpFilesDimensions}" | awk '{print ($1)}'`
	tmpAve=`echo "${tmpDimens}" | awk '{tot+=$1}END{print (tot/NR)}'`
	tmpSig=`echo "${tmpDimens}" | awk -v "ave=${tmpAve}" '{tot+=($1-ave)**2}END{print (sqrt(tot)/NR)}'`
	sixdeskmess -1 "   average dimension (uncompressed): `echo ${tmpAve} | awk '{print ($1/1024)}'` kB - sigma: `echo ${tmpSig} | awk '{print ($1/1024)}'` kB"
	if [ `echo ${tmpAve} | awk '{print ($1==0)}'` -eq 1 ] ; then
	    if [ ${iFort} -eq 8 ] || [ ${iFort} -eq 16 ] ; then
		# just a warning
		sixdeskmess -1 "   --> all fort.${iFort} have a NULL dimension!! I guess you did it on purpose..."
		__lwarn=true
	    else
		# actually a potential problem
		sixdeskmess -1 "   --> NULL average file dimension!! Maybe something wrong with MADX runs?"
		let __lerr+=1
	    fi
	elif [ `echo ${tmpAve} ${tmpSig} ${__factor} | awk '{print ($2<$1*$3/100)}'` -eq 0 ] ; then
	    sixdeskmess -1 "   --> spread in file dimensions larger than ${__factor} % !! Maybe something wrong with MADX runs?"
	    let __lerr+=1
	else
	    tmpDimens=( ${tmpDimens} )
	    for (( ii=0; ii<${#tmpDimens[@]}; ii++ )) ; do
		if [ `echo ${tmpDimens[$ii]} ${tmpAve} ${__factor} | awk '{diff=($1/$2-1); if (diff<0) {diff=-diff} ; print(diff<$3/100)}'` -eq 0 ] ; then
		    sixdeskmess -1 "   --> dimension of file `basename ${tmpFiles[$ii]}` is different from average by more than ${__factor} % !!"
		    let __lerr+=1
		    iMad=`basename ${tmpFiles[$ii]} | cut -d\_ -f2 | cut -d\. -f1`
		    iMadsResubmit="${iMadsResubmit}\n${iMad}"
		fi
	    done
	fi
    done
    # - unique list of seeds
    iMadsResubmit=`echo -e "${iMadsResubmit}" | sort -u`
    iMadsResubmit=( ${iMadsResubmit} )
    if [ ${#iMadsResubmit[@]} -gt 0 ] ; then
	# prepare jobs.list file
	# - last junk dir, in case it is needed to re-run selected seeds
	local __lastJunkDir=`\ls -trd */ 2> /dev/null | tail -1`
	if [ -z "${__lastJunkDir}" ] ; then
	    sixdeskmktmpdir mad
	    __lastJunkDir=$sixdesktmpdir
	else
	    # remove trailing '/'
	    __lastJunkDir=`echo "${__lastJunkDir}" | sed 's/\/$//'`
	fi
	# - actual list
	sixdeskmess 1 "generating list of missing MADX seed in ${__lastJunkDir}/jobs.list"
	rm -f ${__lastJunkDir}/jobs.list
	for iMadResubmit in ${iMadsResubmit[@]} ; do
	    echo "${iMadResubmit}" >> ${__lastJunkDir}/jobs.list
	done
    fi

    # check mother files
    if [ ! -s fort.3.mother1 ] || [ ! -s fort.3.mother2 ] ; then
	sixdeskmess -1 "Could not find fort.3.mother1/2 in $sixtrack_input"
	let __lerr+=1
    else
	sixdeskmess 1 "all mother files are there"
    fi

    # multipole errors
    if [ $CORR_TEST -ne 0 ] && [ ! -s CORR_TEST ] ; then
	sixdeskmiss=0
	for tmpCorr in MCSSX MCOSX MCOX MCSX MCTX ; do
	    rm -f ${tmpCorr}_errors
	    for (( iMad=$istamad; iMad<=$iendmad; iMad++ )) ; do
		ls $tmpCorr"_errors_"$iMad
		if [ -f $tmpCorr"_errors_"$iMad ] ; then
		    cat  $tmpCorr"_errors_"$iMad >> $tmpCorr"_errors"
		else
		    let sixdeskmiss+=1
		fi
	    done
	done
	if [ $sixdeskmiss -eq 0 ] ; then
	    echo "CORR_TEST MC_error files copied" > CORR_TEST
	    sixdeskmess 1 "CORR_TEST MC_error files copied"
	else
	    sixdeskmess -1 "$sixdeskmiss MC_error files could not be found!!!"
	    let __lerr+=1
	fi
    fi

    if [ ${__lerr} -gt 0 ] ; then
	# final remarks
	sixdeskmess 1 "Problems with MADX runs! - error: ${__lerr}"
	exit
    else
	# final remarks
	sixdeskmess 1 "All the mad6t jobs appear to have completed successfully using madx -X Version $MADX in $MADX_PATH"
	sixdeskmess 1 "Please check the sixtrack_input directory as the mad6t runs may have failed and just produced empty files!!!"
	sixdeskmess 1 "All jobs/logs/output are in sixtrack_input/mad.mad6t.sh* directories"
	if ${__lwarn} ; then
	    sixdeskmess -1 "please check warnings about fort.8 / fort.16"
	fi
    fi
    cd ${__currdir}
    return $__lerr
}

function postProcess(){
    sixdeskmess 1 "Performing post-processing of MADX runs for study $LHCDescrip in ${sixtrack_input}"
    local __lerr=0

    cd ${sixtrack_input}
    [ -d /tmp/${LOGNAME} ] || mkdir -p /tmp/${LOGNAME}
    local __filejob=$LHCDescrip
    #   . all files but pieces of fort.3
    local __checkFiles="fort.2 fort.8 fort.16"
    if [ "$fort_34" != "" ] ; then
        __checkFiles="${__checkFiles} fort.34"
    fi
    if [ "$CORR_TEST" -ne 0 ] ; then
        __checkFiles="${__checkFiles} MCSSX_errors MCOSX_errors MCOX_errors MCSX_errors MCTX_errors"
    fi
    
    # - check single jobs
    for (( iMad=$istamad ; iMad<=$iendmad ; iMad++ )) ; do
        # - job is over
        local __lastJunkDir=`ls -1tr $sixtrack_input/*/${__filejob}.out.${iMad} 2> /dev/null | tail -1`
        if [ -z "${__lastJunkDir}" ] ; then
            sixdeskmess -1 "Seed ${iMad} not finished yet - skipping..."
            let __lerr+=1
            continue
        else
            __lastJunkDir=`dirname ${__lastJunkDir}`
        fi
        # - iMad has been already processed
        local __gzippedFiles=""
        for fil in ${__checkFiles} ; do
            __gzippedFiles="${__gzippedFiles} ${fil}_${iMad}.gz"
        done
        sixdeskInspectPrerequisites false ${sixtrack_input} -s ${__gzippedFiles}
        if [ $? -eq 0 ] ; then
            sixdeskmess -1 "Seed ${iMad} already post-processed - skipping..."
            continue
        fi
        # - MADX has run correctly
        grep -i "finished normally" ${__lastJunkDir}/${__filejob}.out.${iMad} 2>&1 > /dev/null
        if [ $? -ne 0 ] ; then
            sixdeskmess -1 "${__filejob}.${iMad} MADX has NOT completed properly!" | tee -a $sixtrack_input/ERRORS
            let __lerr+=1
        fi
        grep -i "TWISS fail" ${__lastJunkDir}/${__filejob}.out.${iMad} 2>&1 > /dev/null
        if [ $? -eq 0 ] ; then
            sixdeskmess -1 "${__filejob}.${iMad} MADX TWISS appears to have failed!" | tee -a $sixtrack_input/ERRORS
            let __lerr+=1
        fi
        # - a non-NULL fort.2 file has been produced
        if [ `zgrep -v '/' ${__lastJunkDir}/fort.2_${iMad}.gz | wc -l` -eq 0 ] ; then
            sixdeskmess -1 "${__filejob}.${iMad} MADX has produced an empty fort.2!" | tee -a $sixtrack_input/ERRORS
            let __lerr+=1
        fi
        # - a non-NULL fort.34 file has been produced
        if [ "$fort_34" != "" ] ; then
            if [ `zgrep -v '/' ${__lastJunkDir}/fort.34_${iMad}.gz | wc -l` -eq 0 ] ; then
                sixdeskmess -1 "${__filejob}.${iMad} MADX has produced an empty fort.34!" | tee -a $sixtrack_input/ERRORS
                let __lerr+=1
            fi
        fi
        # - check against previous versions of the files
        for fil in ${__checkFiles} ; do
            if [ -s $sixtrack_input/${fil}_${iMad}.previous.gz ] ; then
                gunzip -c $sixtrack_input/${fil}_${iMad}.previous.gz > /tmp/${LOGNAME}/${fil}.previous
                gunzip -c ${__lastJunkDir}/${fil}_${iMad}.gz > /tmp/${LOGNAME}/${fil}
                diff /tmp/${LOGNAME}/${fil}.previous /tmp/${LOGNAME}/${fil} > /tmp/${LOGNAME}/diffs
                if [ $? -ne 0 ] ; then
                    sixdeskmess -1 "${__filejob}.${iMad} MADX has produced a different ${fil}!" | tee -a $sixtrack_input/WARNINGS
                    cat /tmp/${LOGNAME}/diffs >> $sixtrack_input/WARNINGS
                    let __lerr+=1
                fi
                rm $sixtrack_input/${fil}_${iMad}.previous.gz
            fi
            mv ${__lastJunkDir}/${fil}_${iMad}.gz $sixtrack_input/${fil}_${iMad}.gz
        done
        # - pieces of fort.3
        local __suffix=".previous"
        if [ ${iMad} -eq ${istamad} ] ; then
            for fil in fort.3.mad fort.3.aux ; do
                gunzip -c ${__lastJunkDir}/${fil}_${iMad}.gz > /tmp/${LOGNAME}/${fil}
                if [ -s $sixtrack_input/${fil}${__suffix} ] ; then
                    diff $sixtrack_input/${fil}${__suffix} /tmp/${LOGNAME}/${fil} > /tmp/${LOGNAME}/diffs
                    if [ $? -ne 0 ] ; then
                        sixdeskmess -1 "${__filejob}.${iMad} MADX has produced a different ${fil}!" | tee -a $sixtrack_input/WARNINGS
                        cat /tmp/${LOGNAME}/diffs >> $sixtrack_input/WARNINGS
                        let __lerr+=1
                    fi
                fi
                mv /tmp/${LOGNAME}/${fil} $sixtrack_input
            done
            # update fort.3.mother? files with accelerator length
            local __myLen=`grep -v '/' $sixtrack_input/fort.3.aux | grep -A1 SYNC | tail -1 | awk '{print ($5)}'`
            if [ -z "${__myLen}" ] ; then
                sixdeskmess -1 "Cannot find accelerator length in fort.3.aux - something wrong with SYNC block?"
            else
                sed -e "s/%length/${__myLen}/g" $sixtrack_input/fort.3.mother1.tmp > $sixtrack_input/fort.3.mother1
                sed -e "s/%length/${__myLen}/g" $sixtrack_input/fort.3.mother2.tmp > $sixtrack_input/fort.3.mother2
                sixdeskmess -1 "...updated fort.3.mother? with accelerator length: ${__myLen}"
            fi
        fi
    done
    
    cd $sixdeskhome
    return $__lerr
}

# ==============================================================================
# main
# ==============================================================================

# ------------------------------------------------------------------------------
# preliminary to any action
# ------------------------------------------------------------------------------
# - get path to scripts (normalised)
if [ -z "${SCRIPTDIR}" ] ; then
    SCRIPTDIR=`dirname $0`
    SCRIPTDIR="`cd ${SCRIPTDIR};pwd`"
    export SCRIPTDIR=`dirname ${SCRIPTDIR}`
fi
# ------------------------------------------------------------------------------

# initialisation of local vars
linter=false
lsub=false
lcheck=false
lpostpr=false
loutform=false
lwrong=false
lSetEnv=true
lunlockMad6T=false
unlockSetEnv=""
currStudy=""
currPythonPath=""
optArgCurrStudy="-s"
optArgCurrPlatForm=""

# get options (heading ':' to disable the verbose error handling)
while getopts  ":hIwsero:cd:p:P:U" opt ; do
    case $opt in
	h)
	    how_to_use
	    exit 1
	    ;;
	I)
	    # interactive mode of running
	    linter=true
	    ;;
	c)
	    # required checking
	    lcheck=true
	    ;;
	s)
	    # required submission
	    lsub=true
	    ;;
	r)
	    # required post-processing
	    lpostpr=true
	    ;;
	o)
	    # output option
	    check_output_option
	    ;;	
	d)
	    # the user is requesting a specific study
	    currStudy="${OPTARG}"
	    ;;
	p)
	    # the user is requesting a specific platform
	    currPlatform="${OPTARG}"
	    ;;
	w)
	    # re-submit wrong seeds
	    lwrong=true
	    # require submission
	    lsub=true
	    # disable checking
	    lcheck=false
	    ;;
	e)
	    # skip set_env.sh (only when called from scripts;
	    #   users should not be made aware of this option!)
	    lSetEnv=false
	    ;;
	P)
	    # the user is requesting a specific path to python
	    currPythonPath="-P ${OPTARG}"
	    ;;
	U)
	    # unlock currently locked folder
	    lunlockMad6T=true
	    unlockSetEnv="-U"
	    ;;
	:)
	    how_to_use
	    echo "Option -$OPTARG requires an argument."
	    exit 1
	    ;;
	\?)
	    how_to_use
	    echo "Invalid option: -$OPTARG"
	    exit 1
	    ;;
    esac
done
shift "$(($OPTIND - 1))"
# user's requests:
# - actions
if ! ${lcheck} && ! ${lsub} && ! ${lunlockMad6T} && ! ${lpostpr} ; then
    how_to_use
    echo "No action specified!!! aborting..."
    exit 1
elif ( ${lcheck} && ${lsub} ) || ( ${lpostpr} && ${lsub} ) ; then
    how_to_use
    echo "If you want to submit, no other action can be specified!!! aborting..."
    exit 1
elif ${lcheck} && ${linter} ; then
    echo "Interactive mode valid only for running. Switching it off!!!"
    linter=false
elif ${lsub} && ! ${lSetEnv} ; then
    echo "Submission requires to run set_env.sh, but you requested to skip this step - aborting!!"
    exit 1
fi
# - options
if [ -n "${currStudy}" ] ; then
    optArgCurrStudy="-d ${currStudy}"
fi
if [ -n "${currPlatform}" ] ; then
    optArgCurrPlatForm="-p ${currPlatform}"
fi

# load environment
# NB: workaround to get getopts working properly in sourced script
OPTIND=1

if ${lSetEnv} ; then
    echo ""
    printf "=%.0s" {1..80}
    echo ""
    echo "--> sourcing set_env.sh"
    printf '.%.0s' {1..80}
    echo ""
    source ${SCRIPTDIR}/bash/set_env.sh ${optArgCurrStudy} ${optArgCurrPlatForm} ${currPythonPath} ${unlockSetEnv} -e
    printf "=%.0s" {1..80}
    echo ""
    echo ""
else
    echo ""
    printf "=%.0s" {1..80}
    echo ""
    echo "--> sourcing dot_profile"
    printf '.%.0s' {1..80}
    echo ""
    source ${SCRIPTDIR}/bash/dot_profile
    printf "=%.0s" {1..80}
    echo ""
    echo ""
fi
if ${loutform} ; then
    sixdesklevel=${sixdesklevel_option}
fi

# - define locking dirs
lockingDirs=( "$sixdeskstudy" "$sixtrack_input" )

# - unlocking
if ${lunlockMad6T} ; then
    sixdeskunlockAll
    if ! ${lcheck} && ! ${lsub} ; then
	sixdeskmess -1 "requested only unlocking. Exiting..."
	exit 0
    fi
fi

# define trap
trap "sixdeskexit 1" EXIT SIGINT SIGQUIT

# don't use this script in case of BNL
if test "$BNL" != "" ; then
    sixdeskmess -1 "Use prepare_bnl instead for BNL runs!!! aborting..."
    exit
fi

# platform
if ${lSetEnv} ; then
    if [ "$sixdeskplatform" != "lsf" ] && [ "$sixdeskplatform" != "htcondor" ]; then
	# set the platform to the default value
	sixdeskSetPlatForm ""
    fi
fi

if ${lsub} ; then
    # - some checks
    preliminaryChecksM6T

    if ${lwrong} ; then
	if [ "$sixdeskplatform" != "htcondor" ]; then
	    # set the platform to htcondor
	    sixdeskSetPlatForm "htcondor"
	fi
	lastJobsList=`ls -tr ${sixtrack_input}/*/jobs.list 2> /dev/null | tail -1`
	if [ -z "${lastJobsList}" ] ; then
	    sixdeskmess -1 "no jobs list previously generated! - I need one for using -w option"
	    exit
	fi
    fi

    # - queue
    sixdeskSetQueue madlsfq madHTCq
    
    # - lock dirs before doing any action
    sixdesklockAll
    
    submit
    
else

    # check jobs are over
    sixdeskCheckRunningJobs "${workspace}_${LHCDescrip}_mad6t" "mad/$workspace/$LHCDescrip"
    lMissing=$?

    # possibly retrieve data
    if [ "$sixdeskplatform" == "htcondor" ] ; then
        lerr=0
        sixdeskmess -1 "Checking if I need to run condor_transfer_data ..."
        # get clusterIDs
        sixdeskGetHTClusterIDs "mad/$workspace/$LHCDescrip"
        if [ -n "${clusterIDs}" ] ; then
            for __clusterID in ${clusterIDs} ; do
                sixdeskHTCondorTransferData ${__clusterID}
                let lerr+=$?
            done
        fi
        if [ $lerr -ne 0 ] ; then
            sixdeskmess -1 "Something wrong with condor_transfer_data - aborting..."
            exit 1
        fi
    fi
        
    if [ ${lMissing} -ne 0 ] ; then
        sixdeskmess -1 "Not all jobs are over - aborting..."
        exit 1
    fi
    
    if ${lpostpr} ; then
        # - lock dirs before doing any action
        sixdesklockAll
        # - actually do post-processing
        postProcess
        if [ $? -gt 0 ] ; then
            sixdeskmess -1 "Something wrong with post-processing - aborting..."
            exit 1
        fi
    fi
    if ${lcheck} ; then
	check
    fi
fi

# - redefine traps
trap "sixdeskexit 0" EXIT SIGINT SIGQUIT

# echo that everything went fine
echo ""
sixdeskmess -1 "done."
