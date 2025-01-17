#!/bin/bash

function how_to_use() {
    cat <<EOF

   `basename $0` [action] [option]
   to set up the SixDesk environment

   actions (mandatory, one of the following):
   -s              set up new study or update existing one according to local
                       version of input files (${necessaryInputFiles[@]})
                   NB: the local input files (${necessaryInputFiles[@]})
                       will be parsed, used and saved in studies/
   -d <study_name> load existing study.
                   NB: the input files (${necessaryInputFiles[@]})
                       in studies/<study_name> will be parsed, used and saved in sixjobs
   -n              retrieve input files (${necessaryInputFiles[@]}) from template dir
                       to prepare a brand new study. The template files will
                       OVERWRITE the local ones. The template dir is:
           ${templateInputFilesPath}
   -N <workspace>  create and initialise a new workspace in the current dir;
                   you can also specify the scratch name with the workspace, eg:
           -N scratch0/wTest
                   the scratch can be omitted - it will be simply ignored;
                   the workspace will be populated with template files as from
EOF
    if ${lGitIsThere} ; then
        cat <<EOF
                       the current scripts or as checked-out from the git repo:
                            ${origRepoForSetup}
                       branch:
                            ${origBranchForSetup}
EOF
    else
        cat <<EOF
                       the current scripts;
EOF
    fi
    cat <<EOF
   -U      unlock dirs necessary to the script to run
           PAY ATTENTION when using this option, as no check whether the lock
              belongs to this script or not is performed, and you may screw up
              processing of another script

   options (optional)
   -p      platform name (when running many jobs in parallel)
           recognised platforms: LSF, BOINC, HTCONDOR
           this option allows to override the value in sixdeskenv, with no need
              for the user to manually change the corresponding variable. Similarly,
              the variable is NOT automatically updated by the script
   -e      just parse the concerned input files (${necessaryInputFiles[@]}),
               without overwriting
   -l      use fort.3.local. This file will be added to the list of necessary
               input files only in case this flag will be issued.
   -g      use a git sparse checkout to initialise workspace (takes disk space)
   -c      take into account also scan_definitions file. This option is available
               only in conjunction with -n
   -P      python path
   -v      verbose (OFF by default)

EOF
}

function basicChecks(){

    # - running dir
    if [ "$sixdeskroot" != "sixjobs" ] ; then
        sixdeskmess -1 "This script must be run in the directory sixjobs!!!"
        sixdeskexit 1
    fi

    # - make sure we have a studies directory
    if ${lset} ; then
        [ -d studies ] || mkdir studies
    elif ${lload} ; then
        sixdeskInspectPrerequisites ${lverbose} studies -d
    fi
    if [ $? -gt 0 ] ; then
        sixdeskexit 2
    fi

    # - make sure that, in case of loading, we have the concerned directory in studies:
    if ${lload} ; then
        sixdeskInspectPrerequisites ${lverbose} ${envFilesPath} -d
        if [ $? -gt 0 ] ; then
            sixdeskmess -1 "Dir containing input files for study $currStudy not found!!!"
            sixdeskmess -1 "Expected: ${envFilesPath}"
            sixdeskexit 3
        fi
    fi
    
}

function consistencyChecks(){

    # - make sure we are in the correct workspace
    if [ -z "${workspace}" ] ; then
        sixdeskmess -1 "Workspace not declared in $envFilesPath/sixdeskenv!!!"
        sixdeskexit 5
    fi
    local __cworkspace=`basename $sixdeskwhere`
    if [ "${workspace}" != "${__cworkspace}" ] ; then
        sixdeskmess -1 "Workspace mismatch: ${workspace} (from sixdeskenv) different from ${__cworkspace} (from current path)!!!"
        sixdeskmess -1 "Check the workspace definition in $envFilesPath/sixdeskenv."
        sixdeskexit 6
    fi

    # - study:
    #   . make sure we have one in sixdeskenv
    if [ -z "${LHCDescrip}" ] ; then
        sixdeskmess -1 "LHCDescrip not declared in $envFilesPath/sixdeskenv!!!"
        sixdeskexit 7
    fi
    #   . make sure it corresponds to the expected one
    if ${lload} ; then
        if [ "${LHCDescrip}" != "${currStudy}" ] ; then
            sixdeskmess -1 "Study mismatch: ${LHCDescrip} (from sixdeskenv) different from $currStudy (command-line argument)!!!"
            sixdeskexit 8
        fi
    fi

    # - sixtrack app version
    sixDeskCheckApp
    if [ $? -ne 0 ] ; then
        sixdeskexit 11
    fi
}

function getInfoFromFort3Local(){
    export fort3localLines=`gawk 'NF' ${envFilesPath}/fort.3.local`
    local __activeLines=`echo "${fort3localLines}" | grep -v '/'`
    local __firstActiveBlock=`echo "${__activeLines}" | head -1 | cut -c1-4`
    local __otherActiveBlocks=`echo "${__activeLines}" | grep -A1 NEXT | grep -v NEXT | grep -v '^\-\-' | cut -c1-4`
    local __allActiveBlocks="${__firstActiveBlock} ${__otherActiveBlocks}"
    __allActiveBlocks=( ${__allActiveBlocks} )
    if [ ${#__allActiveBlocks[@]} -gt 0 ] ; then
        sixdeskmess="active blocks in ${envFilesPath}/fort.3.local:"
        sixdeskmess
        for tmpActiveBlock in ${__allActiveBlocks[@]} ; do
            sixdeskmess="- ${tmpActiveBlock}"
            sixdeskmess
        done
        local __nLines=`echo "${__activeLines}" | wc -l`
        sixdeskmess="for a total of ${__nLines} ACTIVE lines."
        sixdeskmess
    fi
}

function setFurtherEnvs(){
    # set exes
    sixdeskSetExes
    if [ $? -gt 0 ] ; then
        sixdeskexit 19
    fi

    # scan angles:
    lReduceAngsWithAmplitude=false
 
    if [ -n "${reduce_angs_with_aplitude}" ] ; then
        sixdeskmess -1 "wrong spelling of reduce_angs_with_amplitude. Please correct it for future use"
        reduce_angs_with_amplitude=${reduce_angs_with_aplitude}
    fi   
    
    if [ -z "${reduce_angs_with_amplitude}" ]; then
        reduce_angs_with_amplitude=0         
    elif (( $(echo "${reduce_angs_with_amplitude}" | gawk '{print ($1 >=0)}') )); then 
        if [ ${long} -ne 1 ]; then
            sixdeskmess -1 "reduced angles with amplitudes available only for long simulations!"
            sixdeskexit 9
        else
            if [ ${kinil} -ne 1 ] || [ ${kendl} -ne ${kmaxl} ] || [ ${kstep} -ne 1 ]; then
                sixdeskmess -1 "reduced angles with amplitudes available only for kmin=1, kend=kmax and kstep=1"
                sixdeskexit 10
            elif (( $(echo "${reduce_angs_with_amplitude} ${ns2l}" | gawk '{print ($1 >= $2)}') )); then
                sixdeskmess -1 "reduced angles with amplitudes flag greater than maximum amplitude. Please de-activate the flag"
                sixdeskexit 11
            else 
                lReduceAngsWithAmplitude=true
            fi 
        fi
    else
        sixdeskmess -1 "reduced angles with amplitudes set to negative value. Flag de-activated"
    fi
    export totAngle=90
    export lReduceAngsWithAmplitude
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
templateInputFilesPath="${SCRIPTDIR}/../sixjobs"
templateInputFilesPath="`cd ${templateInputFilesPath};pwd`"
# ------------------------------------------------------------------------------

# - infos about current repo
export REPOPATH=`dirname ${SCRIPTDIR}`
if [ `which git 2>/dev/null | wc -l` -eq 1 ] ; then
    lGitIsThere=true
    cd ${REPOPATH}
    # origRepoForSetup='https://github.com/amereghe/SixDesk.git'
    origRepoForSetup=`git remote show origin | grep Fetch | gawk '{print ($NF)}'`
    # origBranchForSetup='newWorkspace'
    origBranchForSetup=`git branch | grep '^*' | gawk '{print ($2)}'`
    cd - 2>&1 > /dev/null
else
    lGitIsThere=false
fi

# - necessary input files
necessaryInputFiles=( sixdeskenv sysenv )

# actions and options
lset=false
lload=false
lcptemplate=false
lcrwSpace=false
loverwrite=true
lverbose=false
llocalfort3=false
lScanDefs=false
lunlock=false
lgit=false
currPlatform=""
currStudy=""
tmpPythonPath=""

# variables set based on parsing fort.3.local

# get options (heading ':' to disable the verbose error handling)
while getopts  ":hsvlcd:ep:P:nN:Ug" opt ; do
    case $opt in
        h)
            how_to_use
            exit 1
            ;;
        s)
            # set study (new/update/switch)
            lset=true
            ;;
        d)
            # load existing study
            lload=true
            currStudy="${OPTARG}"
            ;;
        n) 
            # copy input files from template dir
            lcptemplate=true
            ;;
        N)
            # create workspace
            lcrwSpace=true
            wSpaceName="${OPTARG}"
            # use fort.3.local
            llocalfort3=true
            # use scan_definitions
            lScanDefs=true
            # copy input files from template dir
            lcptemplate=true
            ;;
        e)
            # do not overwrite
            loverwrite=false
            ;;
        p)
            # the user is requesting a specific platform
            currPlatform="${OPTARG}"
            ;;
        l)
            # use fort.3.local
            llocalfort3=true
            ;;
        c)
            # use scan_definitions
            lScanDefs=true
            ;;
        P)
            # the user is requesting a specific path to python
            tmpPythonPath="${OPTARG}"
            ;;
        U)
            # unlock currently locked folder (optional action)
            lunlock=true
            ;;
        v)
            # verbose
            lverbose=true
            ;;
        g)
            # use git sparse checkout to set-up workspace
            if ${lGitIsThere} ; then
                lgit=true
            else
                echo " --> git is NOT there: ignoring -g option"
            fi
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
# user's request
# - actions
if ! ${lset} && ! ${lload} && ! ${lcptemplate} && ! ${lunlock} && ! ${lcrwSpace} ; then
    how_to_use
    echo "No action specified!!! aborting..."
    exit
elif ${lset} && ${lload} ; then
    how_to_use
    echo "Cannot set and load study at the same time!!! aborting..."
    exit
elif ${lcptemplate} && ${lset} ; then
    how_to_use
    echo "Cannot copy templates and set study at the same time!!! aborting..."
    exit
elif ${lcptemplate} && ${lload} ; then
    how_to_use
    echo "Cannot copy templates and load study at the same time!!! aborting..."
    exit
fi
# - de-activate currPlatform in case it is not used
if ${lcptemplate} || ${lcrwSpace} ; then
    if [ -n "${currPlatform}" ] ; then
        echo "--> copy templates / creation of workspace: -p option with argument ${currPlatform} is switched off."
        currPlatform=""
    fi
fi
# - check copy templates:
if ${lcptemplate} ; then
    if ${lgit} ; then
        lScanDefs=true
        llocalfort3=true
    fi
fi
# - options
if [ -n "${currStudy}" ] ; then
    echo "--> User required a specific study: ${currStudy}"
fi
if [ -n "${currPlatform}" ] ; then
    echo "--> User required a specific platform: ${currPlatform}"
fi
if ${llocalfort3} ; then
    echo ""
    echo "--> User requested inclusion of fort.3.local"
    echo ""
    necessaryInputFiles=( "${necessaryInputFiles[@]} fort.3.local" )
fi
if ${lScanDefs} ; then
    if ${lcptemplate} ; then
        echo ""
        echo "--> User requested inclusion of scan_definitions"
        echo ""
        necessaryInputFiles=( "${necessaryInputFiles[@]} scan_definitions" )
    else
        echo ""
        echo "--> Inclusion of scan_definitions avaiable only in case of copy"
        echo "-->    of template files. De-activating it."
        echo ""
        lScanDefs=false
    fi
fi

# ------------------------------------------------------------------------------
# preparatory steps
# ------------------------------------------------------------------------------

export sixdeskhostname=`hostname`
export sixdeskname=`basename $0`
export sixdesknameshort=`echo "${sixdeskname}" | cut -b 1-15`
export sixdeskecho="yes!"
export sixdesklevel=-1
if [ ! -s ${SCRIPTDIR}/bash/dot_profile ] ; then
    echo "dot_profile is missing!!!"
    exit 1
fi
# - load environment
source ${SCRIPTDIR}/bash/dot_profile
# - stuff specific to node where user is running:
sixdeskSetLocalNodeStuff

# - set up new workspace
if ${lcrwSpace} ; then
    sixdeskmess -1 "requested generation of new workspace:"
    sixdeskmess -1 "- current path: $PWD"
    sixdeskmess -1 "- workspace path: ${wSpaceName}"
    if [ -d ${wSpaceName} ] ; then
        how_to_use
        sixdeskmess -1 "workspace ${wSpaceName} already exists!"
        exit 1
    else
        mkdir -p ${wSpaceName}
        cd ${wSpaceName}
        if ${lgit} ; then
            sixdeskmess -1 "Using git to initialise sixjobs dir - repo: ${origRepoForSetup} - branch: ${origBranchForSetup}"
            git init
            git config core.sparseCheckout true
            cat > .git/info/sparse-checkout <<EOF
sixjobs/control_files/*
sixjobs/mask/*
sixjobs/sixdeskTaskIds/*
sixjobs/studies/*
EOF
            git remote add -f origin ${origRepoForSetup}
            git checkout ${origBranchForSetup}
        else
            origDir=${REPOPATH}/sixjobs
            sixdeskmess -1 "Initialising sixjobs from ${origDir}"
            cp -r ${origDir} .
        fi
        cd - 2>&1 > /dev/null
        cd ${wSpaceName}/sixjobs
        touch sixdesklock
        touch studies/sixdesklock
        cd - 2>&1 > /dev/null
    fi
    # do we really need this link?
    [[ "${wSpaceName}" != *"scratch"* ]] || ln -s ${wSpaceName}
    if ! ${lset} && ! ${lload} && ! ${lcptemplate} && ! ${lunlock} ; then
        sixdeskmess -1 "requested only initialising workspace. Exiting..."
        exit 0
    fi
    cd ${wSpaceName}/sixjobs
fi

export sixdeskroot=`basename $PWD`
export sixdeskwhere=`dirname $PWD`
# Set up some temporary values until we parse input files
# Don't issue lock/unlock debug text (use 2 for that)
export sixdesklogdir=""
export sixdeskhome="."

# - locking dirs
if ${lcptemplate} ; then
    lockingDirs=( . )
else
    lockingDirs=( . studies )
fi

# - unlocking
if ${lunlock} ; then
    sixdeskunlockAll
    if ! ${lset} && ! ${lload} && ! ${lcptemplate} ; then
        sixdeskmess -1 "requested only unlocking. Exiting..."
        exit 0
    fi
fi
   
# - path to input files
if ${lset} ; then
    envFilesPath="."
elif ${lload} ; then
    envFilesPath="studies/${currStudy}"
fi

# - basic checks (i.e. dir structure)
basicChecks

# ------------------------------------------------------------------------------
# actual operations
# ------------------------------------------------------------------------------

# - lock dirs
sixdesklockAll

if ${lcptemplate} ; then

    if ${lgit} ; then
        sixdeskmess -1 "Using git to get input files in sixjobs - repo: ${origRepoForSetup} - branch: ${origBranchForSetup}"
        presDir=$PWD
        cd ../
        git branch > /dev/null 2>&1
        if [ $? -ne 0 ] ; then
            # set up git repo
            git init
            git remote add -f origin ${origRepoForSetup}
        fi
        git config core.sparseCheckout true
        if [ `grep 'sixjobs/\*' .git/info/sparse-checkout 2> /dev/null | wc -l` -eq 0 ] ; then
            echo 'sixjobs/*' >> .git/info/sparse-checkout
            git fetch origin ${origBranchForSetup}
            git checkout ${origBranchForSetup}
        else
            rm -f ${necessaryInputFiles[@]}
            git fetch origin ${origBranchForSetup}
            git reset --hard
        fi
        cd ${presDir}

    else
        sixdeskmess -1 "copying here template files for brand new study"
        sixdeskmess -1 "template input files from ${templateInputFilesPath}"

        for tmpFile in ${necessaryInputFiles[@]} ; do
            # preserve original time stamps
            cp -p ${templateInputFilesPath}/${tmpFile} .
            sixdeskmess 2 "${tmpFile}"
        done
    fi

    # get current paths:
    sixdeskGetCurretPaths
    sed -i -e "s#^export workspace=.*#export workspace=${tmpWorkspace}#" \
           -e "s#^export basedir=.*#export basedir=${tmpBaseDir}#" \
           -e "s#^export scratchdir=.*#export scratchdir=${tmpScratchDir}#" \
           -e "s#^export trackdir=.*#export trackdir=${tmpTrackDir}#" \
           -e "s#^export sixtrack_input=.*#export sixtrack_input=${tmpSixtrackInput}#" \
           sixdeskenv
    sed -i -e "s#^export sixdeskwork=.*#export sixdeskwork=${tmpSixdeskWork}#" \
           -e "s#^export cronlogs=.*#export cronlogs=${tmpCronLogs}#" \
           -e "s#^export sixdesklogs=.*#export sixdesklogs=${tmpSixdeskLogs}#" \
           sysenv
else

    # - make sure we have sixdeskenv/sysenv/fort.3.local files
    sixdeskInspectPrerequisites ${lverbose} $envFilesPath -s ${necessaryInputFiles[@]}
    if [ $? -gt 0 ] ; then
        sixdeskmess -1 "not all necessary input files are in $envFilesPath dir:"
        for necInpFile in ${necessaryInputFiles[@]} ; do
            sixdeskInspectPrerequisites true $envFilesPath -s ${necInpFile}
        done
        sixdeskexit 4
    fi

    # - source active sixdeskenv/sysenv
    source ${envFilesPath}/sixdeskenv
    source ${envFilesPath}/sysenv
    if ${llocalfort3} ; then
        getInfoFromFort3Local
    fi

    # - perform some consistency checks on parsed info
    consistencyChecks

    # - set further envs
    setFurtherEnvs

    # - additional files:
    if [ -n "${additionalFilesInp6T}" ] ; then
        sixdeskInspectPrerequisites ${lverbose} $envFilesPath -s "${additionalFilesInp6T}"
        if [ $? -gt 0 ] ; then
            sixdeskmess -1 "not all additional input files for sixtrack are in $envFilesPath dir:"
            for tmpFile in "${additionalFilesInp6T}" ; do
                sixdeskInspectPrerequisites true $envFilesPath -s ${tmpFile}
            done
            sixdeskexit 13
        fi
        for tmpFile in "${additionalFilesInp6T}" ; do
            sixdeskmess -1 "user requested additional input file ${tmpFile} for sixtrack jobs"
        done
    fi

    # - define user tree
    sixdeskDefineUserTree

    # - define some other variables
    sixdeskSetOtherVars

    # - boinc variables
    sixDeskSetBOINCVars

    # - MADX variables
    sixDeskDefineMADXTree ${SCRIPTDIR}
    
    # - save input files
    if ${loverwrite} ; then
        __lnew=false
        if ${lset} ; then
            if ! [ -d ${sixdeskstudy} ] ; then
                __lnew=true
                mkdir ${sixdeskstudy}
            fi
        fi

        # We now call update_sixjobs in case there were changes
        #    and to create for example the logfile directories
        source ${SCRIPTDIR}/bash/update_sixjobs
        if ! ${__lnew} ; then
            # and now we can check 
            source ${SCRIPTDIR}/bash/check_envs
        fi
        
        if ${lset} ; then
            cp ${envFilesPath}/sixdeskenv studies/${LHCDescrip}
            cp ${envFilesPath}/sysenv studies/${LHCDescrip}
            if ${llocalfort3} ; then
                cp ${envFilesPath}/fort.3.local studies/${LHCDescrip}
            fi
            if ${__lnew} ; then
                # new study
                sixdeskmess -1 "Created a NEW study $LHCDescrip"
            else
                # updating an existing study
                sixdeskmess -1 "Updated sixdeskenv/sysenv(/fort.3.local) for $LHCDescrip"
            fi
            # copy necessary .sub/.sh files
            sixdeskmess -1 "if absent, copying necessary .sub/.sh files for MADX run in ${sixtrack_input}"
            sixdeskmess -1 "   and necessary .sub/.sh files for 6T runs in ${sixdeskwork}"
            for tmpFile in htcondor/mad6t.sub lsf/mad6t.sh lsf/mad6t1.sh ; do
                [ -e ${sixtrack_input}/`basename ${tmpFile}` ] || cp -p ${SCRIPTDIR}/templates/${tmpFile} ${sixtrack_input}
            done
            for tmpFile in htcondor/htcondor_run_six.sub htcondor/htcondor_job.sh ; do
                [ -e ${sixdeskwork}/`basename ${tmpFile}` ] || cp -p ${SCRIPTDIR}/templates/${tmpFile} ${sixdeskwork}
            done
            # additional files:
            if [ -n "${additionalFilesInp6T}" ] ; then
                sixdeskmess -1 "taking care of additional files for sixtrack jobs"
                for tmpFile in "${additionalFilesInp6T}" ; do
                    cp ${envFilesPath}/${tmpFile} studies/${LHCDescrip}
                done
            fi
        elif ${lload} ; then
            cp ${envFilesPath}/sixdeskenv .
            cp ${envFilesPath}/sysenv .
            if ${llocalfort3} ; then
                cp ${envFilesPath}/fort.3.local .
            fi
            # additional files:
            if [ -n "${additionalFilesInp6T}" ] ; then
                sixdeskmess -1 "taking care of additional files for sixtrack jobs"
                for tmpFile in "${additionalFilesInp6T}" ; do
                    cp ${envFilesPath}/${tmpFile} .
                done
            fi
            sixdeskmess -1 "Switched to study $LHCDescrip"
        fi
    fi

    # - overwrite platform
    if [ -n "${currPlatform}" ] ; then
        platform=$currPlatform
    fi
    sixdeskSetPlatForm $platform
    if [ $? -ne 0 ] ; then
        sixdeskexit 10
    fi
    if [ "$sixdeskplatform" == "boinc" ] ; then
        sixdeskCheckAppVerBOINC
        if [ $? -ne 0 ] ; then
            sixdeskexit 12
        fi
    fi

    # - set python path
    if [ -n "${tmpPythonPath}" ] ; then
        # overwrite what was stated in sixdeskenv/sysenv
        pythonPath=${tmpPythonPath}
    fi
    sixdeskDefinePythonPath ${pythonPath}

    # - useful output
    PTEXT="[${sixdeskplatform}]"
    STEXT="[${LHCDescrip}]"
    WTEXT="[${workspace}]"
    BTEXT="no BNL flag"
    if [ "$BNL" != "" ] ; then
        BTEXT="BNL flag active"
    fi
    NTEXT="[$sixdeskhostname]"
    if [ -n "${appVer}" ] ; then
        ETEXT="[$appName - ${SIXTRACKEXE} - ${appVer}]"
    else
        ETEXT="[$appName - ${SIXTRACKEXE}]"
    fi

    echo
    sixdeskmess -1 "STUDY          ${STEXT}"
    sixdeskmess -1 "WSPACE         ${WTEXT}"
    sixdeskmess -1 "PLATFORM       ${PTEXT}"
    sixdeskmess -1 "HOSTNAME       ${NTEXT}"
    sixdeskmess -1 "${BTEXT}"
    sixdeskmess -1 "APPNAME/EXE    ${ETEXT}"
    echo
    
    if [ -e "$sixdeskstudy"/deleted ] ; then
        if ${loverwrite} ; then
            rm -f "$sixdeskstudy"/deleted
        else
            sixdeskmess -1 "Warning! Study `basename $sixdeskstudy` has been deleted!!! Please restore it explicitely"
        fi
    fi

fi

# - unlock dirs
sixdeskunlockAll

if ! ${lcptemplate} ; then

    if ${lKerberos} ; then
        # - kinit, to renew kerberos ticket
        sixdeskRenewKerberosToken
    fi
    
    # - fs listquota
    echo ""
    if [[ "${sixdesktrack}" == "/afs"* ]] ; then
        sixdeskmess -1 "fs listquota ${sixdesktrack}:"
        tmpLines=`fs listquota ${sixdesktrack}`
        echo "${tmpLines}"
        #   check, and in case raise a warning
        fraction=`echo "${tmpLines}" | tail -1 | gawk '{frac=$3/$2*100; ifrac=int(frac); if (frac-ifrac>0.5) {ifrac+=1} print (ifrac)}'`
        if [ ${fraction} -gt 90 ] ; then
            sixdeskmess -1 "WARNING: your quota is above 90%!! pay attention to occupancy of the current study, in case of submission..."
        fi
    else
        sixdeskmess -1 "df -Th ${sixdesktrack}:"
        \df -Th ${sixdesktrack}
        sixdeskmess -1 " the above output is at your convenience, for you to check disk space"
    fi

fi
