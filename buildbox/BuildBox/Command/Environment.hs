
-- | Gathering information about the build environment.
module BuildBox.Command.Environment
        ( -- * Build Environment
          Environment(..)
        , getEnvironmentWith

          -- * Build platform
        , Platform(..)
        , getHostPlatform
        , getHostName
        , getHostArch
        , getHostProcessor
        , getHostOS
        , getHostRelease

          -- * Software versions
        , getVersionGHC
        , getVersionGCC)
where
import BuildBox.Build
import BuildBox.Command.System
import BuildBox.Command.File
import BuildBox.Pretty


-- Environment ------------------------------------------------------------------------------------
-- | The environment consists of the `Platform`, and some tool versions.
data Environment
        = Environment
        { environmentPlatform   :: Platform
        , environmentVersions   :: [(String, String)] }
        deriving (Show, Read)


instance Pretty Environment where
 ppr env
        = vcat
        [ ppr "Environment"
        , indents 2
                [ ppr   $ environmentPlatform env
                , indents 2
                        $ ppr "Versions"
                        : ( map (\(name, ver) -> ppr name %% ppr ver)
                          $ environmentVersions env)
                ]
        ]



-- | Get the current environment, including versions of these tools.
getEnvironmentWith
        :: [(String, Build String)]     -- ^ List of tool names and commands to get their versions.
        -> Build Environment

getEnvironmentWith nameGets
 = do   platform
         <- getHostPlatform

        versions
         <- mapM (\(name, get) -> do
                        ver     <- get
                        return  (name, ver))
         $  nameGets

        return  $ Environment
                { environmentPlatform   = platform
                , environmentVersions   = versions }



-- Platform ---------------------------------------------------------------------------------------
-- | Generic information about the platform we're running on.
data Platform
        = Platform
        { platformHostName      :: String
        , platformHostArch      :: String
        , platformHostProcessor :: String
        , platformHostOS        :: String
        , platformHostRelease   :: String }
        deriving (Show, Read)


instance Pretty Platform where
 ppr plat
  = vcat
        [ ppr "Platform"
        , indents 2
                [ ppr "host:      " %  (ppr $ platformHostName plat)
                , ppr "arch:      " %  (ppr $ platformHostArch plat)
                , ppr "processor: " %  (ppr $ platformHostProcessor plat)
                , ppr "system:    " %  (ppr $ platformHostOS plat)
                                    %% (ppr $ platformHostRelease plat) ]]


-- | Get information about the host platform.
getHostPlatform :: Build Platform
getHostPlatform
 = do   name            <- getHostName
        arch            <- getHostArch
        processor       <- getHostProcessor
        os              <- getHostOS
        release         <- getHostRelease

        return  $ Platform
                { platformHostName      = name
                , platformHostArch      = arch
                , platformHostProcessor = processor
                , platformHostOS        = os
                , platformHostRelease   = release }


-- Platform Tests ---------------------------------------------------------------------------------
-- | Get the name of this host, using @uname@.
getHostName :: Build String
getHostName
 = do   check $ HasExecutable "uname"
        name   <- sesystemq "uname -n"
        return  $ init name


-- | Get the host architecture, using @uname@.
getHostArch :: Build String
getHostArch
 = do   check $ HasExecutable "arch"
        name   <- sesystemq "arch"
        return  $ init name


-- | Get the host processor name, using @uname@.
getHostProcessor :: Build String
getHostProcessor
 = do   check $ HasExecutable "uname"
        name   <- sesystemq "uname -p"
        return  $ init name


-- | Get the host operating system, using @uname@.
getHostOS :: Build String
getHostOS
 = do   check $ HasExecutable "uname"
        name   <- sesystemq "uname -s"
        return  $ init name


-- | Get the host operating system release, using @uname@.
getHostRelease :: Build String
getHostRelease
 = do   check $ HasExecutable "uname"
        str    <- sesystemq "uname -r"
        return  $ init str


-- Software version tests -------------------------------------------------------------------------
-- | Get the version of this GHC, or throw an error if it can't be found.
getVersionGHC :: FilePath -> Build String
getVersionGHC path
 = do   check $ HasExecutable path
        str     <- sesystemq $ path ++ " --version"
        return  $ init str

-- | Get the version of this GCC, or throw an error if it can't be found.
getVersionGCC :: FilePath -> Build String
getVersionGCC path
 = do   check $ HasExecutable path
        str     <- sesystemq $ path ++ " --version"
        return  $ head $ lines str


