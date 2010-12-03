
module BuildBox.FileFormat.BuildResults
	( BuildResults(..)
	, mergeResults
	, acceptResult
	, advanceResults)
where
import BuildBox.Time
import BuildBox.Benchmark
import BuildBox.Command.Environment
import BuildBox.Pretty
import BuildBox.Aspect
import Data.List
import Data.Function


-- | A simple build results file format.
data BuildResults
	= BuildResults
	{ buildResultTime		:: UTCTime
	, buildResultEnvironment	:: Environment
	, buildResultBench		:: [BenchResult Single] }
	deriving (Show, Read)

instance Pretty BuildResults where
 ppr results
	= hang (ppr "BuildResults") 2 $ vcat
	[ ppr "time: " <> (ppr $ buildResultTime results)
	, ppr $ buildResultEnvironment results
	, ppr ""
	, vcat 	$ punctuate (ppr "\n") 
		$ map ppr 
		$ buildResultBench results ]


-- | Merge some BuildResults.
--   If we have data for a named benchmark in multiple `BuildResults`,
--   then we take the first one in the list.
--   The resultTime and environment is taken from the last `BuildResults`,
--   in the list.
mergeResults :: [BuildResults] -> BuildResults
mergeResults results
 = let	
	-- All the available benchResults from all files.
	benchResults	= concatMap buildResultBench results

	-- Get a the names of all the available benchmarks.
	benchNames 
		= sort $ nub
		$ map benchResultName
		$ concatMap buildResultBench results 

	-- Merge all the results
	Just newBenchResults
		= sequence 
		$ [ find (\br -> benchResultName br == name) benchResults	
				| name <- benchNames]
			
	-- Use the timestamp and environment from the last one.
	(lastResults : _) = reverse results
		
   in BuildResults
		{ buildResultTime	 = buildResultTime lastResults
		, buildResultEnvironment = buildResultEnvironment lastResults
		, buildResultBench	 = newBenchResults }


-- | Take test results from the first `BuildResults`, except for the named
--   one which we take from the second. If the named test is not in the second
--   then take it from the first. If it's not anywhere then Nothing.
acceptResult :: String -> BuildResults -> BuildResults -> Maybe BuildResults
acceptResult nameAccept baseline recent

 | Just resultAccept	
	<- find (\br -> benchResultName br == nameAccept)
	$  buildResultBench recent
	
 = let	resultsBaseline	
	  	= filter (\br -> benchResultName br /= nameAccept)
		$ buildResultBench baseline
		
	-- use the timestamp from the last one.	
   in	Just $ BuildResults
 	 { buildResultTime		= buildResultTime recent
	 , buildResultEnvironment	= buildResultEnvironment recent
	 , buildResultBench		= sortBy (compare `on` benchResultName) 
					$ resultAccept : resultsBaseline }
	
 | otherwise
 = Nothing
		

-- | Advance benchmark results as per `advanceBenchResults`.
--   The resultTime and environment is taken from the second `BuildResults`.
advanceResults :: Double -> BuildResults -> BuildResults -> BuildResults
advanceResults swing baseline recent
 = let	comparisons = compareManyBenchResults 
			(map statBenchResult $ buildResultBench baseline)
			(map statBenchResult $ buildResultBench recent)
			
	results	    = advanceBenchResults swing 
			comparisons 
			(buildResultBench baseline)
			(buildResultBench recent)
	
   in	BuildResults
		{ buildResultTime		= buildResultTime recent
		, buildResultEnvironment	= buildResultEnvironment recent
		, buildResultBench		= results }


