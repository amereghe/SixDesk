#!/bin/bash

source ./scan_definitions
source ./sixdeskenv


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
    -f      correct directory structure
    -i      run incomplete cases on LSF for all cases defined in scan_definitions
    -s      submit jobs to BOINC for all cases defined in scan_definitions
    -e      rerun existing study
    -l      unlock all for all studies
    -R      retrieve results for all jobs listed in scan_definitions. can be combined with -c and -w
    -O      Overview: show submission status for all jobs in scan
    -A      Analyze with sixdb
    -T      show status of simulations in scan
            will give information about jobs in queue, finished but unretrieved jobs and retrieved jobs
    -M      run missing jobs

    options
    -F      force execution of sixdb even if db file exists
    -c      perform action only for the specific study given as argument
    -p      platform. e.g. -p BOINC submits to boinc
    -P      retrieve in parallel
    -L      run on LSF. compatible with -a 
    -w      repeat periodically; works for actions -a, -T
    -S      selective submission [see man of run_six.sh]
    -q      quiet mode; parses output to different files




EOF
}


### DEFINE FUNCTIONS



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


function analyze_sixdb(){

    if [ ! -d ${sixdbdir} ]; then
	echo "ERROR: ${sixdbdir} not found"
	exit 1
    fi
       
    echo "--> RUNNING SIXDESKDB FOR ${study}"
    set_env_to_mask
    thisdir=$(pwd)
	    
    cd ${sixdbdir}
    if [ ! -e ${study}.db ] || ${lforce}; then
	./sixdb ${thisdir} load_dir
    fi

    cd ${thisdir}
	    
    
}



function do_submit(){

    ./unlock_all

    if ${lrerun}; then
	flags="-s"
    else
	flags="-a"
    fi


    if ${quiet}; then
	flags="${flags} -q"
    fi

    if ${selective}; then
	flags="${flags} -S"
    fi

    if ${lplatform}; then
	flages="${flags} -p ${platform}"
    fi

    if ! ${parallel}; then
	echo "FLAGS: ${flags}"
	$SixDeskDev/run_six.sh ${flags}
    else
	sixdeskmess="Parallel submission launched for ${study}"
	sixdeskmess
	$SixDeskDev/run_six.sh ${flags} > output.${study} &
	sixdeskmess="waiting 60s"
	sixdeskmess
	sleep 60	
    fi


    }

function submit_status(){
    sixdeskmess="--------------------------------"
    sixdeskmess
    sixdeskmess="Study: ${study}"
    sixdeskmess
#    tail -n 1 output.${study}
    grep 'Point in scan' output.${study} | tail -n 1
    sixdeskmess="--------------------------------"
    sixdeskmess
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



function retrieve_job_lsf(){
    PWD=$(pwd)
    cat <<EOF > scan_run_six_retrieve_lsf.sh

cd ${PWD}
./scan_run_six.sh -R -w 

EOF
    chmod 777 scan_run_six_retrieve_lsf.sh
    bsub -q 1nw < scan_run_six_retrieve_lsf.sh
    
    }



function retrieve_job(){
    kinit -R
    sixdeskmess="-->  Workspace for retrieving:  ${workspace}"
    sixdeskmess
    sixdeskmess="-->  Retrieving for targetjob:  ${study}"
    sixdeskmess
    ${SixDeskDev}/run_results
}


function scan_loop() {


    if [[ $# -eq 0 ]] ; then
	sixdeskmess='ERROR: no argument given to scan_loop'
	sixdeskmess
	sixdeskmess='ERROR: this error should not be triggered, there could be a bug in scan_run_six.sh'
	sixdeskmess
	exit 1
    fi
   
    
    if ${qcase}; then
	study=${jobstring}
	if ! ${skipenv}; then
	    set_env_to_mask 
	fi
	for var in "$@"
	do
	    $var
	done
	
    elif ${scan_masks};then
	for study in ${mask_names}; do

	    if ! ${skipenv}; then
		set_env_to_mask 
	    fi
	    
	    for var in "$@"
	    do
		$var
	    done	    
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
		       if ! ${skipenv}; then
			   set_env_to_mask >> output.${study}
		       fi
		       
		       for var in "$@"
		       do
			   $var
		       done
		   done
	       done
	   done
        done
    fi

    }











function get_status(){

    BOINCNAME="${workspace}_${mask}"
    BOINCDIR=/afs/cern.ch/work/b/boinc/boinc/${BOINCNAME}
    NRES=$(ls ${BOINCDIR}/results/ | wc -l)                                           # ready to recieve
    
    NPEN=$(ls ${BOINCDIR}/work/    | wc -l)	                                      # pending
    NREC=$(find ../track/${mask}/*/*/*/*/*/*/ -type f -name "*.10.gz" | wc -l)        # recieved

    if ${quiet}; then

	sixdeskmess="--> NAME         ${mask}" >> ${OUTFILE}
	sixdeskmess
	sixdeskmess="--> PENDING      $NPEN"   >> ${OUTFILE}
	sixdeskmess
	sixdeskmess="--> COMPLETED    $NRES"   >> ${OUTFILE}
	sixdeskmess
	sixdeskmess="--> RECIEVED     $NREC"   >> ${OUTFILE}
	sixdeskmess
	sixdeskmess=""                         >> ${OUTFILE}
	sixdeskmess
    else
	sixdeskmess="--> NAME         ${mask}"
	sixdeskmess
	sixdeskmess="--> PENDING      $NPEN"
	sixdeskmess
	sixdeskmess="--> COMPLETED    $NRES"
	sixdeskmess
	sixdeskmess="--> RECIEVED     $NREC"
	sixdeskmess
	echo 
    fi
    
    }




function runmissing(){
    ${SixDeskDev}/run_status
    ${SixDeskDev}/run_six.sh -i -s -p HTCONDOR
}




function set_env_to_mask(){   
    cat sixdeskenv |\
      sed -e "s/export LHCDescrip=.*/export LHCDescrip=${study}/" > sixdeskenv.new
    mv sixdeskenv.new sixdeskenv
    ${SixDeskDev}/set_env
}










sear_string=false
submit=false
fix=false
unlock=false
retrieve=false
incomplete=false
qcase=false
parallel=false
lanalyze=false
lreslsf=false
lplatform=false
lrunmiss=false
lrerun=false
lforce=false
quiet=false
progress=false
status=false
substatus=false
repeat=false
#jobstringQ=false
skipenv=false
selective=false

# get options (heading ':' to disable the verbose error handling)
while getopts  "FfhMwlAp:PLc:iqTOSsRbe" opt ; do
    case $opt in
        f)
            fix=true
            ;;
        F)
            lforce=true
            ;;	
	e)
	    lrerun=true
	    ;;
        M)
            lrunmiss=true
            ;;	
	L)
	    lreslsf=true
	    ;;
        q)
            quiet=true
            ;;
        A)
            lanalyze=true
            ;;
        O)
            substatus=true
            ;;	
        S)
            selective=true
            ;;	
        c)
            qcase=true
	    jobstring=${OPTARG}
            ;;
        p)
            lplatform=true
	    platform=${OPTARG}
            ;;	
        T)
            status=true
            ;;	
        P)
            parallel=true
            ;;	
        i)
            incomplete=true
            ;;
        w)
            repeat=true
            ;;	
        R)
            retrieve=true
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
	    sixdeskmess="Option -$OPTARG requires an argument."
	    sixdeskmess
	    exit 1
	    ;;
	\?)
	    how_to_use
	    sixdeskmess="Invalid option: -$OPTARG"
	    sixdeskmess
	    exit 1
	    ;;
    esac
done
shift "$(($OPTIND - 1))"










if ${lrunmiss}; then
    scan_loop runmissing
fi



if ${status}; then
    
    OUTFILE="scan_status.dat"
    DTETIME=$(date)

    if ${quiet}; then
	sixdeskmess="--> DATE: ${DTETIME}" >> ${OUTFILE}
	sixdeskmess
	sixdeskmess=" "                    >> ${OUTFILE}
	sixdeskmess
    fi


    while true; do
	scan_loop get_status    
	
	if ! ${repeat}; then
	    exit
	else
	    echo " "
	    sleep 60
	    sixdeskmess="--> DATE         ${DTETIME}"
	    sixdeskmess
	fi
    done
fi


if ${lanalyze}; then
    scan_loop analyze_sixdb
fi



if ${incomplete}; then
    scan_loop ${SixDeskDev}/run_incomplete_cases_lsf	    		
fi





if ${retrieve} && ! ${lreslsf} ; then
    if ${qcase}; then
	study=${jobstring}
	retrieve_job
    else
        while true; do
	    scan_loop retrieve_job
	    if ${repeat}; then
		sixdeskmess="Waiting 60s"
		sixdeskmess
		sleep 60
	    else
		exit
	    fi
	done
    fi
fi

if ${retrieve} && ${lreslsf} ; then
    retrieve_job_lsf
fi

   

if ${submit}; then
    scan_loop do_submit 

    clear
    if ${parallel}; then
	sixdeskmess="Submission Status"
	sixdeskmess
	while true; do
	    clear
	    sixdeskmess="Submission Status"
	    sixdeskmess
	    echo
	    scan_loop submit_status
	    sleep 2	    
	done
    fi
fi


if ${unlock}; then
    sixdeskmess="Option unlock all"
    sixdeskmess
    scan_loop ./unlock_all
fi





if ${fix}; then  
    scan_loop $SixDeskDev/run_six.sh -f 
fi

if ${substatus}; then
    skipenv=true
    while true; do
	clear
	sixdeskmess="Submission Status"
	sixdeskmess
	echo
	scan_loop submit_status
	sleep 2
    done
fi











exit


