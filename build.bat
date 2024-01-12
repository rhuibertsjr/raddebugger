@echo off
setlocal
cd /D "%~dp0"

:: --- Usage Notes (2024/1/10) ------------------------------------------------
::
:: This is a central build script for the RAD Debugger project. It takes a list
:: of simple alphanumeric-only arguments which control (a) what is built, (b)
:: which compiler & linker are used, and (c) extra high-level build options. By
:: default, if no options are passed, then the main "raddbg" graphical debugger
:: is built.
::
:: Below is a non-exhaustive list of possible ways to use the script:
:: `build raddbg`
:: `build raddbg clang`
:: `build raddbg release`
:: `build raddbg asan telemetry`
:: `build raddbg_from_pdb`
::
:: For a full list of possible build targets and their build command lines,
:: search for @build_targets in this file.
::
:: Below is a list of all possible non-target command line options:
::
:: - `asan`: enable address sanitizer
:: - `telemetry`: enable RAD telemetry profiling support

:: --- Unpack Arguments -------------------------------------------------------
for %%a in (%*) do set "%%a=1"
if not "%msvc%"=="1" if not "%clang%"=="1" set msvc=1
if not "%release%"=="1" set debug=1
if "%debug%"=="1"   set release=0 && echo [debug mode]
if "%release%"=="1" set debug=0 && echo [release mode]
if "%msvc%"=="1"    set clang=0 && echo [msvc compile]
if "%clang%"=="1"   set msvc=0 && echo [clang compile]
if "%~1"==""        echo [default mode, assuming `raddbg` build] && set raddbg=1

:: --- Unpack Command Line Build Arguments ------------------------------------
set auto_compile_flags=
if "%telemetry%"=="1" set auto_compile_flags=%auto_compile_flags% -DPROFILE_TELEMETRY=1 && echo [telemetry profiling enabled]
if "%asan%"=="1"      set auto_compile_flags=%auto_compile_flags% -fsanitize=address && echo [asan enabled]

:: --- Compile/Link Line Definitions ------------------------------------------
set cl_common=     /I..\src\ /I..\local\ /nologo /FC /Z7 /MP
set clang_common=  -I..\src\ -I..\local\ -maes -mssse3 -msse4 -gcodeview -fdiagnostics-absolute-paths -Wall -Wno-missing-braces -Wno-unused-function -Wno-writable-strings -Wno-unused-value -Wno-unused-variable -Wno-unused-local-typedef -Wno-deprecated-register -Wno-deprecated-declarations -Wno-unused-but-set-variable -Wno-single-bit-bitfield-constant-conversion -Xclang -flto-visibility-public-std -D_USE_MATH_DEFINES -Dstrdup=_strdup -Dgnu_printf=printf
set cl_debug=      call cl /Od /D_DEBUG %cl_common%
set cl_release=    call cl /O2 /DNDEBUG %cl_common%
set clang_debug=   call clang -g -O0 -D_DEBUG %clang_common%
set clang_release= call clang -g -O3 -DNDEBUG %clang_common% 
set cl_link=       /link /natvis:"%~dp0\src\natvis\base.natvis"
set clang_link=    -Xlinker /natvis:"%~dp0\src\natvis\base.natvis"
set cl_out=        /out:
set clang_out=     -o

:: --- Per-Build Settings -----------------------------------------------------
set gfx=-DOS_FEATURE_GRAPHICAL=1
set net=-DOS_FEATURE_SOCKET=1
set link_dll=-DLL

:: --- Choose Compile/Link Lines ----------------------------------------------
if "%msvc%"=="1"      set compile_debug=%cl_debug%
if "%msvc%"=="1"      set compile_release=%cl_release%
if "%msvc%"=="1"      set compile_link=%cl_link%
if "%msvc%"=="1"      set out=%cl_out%
if "%clang%"=="1"     set compile_debug=%clang_debug%
if "%clang%"=="1"     set compile_release=%clang_release%
if "%clang%"=="1"     set compile_link=%clang_link%
if "%clang%"=="1"     set out=%clang_out%
if "%debug%"=="1"     set compile=%compile_debug%
if "%release%"=="1"   set compile=%compile_release%
set compile=%compile% %auto_compile_flags%

:: --- Prep Directories -------------------------------------------------------
if not exist build mkdir build
if not exist local mkdir local

:: --- Build & Run Metaprogram ------------------------------------------------
if "%no_meta%"=="1" echo [skipping metagen]
if not "%no_meta%"=="1" (
  pushd build
  %compile_debug% ..\src\metagen\metagen_main.c %compile_link% %out%metagen.exe
  metagen.exe
  popd
)

:: --- Build Everything (@build_targets) --------------------------------------
pushd build
if "%raddbg%"=="1"             %compile% %gfx%       ..\src\raddbg\raddbg.cpp                                     %compile_link% %out%raddbg.exe
if "%raddbg_from_pdb%"=="1"    %compile%             ..\src\raddbg_convert\pdb\raddbg_from_pdb_main.c             %compile_link% %out%raddbg_from_pdb.exe
if "%raddbg_from_dwarf%"=="1"  %compile%             ..\src\raddbg_convert\dwarf\raddbg_from_dwarf.c              %compile_link% %out%raddbg_from_dwarf.exe
if "%raddbg_dump%"=="1"        %compile%             ..\src\raddbg_dump\raddbg_dump.c                             %compile_link% %out%raddbg_dump.exe
if "%ryan_scratch%"=="1"       %compile%             ..\src\scratch\ryan_scratch.c                                %compile_link% %out%ryan_scratch.exe
if "%look_at_raddbg%"=="1"     %compile%             ..\src\scratch\look_at_raddbg.c                              %compile_link% %out%look_at_raddbg.exe
if "%mule_main%"=="1"          del vc*.pdb mule*.pdb && %cl_release% /c ..\src\mule\mule_inline.cpp && %cl_release% /c ..\src\mule\mule_o2.cpp && %cl_debug% /EHsc ..\src\mule\mule_main.cpp ..\src\mule\mule_c.c mule_inline.obj mule_o2.obj
if "%mule_module%"=="1"        %compile%             ..\src\mule\mule_module.cpp                                  %compile_link% %link_dll% %out%mule_module.dll
popd

:: --- Unset ------------------------------------------------------------------
for %%a in (%*) do set "%%a=0"
set raddbg=
set compile=
set compile_link=
set out=
set msvc=
set debug=
