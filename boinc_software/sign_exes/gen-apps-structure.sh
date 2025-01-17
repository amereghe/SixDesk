#!/bin/bash

# example of tree structure:
# /data/boinc/project/sixtrack/apps/<app_name>
#   |_ gen-apps-structure.sh                    this script
#   |_ <dir_with_new_unsigned_exes>             any name
#   |     |_ <exe1>
#   |     |_ <exe2>
#   |     |_ ...
#   |_ $VER                                     tag of version   \
#       |_ <boinc_platform_1>                      dir           |
#       |    |_ <signed_exe>                       exe           | created by
#       |    |_ <signed_exe>.sig                   signature     |  this script
#       |_ <boinc_platform_2>                                    |
#       |    |_ <signed_exe>                       exe           |
#       |    |_ <signed_exe>.sig                   signature     |
#       |_ ...                                                  /

# NB: <signed_exe> should be UNIQUE names
# NBB:
# - VER/VS: used for signed exes;
# - VSorig: exes to be signed;

PROJ=/usr/local/boinc/project/sixtrack
dir_unsigned=/afs/cern.ch/project/sixtrack/build/50205
VER=502.05
VS=50205
VSorig="${VS}-9c2159c"
commonFlags="boinc"
lCheck=false # check evreything is ready for signature
projXml=../../project.xml
fullAppName=sixtrack

signit()
{
    # interface:
    #   signit <boinc_platform> <exe_to_be_signed> <signed_exe>
    local __dir=$VER/$1
    local __exe=$2
    local __app=$3
    local __lerr=0
    local __platform=`echo $1 | sed 's#__.*##'`
  
    if ${lCheck} ; then
	if [ ! -e ${dir_unsigned}/${__exe} ] ; then
	    echo "unsigned exe ${dir_unsigned}/${__exe} does not exist!"
	    let __lerr+=1
	fi
	local __BOINCplatform=`grep '\<name\>' ${projXml} | cut -d\< -f2 | cut -d\> -f2 | grep ${__platform} 2> /dev/null`
	if [ -z "${__BOINCplatform}" ] ; then
	    echo "unknonw platform: ${1}"
	    let __lerr+=1
	fi
    else
	echo "signing exe: ${__dir} ${__exe} ${__app}" >> README_${VER}_${rightNow}
	[ -d ${__dir} ] || mkdir -p ${__dir}
	cp -u ${dir_unsigned}/${__exe} ${__dir}/${__app}
        # actually sign:
	cd ${__dir}
	echo "GEN SIGN:"
	$PROJ/bin/sign_executable ${__app} $PROJ/keys/code_sign_private >${__app}.sig
	ls
	pwd
	cd -
	echo "_____________________________________________"
	echo ""
    fi
    return ${__lerr}
}

rightNow=`date +"%F_%H-%M-%S"`
if ! ${lCheck} ; then
    [ -d ${VER} ] || mkdir -p ${VER}
    echo "running `basename $0` at ${rightNow}" > README_${VER}_${rightNow}
    echo "unsigned exes from: ${dir_unsigned}" >> README_${VER}_${rightNow}
    echo "version: ${VER} - ${VS} - ${VSorig}" >> README_${VER}_${rightNow}
fi

# #__________________________________________________ linux   64 bit ______________________________________________
signit x86_64-pc-linux-gnu__sse2        SixTrack_${VSorig}_${commonFlags}_Linux64_static                       ${fullAppName}_lin64_${VS}_sse2.linux
signit x86_64-pc-linux-gnu__avx         SixTrack_${VSorig}_${commonFlags}_Linux64_static_avx                   ${fullAppName}_lin64_${VS}_avx.linux
# #__________________________________________________ linux   32 bit ______________________________________________
# signit i686-pc-linux-gnu__sse2          SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_i686_32bit                  ${fullAppName}_lin32_${VS}_sse2.linux
#__________________________________________________ linux   ARM64  ______________________________________________
# NB: no SSE/AVX/x86 instruction sets - keep generic
# signit aarch64-android-linux-gnu        SixTrack_50000_libarchive_stf_cr_boinc_api_crlibm_rn_Linux_gfortran-8_static_aarch64_64bit_double             ${fullAppName}_aarch_android_lin64_${VS}.linux
# signit aarch64-unknown-linux-gnu        SixTrack_50000_libarchive_stf_cr_boinc_api_crlibm_rn_Linux_gfortran-8_static_aarch64_64bit_double             ${fullAppName}_aarch_unknown_lin64_${VS}.linux
# #__________________________________________________ linux   ARM32  ______________________________________________
# # NB: no SSE/AVX/x86 instruction sets - keep generic
# signit arm-unknown-linux-gnueabihf      SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_armv6l_32bit                ${fullAppName}_arm_unknown_lin32_${VS}.linux
# signit armv6l-unknown-linux-gnueabihf   SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_armv6l_32bit                ${fullAppName}_arm6_unknown_lin32_${VS}.linux
# signit armv7l-unknown-linux-gnueabihf   SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_armv6l_32bit                ${fullAppName}_arm7_unknown_lin32_${VS}.linux
# #__________________________________________________ linux   ppc 64 bit le _______________________________________
# signit ppc64-linux-gnu                  SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_ppc64le_64bit               ${fullAppName}_lin64_ppc64le_${VS}.exe
# signit powerpc64le-unknown-linux-gnu    SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_ppc64le_64bit               ${fullAppName}_lin64_ppc64le_${VS}.exe
# 
# 
# #__________________________________________________ android 32bit  ______________________________________________
# signit x86-android-linux-gnu__sse2      SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_i686_32bit                  ${fullAppName}_and32_${VS}_sse2.linux
# #__________________________________________________ android 64bit  ______________________________________________
# signit x86_64-android-linux-gnu__sse2   SixTrack_${VSorig}_${commonFlags}_Linux_gfortran_static_x86_64_64bit                ${fullAppName}_and64_${VS}_sse2.linux
# 
# 
#__________________________________________________ win     64 bit ______________________________________________
signit windows_x86_64__sse2             SixTrack_${VSorig}_${commonFlags}_Win64_static.exe                      ${fullAppName}_win64_${VS}_sse2.exe
signit windows_x86_64__avx              SixTrack_${VSorig}_${commonFlags}_Win64_static_avx.exe                  ${fullAppName}_win64_${VS}_avx.exe
#__________________________________________________ win     32 bit ______________________________________________
signit windows_intelx86__sse2           SixTrack_${VSorig}_${commonFlags}_Win32_static.exe                      ${fullAppName}_win32_${VS}_sse2.exe
signit windows_intelx86__avx            SixTrack_${VSorig}_${commonFlags}_Win32_static_avx.exe                  ${fullAppName}_win32_${VS}_avx.exe
# 
# 
#__________________________________________________ mac     64 bit ______________________________________________
# signit x86_64-apple-darwin__sse2        SixTrack_50000_libarchive_bignblz_cr_boinc_api_crlibm_rn_fast_tilt_cmake_Darwin_gfortran_static_x86_64_64bit_double               ${fullAppName}_darwin_${VS}_sse2.exe
# signit x86_64-apple-darwin__avx         SixTrack_50000_libarchive_bignblz_cr_boinc_api_crlibm_rn_fast_tilt_cmake_Darwin_gfortran_static_avx_x86_64_64bit_double           ${fullAppName}_darwin_${VS}_avx.exe


#__________________________________________________ freeBSD 64 bit ______________________________________________
# signit x86_64-pc-freebsd__sse2          SixTrack_50000_libarchive_stf_cr_boinc_api_crlibm_rn_FreeBSD_gfortran8_static_amd64_64bit_double                                  ${fullAppName}_freeBSD64_${VS}_sse2.exe
# signit x86_64-pc-freebsd__avx           SixTrack_${VSorig}_${commonFlags}_FreeBSD_gfortran_static_avx_amd64_64bit           ${fullAppName}_freeBSD64_${VS}_avx.exe


#__________________________________________________ netBSD  64 bit _______________________________________________
# signit x86_64-pc-netbsd__sse2           SixTrack_${VSorig}_${commonFlags}_NetBSD_gfortran_static_x86_64_64bit               ${fullAppName}_netBSD64_${VS}_sse2.exe
# signit x86_64-pc-netbsd__avx            SixTrack_${VSorig}_${commonFlags}_NetBSD_gfortran_static_avx_x86_64_64bit           ${fullAppName}_netBSD64_${VS}_avx.exe


#__________________________________________________ openBSD 64 bit ______________________________________________
# signit x86_64-pc-openbsd__sse2          SixTrack_${VSorig}_${commonFlags}_OpenBSD_gfortran_amd64_64bit                      ${fullAppName}_openBSD64_${VS}_sse2.exe


#___________________ finalize ________________
# if ! ${lCheck} ; then
#     chown -R lhcathom.boinc $VER
# fi

