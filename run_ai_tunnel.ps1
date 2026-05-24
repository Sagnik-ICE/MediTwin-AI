$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================"
Write-Host " MediTwin AI - Local AI Tunnel Launcher"
Write-Host "========================================"
Write-Host ""

function Test-CommandExists {
    param([string]$CommandName)

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

if (-not (Test-CommandExists "ollama")) {
    Write-Host "[ERROR] Ollama was not found in PATH." -ForegroundColor Red
    Write-Host "Install Ollama first, then reopen PowerShell."
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not (Test-CommandExists "cloudflared")) {
    Write-Host "[ERROR] cloudflared was not found in PATH." -ForegroundColor Red
    Write-Host "Install it once with:"
    Write-Host "winget install --id Cloudflare.cloudflared -e" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[1/5] Checking Ollama local server..." -ForegroundColor Cyan

$ollamaOk = $false
try {
    $localResponse = Invoke-WebRequest "http://127.0.0.1:11434" -UseBasicParsing -TimeoutSec 5
    if ($localResponse.StatusCode -eq 200) {
        $ollamaOk = $true
    }
} catch {
    $ollamaOk = $false
}

if (-not $ollamaOk) {
    Write-Host "Ollama is not running. Starting Ollama..." -ForegroundColor Yellow
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Minimized
    Start-Sleep -Seconds 5
}

try {
    $localResponse = Invoke-WebRequest "http://127.0.0.1:11434" -UseBasicParsing -TimeoutSec 10
    Write-Host "Ollama local server is running." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Could not start or reach Ollama at http://127.0.0.1:11434" -ForegroundColor Red
    Write-Host $_.Exception.Message
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "[2/5] Checking available Ollama models..." -ForegroundColor Cyan

try {
    $tags = Invoke-RestMethod "http://127.0.0.1:11434/api/tags" -TimeoutSec 10
    if ($tags.models.Count -gt 0) {
        Write-Host "Installed models:" -ForegroundColor Green
        foreach ($model in $tags.models) {
            Write-Host " - $($model.name)"
        }
    } else {
        Write-Host "[WARNING] No Ollama models found." -ForegroundColor Yellow
        Write-Host "Pull a model first, for example:"
        Write-Host "ollama pull qwen3:4b" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Could not read Ollama model list." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3/5] Stopping old Cloudflare tunnel processes..." -ForegroundColor Cyan
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

Write-Host ""
Write-Host "[4/5] Starting Cloudflare Tunnel..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Important:"
Write-Host "This tunnel uses --http-host-header 127.0.0.1:11434 to prevent Ollama 403 Forbidden."
Write-Host ""

$arguments = "tunnel --url http://127.0.0.1:11434 --http-host-header 127.0.0.1:11434"

$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = "cloudflared"
$processInfo.Arguments = $arguments
$processInfo.RedirectStandardError = $true
$processInfo.RedirectStandardOutput = $true
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $false

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo

[void]$process.Start()

$tunnelBaseUrl = $null
$deadline = (Get-Date).AddSeconds(45)

while ((Get-Date) -lt $deadline -and -not $process.HasExited) {
    $line = $process.StandardError.ReadLine()

    if ($line) {
        Write-Host $line

        if ($line -match "https://[a-zA-Z0-9-]+\.trycloudflare\.com") {
            $tunnelBaseUrl = $matches[0]
            break
        }
    }
}

if (-not $tunnelBaseUrl) {
    Write-Host ""
    Write-Host "[ERROR] Could not detect Cloudflare Tunnel URL." -ForegroundColor Red
    Write-Host "Close this window and try again."
    Read-Host "Press Enter to exit"
    exit 1
}

$connectUrl = "$tunnelBaseUrl/api/chat"

Write-Host ""
Write-Host "[5/5] Tunnel created." -ForegroundColor Green
Write-Host ""
Write-Host "========================================"
Write-Host " AI CONNECT URL"
Write-Host "========================================"
Write-Host $connectUrl -ForegroundColor Green
Write-Host "========================================"
Write-Host ""

try {
    Set-Clipboard $connectUrl
    Write-Host "The AI Connect URL has been copied to clipboard." -ForegroundColor Green
} catch {
    Write-Host "Could not copy to clipboard. Copy it manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Testing tunnel root..."
Start-Sleep -Seconds 4

try {
    $testRoot = Invoke-WebRequest $tunnelBaseUrl -UseBasicParsing -TimeoutSec 20
    Write-Host "Root test: OK" -ForegroundColor Green
} catch {
    Write-Host "Root test failed. The tunnel may need a few more seconds." -ForegroundColor Yellow
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Keep this PowerShell window open during the demo."
Write-Host "Closing this window will stop the Cloudflare Tunnel."
Write-Host ""

while (-not $process.HasExited) {
    Start-Sleep -Seconds 2
}