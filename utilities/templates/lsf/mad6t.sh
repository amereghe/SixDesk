#!/bin/bash
export i=%SIXI%
export filejob=%SIXFILEJOB%
export sixtrack_input=%SIXTRACK_INPUT%
export CORR_TEST=%CORR_TEST%
export fort_34=%FORT_34%
export MADX_PATH=%MADX_PATH%
export MADX=%MADX%
lFirst=%lFirst%
waitTime=60

if [ ${lFirst} -ne 0 ] ; then
  echo "sleeping ${waitTime} s..."
  sleep ${waitTime}
fi
echo "Calling madx version $MADX in $MADX_PATH"
$MADX_PATH/$MADX < ${sixtrack_input}/${i}/${filejob}.mask > ${filejob}.out
cp -f ${filejob}.out ${sixtrack_input}/${i}
ls -l
grep -i "finished normally" ${filejob}.out > /dev/null
if test $? -ne 0
then
  echo "${i}/${filejob} MADX has NOT completed properly!" | tee -a $sixtrack_input/ERRORS
  exit 1
fi
grep -i "TWISS fail" ${filejob}.out > /dev/null
if test $? -eq 0
then
  echo "${i}/${filejob} MADX TWISS appears to have failed!" | tee -a $sixtrack_input/ERRORS
  exit 2
fi
if [ ${lFirst} -eq 0 ] ; then
  #  RDM 28/4/2015
  #  Mad conversion can have an empty fc.3 in some cases (no multipole errors)
  #  RDM 28/4/2015
  #if test ! -s fc.3
  #then
  #  echo "${i}/${filejob} MADX has produced an empty fc.3/fort.3.mad!" | tee -a $sixtrack_input/ERRORS
  #  exit 3
  #fi
  if test ! -f fc.3
  then
    touch fc.3
  fi
  if [ -f fc.3.aper ]; then
    cat fc.3.aper >> fc.3
  fi
  if test -s $sixtrack_input/fort.3.mad.previous
  then
    diff $sixtrack_input/fort.3.mad.previous fc.3
    if test $? -ne 0
    then
      echo "${i}/${filejob} MADX has produced a new and different fc.3/fort.3.mad!" | tee -a $sixtrack_input/ERRORS
      exit 997
    fi
  fi
  cp -f fc.3 $sixtrack_input/fort.3.mad
  if test -s $sixtrack_input/fort.3.aux.previous
  then
    diff $sixtrack_input/fort.3.aux.previous fc.3.aux
    if test $? -ne 0
    then
      echo "${i}/${filejob} MADX has produced a new and different fc.3.aux/fort.3.aux!" | tee -a $sixtrack_input/ERRORS
      exit 996
    fi
  fi
  cp -f fc.3.aux $sixtrack_input/fort.3.aux
fi
if test ! -s fc.2
then
  echo "${i}/${filejob} MADX has produced an empty fc.2/fort.2!" | tee -a $sixtrack_input/ERRORS
  exit 4
fi
if test "$fort.34" != ""
then
  if test ! -s fc.34
  then
    echo "${i}/${filejob} MADX has produced an empty fc.34/fort.34!" | tee -a $sixtrack_input/ERRORS
    exit 5
  fi
  mv fc.34 fort.34
  if test -s $sixtrack_input/${i}/fort.34.previous.gz
  then
    gunzip -c $sixtrack_input/${i}/fort.34.previous.gz > fort.34.previous
    diff fort.34.previous fort.34 > diffs
    if test $? -ne 0
    then
      echo "${i}/${filejob} MADX has produced a different fc.34/fort.34!" | tee -a $sixtrack_input/WARNINGS
      cat diffs | tee -a $sixtrack_input/WARNINGS
    fi
  fi
  gzip fort.34
  cp fort.34.gz ${sixtrack_input}/${i}
fi
# and now do 2, 16, and 8 (zipped) and the MC errors (unzipped)
touch fc.16
touch fc.8
touch fc.34
mv fc.2 fort.2
mv fc.16 fort.16
mv fc.8 fort.8
for fil in fort.2 fort.8 fort.16
do
  if test -s ${sixtrack_input}/${i}/${fil}.previous.gz
  then
    gunzip -c ${sixtrack_input}/${i}/${fil}.previous.gz > ${fil}.previous
    diff ${fil}.previous $fil > diffs
    if test $? -ne 0
    then
      echo "${i}/${filejob} MADX has produced a different ${fil}!" | tee -a $sixtrack_input/WARNINGS
      cat diffs | tee -a $sixtrack_input/WARNINGS
    fi
  fi
  gzip $fil
  cp ${fil}.gz $sixtrack_input/${i}
done
if test "$CORR_TEST" -ne 0
then
  for fil in MCSSX_errors MCOSX_errors MCOX_errors MCSX_errors MCTX_errors
  do
    if test -s $sixtrack_input/${i}/${fil}.previous.gz
  then
    gunzip -c $sixtrack_input/${i}/${fil}.previous.gz > ${fil}.previous
    diff ${fil}.previous temp/${fil} > diffs
    if test $? -ne 0
    then
      echo "${i}/${filejob} MADX has produced a different ${fil}!" | tee -a $sixtrack_input/WARNINGS
      cat diffs | tee -a $sixtrack_input/WARNINGS
    fi
  fi
  gzip temp/${fil}
  cp temp/${fil} $sixtrack_input/${i}
  done
fi
if [ ${lFirst} -eq 0 ] ; then
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
        echo "${i}/${filejob} MADX first line of fc.3.aux does NOT contain SYNC!" | tee -a $sixtrack_input/ERRORS
        exit 996
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
