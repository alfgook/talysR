      subroutine readinput
c
c +---------------------------------------------------------------------
c | Author: Arjan Koning
c | Date  : February 25, 2012
c | Task  : Read input
c +---------------------------------------------------------------------
c
c +---------------------------------------------------------------------
c | Modified by: Alf Göök
c | Date       : January 10, 2023
c | Purpuse    : read from file 'input' instead of stdin in order to
c |              make it work with MPI       
c +---------------------------------------------------------------------
c
c ****************** Declarations and common blocks ********************
c
      include "talys.cmb"
      integer i
c
c ************************** User Input ********************************
c
c iso     : counter for isotope
c inline  : input line
c numlines: maximum number of input lines
c nlines  : number of input lines
c
c modification: instead of reading from stdin we read from a file in the 
c current directory called 'input'
      open(1, file = 'input', status = 'old')
c
c
c We read the complete input file first as a set of character strings.
c The actual keywords will be read from these later on. For natural
c elements, the input file only needs to be read once.
c
      if (iso.ne.1) return
      if (nlines.gt.0) return
      i=1
   10 read(1,'(a80)',end=100) inline(i)
      i=i+1
      if (i.gt.numlines) then
        write(*,'(" TALYS-error: Number of input lines exceeds ",i5)')
     +    numlines
        write(*,'(" numlines in talys.cmb should be increased")')
        stop
      endif
      goto 10
  100 nlines=i-1

      close(1)
c
c ************** Convert uppercase to lowercase characters *************
c
c For easy handling of all the input parameters, the whole input is
c converted to lowercase characters, with the exception of filenames or
c other character strings.
c
c convert: subroutine to convert input line from upper case to lowercase
c
      do 110 i=1,nlines
        call convert(i)
  110 continue
      nlines0=nlines
      return
      end
Copyright (C)  2013 A.J. Koning, S. Hilaire and S. Goriely
