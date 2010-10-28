{-# LANGUAGE ScopedTypeVariables, PatternGuards #-}

import Args
import BuildBox
import BuildBox.FileFormat.BuildResults
import System.Console.ParseArgs	hiding (args)
import Data.List

main :: IO ()
main 
 = do	args	<- parseArgsIO ArgsTrailing resultsArgs
	mainWithArgs args

mainWithArgs :: Args ResultsArg -> IO ()
mainWithArgs args

	-- Print usage help
	| gotArg args ArgHelp
	= usageError args ""

	-- Dump a results file.
	| Just fileName	<- getArg args ArgDump
	, []		<- argsRest args
	= do	contents	<- readFile fileName
		let results	=  (read contents) :: BuildResults
		putStrLn $ render $ ppr results

	-- Compare two results files.
	| gotArg args ArgCompare
	= do	let fileNames	= argsRest args
		contentss	<- mapM readFile fileNames

		let (results :: [BuildResults])
			= map read contentss
		
		let [baseline, current] 
			= map buildResultBench results

		putStrLn $ render $ pprComparisons baseline current

	-- Merge two results files, prefering benchmark results on the left.
	-- The time and environment fields are taken from the file on the right.
	| gotArg args ArgMerge
	= do	
		-- Read all the files.
		let fileNames	= argsRest args
		contentss <- mapM readFile fileNames
		let (results :: [BuildResults])
			  = map read contentss
			
		print $ mergeResults results

	| otherwise
	= usageError args "Nothing to do...\n"
