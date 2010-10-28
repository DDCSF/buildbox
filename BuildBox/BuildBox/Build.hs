
-- | Defines the main `Build` monad and common utils.
module BuildBox.Build 
	( module BuildBox.Build.Testable
	, module BuildBox.Build.BuildError
	, module BuildBox.Build.BuildState
	, Build
	, runBuild
	, runBuildPrint
	, runBuildPrintWithState
	, throw
	, io
	, logSystem
	, out
	, outLn
	, outBlank
	, outLine
	, outLINE
	, whenM)
where
import BuildBox.Build.Base
import BuildBox.Build.Testable
import BuildBox.Build.BuildState
import BuildBox.Build.BuildError
import Control.Monad.State
import System.IO


-- | Log a system command to the handle in our `BuildConfig`, if any.
logSystem :: String -> Build ()
logSystem cmd
 = do	mHandle	<- gets buildStateLogSystem
	case mHandle of
	 Nothing	-> return ()
	 Just handle	
	  -> do	io $ hPutStr   handle "buildbox system: "
		io $ hPutStrLn handle cmd
		return ()

