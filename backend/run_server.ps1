$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path '.env')) { Copy-Item '.env.example' '.env' }
python -m uvicorn main:app --host 0.0.0.0 --port 8000
