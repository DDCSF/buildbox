{-# LANGUAGE PatternGuards, StandaloneDeriving, FlexibleContexts, UndecidableInstances, RankNTypes #-}
module BuildBox.Benchmark.BenchResult
	( 
	-- * Benchmark results	
	  BenchResult (..)

	-- * Concatenation
	, concatBenchResult
	
	-- * Collation
	, collateBenchResult

	-- * Statistics
	, statCollatedBenchResult
	, statBenchResult

	-- * Comparison
	, compareBenchResults
	, compareBenchResultWith
	, compareManyBenchResults
	, predBenchResult
	, swungBenchResult
	
	-- * Benchmark run results
	, BenchRunResult (..)

	-- * Application functions
	, appBenchRunResult
	, appRunResultAspects


	-- * Lifting functions
	, liftBenchRunResult
	, liftBenchRunResult2
	, liftToAspectsOfBenchResult
	, liftToAspectsOfBenchResult2
	, liftRunResultAspects
	, liftRunResultAspects2)
where
import BuildBox.Aspect
import BuildBox.Pretty
import Data.List


-- BenchResult ------------------------------------------------------------------------------------
-- | We include the name of the original benchmark to it's easy to lookup the results.
--   If the `BenchResult` is carrying data derived directly by running a benchmark, 
--   there will be an element of the `benchResultRuns` for each iteration. On the other hand,
--   If the `BenchResult` is carrying statistics or comparison data there should
--   be a single element with an index of 0. This is suggested usage, and  adhered to by
--   the functions in this module, but not required.
data BenchResult c
	= BenchResult
	{ benchResultName	:: String
	, benchResultRuns	:: [BenchRunResult c] }

deriving instance 
	(  Show (c Seconds), Show (c Bytes)) 
	=> Show (BenchResult c)

deriving instance
	(  HasUnits (c Bytes) Bytes
	,  Read (c Bytes)
	,  HasUnits (c Seconds) Seconds
	,  Read (c Seconds))
	=> Read (BenchResult c)


instance  ( Pretty (c Seconds), Pretty (c Bytes))
	 => Pretty (BenchResult c) where
 ppr result
	= text (benchResultName result)
	$+$ nest 4 (vcat $ map ppr $ benchResultRuns result)


-- | Concatenate the results of all runs.
--   The the resulting `BenchResult` has a single `BenchRunResult` with an index of 0, containing all aspects.
concatBenchResult :: BenchResult c1 -> BenchResult c1
concatBenchResult 
	= liftBenchRunResult 
	$ \bsResults -> [BenchRunResult 0 (concatMap benchRunResultAspects bsResults)]


-- | Collate the aspects of each run. See `collateWithUnits` for an explanation and example.
collateBenchResult :: BenchResult Single -> BenchResult []
collateBenchResult
	= liftToAspectsOfBenchResult collateWithUnits


-- | Compute statistics from collated aspects of a run.
statCollatedBenchResult :: BenchResult [] -> BenchResult Stats
statCollatedBenchResult
	= liftToAspectsOfBenchResult (map (liftWithUnits makeAspectStats))


-- | Collate the aspects, then compute statistics of a run.
statBenchResult :: BenchResult Single -> BenchResult Stats
statBenchResult 
	= statCollatedBenchResult . collateBenchResult . concatBenchResult


-- | Compute comparisons of benchmark results.
--	Both results must have the same `benchResultName` else `error`.
compareBenchResults
	:: BenchResult Stats -> BenchResult Stats -> BenchResult StatsComparison

compareBenchResults 
	= liftBenchRunResult2 (zipWith (liftRunResultAspects2 (liftsWithUnits2 makeAspectComparisons)))


-- | Compute comparisons of benchmark result, looking up the baseline results from a given list.
--	If there are no matching baseline results then this creates a `ComparisonNew` in the output.
compareBenchResultWith 
	:: [BenchResult Stats] -> BenchResult Stats -> BenchResult StatsComparison

compareBenchResultWith base result
	| Just baseResult	<- find (\baseResult -> benchResultName baseResult == benchResultName result) base
	= compareBenchResults baseResult result
	
	| otherwise
	= liftToAspectsOfBenchResult (liftsWithUnits (map (liftAspect makeStatsComparisonNew))) result


-- | Compare some baseline results against new results.
--	If there are no matching baseline results then this creates a `ComparisonNew` in the output.
compareManyBenchResults 
	:: [BenchResult Stats] -> [BenchResult Stats] -> [BenchResult StatsComparison]
	
compareManyBenchResults base new
	= map (compareBenchResultWith base) new


-- | Return true if any of the aspect data in a result matches a given predicate.
predBenchResult
	:: (forall units. Real units => c units -> Bool)
	-> BenchResult c -> Bool

predBenchResult f
	= appBenchRunResult $ or . map (appRunResultAspects $ or . map (appAspectWithUnits f))


-- | Return true if any of the aspects have swung by more than a given fraction since last time.
--   For example, use @0.1@ for 10 percent.
swungBenchResult :: Double -> BenchResult StatsComparison -> Bool
swungBenchResult limit
	= predBenchResult (predSwingStatsComparison (\x -> abs x > limit)) 


-- Lifting ----------------------------------------------------------------------------------------
-- | Apply a function to the aspects of a `BenchRunResult`
appBenchRunResult :: ([BenchRunResult c1] -> b) -> BenchResult c1 -> b
appBenchRunResult f (BenchResult _ runs) = f runs


-- | Lift a function to the `BenchRunResult` in a `BenchResult`
liftBenchRunResult 
	:: ([BenchRunResult c1] -> [BenchRunResult  c2])
	-> (BenchResult     c1  -> BenchResult      c2)

liftBenchRunResult f (BenchResult name runs)	
	= BenchResult name (f runs)


-- | Lift a binary function to the `BenchResults` in a `BenchResult`
liftBenchRunResult2
	:: ([BenchRunResult c1] -> [BenchRunResult c2] -> [BenchRunResult c3])
	->  BenchResult c1      ->  BenchResult c2     ->  BenchResult c3

liftBenchRunResult2 f (BenchResult name1 runs1) (BenchResult name2 runs2)
	| name1 == name2	= BenchResult name1 (f runs1 runs2)
	| otherwise		= error "liftBenchRunResult2: names don't match"
	

-- | Lift a function to the aspects of each `BenchRunResult`.
liftToAspectsOfBenchResult 
	:: ([WithUnits (Aspect c1)] -> [WithUnits (Aspect c2)])
	-> BenchResult c1           -> BenchResult c2

liftToAspectsOfBenchResult 
	= liftBenchRunResult . map . liftRunResultAspects


-- | Lift a binary function to the aspects of each `BenchRunResult`.
liftToAspectsOfBenchResult2
	:: ([WithUnits (Aspect c1)] -> [WithUnits (Aspect c2)] -> [WithUnits (Aspect c3)])
	-> BenchResult c1           -> BenchResult c2          -> BenchResult c3

liftToAspectsOfBenchResult2
	= liftBenchRunResult2 . zipWith . liftRunResultAspects2



-- BenchRunResult ---------------------------------------------------------------------------------
-- | Holds the result of running a benchmark once.
data BenchRunResult c
	= BenchRunResult
	{ -- | What iteration this run was.
	  --   Use 1 for the first ''real'' iteration derived by running a program.
	  --   Use 0 for ''fake'' iterations computed by statistics or comparisons.
	  benchRunResultIndex	:: Integer

	  -- | Aspects of the benchmark run.
	, benchRunResultAspects	:: [WithUnits (Aspect c)] }


deriving instance 
	(  Show (c Seconds), Show (c Bytes)) 
	=> Show (BenchRunResult c)

deriving instance
	(  HasUnits (c Bytes) Bytes
	,  Read (c Bytes)
	,  HasUnits (c Seconds) Seconds
	,  Read (c Seconds))
	=> Read (BenchRunResult c)


instance  ( Pretty (c Seconds), Pretty (c Bytes)) 
	 => Pretty (BenchRunResult c) where
 ppr result
	| benchRunResultIndex result == 0
	=  (nest 2 $ vcat $ map ppr $ benchRunResultAspects result)

	| otherwise
	= ppr (benchRunResultIndex result) 
	$$ (nest 2 $ vcat $ map ppr $ benchRunResultAspects result)


-- Lifting ----------------------------------------------------------------------------------------
-- | Apply a function to the aspects of a `BenchRunResult`
appRunResultAspects :: ([WithUnits (Aspect c1)] -> b) -> BenchRunResult c1 -> b
appRunResultAspects f (BenchRunResult _ aspects) = f aspects


-- | Lift a function to the aspects of a `BenchRunResult`
liftRunResultAspects
	:: ([WithUnits (Aspect c1)] -> [WithUnits (Aspect c2)])
	-> BenchRunResult c1        -> BenchRunResult c2
	
liftRunResultAspects f (BenchRunResult ix as)
	= BenchRunResult ix (f as)


-- | Lift a binary function to the aspects of a `BenchRunResult`
liftRunResultAspects2
	:: ([WithUnits (Aspect c1)] -> [WithUnits (Aspect c2)] -> [WithUnits (Aspect c3)])
	-> BenchRunResult c1        -> BenchRunResult c2       -> BenchRunResult c3
	
liftRunResultAspects2 f (BenchRunResult ix1 as) (BenchRunResult ix2 bs)
	| ix1 == ix2		= BenchRunResult ix1 (f as bs)
	| otherwise		= error "liftRunResultAspects2: indices don't match"

