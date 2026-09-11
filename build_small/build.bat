@echo off
setlocal
cd /d "%~dp0"
odin build . -no-entry-point -o:size -no-bounds-check -no-type-assert -min-link-libs -source-code-locations:none -no-crt -no-thread-local -lto:thin -linker:lld -extra-linker-flags:"/OPT:REF /OPT:ICF" -out:fc.exe %*
if %ERRORLEVEL% equ 0 (
    upx --ultra-brute fc.exe
)
