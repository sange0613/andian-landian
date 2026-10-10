#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
node native-win/make-small-icon.cjs
clang++ -std=c++17 -Wall -Wextra -Werror native-win/tests/logic_test.cpp -o dist/native-win/logic-test
dist/native-win/logic-test
x86_64-w64-mingw32-windres -I native-win --codepage=65001 native-win/DianDian.rc -O coff -o dist/native-win/resources.o
x86_64-w64-mingw32-g++ -std=c++17 -Os -Wall -Wextra -Werror -D_WIN32_WINNT=0x0A00 \
  -municode -mwindows -static -static-libgcc -static-libstdc++ -fno-exceptions -fno-rtti \
  -ffunction-sections -fdata-sections -Wl,--gc-sections -s \
  native-win/DianDian.cpp dist/native-win/resources.o -o dist/native-win/DimBlueDot.exe \
  -lgdiplus -lshell32 -lgdi32 -luser32 -ladvapi32
makensis -V2 native-win/installer.nsi
node native-win/check-package.cjs
