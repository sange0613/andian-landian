$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
node native-win/make-small-icon.cjs
if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed' }

& cl /nologo /std:c++17 /utf-8 /W4 /WX /Os /MT native-win/tests/logic_test.cpp /Fo:dist/native-win/logic.obj /Fe:dist/native-win/logic-test.exe
if ($LASTEXITCODE -ne 0) { throw 'Logic test compilation failed' }
& ./dist/native-win/logic-test.exe
if ($LASTEXITCODE -ne 0) { throw 'Logic tests failed' }

& rc /nologo /c65001 /fo dist/native-win/resources.res native-win/DianDian.rc
if ($LASTEXITCODE -ne 0) { throw 'Resource compilation failed' }
& cl /nologo /std:c++17 /utf-8 /W4 /WX /Os /MT /GR- /EHsc /D_WIN32_WINNT=0x0A00 native-win/DianDian.cpp dist/native-win/resources.res /Fo:dist/native-win/main.obj /Fe:dist/native-win/DimBlueDot.exe /link /SUBSYSTEM:WINDOWS /MANIFEST:NO /OPT:REF /OPT:ICF user32.lib gdi32.lib shell32.lib gdiplus.lib advapi32.lib
if ($LASTEXITCODE -ne 0) { throw 'Application compilation failed' }
Get-Item ./dist/native-win/DimBlueDot.exe | Select-Object FullName, Length
& cl /nologo /std:c++17 /utf-8 /W4 /WX /Os /MT /GR- /EHsc /D_WIN32_WINNT=0x0A00 native-win/tests/window_test.cpp dist/native-win/resources.res /Fo:dist/native-win/window-test.obj /Fe:dist/native-win/window-test.exe /link /SUBSYSTEM:CONSOLE /MANIFEST:NO user32.lib gdi32.lib shell32.lib gdiplus.lib advapi32.lib
if ($LASTEXITCODE -ne 0) { throw 'Window test compilation failed' }
& ./dist/native-win/window-test.exe
if ($LASTEXITCODE -ne 0) { throw 'Window tests failed' }

$nsisCommand = Get-Command makensis -ErrorAction SilentlyContinue
$nsis = if ($nsisCommand) { $nsisCommand.Source } else { Join-Path ${env:ProgramFiles(x86)} 'NSIS/makensis.exe' }
& $nsis /INPUTCHARSET UTF8 /V3 native-win/installer.nsi
if ($LASTEXITCODE -ne 0) { throw 'Installer build failed' }
node native-win/check-package.cjs
if ($LASTEXITCODE -ne 0) { throw 'Package verification failed' }
