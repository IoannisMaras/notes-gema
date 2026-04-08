# setup_model.ps1
# Script to download the Gemma model locally for consistent web performance

$modelUrl = "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"
$destFolder = "web"
$destPath = "$destFolder/gemma-4-E2B-it.litertlm"

if (!(Test-Path $destFolder)) {
    Write-Host "> Creating directory: $destFolder" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $destFolder | Out-Null
}

Write-Host "> Downloading Gemma Model (2.5 GB)..." -ForegroundColor Yellow
Write-Host "> This may take several minutes depending on your connection." -ForegroundColor Gray

# Use curl.exe directly as it's more reliable for large files and shows a progress bar
curl.exe -L $modelUrl -o $destPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n> SUCCESS: Model downloaded to $destPath" -ForegroundColor Green
    Write-Host "> You can now run the project and it will load from your local disk." -ForegroundColor Green
} else {
    Write-Host "`n> ERROR: Download failed. Please check your internet connection and try again." -ForegroundColor Red
}
