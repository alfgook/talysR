#' Setup Cluster for TALYS
#'
#' Setup a computing cluster for TALYS calculations
#'
#'
#' @return
#' list with functions to perform TALYS calculations
#' @export initTALYSmpi
#'
#' @import Rmpi
#' @import digest
#' @import TALYSeval
#' @import data.table
#' @useDynLib talysR

#library(Rmpi)
#dyn.load("talys-lib.so")

initTALYSmpi <- function(runOpts=NULL, maxNumCPU=0) {

	cat("nworkers = ",maxNumCPU,"\n")
	if(!maxNumCPU) maxNumCPU <- mpi.universe.size() - 1
	cat("nworkers = ",maxNumCPU,"\n")
	#mpi.spawn.Rslaves(nslaves=maxNumCPU) # This is to get log files for debugging
	mpi.spawn.Rslaves(nslaves=maxNumCPU,quiet=TRUE,needlog=FALSE)

	#mpi.bcast.cmd(dyn.load("talys-lib.so"))
	#mpi.bcast.cmd(library(digest))
	#mpi.bcast.cmd(library(TALYSeval))
	#mpi.bcast.cmd(library(data.table))

	defaults <- list(runOpts=runOpts)
	theResults <- NA

	close <- function(env) {
		#mpi.exit()
		mpi.close.Rslaves(dellog = FALSE)
		mpi.exit()
	}
	ee <- environment()
	reg.finalizer(ee, close, onexit = TRUE)

	runTALYS <- function(input_object) {

		# this function is used internally only
		# this will do the actual running of talys
		# one single job

		#library(digest)
	    #library(TALYSeval)
	    #library(data.table)

	    if (is.null(runOpts)) runOpts <- defaults$runOpts

	    talysMod <- createModelTALYS()
	    result <- list()
	    result$input <- input_object$input

	    # create the temporary directory
		globalTempdir <- runOpts$TMPDIR
		if (globalTempdir=="") globalTempdir <- Sys.getenv("TMPDIR")
		if (globalTempdir=="") globalTempdir <- getwd()
		dir.create(globalTempdir, showWarnings=FALSE)

		# create the temporary directory for the current calculation
		cnt <- 0
		succ <- FALSE
		while (!succ && (cnt<-cnt+1) < 100) {
			proposedDirname <- sprintf("tmpcalc_%s", paste0(sample(letters,10),collapse=""))
			proposedPathname <- file.path(globalTempdir, proposedDirname)
			#print(paste0("proposedPathname = ",proposedPathname,", cnt = ",cnt))
			succ <- dir.create(proposedPathname, showWarnings = FALSE)
		}
		if (!succ) stop(paste0("unable to create temporary directory ",proposedPathname," in ", globalTempdir))
		basedir <- proposedPathname

		talysMod$prepare(basedir,input_object$input)

		.C("talys",directory=basedir)

		# save talys output summary: will skip this, just takes time
        # numLines <- as.integer(system(paste0("wc -l ",basedir,"/output | awk '{print $1}'"), intern=TRUE))
        # if (numLines <= 60)
        #   outputSummary <- system(paste0("cat ",basedir,"/output"), intern=TRUE)
        # else
        # {
        #   cmdstr <- paste0("head -n 15 ",basedir,"/output; echo --- LINES SKIPPED ---; tail -n 15 ",basedir,"/output")
        #   outputSummary <- system(cmdstr, intern=TRUE)
        # }
        # result$output <- outputSummary

		result$result <- talysMod$read(basedir, copy(input_object$outspec), packed=FALSE)

		unlink(list.files(basedir))
		unlink(basedir, recursive=TRUE)

		return(result)
	}
	mpi.bcast.Robj2slave(obj = runTALYS)

	runTALYSparallel <- function(inpSpecList, outSpec, runOpts=NULL, saveDir=NULL, calcsPerJob) {
		# the argument calcsPerJob is deprecated

		# this function is called by the client, given a list of inputs and output needs
		# it will exexcute talys for each input and return a list of results

		if (!is.list(inpSpecList) || !all(sapply(inpSpecList, is.list)))
		stop("inpSpecList must be a list of TALYS inputs")
		if (!is.data.table(outSpec) && !(is.list(outSpec) &&
		                            all(sapply(outSpec, is.data.table)) &&
		                            length(inpSpecList) == length(outSpec)))
		stop(paste0("outSpec must be either a datatable or ",
		          "a list of datatables of the same length as inpSpecList"))

		if (is.null(runOpts)) runOpts <- defaults$runOpts

		if (is.data.table(outSpec)) {
			# all calculations have the same output specification (outSpec)
			
			# create a list with input and uotput specification for each job
			input <- lapply(seq_along(inpSpecList),function(i)
				list(input=inpSpecList[[i]], outspec=outSpec,saveDir=saveDir, calcIdx=i, calcDir="")
				)

			resultList <- mpi.parLapply(input,runTALYS,job.num=length(input))
			theResults <<- resultList
			
		} else if (is.list(outSpec)) {
			# each calculation have a unique output specification (outSpec)
			stopifnot(length(inpSpecList)==length(outSpec))
			input <- mapply(function(i, x, y) {
				list(input=x, outspec=y, saveDir = saveDir, calcIdx=i, calcDir="")
			}, i=seq_along(inpSpecList), x=inpSpecList, y=outSpec, SIMPLIFY = FALSE)

			resultList <- mpi.parLapply(input,runTALYS,job.num=length(input))
			theResults <<- resultList
		} else {
			stop("outSpec is neither a data.table nor a list of data.tables.")
		}
	
		#return(unlist(resultList,recursive=FALSE))
		return(resultList)
	}

	getResults <- function(jobList, selection=TRUE) {
		stopifnot(isTRUE(selection == TRUE) || is.numeric(selection))

	    if(isTRUE(selection)) {
	    	return(theResults)
	    } else {
	    	return(theResults[[selection]])
	    }
	}

	isRunningTALYS <- function() {
		FALSE
	}

	list(run=runTALYSparallel,result=getResults,isRunning=isRunningTALYS)
}