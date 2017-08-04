#!/bin/bash

### INITIALIZATION

#lscan_var1=false
#lscan_var2=false
#lscan_var3=false
#lscan_var4=false
#scan_masks=false
#skipenv=false

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

if [ ! -s ${SixDeskDev}/dot_scan ] ; then
    echo "${SixDeskDev}"
    echo "dot_scan is missing!!!"
    exit 1
fi

sixdeskmessleveldef=0
sixdeskmesslevel=$sixdeskmessleveldef

# - load environment
source ${SixDeskDev}/dot_profile
source ${SixDeskDev}/dot_scan

kinit -R 




function how_to_use() {
    cat <<EOF
   `basename $0` [action] [option]
    performs actions on the input preparation for a defined set of studies

    actions
    -s      submit MAD jobs for all studies to HTCondor
    -p      progress of MAD input
    -m      find missing seeds in study 
    -r      rerun missing seeds in study / remove faulty output

    options
    -c      specify the name of the study to use. Argument: study name. 
            Otherwise the operation will be performed for all elements of the scan.
    -v      verbose mode, by default set to false

EOF
}





scan_







exit




function scan_loop() {


    if [[ $# -eq 0 ]] ; then
	sixdeskmess -1 'ERROR: no argument given to scan_loop'
	sixdeskmess -1 'ERROR: this error should not be triggered, there could be a bug in scan_run_six.sh'
	exit 1
    fi
   
    
    if ${qcase}; then
	echo "QCASE"
	study=${jobstring}
	set_env_to_mask 
	
	for var in "$@"
	do
	    $var
	done
	
    elif ${scan_masks};then
	echo "SCAN_MASKS}"
	for study in ${mask_names}; do
	    echo " SETTING ENVIRONMENT"
	    set_env_to_mask ${study}	    
	    
	    for var in "$@"
	    do
		$var
	    done	    
	done
	
    elif ${lscan_var1} || ${lscan_var2} || ${lscan_var3} || ${lscan_var4} ; then
	echo "LSCAN"
	initialize_scan

	echo "SETTING ENVIRONMENT"
       for va in ${scan_var1_vals}
       do
	   for vb in ${scan_var2_vals}
	   do
	       for vc in ${scan_var3_vals}
	       do
		   for vd in ${scan_var4_vals}
		   do
		       echo ${va}
		       get_mask_name
		       study=${mask}
		       
		       set_env_to_mask ${study}	    
		       
		       
		       for var in "$@"
		       do
			   $var
		       done
		   done
	       done
	   done
       done
    else
	echo "SCAN LOOP: NO OPTION SELECTED -ERROR!"
	exit 1
    fi

    }



function initialize_scan(){

    if ! ${lscan_var1}; then
	scan_var1_vals="0.0"
    fi

    if ! ${lscan_var2}; then
	scan_var2_vals="0.0"
    fi

    if ! ${lscan_var3}; then
	scan_var3_vals="0.0"
    fi

    if ! ${lscan_var4}; then
	scan_var4_vals="0.0"
    fi    

}


get_mask_name(){

    mask=${mask_prefix}

    if ${lscan_var1}; then
	mask="${mask}_${scan_var1}_${va}"
    fi

    if ${lscan_var2}; then
	mask="${mask}_${scan_var2}_${vb}"
    fi

    if ${lscan_var3}; then
	mask="${mask}_${scan_var3}_${vc}"
    fi

    if ${lscan_var4}; then
	mask="${mask}_${scan_var4}_${vd}"
    fi        
    
}


generate_mask_file(){

    get_mask_name

    get_mask_variables
    
    if ${lscan_var1} || ${lscan_var2} || ${lscan_var3} || ${lscan_var4} 
    then
	cat mask/${mask_prefix}.mask |\
	    sed -e "s/${MASKV1}/${va}/g" |\
	    sed -e "s/${MASKV2}/${vb}/g" |\
	    sed -e "s/${MASKV3}/${vc}/g" |\
	    sed -e "s/${MASKV4}/${vd}/g"     >  "mask/${mask}.mask"
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
    sixdeskmess
    sixdeskmess="Study          ${study}"
    sixdeskmess
    sixdeskmess="Workspace      ${workspace}"
    sixdeskmess

    MADdir="${sixtrack_input}/../${study}"
    sixdeskmess="Input in dir   ${MADdir}"
    sixdeskmess

    local rerunQ=false

    seeds=$(seq 1 ${iendmad}) 

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

get_mask_variables(){
    MASKV1="%${scan_var1}V"
    MASKV2="%${scan_var2}V"
    MASKV3="%${scan_var3}V"
    MASKV4="%${scan_var4}V"
}

check_mask_file_vars(){
    MASKVG=$1
    SCANVG=$2

    if grep -q "${MASKVG}" "mask/${mask_prefix}.mask"; then
	sixdeskmess="Scan Variable ${SCANVG}       mask file contains ${MASKV1}"
	sixdeskmess
    else
	sixdeskmess="Scan Variable ${SCANVG}       WARNING for raw mask file ${mask_prefix}.mask!"
	sixdeskmess
	sixdeskmess="Scan Variable ${SCANVG}       String ${MASKVG} not found in mask file"
	sixdeskmess
	sixdeskmess="Scan Variable ${SCANVG}       Continue? [y/n]"	    
	sixdeskmess
	mask_integrity_error_message
    fi	

}


check_mask_file(){

    # this part is still dirty and should be optimized
#    echo 
#    sixdeskmess="Checking mask file for integrity"
    #    sixdeskmess
    get_mask_variables
    
    if ${lscan_var1}; then
	check_mask_file_vars ${MASKV1} ${scan_var1}
    fi
    if ${lscan_var2}; then
	check_mask_file_vars ${MASKV2} ${scan_var2}
    fi
    if ${lscan_var3}; then
	check_mask_file_vars ${MASKV3} ${scan_var3}
    fi
    if ${lscan_var4}; then
	check_mask_file_vars ${MASKV4} ${scan_var4}
    fi
    


    
    if grep -q "%SEEDRAN" "mask/${mask_prefix}.mask"; then
	sixdeskmess -1 "Random seed       mask file contains %SEEDRAN"
    else
	sixdeskmess -1 "ERROR! mask file does not contain %SEEDRAN"
	sixdeskmess -1 "Continue?"
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
    elif ${lscan_var1} || ${lscan_var2} || ${lscan_var3} || ${lscan_var4} ; then
       initialize_scan
       for va in ${scan_var1_vals}
       do
	   for vb in ${scan_var2_vals}
	   do
	       for vc in ${scan_var3_vals}
	       do
		   for vd in ${scan_var4_vals}
		   do	       		   
		       get_mask_name
		       study=${mask}
		       find_missing_seed
		   done
	       done
	   done
       done
    fi
fi






if ${submit}; then
    echo 
    sixdeskmess="SUBMIT MADX JOBS TO PRODUCE SIXTRACK INPUT"
    sixdeskmess
    
    if ${scan_masks}; then
	sixdeskmess="user selected scan_masks"
	sixdeskmess
    else
	sixdeskmess="no scan_masks found"
	sixdeskmess
    fi
	
    echo 
    if ${lscan_var1} || ${lscan_var2} || ${lscan_var3} || ${lscan_var4}; then
	sixdeskmess -1 "Scanning over variables"
	initialize_scan
	for va in ${scan_var1_vals}
	do
	    for vb in ${scan_var2_vals}
	    do
		for vc in ${scan_var3_vals}
		do
		    for vd in ${scan_var4_vals}
		    do	       		   	
			get_mask_name
			sixdeskmess="STUDY             ${mask}"
			sixdeskmess		       		       
			check_mask_file
			generate_mask_file
			set_env_to_mask ${mask}
			run_new_mad6t
		    done
		done
	   done
	done
    elif ${scan_masks}; then
	echo "Preparing input for the following studies:"
	for NAME in ${mask_names}; do
	    echo "${NAME}"
	done
	echo 
	for maskname in ${mask_names}; do
	    mask=${maskname}
	    set_env_to_mask ${mask}
	    run_new_mad6t	    
	done
    fi

fi






if ${progress}; then
    echo 
    if ${lscan_var1} || ${lscan_var2} || ${lscan_var3} || ${lscan_var4}; then
        initialize_scan
	for va in ${scan_var1_vals}
	do
	    for vb in ${scan_var2_vals}
	    do
		for vc in ${scan_var3_vals}
		do
		    for vd in ${scan_var4_vals}
		    do	           
			get_mask_name
			
			sixdeskmess="Progress for study  : ${mask}"
			sixdeskmess
			
			if ${lscan_var1}; then
			    sixdeskmess="${scan_var1}                  : ${va}"
			    sixdeskmess
			fi
			if ${lscan_var2}; then
			    sixdeskmess="${scan_var2}                  : ${vb}"
			    sixdeskmess
			fi
			if ${lscan_var3}; then
			    sixdeskmess="${scan_var3}                  : ${vc}"
			    sixdeskmess
			fi
			if ${lscan_var4}; then
			    sixdeskmess="${scan_var4}                  : ${vd}"
			    sixdeskmess
			fi			

			echo 
			set_env_to_mask ${mask}
			${SixDeskDev}/mad6t.sh -c 
		    done
		done
	   done
       done
    elif ${scan_masks}; then
	echo "scan_masks true"
	for mask in ${mask_names}; do
	    sixdeskmess="Progress for study  : ${mask}"	    
	    sixdeskmess
	    set_env_to_mask ${mask}
	    ${SixDeskDev}/mad6t.sh -c 
       done
    fi
	
fi
