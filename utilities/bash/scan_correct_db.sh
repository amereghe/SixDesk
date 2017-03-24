#!/bin/bash




# assume that the correct sixdeskenv is selected



source ./sixdeskenv

taskidfile="work/taskids"
compcasesfile="work/completed_cases"
incompcasesfile="work/incomplete_cases"
mycompcasesfile="work/mycompleted_cases"
myincompcasesfile="work/myincomplete_cases"

backedupq=false
taskids_correct=false

complete_errors=false


function initialize(){
    
    let "nseeds=${iendmad}-${istamad}+1"
    let "nampls=(${ns2l}-${ns1l})/${nsincl}"
    let "angles=${kendl}-${kinil}+1"
    let "njobs=${nseeds}*${nampls}*${angles}"

    db_status


}







function check_ntasks(){

    if [ ${ntaskids} -eq ${njobs} ]; then
	echo "number of tasks identical to number of jobs"
	taskids_correct=true
    fi


    let "totcomp=${ncompl1}+${nincom1}"

    if [ ${totcomp} -eq ${ntaskids} ]; then
	echo "sum of incomplete and complete_cases equals taskids"
    else
	echo "ERROR: complete and incomplete cases different from taskids"
	complete_errors=true
    fi

    let "totcomp=${ncompl2}+${nincom2}"

    if [ ${totcomp} -eq ${ntaskids} ]; then
	echo "sum of myincomplete and mycomplete_cases equals taskids"
    else
	echo "ERROR: mycomplete and myincomplete cases different from taskids"
	complete_errors=true	
    fi
    

    
    }





function get_jobname(){
    
    job=$(echo ${dir} | sed 's/\//%/g')
    job=$(echo ${job} | sed 's/e5/5/g')
    job=$(echo ${job} | sed "s/track/${LHCDescrip}/g")
    job=$(echo ${job} | sed "s/simul/s/g")
    
    }

function backup_db(){
    mkdir -p work/backup
    cd work
    cp * work/backup
    cd ../
    backedupq=true
}

function db_status(){

    ntaskids=$(less ${taskidfile} | wc -l)    
    ncompl1=$(less work/completed_cases | wc -l)
    ncompl2=$(less work/mycompleted_cases | wc -l)
    nincom1=$(less work/incomplete_cases | wc -l)
    nincom2=$(less work/myincomplete_cases | wc -l)

    echo
    echo "FILE                 LINES       "
    echo "---------------------------------"    
    echo "taskids              ${ntaskids}"
    echo "---------------------------------"
    echo "completed_cases      ${ncompl1}"
    echo "incomplete_cases     ${nincom1}"
    echo "---------------------------------"    
#    echo
    echo "mycompleted_cases    ${ncompl2}"
    echo "myincompleted_cases  ${nincom2}"
    echo "---------------------------------"
    echo
}


function correct_db_entries(){

    local correctionq=false
 
    get_jobname

    if grep -q "${job}" work/completed_cases; then
	sed -i "/${job}/d" work/completed_cases
	correctionq=true
    fi

    if ! grep -q "${job}" work/incomplete_cases; then
	echo ${job} >> work/incomplete_cases
	correctionq=true	
    fi

    if grep -q "${job}" work/mycompleted_cases; then
	sed -i "/${job}/d" work/mycompleted_cases
	correctionq=true	
    fi    

    if ! grep -q "${job}" work/myincomplete_cases; then
	echo ${job} >> work/myincomplete_cases
	correctionq=true	
    fi    

    if ${correctionq}; then
	echo "Corrected: ${job}"
    fi
    
    
    }




function correct_corrupted_database(){
    
    if ! ${backedupq}; then
	backup_db
    fi

    if ${taskids_correct} && ${complete_errors}; then
	echo "Setting up a new database"
	rm work/*_cases
	cat work/taskids | awk '{print $1}' > work/completed_cases
	cat work/taskids | awk '{print $1}' > work/mycompleted_cases
    fi

    for i in track/*/simul/*/*/e5/*; do # Whitespace-safe but not recursive.
	if [ ! -e ${i}/fort.10.gz ]; then
	    dir=${i}
	    if ! ${backedupq}; then
		backup_db
	    fi
	    correct_db_entries
    fi
done
    
    
}



################################ MAIN ###################################

initialize
check_ntasks

correct_corrupted_database

exit








