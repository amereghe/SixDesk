      program checkf10
      implicit none
      double precision prob(60),prob1(60)
      integer line,word
      logical diff,diffs
! Now compare the closed orbit in 53-58 as well
! and NMAC in 59 (60 is used for CPU for Massimo) 
      line=0
      diff=.false.
    1 read (20,*,end=100,err=98) prob
      line=line+1
      read (21,*,end=99,err=97) prob1
      diffs=.false.
      do word=1,51
        if (prob(word).ne.prob1(word)) diffs=.true.
      enddo 
      do word=53,59
        if (prob(word).ne.prob1(word)) diffs=.true.
      enddo 
      if (diffs) then
        diff=.true.
        write (*,*)
        write (*,*) "DIFF fort.10, line",line
        do word=1,51
          if (prob(word).ne.prob1(word)) then
            write (*,*) "DIFF",word,prob(word),prob1(word)
          else
            write (*,*) "SAME",word,prob(word)
          endif
        enddo
        do word=53,59
          if (prob(word).ne.prob1(word)) then
            write (*,*) "DIFF",word,prob(word),prob1(word)
          else
            write (*,*) "SAME",word,prob(word)
          endif
        enddo
        write (*,*)
      else
        write (*,*) "SAME fort.10, line",line
      endif
      go to 1
 99   continue
      write (*,*) "Comparing VERSION ",prob(52)," to ",prob1(52)
      write (*,*) "DIFF I/O error, wrong no of lines!! line no ",line
      call exit(2)
      stop
 98   continue
      write (*,*) "Comparing VERSION ",prob(52)," to ",prob1(52)
      write (*,*) "DIFF I/O error!! fort.20 line no ",line
      call exit(3)
      stop
 97   continue
      write (*,*) "Comparing VERSION ",prob(52)," to ",prob1(52)
      write (*,*) "DIFF I/O error!! fort.21 line no ",line
      call exit(4)
      stop
 100  continue
      if (line.eq.0) go to 99
      write (*,*) "Comparing VERSION ",prob(52)," to ",prob1(52)
      if (diff) then
        write (*,*) "DIFF after comparing ",line ,"lines"
        call exit(1)
      else
        write (*,*) "SAME after comparing ",line ,"lines"
        call exit(0)
      endif
      end
