# PowerContext Server watchdog (resident): probe health, restart if dead.
# Idempotent: exits silently when healthy; guards against duplicate starts.
# Registered as a Scheduled Task: at logon + every 1 minute.

$ErrorActionPreference = 'SilentlyContinue'

$exe       = Join-Path $env:USERPROFILE '.local\bin\powercontext.exe'
$healthUrl = 'http://127.0.0.1:8000/'
$logDir    = 'D:\github\powercontext-runtime'
$logFile   = Join-Path $logDir 'watchdog.log'
$outLog    = Join-Path $logDir 'server-out.log'
$errLog    = Join-Path $logDir 'server-err.log'

function Write-WdLog([string]$line) {
  try {
    if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 2MB)) {
      Set-Content -Path $logFile -Value "[$(Get-Date -Format s)] log rotated" -Encoding utf8
    }
    Add-Content -Path $logFile -Value "[$(Get-Date -Format s)] $line" -Encoding utf8
  } catch {}
}

if (-not (Test-Path $exe)) { Write-WdLog 'powercontext.exe not found; skip'; exit 1 }
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# 1) healthy? done.
try {
  $r = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 6
  if ($r.StatusCode -eq 200) { exit 0 }
} catch {}

# 2) process alive but still booting? don't double-start.
$alive = Get-CimInstance Win32_Process -Filter "Name='powercontext.exe'" |
  Where-Object { $_.CommandLine -match 'server' }
if ($alive) { Write-WdLog 'process alive, health not ready yet; wait'; exit 0 }

# 3) start hidden server
Write-WdLog 'server dead; starting'
Start-Process -FilePath $exe -ArgumentList 'server','run' -WindowStyle Hidden `
  -RedirectStandardOutput $outLog -RedirectStandardError $errLog
Start-Sleep -Seconds 6
try {
  $r2 = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 8
  Write-WdLog "restart ok (HTTP $($r2.StatusCode))"
} catch {
  Write-WdLog 'restart attempted; health still not ready (will retry next patrol)'
}
exit 0
