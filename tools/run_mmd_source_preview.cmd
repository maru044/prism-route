@echo off
setlocal
set "PR_PREVIEW_BLENDER=D:\blender\blender.exe"
set "PR_PREVIEW_SCRIPT=%~dp0mmd_preview\blender_source_browser.py"
set "PR_PREVIEW_SCENE=%~dp0..\..\research\mmd_source_preview_20261103\mmd_source_browser.blend"
if not exist "%PR_PREVIEW_BLENDER%" (
  echo Blender was not found. Use run_mmd_source_preview.ps1 -BlenderPath with your Blender executable.
  pause
  exit /b 1
)
if exist "%PR_PREVIEW_SCENE%" (
  start "" "%PR_PREVIEW_BLENDER%" "%PR_PREVIEW_SCENE%" --python "%PR_PREVIEW_SCRIPT%"
) else (
  start "" "%PR_PREVIEW_BLENDER%" --factory-startup --python "%PR_PREVIEW_SCRIPT%"
)
