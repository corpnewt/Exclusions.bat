:::::::::::::::::::::::::::::::::::::::::
:: Automatically check & get admin rights
:::::::::::::::::::::::::::::::::::::::::
@echo off

:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
setlocal DisableDelayedExpansion
set "batchPath=%~0"
setlocal EnableDelayedExpansion
ECHO Set UAC = CreateObject^("Shell.Application"^) > "%temp%\OEgetPrivileges.vbs"
ECHO UAC.ShellExecute "!batchPath!", "%*", "", "runas", 1 >> "%temp%\OEgetPrivileges.vbs"
"%temp%\OEgetPrivileges.vbs"
exit /B

:gotPrivileges
:: set the current directory to the batch file location
cd /d %~dp0
::::::::::::::::::::::::::::
::START
::::::::::::::::::::::::::::

setlocal enabledelayedexpansion

REM This script will take a .conf file named the same as itself
REM that contains a newline delimited list of paths to add or
REM exclude.
REM
REM The formatting of that .conf file is like so:
REM
REM Lines starting with # are comments, and ignored
REM Lines starting with ADD: will add everything after as an exclusion
REM Lines starting with REM: will remove the following path from exclusions
REM
REM Standard windows path variables will expand correctly:
REM
REM %CD% - current directory
REM %USERPROFILE% - current user directory
REM %APPDATA% - the app data folder
REM %WINDIR% - the current system folder
REM
REM Examples:
REM
REM # This comment will be ignored
REM  ^ This line is ignored
REM ADD:C:\prog.exe
REM  ^ This will add an exclusion for prog.exe
REM REM:%CD%prog.exe
REM  ^ This will remove an exclusion for prog.exe in this script's path

REM Setup some default values
set /a add.Count=0
set /a rem.Count=0
set "thisdir=%~dp0"
set "filecheck=%~n0.conf"
set "manual=false"

:process
set /a added.Count=0
set /a removed.Count=0

call :header

echo Gathering target exclusions...
if /i "!manual!"=="false" (
    REM Gather our target exclusions
    if EXIST "!thisdir!!filecheck!" (
        echo   Found "!filecheck!" - parsing...
        REM Gather our lists
        call :getconf "ADD:" "add" "!filecheck!" "!thisdir!"
        call :getconf "REM:" "rem" "!filecheck!" "!thisdir!"
    ) else (
        echo   "!thisdir!!filecheck!" not found...
        echo     Enabling manual mode...
        set "manual=true"
        REM Uncomment the following line to display that manual
        REM mode is active when no .conf is found:
        REM timeout 3 > nul
        goto :mainmenu
    )
)

REM Make sure we have something to do
if "!add.Count!"=="0" (
    if "!rem.Count!"=="0" (
        echo   Found 0 exclusions to add or remove.  Nothing to do.
        echo.
        echo Press any key to exit...
        pause > nul
        exit /b
    )
)

REM Print out the exclusions we've found
if not "!rem.Count!"=="0" (
    if "!rem.Count!"=="1" (
        echo   Found 1 exclusion to remove.
    ) else (
        echo   Found !rem.Count! exclusions to remove.
    )
)
if not "!add.Count!"=="0" (
    if "!add.Count!"=="1" (
        echo   Found 1 exclusion to add.
    ) else (
        echo   Found !add.Count! exclusions to add.
    )
)

REM Let's check removals first
if not "!rem.Count!"=="0" (
    echo.
    echo Gathering existing exclusions...
    REM Build a list of our existing exclusions
    call :getexclusions "ex"
    if not "!ex.Count!"=="0" (
        if "!ex.Count!"=="1" (
            echo   Found 1 existing exclusion:
        ) else (
            echo   Found !ex.Count! existing exclusions:
        )
        call :printlist "ex" "    "
    ) else (
        echo   Found 0 existing exclusions.
    )
    echo.
    if "!rem.Count!"=="1" (
        echo Iterating 1 exclusion to remove...
    ) else (
        echo Iterating !rem.Count! exclusions to remove...
    )

    REM Now we iterate our current list of exclusions, and if found,
    REM we can remove it
    for /l %%a in (1, 1, !rem.Count!) do (
        set "found=false"
        for /l %%x in (1, 1, !ex.Count!) do (
            if /i "!rem[%%a]!"=="!ex[%%x]!" (
                REM Add the exclusion
                set "found=true"
                set /a removed.Count+=1
                echo   Found "!rem[%%a]!":
                echo     Removing exclusion...
                powershell -inputformat none -outputformat none -NonInteractive -Command "Remove-MpPreference -ExclusionPath '!rem[%%a]!'"
            )
        )
        if /i "!found!"=="false" (
            echo   "!rem[%%a]!" doesn't exist, skipping...
        )
    )

    echo.
    if "!removed.Count!"=="1" (
        echo Removed !removed.Count! of 1 exclusion.
    ) else (
        echo Removed !removed.Count! of !rem.Count! exclusions.
    )
)

REM Now we check additions
if not "!add.Count!"=="0" (
    echo.
    echo Gathering existing exclusions...
    REM Build a list of our existing exclusions
    call :getexclusions "ex"
    if not "!ex.Count!"=="0" (
        if "!ex.Count!"=="1" (
            echo   Found 1 existing exclusion:
        ) else (
            echo   Found !ex.Count! existing exclusions:
        )
        call :printlist "ex" "    "
    ) else (
        echo   Found 0 existing exclusions.
    )
    echo.
    if "!add.Count!"=="1" (
        echo Iterating 1 exclusion to add...
    ) else (
        echo Iterating !add.Count! exclusions to add...
    )

    REM Now we iterate our current list of exclusions, and if not found,
    REM we can add it
    for /l %%a in (1, 1, !add.Count!) do (
        set "found=false"
        for /l %%x in (1, 1, !ex.Count!) do (
            if /i "!add[%%a]!"=="!ex[%%x]!" (
                echo   "!add[%%a]!" already exists, skipping...
                set "found=true"
            )
        )
        if /i "!found!"=="false" (
            REM Didn't find it - add it
            set /a added.Count+=1
            echo   Didn't find "!add[%%a]!":
            echo     Adding exclusion...
            powershell -inputformat none -outputformat none -NonInteractive -Command "Add-MpPreference -ExclusionPath '!add[%%a]!'"
        )
    )

    echo.
    if "!added.Count!"=="1" (
        echo Added !added.Count! of 1 exclusion.
    ) else (
        echo Added !added.Count! of !add.Count! exclusions.
    )
)

echo.
if /i "!manual!"=="false" (
    echo Press any key to exit...
    pause > nul
    exit /b
) else (
    echo Press any key to return to the menu...
    pause > nul
    goto :mainmenu
)

REM Following this is a list of helper methods
REM They do everything from pre-fill lists to
REM gather string length and such.

:header
cls
echo   ####################################
echo  #        Defender Exclusions       #
echo ####################################
if "!manual!"=="true" (
    echo   By CorpNewt  -- MANUAL MODE --
) else (
    echo   By CorpNewt
)
echo.
goto :EOF

:mainmenu
REM This is the interactive mode in case we have no defaults
call :header
REM Get our current exclusions
call :getexclusions "ex"
echo Existing Exclusions:
echo.
if "!ex.Count!"=="0" (
    echo   None
) else (
    call :printlist "ex" "  "
)
echo.
echo 1. Add New Exclusion
echo 2. Remove Existing Exclusion
echo.
echo Q. Quit
echo.
set /p "menu=Please make a selection:  "
if "!menu!"=="" (
    goto :mainmenu
)
if /i "!menu!"=="q" (
    exit /b
)
if /i "!menu!"=="1" (
    goto :addexclusion
)
if /i "!menu!"=="2" (
    goto :remexclusion
)

:addexclusion
call :header
call :getexclusions "ex"
echo Existing Exclusions:
echo.
if "!ex.Count!"=="0" (
    echo   None
) else (
    call :printlist "ex" "  "
)
echo.
echo M. Main Menu
echo Q. Quit
echo.
set /p "menu=Please type the path to the new exclusion:  "
if "!menu!"=="" (
    goto :addexclusion
)
if /i "!menu!"=="m" (
    goto :mainmenu
)
if /i "!menu!"=="q" (
    exit /b
)
REM At this point, we should have a path
set /a rem.Count=0
set /a add.Count=1
set "add[1]=!menu!"
goto :process

:remexclusion
call :header
call :getexclusions "ex"
echo Existing Exclusions:
echo.
if "!ex.Count!"=="0" (
    echo   None
    echo.
) else (
    call :printlist "ex" "  " "numbers"
    echo.
    echo A. Remove All
)
echo M. Main Menu
echo Q. Quit
echo.
set /p "menu=Please select the exclusion to remove:  "
if "!menu!"=="" (
    goto :remexclusion
)
if /i "!menu!"=="m" (
    goto :mainmenu
)
if /i "!menu!"=="q" (
    exit /b
)
if /i "!menu!"=="a" (
    if /i not "!ex.Count!"=="0" (
        REM We have at least one, and we'll remove it
        call :copylist "ex" "rem"
        set /a add.Count=0
        goto :process
    )
)
if !menu! GTR 0 (
    if !menu! LEQ !ex.Count! (
        REM Found it!
        set /a rem.Count=1
        set /a add.Count=0
        set "rem[1]=!ex[%menu%]!"
        goto :process
    )
)
goto :remexclusion

:copylist <prefix_from> <prefix_to>
set /a %~2.Count=!%~1.Count!
for /l %%a in (1, 1, !%~1.Count!) do (
    set "%~2[%%a]=!%~1[%%a]!"
)
goto :EOF

:printlist <prefix> <pad>
for /l %%a in (1, 1, !%~1.Count!) do (
    if /i "%~3"=="numbers" (
        echo %~2%%a. !%~1[%%a]!
    ) else (
        echo %~2!%~1[%%a]!
    )
)
goto :EOF

:getconf <search> <var_prefix> <file_name> <file_path>
set "thisdir=%~dp0"
set "search=%~1"
set "prefix=%~2"
set "file_name=%~3"
set "file_path=%~4"
REM Get the search length
call :len "!search!" "len"
set /a !prefix!.Count=0
if not "!file_path!"=="" (
    REM We have a path to push
    pushd "!file_path!"
)
if not EXIST "!file_name!" (
    if not "!file_path!"=="" (
        popd
    )
    REM File doesn't exist - so bail
    goto :EOF
)
REM We have a file that exists
for /f "tokens=*" %%a in (!file_name!) do (
    set "temp=%%a"
    if /i "!temp:~0,%len%!"=="!search!" (
        REM Got an entry - let's normalize path vars
        REM then add it to our list
        set addtemp=!temp:~%len%!
        set /a !prefix!.Count+=1
        call :setvar "!prefix![!%prefix%.Count!]" "!addtemp!"
    )
)
if not "!file_path!"=="" (
    popd
)
goto :EOF

:getexclusions <var_prefix>
set "prefix=%~1"
set /a !prefix!.Count=0
for /f "tokens=*" %%i in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" 2^> nul') do (
    REM Verify that we have a REG_DWORD
    set "temp=%%i"
    if not "!temp:REG_DWORD=!"=="!temp!" (
        REM Contains REG_DWORD - let's strip out all "    REG_DWORD" and "    0x0" entries
        REM Then we'll get everything from the 5th char on (as it starts with 4 spaces)
        set "temp=!temp:    REG_DWORD=!"
        set "temp=!temp:    0x0=!"
        set /a !prefix!.Count+=1
        call :setvar "!prefix![!%prefix%.Count!]" "!temp!"
    )
)
goto :EOF

:setvar <var_name> <value>
set %~1=%~2
goto :EOF

REM Pulled from here: https://stackoverflow.com/a/22971891
:len <string> <length_variable> - note: string must be quoted because it may have spaces
setlocal enabledelayedexpansion&set l=0&set str=%~1
:len_loop
set x=!str:~%l%,1!&if not defined x (endlocal&set "%~2=%l%"&goto :eof)
set /a l=%l%+1&goto :len_loop
goto :EOF
