#' Setup Cluster for TALYS
#'
#' Setup a computing cluster for TALYS calculations.
#' @param runOpts list of run options
#' @param maxNumCPU (optional) the maximum number of CPUs to use
#' @param needlog (optional) passed on to Rmpi::mpi.spawn.Rslaves. If TRUE, R BATCH outputs will be saved in log files.  If FALSE, the outputs will send to /dev/null.If TRUE, do not print anything unless an error occurs
#' @param quiet (optional) passed on to Rmpi::mpi.spawn.Rslaves. If TRUE, do not print anything unless an error occurs
#' @export
#'
#' @import data.table
#' @import Rmpi
#' @import doMPI
#' @import digest
#' @import TALYSeval
#' @useDynLib talysR

initTALYSmpi <- function(runOpts=NULL, maxNumCPU=0, needlog=FALSE, quiet=TRUE) {

	talys_home_path <- Sys.getenv("TALYSHOME")
	if(nchar(talys_home_path) == 0) {
		print("environment variable TALYSHOME not set")
		return(list(error="environment variable TALYSHOME not set"))
	}

	if(!("structure" %in% list.files(talys_home_path))) {
		err <- paste0("structure files not found in: ",talys_home_path)
		print(err)
		return(list(error=err))
	}

	#if(!maxNumCPU) maxNumCPU <- mpi.universe.size() - 1
	#mpi.spawn.Rslaves(nslaves=maxNumCPU) # This is to get log files for debugging
	#mpi.spawn.Rslaves(nslaves=maxNumCPU,quiet=quiet,needlog=needlog)

	cluster <- startMPIcluster()
	registerDoMPI(cluster)

	defaults <- list(runOpts=runOpts)
	theResults <- NA

	close <- function(env) {
		closeCluster(cluster)
		#mpi.close.Rslaves(dellog = FALSE)
		mpi.finalize()
	}
	ee <- environment()
	reg.finalizer(ee, close, onexit = TRUE)

	runTALYS <- function(input_object) {

		# this function is used internally only
		# this will do the actual running of talys
		# one single job

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
			proposedDirname <- sprintf("tmpcalc_%s_%d", paste0(sample(letters,10),collapse=""), input_object$calcIdx)
			proposedPathname <- file.path(globalTempdir, proposedDirname)
			#print(paste0("proposedPathname = ",proposedPathname,", cnt = ",cnt))
			succ <- dir.create(proposedPathname, showWarnings = FALSE)
		}
		if (!succ) stop(paste0("unable to create temporary directory ",proposedPathname," in ", globalTempdir))
		basedir <- proposedPathname

		talysMod$prepare(basedir,input_object$input)

		.C("talys",directory=basedir)

		result$result <- talysMod$read(basedir, copy(input_object$outspec), packed=FALSE)

		# clean up the calculation
		if (!is.null(input_object$saveDir)) {
			tarfile <- sprintf("calc.%04d.tar", input_object$calcIdx)
			saveFilePath <- file.path(input_object$saveDir,tarfile)
			tarcmd <- paste0('tar -czf ', tarfile,' *')
			movecmd <- paste0('mv ', tarfile, ' ', saveFilePath)

			err_str <- ""
			curdir <- getwd()
			setwd(basedir)
			if (system(tarcmd, intern=FALSE) != 0)
				err_str <- paste0(err_str," | Problem with: ", tarcmd)
			if (system(movecmd, intern=FALSE) != 0)
				err_str <- paste0(err_str," | Problem with: ", movecmd)

			if(nchar(err_str))
				result$error <- err_str
			setwd(curdir)
		}
		
		unlink(list.files(basedir))
		unlink(basedir, recursive=TRUE)

		return(result)
	}
	#mpi.bcast.Robj2slave(obj = runTALYS)
	exportDoMPI(cluster,'runTALYS',envir=environment())

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
			
			# create a list with input and output specification for each job
			input <- lapply(seq_along(inpSpecList),function(i)
				list(input=inpSpecList[[i]], outspec=outSpec,saveDir=saveDir, calcIdx=i, calcDir="")
				)

			cat("talysR: number of jobs to do: ", length(input), "\n")
			#cat("talysR: number of workers: ", maxNumCPU, "\n")

			#resultList <- mpi.applyLB(input,runTALYS)
			resultList <- foreach(inp=input) %dopar% {
				runTALYS(inp)
			}
			
			theResults <<- resultList
			
		} else if (is.list(outSpec)) {
			# each calculation have a unique output specification (outSpec)
			stopifnot(length(inpSpecList)==length(outSpec))
			input <- mapply(function(i, x, y) {
				list(input=x, outspec=y, saveDir = saveDir, calcIdx=i, calcDir="")
			}, i=seq_along(inpSpecList), x=inpSpecList, y=outSpec, SIMPLIFY = FALSE)

			cat("talysR: number of jobs to do: ", length(input), "\n")
			#cat("talysR: number of workers: ", maxNumCPU, "\n")
			#resultList <- mpi.applyLB(input,runTALYS)
			resultList <- foreach(inp=input) %dopar% {
				runTALYS(inp)
			}


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

	isRunningTALYS <- function(jobList, combine=TRUE) {
		# dummy function to be compatible with georgs clusterTALYS, will always return FALSE
		if (isTRUE(combine))
			return(FALSE)
		else
			return(rep(FALSE,length(jobList)))
	}

	list(run=runTALYSparallel,result=getResults,isRunning=isRunningTALYS)
}