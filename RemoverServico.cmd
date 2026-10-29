@echo off
setlocal
net session >nul 2>&1
if errorlevel 1 (
  echo Execute este arquivo como Administrador.
  pause
  exit /b 1
)

set "SERVICE_EXE=%~dp0WorbyService.exe"

if not exist "%SERVICE_EXE%" (
  echo WorbyService.exe nao foi encontrado.
  pause
  exit /b 1
)

"%SERVICE_EXE%" /uninstall
pause
