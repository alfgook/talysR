# talysR
An interface to run parallel talys model calculations via an R interface

This packages allows you to run the nuclear reaction model talys inside R. Furthermore, using Rmpi and depending on the package TALYSeval (by G. Schnabel) talysR provides an interface to run talys in parallel via MPI, parse the output and return it to the calling process in data.table format.
