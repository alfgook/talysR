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

