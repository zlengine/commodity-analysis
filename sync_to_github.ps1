param(
    [Parameter(Mandatory=$false)]
    [string[]]$Files,

    [Parameter(Mandatory=$false)]
    [switch]$All,

    [Parameter(Mandatory=$false)]
    [switch]$TriggerBuild
)

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$repo = "zlengine/commodity-analysis"
$branch = "main"
$basePath = "c:\Users\Admin\Documents\trae_projects\shangpin"

$allFiles = @(
    "index.html",
    "bottom_index.html",
    "20260503_SR.html",
    "20260503_CF.html",
    "20260503_C.html",
    "20260503_AL.html",
    "20260503_CU.html",
    "20260503_AG.html",
    "20260503_AU.html",
    "20260503_RU.html",
    "20260503_RB.html",
    "20260503_I.html",
    "20260503_IF.html",
    "analyses/20260505_SH.html",
    "analyses/20260506_CJ.html",
    "css/bottom_analysis.css"
)

if ($All) {
    $Files = $allFiles
}

if ($Files.Count -eq 0) {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\sync_to_github.ps1 -Files @('index.html','20260521_SR.html')"
    Write-Host "  .\sync_to_github.ps1 -All"
    Write-Host "  .\sync_to_github.ps1 -All -TriggerBuild"
    exit 1
}

$successCount = 0
$failCount = 0

foreach ($file in $Files) {
    $filePath = Join-Path $basePath $file
    
    if (-not (Test-Path $filePath)) {
        Write-Host "SKIP $file (not found locally)" -ForegroundColor Yellow
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $content = [Convert]::ToBase64String($bytes)

    $existingSha = $null
    try {
        $existingSha = gh api "repos/$repo/contents/$file" --jq ".sha" 2>$null
    } catch {}

    $jsonBody = @{
        message = "Update $file"
        content = $content
        branch = $branch
    }
    if ($existingSha) {
        $jsonBody.sha = $existingSha
    }

    $jsonStr = $jsonBody | ConvertTo-Json -Compress

    $tmpFile = [System.IO.Path]::GetTempFileName()
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tmpFile, $jsonStr, $utf8NoBom)

    Write-Host "Uploading $file ..." -NoNewline
    try {
        $result = gh api "repos/$repo/contents/$file" -X PUT --input $tmpFile 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " OK" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  $result" -ForegroundColor DarkRed
            $failCount++
        }
    } catch {
        Write-Host " ERROR" -ForegroundColor Red
        Write-Host "  $_" -ForegroundColor DarkRed
        $failCount++
    }

    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

Write-Host "`nDone! Success: $successCount, Failed: $failCount" -ForegroundColor Cyan

if ($TriggerBuild) {
    Write-Host "`nTriggering GitHub Pages build ..." -NoNewline
    try {
        gh api "repos/$repo/pages/builds" -X POST 2>&1 | Out-Null
        Write-Host " OK" -ForegroundColor Green
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
    }
}
