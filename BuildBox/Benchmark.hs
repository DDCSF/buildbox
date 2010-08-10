{-# LANGUAGE PatternGuards #-}

-- | Defines benchmarks that we can run.
module BuildBox.Benchmark
	( module BuildBox.Benchmark.Base
	, module BuildBox.Benchmark.TimeAspect
	, module BuildBox.Benchmark.Pretty
	
	, runTimedCommand
	, outRunBenchmarkSingle
	, runBenchmarkSingle
	, outRunBenchmark
	, outRunBenchmarkAgainst)
where
import BuildBox.Build	
import BuildBox.Pretty
import BuildBox.Benchmark.Base
import BuildBox.Benchmark.TimeAspect
import BuildBox.Benchmark.Pretty
import Data.Time
import Data.List
import Control.Monad


-- Running Commands -------------------------------------------------------------------------------
runTimedCommand 
	:: Build a
	-> Build (NominalDiffTime, a) 
		
runTimedCommand cmd
 = do	start	<- io $ getCurrentTime
	result	<- cmd
	finish	<- io $ getCurrentTime
	return (diffUTCTime finish start, result)
	

-- | Run a benchmark a single time, printing results.
outRunBenchmarkSingle
	:: Benchmark
	-> Build BenchRunResult
	
outRunBenchmarkSingle bench
 = do	out $ "Running " ++ benchmarkName bench ++ "..."
	result	<- runBenchmarkSingle bench
	outLn "ok"
	outLn $ "    elapsed        = " ++ (pprFloatTime $ benchRunResultElapsed result)
		
	maybe (return ()) (\t -> outLn $ "    kernel elapsed = " ++ pprFloatTime t) 
		$ benchRunResultKernelElapsed result

	maybe (return ()) (\t -> outLn $ "    kernel cpu     = " ++ pprFloatTime t) 
		$ benchRunResultKernelCpuTime result

	maybe (return ()) (\t -> outLn $ "    kernel system  = " ++ pprFloatTime t)
		$ benchRunResultKernelSysTime result
	
	outBlank
	
	return result
	
	
-- | Run a benchmark a single time.
runBenchmarkSingle
	:: Benchmark 
	-> Build BenchRunResult
	
runBenchmarkSingle bench
 = do	-- Run the setup command
	_setupOk <- benchmarkSetup bench

	(diffTime, mKernelTimings)	
		<- runTimedCommand 
		$  benchmarkCommand bench
	
	case mKernelTimings of
	 Nothing 
	  -> return	
		$ BenchRunResult
		{ benchRunResultElapsed		= fromRational $ toRational diffTime
		, benchRunResultKernelElapsed	= Nothing
		, benchRunResultKernelCpuTime	= Nothing
		, benchRunResultKernelSysTime	= Nothing }

	 Just (mElapsed, mCpu, mSystem) 
	  -> return	
		$ BenchRunResult
		{ benchRunResultElapsed		= fromRational $ toRational diffTime
		, benchRunResultKernelElapsed	= mElapsed
		, benchRunResultKernelCpuTime	= mCpu
		, benchRunResultKernelSysTime	= mSystem }


-- | Run a benchmark several times, logging activity to the console.
outRunBenchmark
	:: Int			-- ^ Number of times to run each benchmark for to get averages.
	-> Maybe BenchResult	-- ^ Optional previous results for comparison.
	-> Benchmark		-- ^ Benchmark to run.
	-> Build BenchResult
	
outRunBenchmark iterations mPrior bench  
 = do	out $ "Running " ++ benchmarkName bench ++ " " ++ show iterations ++ " times..."
	runResults	<- replicateM iterations (runBenchmarkSingle bench) 
	outLn "ok"

	let result	= BenchResult
			{ benchResultName	= benchmarkName bench
			, benchResultRuns	= runResults }

	outLn pprBenchResultAspectHeader
	
	maybe (return ()) outLn	$ pprBenchResultAspect TimeAspectElapsed	mPrior result
	maybe (return ()) outLn	$ pprBenchResultAspect TimeAspectKernelElapsed	mPrior result
	maybe (return ()) outLn	$ pprBenchResultAspect TimeAspectKernelCpu	mPrior result
	maybe (return ()) outLn	$ pprBenchResultAspect TimeAspectKernelSys	mPrior result
		
	
	outBlank
	return	result


-- | Run a benchmark serveral times, logging activity to the console.
--   Optionally lookup data for comparison from this list of prior results.
outRunBenchmarkAgainst 
	:: Int			-- ^ Number of times to run each benchmark to get averages.
	-> Maybe [BenchResult]	-- ^ List of prior results.
	-> Benchmark		-- ^ The benchmark to run.
	-> Build BenchResult

outRunBenchmarkAgainst iterations mPrior bench
	| Just prior	<- mPrior
	, Just baseline	<- find (\b -> benchResultName b == benchmarkName bench) prior
	= outRunBenchmark iterations (Just baseline) bench
	
	| otherwise
	= outRunBenchmark iterations Nothing bench
	