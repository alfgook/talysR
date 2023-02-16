# talysR
An interface to run parallel talys model calculations via an R interface

This packages allows you to run the nuclear reaction model talys inside R. Furthermore, using Rmpi and depending on the package TALYSeval (by G. Schnabel) talysR provides an interface to run talys in parallel via MPI, parse the output and return it to the calling process in data.table format.

## Installation

talysR depends on the TALYSeval (by G. Schnabel) package, which is available at https://github.com/gschnabel/TALYSeval. It can be installed by running the following commands in a terminal

```
git clone https://github.com/gschnabel/TALYSeval.git
R CMD INSTALL TALYSeval
```
Once TALYSeval is installed you can install talysR by running the following commands in a terminal:
```
git clone https://github.com/alfgook/talysR.git
cd ..
R CMD build talysR
R CMD INSTALL talysR_0.0.0.9000.tar.gz
```
you may need to replace 0.0.0.9000 with the current version of the built package.

In order for the package to work you also need the talys structure data. This is a relatively large data set and not distributed
with this package. It can be obtained by downloading talys1.95 from https://tendl.web.psi.ch/tendl_2021/talys.html

for e.g.

```
cd /home/user
wget https://tendl.web.psi.ch/tendl_2019/talys/talys1.95.tar
tar -xzf talys1.95.tar
rm talys1.95.tar
```
replace /home/user with a suitable place for the talys data. Now we need to set the environment variable TALYSHOME for talysR to find the data at runtime, according to our example above

```
export TALYSHOME=/home/user/talys
```
you may want to place the above line in your logon script, ~/.bashrc.

## Basic usage

## Information about talys

the source code in src/ is that of talys1.96

with a few minor modifications:

1) the main file talys.f is removed and replaced by a C-wrapper talys-c.c the wrapper runs talys in the exact same way that the normal talys.f does, but redirects the stdout to a file named output created in the working directory. This is necessary for running talys as a 'subroutine' (or function) from R. It also facilitates the parallelization of talys runs via mpi.

2) the file readinput.f has been modified so that the input is read from a file 'input' in the current working directory, instead of stdin. This modification is necessary for running talys as a 'subroutine' (or function) from R. It also facilitates the parallelization of talys runs.

3) the file machine.f is modified so that the input structure data path is not hardcoded, and must be set at compile time. Instead the talys home path is set by the environment variable TALYSHOME. The user must set this environment variable, for example

	export TALYSHOME=/home/user/talys

the code will look for structure data in $TALYSHOME/structure/

the structure data base should be that of talys version 1.96 the code will some checks, that the data is not from an older version of talys. If it cannot find $TALYSHOME/abundance/H.abun it will write an error message in the output file and stop