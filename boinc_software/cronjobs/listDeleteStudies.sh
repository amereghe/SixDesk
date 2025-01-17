#!/bin/bash

# A.Mereghetti, 2017-04-04
# find studies to be deleted; then, send an email for confirmation
# to be run in:
#     /afs/cern.ch/work/b/boinc/boinc
oldN=30 # days
threshOccupancy=1.0 # [GB]
BOINCspoolDir=$PWD
SCRIPTDIR=`dirname $0`
SCRIPTDIR="`cd ${SCRIPTDIR} ; pwd`"

function treatSingleDir(){
    local __tmpStudy=$1
    if [ -e ${__tmpStudy}/owner ] ; then
	local __ownerFromFile=`cat ${__tmpStudy}/owner`
    else
	local __ownerFromFile="-"
    fi
    local __ownerFromUnix=`\ls -ld ${__tmpStudy} | awk '{print ($3)}'`
    echo "${__tmpStudy}" >> /tmp/${LOGNAME}/delete_${__ownerFromUnix}_${now}.txt
    if [ "${__ownerFromFile}" == "-" ] ; then
	echo "${__tmpStudy}" >> /tmp/${LOGNAME}/no_owner_${now}.txt
    elif [ "${__ownerFromFile}" != "${__ownerFromUnix}" ] ; then
	echo "${__tmpStudy}" >> /tmp/${LOGNAME}/mismatched_owners_${now}.txt
    fi
    echo "study ${__tmpStudy} belongs to ${__ownerFromFile}/${__ownerFromUnix} (owner file / unix)"
}

trap "echo \" ...ending at \`date\` .\" " exit
echo ""
echo " starting `basename $0` at `date` ..."

# prepare delete dir
[ -d delete ] || mkdir delete

# prepare /tmp/sixtadm dir
[ -d /tmp/${LOGNAME} ] || mkdir /tmp/${LOGNAME}

# convert threshold in kB
threshOccupancyKB=`echo ${threshOccupancy} | awk '{print ($1*1024**2)}'`

echo " checking BOINC spooldir ${BOINCspoolDir} ..."

# list spooldirs that can be labelled for deletion and
#    ask confirmation to user
now=`date +"%F_%H-%M-%S"`
# find old directories (based on <workspace>_<studyName>/work/)
if [ -n "$1" ] ; then
    case "$1" in
	work | results )
	    echo " find old directories based on <workspace>_<studyName>/$1/ ..."
	    allStudies=`find . -maxdepth 2 -type d -name $1 -ctime +${oldN}`
	    for currCase in ${allStudies} ; do
		treatSingleDir ${currCase%/$1}
	    done
	    ;;
	* )
	    echo " wrong input: $1 [work|results]"
	    exit 1
	    ;;
    esac
else
    echo " find old directories based on <workspace>_<studyName> only ..."
    allStudies=`find . -maxdepth 1 ! -path . -type d -ctime +${oldN} | grep -v -e upload -e delete`
    for currCase in ${allStudies} ; do
	treatSingleDir ${currCase}
    done
fi

allUsers=`ls -1 /tmp/${LOGNAME}/delete_*txt | cut -d\_ -f2`
for tmpUserName in ${allUsers} ; do
    fileList=delete_${tmpUserName}_${now}.txt
    allStudies=`cat /tmp/${LOGNAME}/${fileList}`
    # send notification email only if dimension is larger than
    tmpTotOccupancyKB=`\du -c --summarize ${allStudies} | tail -1 | awk '{print ($1)}'`
    if [ ${tmpTotOccupancyKB} -gt ${threshOccupancyKB} ] ; then
	tmpTotOccupancy=`echo ${tmpTotOccupancyKB} | awk '{print ($1/1024**2)}'`
	echo "sending notification to ${tmpUserName} ..."
	echo -e "`cat ${SCRIPTDIR}/mail.txt`\n`\du -ch --summarize ${allStudies}`" | sed -e "s/<SixDeskUser>/${tmpUserName}/g" -e "s#<spooldir>#${BOINCspoolDir}#g" -e "s/<xxx>/${oldN}/g" -e "s#<fileList>#${fileList}#g" -e "s/<diskSpace>/${tmpTotOccupancy}/g" | mail -a /tmp/${LOGNAME}/${fileList} -c sixtadm@cern.ch -s "old studies in BOINC spooldir ${BOINCspoolDir}" ${tmpUserName}@cern.ch
    fi
    rm /tmp/${LOGNAME}/${fileList}
done

errorFiles=""
[ ! -e /tmp/${LOGNAME}/no_owner_${now}.txt ] || errorFiles="${errorFiles} /tmp/${LOGNAME}/no_owner_${now}.txt"
[ ! -e /tmp/${LOGNAME}/mismatched_owners_${now}.txt ] || errorFiles="${errorFiles} /tmp/${LOGNAME}/mismatched_owners_${now}.txt"
if [ -n "${errorFiles}" ] ; then
    echo "sending error notification to sixtadm ..."
    echo "errors!" | mail -a /tmp/${LOGNAME}/no_owner_${now}.txt -s "old studies in BOINC spooldir ${BOINCspoolDir} - errors!" sixtadm@cern.ch
    rm -f /tmp/${LOGNAME}/no_owner_${now}.txt
    rm -f /tmp/${LOGNAME}/mismatched_owners_${now}.txt
fi
