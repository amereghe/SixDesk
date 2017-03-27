#!/bin/bash

source ./scan_definitions
source ./sixdeskenv
#source $SixDeskDev/dot_profile

# ------------------------------------------------------------------------------
# preparatory steps
# ------------------------------------------------------------------------------

export sixdeskhostname=`hostname`
export sixdeskname=`basename $0`
export sixdeskroot=`basename $PWD`
export sixdeskwhere=`dirname $PWD`
# Set up some temporary values until we execute sixdeskenv/sysenv
# Don't issue lock/unlock debug text (use 2 for that)
export sixdesklogdir=""
export sixdesklevel=1
export sixdeskhome="."
export sixdeskecho="yes!"
if [ ! -s ${SixDeskDev}/dot_profile ] ; then
    echo "${SixDeskDev}"
    echo "dot_profile is missing!!!"
    exit 1
fi

sixdeskmessleveldef=0
sixdeskmesslevel=$sixdeskmessleveldef

# - load environment
source ${SixDeskDev}/dot_profile

kinit -R 


function how_to_use() {
    cat <<EOF
   `basename $0` [action] [option]

    actions
    -s      submit MAD jobs to LSF
    -p      progress of MAD input
    -m      find missing seeds in study 
    -r      rerun missing seeds in study
    options
    -c      specify the name of the study to use. Argument: study name. 
            Otherwise the operation will be performed for all elements of the scan.
    -v      verbose mode, by default set to false

EOF
}

## if a scan in octupole and/or chromaticity should be carried out, the
## corresponding settings in the mask file must be replaced by
## %QPV and %OCV




set_env_to_mask(){
    
#    echo "--> Setting sixdeskenv to ${mask}"
    
#    cat sixdeskenv |\
#	sed -e 's/export LHCDescrip=.*/export LHCDescrip='$mask'/' > sixdeskenv.new
  #  #
#    mv sixdeskenv.new sixdeskenv
    
    ${SixDeskDev}/set_env.sh -d ${mask} > /dev/null 2>&1
}


function initialize_scan(){

    if ! ${scan_chroma}; then
	SCAN_QP="0.0"
    fi

    if ! ${scan_octupoles}; then
	SCAN_OC="0.0"
    fi    

}


get_mask_name(){

    mask=${mask_prefix}

    if ${scan_chroma}; then
	mask="${mask}-QP-${qp}"
    fi
    
    if ${scan_octupoles}; then
	mask="${mask}-OC-${oc}"
    fi
    
}

generate_mask_file(){

    get_mask_name
    
    if ${scan_chroma} || ${scan_octupoles} 
    then
	cat mask/${mask_prefix}.mask |\
	    sed -e 's/%QPV/'${qp}'/g' |\
	    sed -e 's/%OCV/'${oc}'/g' >  "mask/${mask}.mask"
    fi
    

}





find_rerun_missing_seed(){

    for seed in $(seq 1 ${iendmad})
    do
	local f2name=${SixTrackInput}/${mask}/fort.2_${seed}.gz
	#echo "$f2name"
	if [ ! -e ${f2name} ]; then
	    ../redomad/redomadx.sh ${mask} ${seed}
	    sixdeskmess="Re-running MADX run ${mask} for seed ${seed}"
	    sixdeskmess
	fi
    done
    
    }



function find_missing_seed() {

    echo
    sixdeskmess="Find missing seeds"
    sixdeskemss
    sixdeskmess="Study          ${study}"
    sixdeskmess
    sixdeskmess="Workspace      ${workspace}"

    MADdir="${sixtrack_input}"
    sixdeskmess="Input in dir   ${MADdir}"

    local rerunQ=false

    seeds=$(seq 1 60) # later we could get them from 

    for i in ${seeds}; do

	rerunQ=false
	f16="${MADdir}/fort.16_${i}.gz"
	f02="${MADdir}/fort.2_${i}.gz"
	f08="${MADdir}/fort.8_${i}.gz"

	if [ ! -e ${f16} ]; then
	    sixdeskmess="Seed ${i} - fort.16 not existing"
	    sixdeskmess
	    rerunQ=true
	fi
	if [ ! -e ${f02} ]; then
	    sixdeskmess="Seed ${i} - fort.2  not existing"
	    sixdeskmess
	    rerunQ=true
	fi
	if [ ! -e ${f08} ]; then
	    sixdeskmess="Seed ${i} - fort.8  not existing"
	    sixdeskmess
	    rerunQ=true
	fi

	if ${rerunQ}; then
	    if ${dorerun}; then
		redo_mad
	    fi
	fi
        
	    	
    done

}




function redo_mad(){

    seed=${i}

    sixtrack_input=${MADdir}
    
    PWD=$(pwd)

    studydir=${PWD}$/../redomad/${study}_seed$seed
    mkdir -p ${studydir}

    cd ${studydir}

    source=$(ls $sixtrack_input/mad*/${study}.$seed | head -1)
    
    cp $source ./baseline.madx

    sixdeskmess="Running madx for study:   "$study",    seed "$seed
    sixdeskmess
    
    madx baseline.madx &> baseline.out

    sixdeskmess="Copying files"
    sixdeskmess

    gzip < fc.2 > fort.2_${seed}.gz
    gzip < fc.8 > fort.8_${seed}.gz
    gzip < fc.16 > fort.16_${seed}.gz

    mv fort.*.gz $sixtrack_input/

    
    if [ $seed -eq 1 ]; then
	cp -f fc.3 $sixtrack_input/fort.3.mad
	cp -f fc.3.aux $sixtrack_input/fort.3.aux
        # update fort.3.mother1.tmp and fort.3.mother2.tmp
	n=0
	while read line 
	do
	    n=`expr $n + 1`
	    if test $n -eq 1
	    then
		echo $line | grep SYNC
		if test $? -ne 0
		then
		    sixdeskmess="First line of fc.3.aux does NOT contain SYNC!!!"
		    sixdeskmess
		    exit 1
		fi
	    else
		echo $line
		myline=`echo $line | sed -e's/^ *//' \
                    -e's/  */ /g'`
		mylength=`echo $myline | cut -d" " -f 5`
		echo $mylength
		sed -e 's/%length/'$mylength'/g' \
		    $sixtrack_input/fort.3.mother1.tmp > $sixtrack_input/fort.3.mother1
		sed -e 's/%length/'$mylength'/g' $sixtrack_input/fort.3.mother2.tmp > $sixtrack_input/fort.3.mother2
		break
	    fi
	done < fc.3.aux
    fi

}

mask_integrity_error_message(){
	read answer
	case ${answer} in	
	    [yY] | [yY][Ee][Ss] )
		sixdeskmess="Continuing..."
		sixdeskmess
                ;;

	    [nN] | [n|N][O|o] )
                sixdeskmess="Interrupted, please modify mask file or check scan_definitions";
		sixdeskmess
                exit 1
                ;;
	    *) sixdeskmess="Invalid input"
	       sixdeskmess
	       ;;
	esac	    
}


check_mask_file(){

    # this part is still dirty and should be optimized
#    echo 
#    sixdeskmess="Checking mask file for integrity"
#    sixdeskmess
    
    if ${scan_chroma}; then
	if grep -q "%QPV" "mask/${mask_prefix}.mask"; then
	    sixdeskmess="Chroma scan       mask file contains %QPV"
	    sixdeskmess
	else
	    sixdeskmess="Chroma scan       WARNING for raw mask file ${mask_prefix}.mask!"
	    sixdeskmess="Chroma scan       mask file not containing %QPV"
	    sixdeskmess="Chroma scan       Continue? [y/n]"
	    mask_integrity_error_message
	fi	
    fi

    
    if ${scan_octupoles}; then
	if grep -q "%OCV" "mask/${mask_prefix}.mask"; then
	    sixdeskmess="Octupole scan     mask file contains %OCV"
	    sixdeskmess
	else
	    sixdeskmess="Octupole scan     WARNING for raw mask file ${mask_prefix}.mask!"
	    sixdeskmess
	    sixdeskmess="Octupole scan     mask file not containing %OCV"
	    sixdeskmess
	    sixdeskmess="Octupole scan     Continue? [y/n]"
	    sixdeskmess
	    mask_integrity_error_message
	fi		
    fi
    if grep -q "%SEEDRAN" "mask/${mask_prefix}.mask"; then
	sixdeskmess="Octupole scan     mask file contains %OCV"
	sixdeskmess
	sixdeskmess="Random seed       mask file contains %SEEDRAN"
	sixdeskmess
    else
	sixdeskmess="ERROR! mask file does not contain %SEEDRAN"
	sixdeskmess
	sixeskmess="Continue?"
	sixdeskmess
	mask_integrity_error_message
    fi
    }





check_sixtrack_input() {
    
    local Nfort2=$(ls ${SixTrackInput}/${mask}/fort.2_*.gz | wc -l)
    local Nfort8=$(ls ${SixTrackInput}/${mask}/fort.8_*.gz | wc -l)    
    local Nfort16=$(ls ${SixTrackInput}/${mask}/fort.16_*.gz | wc -l)    

    sixdeskmess="fort.2:    $Nfort2"
    sixdeskmess
    sixdeskmess="fort.8:    $Nfort8"
    sixdeskmess
    sixdeskmess="fort.16:   $Nfort16"
    sixdeskmess

    if [ ${Nfort2} -eq ${iendmad} ]; then
	find_rerun_missing_seed
    else
	sixdeskmess="sixtrack input not existing"
	sixdeskmess
    fi    
    
    }



# function to submit only new jobs if less than 90% of the seed have been submitted
run_new_mad6t() {

    if [ -e ${SixTrackInput}/${mask}/ ]; then
	exts=( ${SixTrackInput}/${mask}/fort.2_*.gz )
	Nfort2=${#exts[@]}
    else
	Nfort2=0
    fi
    
#   sixdeskmess="fort.2:    $Nfort2"
#   sixdeskmess

    if [ ${Nfort2} -ne 60 ]; then
	sixdeskmess="fort.2 files      ${Nfort2}"
	sixdeskmess
	${SixDeskDev}/mad6t.sh -s
    else
	sixdeskmess="Found ${Nfort2} input files, no new jobs submitted"
	sixdeskmess
    fi    
    
    }


function get_progress(){

	    NF2=$(ls ../../sixtrack_input/${workspace}/${mask}/fort.2* | wc -l)
	    NF1=$(ls ../../sixtrack_input/${workspace}/${mask}/fort.16* | wc -l)
	    sixdeskmess="fort.2 files        : ${NF2}"
	    sixdeskmess
	    sixdeskmess="fort.16 files       : ${NF2}"
	    sixdeskmess
	    echo

    }




submit=false
verbose=false
progress=false
findmissing=false
qcase=false
rerunQ=false

while getopts  "hrvmc:ps" opt ; do
    case $opt in
	s)
	    submit=true
	    ;;
	v)
	    verbose=true
	    ;;	
	c)
	    qcase=true
	    study=${OPTARG}
	    ;;
	m)  findmissing=true
	    ;;
	r)  rerunQ=true
	    findmissing=true
	    ;;	
	p)
	    progress=true
	    ;;	
	h)
	    how_to_use
	    exit 1
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





if ${findmissing}; then
    if ${qcase}; then
	find_missing_seed
    elif ${scan_masks};then
	for study in ${mask_names}; do
	    find_missing_seed
	done
    elif ${scan_chroma} || ${scan_octupoles} ; then
       initialize_scan
       for qp in ${SCAN_QP}
       do
	   for oc in ${SCAN_OC}
	   do
	       get_mask_name
	       study=${mask}
	       find_missing_seed
	   done
       done
    fi
fi






if ${submit}; then
    echo 
    sixdeskmess="SUBMIT MADX JOBS TO PRODUCE SIXTRACK INPUT"
    sixdeskmess
    echo 
    if ${scan_chroma} || ${scan_octupoles}
    then
       initialize_scan
       for qp in ${SCAN_QP}
       do
	   for oc in ${SCAN_OC}
	   do
	       get_mask_name
	       sixdeskmess="STUDY             ${mask}"
	       sixdeskmess		       		       
	       check_mask_file
	       generate_mask_file
	       set_env_to_mask
	       run_new_mad6t
	   done
	done
    elif ${scan_masks}; then
	sixdeskmess="Preparing input for the following studies:"
	sixdeskmess
	sixdeskmess="${mask_names}"
	sixdeskmess
	for mask_prefix in ${mask_names}; do
	    mask=${mask_prefix}
	    set_env_to_mask
	    run_new_mad6t	    
	done
    fi

fi




if ${progress}; then
    echo 
    if ${scan_chroma} || ${scan_octupoles} ; then
       initialize_scan
       for qp in ${SCAN_QP}
       do
	   for oc in ${SCAN_OC}
	   do
	       get_mask_name
	       
	       sixdeskmess="Progress for study  : ${mask}"
	       sixdeskmess
		       
	       if ${scan_chroma}; then
		   sixdeskmess="CHROMATICITY        : ${qp}"
		   sixdeskmess
	       fi
	       if ${scan_octupoles}; then
		   sixdeskmess="OCTUPOLE STRENGTH   : ${oc}"
		   sixdeskmess			   
	       fi
	       echo 
	       get_progress
	   done
       done
    elif ${scan_masks}; then
       for mask in ${mask_names}; do
           sixdeskmess="Progress for study: ${mask}"
	   sixdeskmess
           get_progress
       done
    fi
	
fi
