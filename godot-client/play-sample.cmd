@echo off
if exist "%~dp0build\pixel-training.exe" (
  "%~dp0build\pixel-training.exe"
) else (
  call "%LOCALAPPDATA%\Programs\Godot\bin\godot.cmd" --path "%~dp0."
)
