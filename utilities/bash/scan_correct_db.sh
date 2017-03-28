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
startq=true
complete_errors=false


function initialize(){
    
    let "nseeds=${iendmad}-${istamad}+1"
    let "nampls=(${ns2l}-${ns1l})/${nsincl}"
    let "angles=${kendl}-${kinil}+1"
    let "njobs=${nseeds}*${nampls}*${angles}"

    db_status
    startq=false

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

    if ${startq}; then
	ntaskids_start=${ntaskids}
	ncompl1_start=${ncompl1}
	ncompl2_start=${ncompl2}
	nincom1_start=${nincom1}
	nincom2_start=${nincom2}
    fi
    
    echo
    echo "FILE                 LINES       "
    echo "---------------------------------"    
    echo "taskids              ${ntaskids}"
    echo "---------------------------------"
    echo "completed_cases      ${ncompl1}"
    echo "incomplete_cases     ${nincom1}"
    echo "---------------------------------"    

    echo "mycompleted_cases    ${ncompl2}"
    echo "myincompleted_cases  ${nincom2}"
    echo "---------------------------------"
    echo
}


function correct_db_entries(){

    local correctionq=false
 
    get_jobname

    if ${taskids_correct} && [ ! -e ${dir}/fort.10.gz ]; then
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

    elif ! ${taskids_correct}; then

	if [ -e ${dir}/fort.10.gz ]; then
	    echo "--> Complete:     ${job}"
	    echo ${job} >> work/completed_cases
	    echo ${job} >> work/mycompleted_cases
	else
	    echo "--> Incomplete:   ${job}"	    
	    echo ${job} >> work/incomplete_cases
	    echo ${job} >> work/myincomplete_cases
	fi

	if [ -e work/old_taskids ] && grep -q ${job} work/old_taskids; then
	    grep ${job} work/old_taskids | head -n 1 >> work/taskids
	else    
	    echo ${job} >> work/taskids
	fi
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
    elif ! ${taskids_correct}; then
	rm work/*_cases
	mv work/taskids work/old_taskids
    fi


    

    for dir in track/*/simul/*/*/e5/*; do 
	correct_db_entries	
    done
    
    
}



################################ MAIN ###################################

initialize
check_ntasks

correct_corrupted_database

echo "BEFORE"
echo
echo "FILE                 LINES       "
echo "---------------------------------"    
echo "taskids              ${start_ntaskids}"
echo "---------------------------------"
echo "completed_cases      ${start_ncompl1}"
echo "incomplete_cases     ${start_nincom1}"
echo "---------------------------------"    

echo "mycompleted_cases    ${start_ncompl2}"
echo "myincompleted_cases  ${start_nincom2}"
echo "---------------------------------"
echo
echo "AFTER"
echo 


db_status




exit








