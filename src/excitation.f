      subroutine excitation
c
c +---------------------------------------------------------------------
c | Author: Arjan Koning and Stephane Hilaire
c | Date  : October 15, 2015
c | Task  : Excitation energy population
c +---------------------------------------------------------------------
c
c ****************** Declarations and common blocks ********************
c
      include "talys.cmb"
      integer Zcomp,Ncomp,A,odd,NL,nex0,nex,nen,parity,J
      real    Eex,dEx,Exlow,Exup,Pex(0:numex),Edlow,Edup,dElow,dEup,
     +        PexJP(0:numex,0:numJ,-1:1),dE,Eexmin,frac,ald,ignatyuk,
     +        Ea,Eb,Pa,Pb,Rspin,Probex,Prob,spindis,xsinputpop,
     +        Edistlow(0:numpop),Eexlow(0:numex)
c
c ******************** Fill energy bins with population ****************
c
c flagpopMeV: flag to use initial population per MeV instead of
c             histograms
c xsinputpop: total population given in input
c npopE    : number of energies for population distribution
c PdistE   : population distribution, spin-independent
c EdistE   : excitation energy of population distribution
c npopJ    : number of spins for population distribution
c PdistJP  : population distribution per spin and parity
c Edistlow : lower bound of energy bin of population distribution
c Zcomp    : charge number index for compound nucleus
c Ncomp    : neutron number index for compound nucleus
c Ex,Eex   : excitation energy
c maxex    : maximum excitation energy bin for compound nucleus
c AA,A     : mass number of residual nucleus
c odd      : odd (1) or even (0) nucleus
c Nlast,NL : last discrete level
c dEx      : excitation energy bin
c edis     : energy of level
c deltaEx  : excitation energy bin for population arrays
c locate   : subroutine to find value in ordered table
c Ea,Eb,.. : help variables
c ignatyuk : function for energy dependent level density parameter a
c jdis     : spin of level
c maxJ     : maximal J-value
c parlev   : parity of level
c xspop    : population cross section
c spindis  : spin distribution
c pardis   : parity distribution
c xspopex  : population cross section summed over spin and parity
c xspopnuc : population cross section per nucleus
c feedexcl : feeding terms from compound excitation energy bin to
c            residual excitation energy bin
c xsinitpop: initial population cross section
c popexcl  : population cross section of bin just before decay
c
c Write initial population by summing the bins of the input energy
c grid.
c
      if (.not.flagpopMeV) then
        xsinputpop=0.
        if (npopJ.gt.0) then
          do 5 parity=-1,1,2
            do 6 J=0,npopJ-1
              do 7 nen=1,npopE
                xsinputpop=xsinputpop+PdistJP(nen,J,parity)
    7         continue
    6       continue
    5     continue
        else
          do nen=1,npopE
            xsinputpop=xsinputpop+PdistE(nen)
          enddo
        endif
        write(*,'(/" Total population of input excitation energy grid:",
     +    es12.5/)') xsinputpop
      endif
c
c Set population bins on basis of input
c
      if (EdistE(1).eq.0.) then
        do 10 nen=1,npopE
          EdistE(nen-1)=EdistE(nen)
          PdistE(nen-1)=PdistE(nen)
          do 20 parity=-1,1,2
            do 30 J=0,npopJ-1
              PdistJP(nen-1,J,parity)=PdistJP(nen,J,parity)
   30       continue
   20     continue
   10   continue
        npopE=npopE-1
      endif
      if (npopJ.gt.0) then
        do 40 nen=1,npopE
          PdistE(nen)=0.
          do 50 parity=-1,1,2
            do 60 J=0,npopJ-1
              PdistE(nen)=PdistE(nen)+PdistJP(nen,J,parity)
   60       continue
   50     continue
   40   continue
      endif
      do 70 nen=0,npopE
        Edistlow(nen)=0.5*(EdistE(nen)+EdistE(max(nen-1,0)))
   70 continue
      Zcomp=0
      Ncomp=0
c
c Set boundaries of excitation energy bins
c
c dElow: energy increment at lower bound
c dEup : energy increment at upper bound
c Eexmin: minimal excitation energy
c Exlow: lower bound excitation energy
c Eexlow: lower bound excitation energy
c Exup : upper bound excitation energy
c
      do 80 nex=0,maxex(Zcomp,Ncomp)
        Eex=Ex(Zcomp,Ncomp,nex)
        Eexmin=Ex(Zcomp,Ncomp,max(nex-1,0))
        Eexlow(nex)=0.5*(Eex+Eexmin)
   80 continue
c
c Redistribute bins
c
c Pa: probability distribution value
c Pb: probability distribution value
c Edlow: help variable
c Edup: help variable
c Pex: probability at excitation energy
c PexJP: probability at excitation energy, J and P
c Prob : probability
c Probex : probability
c
      A=AA(Zcomp,Ncomp,0)
      odd=mod(A,2)
      NL=Nlast(Zcomp,Ncomp,0)
      nex0=maxex(Zcomp,Ncomp)+1
      do 110 nex=0,maxex(Zcomp,Ncomp)
        Eex=Ex(Zcomp,Ncomp,nex)
        dEx=deltaEx(Zcomp,Ncomp,nex)
        if (.not.flagpopMeV) then
          Pex(nex)=0.
          do 120 parity=-1,1,2
            do 130 J=0,maxJ(Zcomp,Ncomp,nex)
              PexJP(nex,J,parity)=0.
  130       continue
  120     continue
          Exlow=Eexlow(nex)
          Exup=Eexlow(min(nex+1,maxex(Zcomp,Ncomp)))
          do 140 nen=0,npopE-1
            Edlow=Edistlow(nen)
            Edup=Edistlow(nen+1)
            if (Edlow.ge.Exup) goto 140
            if (Edup.le.Exlow) goto 140
            dE=Edup-Edlow
            dElow=max(Exlow-Edlow,0.)
            dEup=max(Edup-Exup,0.)
            frac=(dE-dElow-dEup)/dE
            Pex(nex)=Pex(nex)+frac*PdistE(nen)
            if (npopJ.gt.0.and.nex.gt.NL) then
              do 190 parity=-1,1,2
                do 200 J=0,maxJ(Zcomp,Ncomp,nex)
                  PexJP(nex,J,parity)=PexJP(nex,J,parity)+
     +              frac*PdistJP(nen,J,parity)
  200           continue
  190         continue
           endif
  140     continue
          if (nex.le.NL) then
            J=int(jdis(Zcomp,Ncomp,nex))
            parity=parlev(Zcomp,Ncomp,nex)
            PexJP(nex,J,parity)=Pex(nex)
          else
            if (npopJ.eq.0) then
              ald=ignatyuk(Zcomp,Ncomp,Eex,0)
              do 210 parity=-1,1,2
                do 220 J=0,maxJ(Zcomp,Ncomp,nex)
                  Rspin=real(J)+0.5*odd
                  PexJP(nex,J,parity)=Pex(nex)*
     +              spindis(Zcomp,Ncomp,Eex,ald,Rspin,0)*pardis
  220           continue
  210         continue
            endif
          endif
          do 230 parity=-1,1,2
            do 240 J=0,maxJ(Zcomp,Ncomp,nex)
              xspop(Zcomp,Ncomp,nex,J,parity)=PexJP(nex,J,parity)
              xspopex(Zcomp,Ncomp,nex)=xspopex(Zcomp,Ncomp,nex)+
     +          PexJP(nex,J,parity)
  240       continue
  230     continue
        else
          call locate(EdistE,0,npopE,Eex,nen)
          nen=max(0,nen)
          Ea=EdistE(nen)
          Eb=EdistE(nen+1)
          if (npopJ.eq.0) then
            Pa=PdistE(nen)
            Pb=PdistE(nen+1)
            call pol1(Ea,Eb,Pa,Pb,Eex,Probex)
            ald=ignatyuk(Zcomp,Ncomp,Eex,0)
          endif
          do 310 parity=-1,1,2
            do 320 J=0,maxJ(Zcomp,Ncomp,nex)
              Rspin=real(J)+0.5*odd
              if (nex.le.NL.and.(jdis(Zcomp,Ncomp,nex).ne.J.or.
     +          parlev(Zcomp,Ncomp,nex).ne.parity)) goto 320
              if (npopJ.eq.0) then
                Prob=Probex*spindis(Zcomp,Ncomp,Eex,ald,Rspin,0)*
     +            pardis
              else
                Pa=PdistJP(nen,J,parity)
                Pb=PdistJP(nen+1,J,parity)
                call pol1(Ea,Eb,Pa,Pb,Eex,Prob)
              endif
              xspop(Zcomp,Ncomp,nex,J,parity)=Prob*dEx
              xspopex(Zcomp,Ncomp,nex)=xspopex(Zcomp,Ncomp,nex)+
     +          xspop(Zcomp,Ncomp,nex,J,parity)
  320       continue
  310     continue
        endif
        xspopnuc(Zcomp,Ncomp)=xspopnuc(Zcomp,Ncomp)+
     +    xspopex(Zcomp,Ncomp,nex)
        feedexcl(Zcomp,Ncomp,0,nex0,nex)=xspopex(Zcomp,Ncomp,nex)
  110 continue
      xsinitpop=xspopnuc(Zcomp,Ncomp)
      popexcl(Zcomp,Ncomp,nex0)=xsinitpop
      return
      end
