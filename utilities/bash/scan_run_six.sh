#!/bin/bash

source ./scan_definitions
source ./sixdeskenv




function how_to_use() {
    cat <<EOF
   `basename $0` [action] [option]

    actions
    -u      list unfinished jobs from BOINC
    -f      correct directory structure
    -i      run incomplete cases on LSF for all cases defined in scan_definitions
    -s      submit jobs to BOINC for all cases defined in scan_definitions
    -l      unlock all for all studies
    -a      run run_results for all cases defined in scan_definitions

    options
    -c      perform action only for the specific study given as argument

    -r      retreive results for jobs listed in the given file

    -P      retrieve in parallel
    -w      perform periodically; works for actions -a, -T
    -b      back up retreived results to /afs/work/
    -T      show status of simulations in scan
            will give information about jobs in queue, finished but unretrieved jobs and retrieved jobs
    -S      selective submission [see man of run_six.sh]
    -q      quiet mode; parses output to different files


EOF
}


### DEFINE FUNCTIONS


function check_BOINC_results() {

    echo 
    echo "--> CHECKING ${USER}'s jobs in /afs/cern.ch/work/b/boinc/boinc/"
    
    if [ ! ${qcase} ]; then
	local SEARCHDIR=/afs/cern.ch/work/b/boinc/boinc/*
    else
	local SEARCHDIR=/afs/cern.ch/work/b/boinc/boinc/$jobstring
    fi
  

    for DIRNME in $SEARCHDIR
    do
        
	UNM=$(ls -ld ${DIRNME} | awk {'print $3'})
	DIR=${DIRNME%/*}
	BDI=$(basename $DIRNME)
	if [ $UNM = ${USER} ]                                                                                                           
	then
	    NRES=$(ls $DIRNME/results/ | wc -l)
	    NPEN=$(ls $DIRNME/work/    | wc -l)
	    echo 
	    echo "--> NAME         $BDI"
	    echo "--> PENDING      $NPEN" 	    
	    echo "--> COMPLETED    $NRES"
	fi
    done 

}



function runincomplete() {

    if ${scan_chroma} && ${scan_octupoles}
    then
        for x in $SCAN_QP
	do
	    for y in $SCAN_OC
	    do
		mask="${mask_prefix}-${x}-${y}"
		echo "-->  Running incomplete cases for: $mask"		
		set_env_to_mask
		${SixDeskDev}/run_incomplete_cases_lsf	    		
		
	    done
        done
	
    elif ${scan_masks} && ! ${qcase}; then
	for mask in ${mask_names}; do
	    echo "-->  Running incomplete cases for: $mask"
	    set_env_to_mask
	    ${SixDeskDev}/run_incomplete_cases_lsf	    
	done
	
    elif ${qcase}; then
	mask=${jobstring}
	echo "-->  Running incomplete cases for: $mask"
	set_env_to_mask
	${SixDeskDev}/run_incomplete_cases_lsf
    fi    

}


function retrieve_all() {


    if ${scan_chroma} && ${scan_octupoles}
    then
        for x in $SCAN_QP
	do
	    for y in $SCAN_OC
	    do
		kinit -R
		mask="${mask_prefix}-${x}-${y}"
		echo "-->  run_results for: $mask"
		echo "-->  CHROMA: ${x}"
		echo "-->  IMO   : ${y}"
		if ${parallel}; then
		    ${SixDeskDev}/control.sh -w ${workspacedir} -R -s ${mask}  &
		else 
		    ${SixDeskDev}/control.sh -w ${workspacedir} -R -s ${mask}  
		fi
		echo		
	    done
        done
	
    elif ${scan_masks} && ! ${qcase}; then
	for mask in ${mask_names}; do
	    echo "-->  run_results for: $mask"
	    if ${parallel}; then
		${SixDeskDev}/control.sh -w ${workspacedir} -R -s ${mask}  &
	    else 
		${SixDeskDev}/control.sh -w ${workspacedir} -R -s ${mask}  
	    fi
	    echo			    
	done
	
    elif ${qcase}; then
	mask=${jobstring}
	echo "-->  run_results for: $mask"
    fi   

    }


function get_status(){

    BOINCNAME="${workspace}_${mask}"
    BOINCDIR=/afs/cern.ch/work/b/boinc/boinc/${BOINCNAME}
    NRES=$(ls ${BOINCDIR}/results/ | wc -l)                                           # ready to recieve
    
    NPEN=$(ls ${BOINCDIR}/work/    | wc -l)	                                      # pending
    NREC=$(find ../track/${mask}/*/*/*/*/*/*/ -type f -name "*.10.gz" | wc -l)        # recieved

    if ${quiet}; then

	echo "--> NAME         ${mask}" >> ${OUTFILE}
	echo "--> PENDING      $NPEN"   >> ${OUTFILE} 	    
	echo "--> COMPLETED    $NRES"   >> ${OUTFILE}
	echo "--> RECIEVED     $NREC"   >> ${OUTFILE}
	echo ""                         >> ${OUTFILE}
    else
	echo "--> NAME         ${mask}"
	echo "--> PENDING      $NPEN" 	    
	echo "--> COMPLETED    $NRES"
	echo "--> RECIEVED     $NREC"
	echo 
    fi
    
    }


function list_status() {

    if ${scan_chroma} && ${scan_octupoles}
    then
        for x in $SCAN_QP
	do
	    for y in $SCAN_OC
	    do
		kinit -R 
		mask="${mask_prefix}-${x}-${y}"
		get_status
	    done
        done
	
    elif ${scan_masks} && ! ${qcase}; then
	for mask in ${mask_names}; do
	    get_status
	done
	
    elif ${qcase}; then
	mask=${jobstring}
	get_status
    fi    	    

	    
    }




function set_env_to_mask(){
    
    echo "-->  Setting sixdeskenv to ${mask}"
    
    cat sixdeskenv |\
	sed -e 's/export LHCDescrip=.*/export LHCDescrip='$mask'/' > sixdeskenv.new
    
    mv sixdeskenv.new sixdeskenv
    
    ${SixDeskDev}/set_env >> scan_out.dat
}







list_unfinished=false
sear_string=false
submit=false
fix=false
unlock=false
retrieve=false
incomplete=false
qcase=false
retrieveall=false
backup=false
parallel=false
quiet=false
progress=false
status=false
repeat=false
#jobstringQ=false
selective=false

# get options (heading ':' to disable the verbose error handling)
while getopts  "fhwlPc:iuqTSasr:b" opt ; do
    case $opt in
	u)
	    list_unfinished=true
	    ;;
        f)
            fix=true
            ;;
        q)
            quiet=true
            ;;
        S)
            selective=true
            ;;	
        c)
            qcase=true
	    jobstring=${OPTARG}
            ;;
        T)
            status=true
            ;;	
        P)
            parallel=true
            ;;	
        a)
            retrieveall=true
            ;;
        i)
            incomplete=true
            ;;
        b)
            backup=true
            ;;	
        w)
            repeat=true
            ;;	
        r)
            retrieve=true
	    jobstring=${OPTARG}
            ;;
	
        l)
            unlock=true
            ;;
	s)
	    submit=true
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














if ${status}; then
    
    OUTFILE="scan_status.dat"
    DTETIME=$(date)

    if ${quiet}; then
	echo "--> DATE: ${DTETIME}" >> ${OUTFILE}
	echo " "                    >> ${OUTFILE}
    fi


    while true; do
	list_status
	if ! ${repeat}; then
	    exit
	else
	    echo " "
	    sleep 60
	    echo "--> DATE         ${DTETIME}"
	fi
    done
fi


if ${incomplete}; then
    runincomplete
fi




if ${retrieveall}; then
  
    workspacedir=$(pwd)


    if ${repeat}; then
	while true; do


	    
	    retrieve_all

	    kinit -R 




	    
	    list_status

	    
	    dte=$(date)
	    echo "--> ${dte}"
	    echo "--> Waiting 1 minute"
	    

	    sleep 60
	    
	    

	done
    else 
	retrieve_all
    fi

    exit
fi


if ${retrieve}; then

    kinit -R
    
    workspace=$(pwd)
    targetjob=${jobstring}
    
    backupsrc="${workspace}/../track/${targetjob}"
    backuptar="/afs/cern.ch/work/p/phermes/private/170202_sixdesk/track"
    
    echo "-->  Workspace for retrieving:  ${workspace}" 
    echo "-->  Retrieving for targetjob:  ${targetjob}"

    ${SixDeskDev}/control.sh -w ${workspace} -R -s ${targetjob} 
    wait
    if ${backup}; then
	echo "-->  Backup source ${backupsrc}"
	echo "-->  Backup target ${backuptar}"
	mv ${backupsrc} ${backuptar}
    fi
    
    exit
fi






if $list_unfinished; then
    check_BOINC_results
fi




if ${submit}; then
    if ${scan_chroma} && ${scan_octupoles}
    then
        for x in $SCAN_QP
	do
	    for y in $SCAN_OC
	    do
		echo "-->  CHROMA: ${x}"
		echo "-->  IMO   : ${y}"
		mask="${mask_prefix}-${x}-${y}"
		echo "-->  Submitting study: $mask"
		
		set_env_to_mask

		if ${selective} && ${quiet}; then
		    $SixDeskDev/run_six.sh -a -S -q
		elif ${quiet}; then
		    $SixDeskDev/run_six.sh -a -q
		fi
		
		echo		
	    done
        done
	
    elif ${scan_masks} && ! ${qcase}; then
	for mask in ${mask_names}; do
	    set_env_to_mask
	    echo "-->  Submitting study: $mask"
	    if ${selective} && ${quiet}; then
		$SixDeskDev/run_six.sh -a -S -q
	    elif ${quiet}; then
		$SixDeskDev/run_six.sh -a -q
	    fi	    
	done
	
    elif ${qcase}; then
	mask=${jobstring}
	set_env_to_mask
	echo "-->  Submitting SELECTED study: $mask"
	if ${selective} && ${quiet}; then
	    $SixDeskDev/run_six.sh -a -S -q
	elif ${quiet}; then
	    $SixDeskDev/run_six.sh -a -q
	fi
	
    fi    

fi



if ${unlock}; then  
    for x in $SCAN_QP
    do
	for y in $SCAN_OC
	do

	    echo "-->  Submitting study: $mask"
	    echo "-->  CHROMA: ${x}"
	    echo "-->  IMO   : ${y}"
	    mask="${mask_prefix}-${x}-${y}"
	    set_env_to_mask

	    ./unlock_all
	    
	    echo
	    
	done
    done
fi


if ${fix}; then  
    for x in $SCAN_QP
    do
	for y in $SCAN_OC
	do

	    echo "-->  Submitting study: $mask"
	    echo "-->  CHROMA: ${x}"
	    echo "-->  IMO   : ${y}"
	    mask="${mask_prefix}-${x}-${y}"
	    set_env_to_mask

	    $SixDeskDev/run_six.sh -f 
	    
	    echo
	    
	done
    done
fi





exit


