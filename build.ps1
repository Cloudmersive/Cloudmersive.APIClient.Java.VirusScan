$ErrorActionPreference = "Stop"

# Always operate relative to this script's directory (NOT the caller's cwd)
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }

Push-Location $root
try {
  # ----------------------------------------------------------------------
  # Force TLS 1.2 for Invoke-WebRequest (Windows PowerShell / older .NET defaults)
  # ----------------------------------------------------------------------
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  } catch {
    # fallback constant for TLS 1.2 on older frameworks
    [Net.ServicePointManager]::SecurityProtocol = 3072
  }

  function Write-Utf8NoBom {
    param(
      [Parameter(Mandatory=$true)][string]$Path,
      [Parameter(Mandatory=$true)][string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  }

  function Read-TextFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    return [System.IO.File]::ReadAllText($Path)  # auto-detects encoding and strips UTF-8 BOM if present
  }

  function Remove-Utf8BomInFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
      [System.IO.File]::WriteAllBytes($Path, $bytes[3..($bytes.Length-1)])
    }
  }

  # ----------------------------------------------------------------------
  # Paths (absolute, based on script dir)
  # ----------------------------------------------------------------------
  $clientDir      = Join-Path $root "client"
  $swaggerPath    = Join-Path $root "virus-api-swagger.json"
  $openapiJar     = Join-Path $root "openapi-generator-cli-7.12.0.jar"
  $packageConfig  = Join-Path $root "packageconfig.json"

  $patchRoot          = Join-Path $root "patches"
  $patchInterceptor   = Join-Path $patchRoot "ForceChunkedMultipartInterceptor.java"
  $patchChunkedMethod = Join-Path $patchRoot "ApiClient.enableChunkedTransfer.snippet.java"

  foreach ($p in @($openapiJar, $packageConfig, $patchInterceptor, $patchChunkedMethod)) {
    if (!(Test-Path $p)) { throw "Missing required file: $p" }
  }

  # ----------------------------------------------------------------------
  # Clean
  # ----------------------------------------------------------------------
  if (Test-Path $clientDir) {
    Remove-Item -Path $clientDir -Recurse -Force
  }

  # ----------------------------------------------------------------------
  # Download swagger (TLS 1.2)
  # ----------------------------------------------------------------------
  Write-Host "Downloading swagger -> $swaggerPath"

  $iwrParams = @{
    Uri         = 'https://api.cloudmersive.com/virus/docs/v1/swagger'
    OutFile     = $swaggerPath
    ErrorAction = 'Stop'
  }

  # Optional compatibility switches (only if supported)
  $iwrCmd = Get-Command Invoke-WebRequest
  if ($iwrCmd.Parameters.ContainsKey('UseBasicParsing')) { $iwrParams['UseBasicParsing'] = $true }
  if ($iwrCmd.Parameters.ContainsKey('SslProtocol'))     { $iwrParams['SslProtocol'] = 'Tls12' }

  Invoke-WebRequest @iwrParams

  if (!(Test-Path $swaggerPath)) {
    throw "Swagger download did not create expected file: $swaggerPath (PWD: $(Get-Location))"
  }

  # ----------------------------------------------------------------------
  # Patch swagger host + scheme (write no BOM)
  # ----------------------------------------------------------------------
  $swaggerJson = Read-TextFile $swaggerPath
  $swaggerJson = $swaggerJson.Replace('localhost', 'api.cloudmersive.com').Replace('"http"', '"https"')
  Write-Utf8NoBom -Path $swaggerPath -Content $swaggerJson

  # ----------------------------------------------------------------------
  # Generate Java client
  # ----------------------------------------------------------------------
  Write-Host "Generating client -> $clientDir"
  & java -jar $openapiJar generate `
    -i $swaggerPath `
    -g java `
    --library okhttp-gson `
    -o $clientDir `
    -c $packageConfig

  # ----------------------------------------------------------------------
  # Copy ForceChunkedMultipartInterceptor.java into generated sources (UTF-8 no BOM)
  # ----------------------------------------------------------------------
  $destInterceptor = Join-Path $clientDir "src\main\java\org\openapitools\client\ForceChunkedMultipartInterceptor.java"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destInterceptor) | Out-Null
  Write-Utf8NoBom -Path $destInterceptor -Content (Read-TextFile $patchInterceptor)

  # ----------------------------------------------------------------------
  # Patch ApiClient.java:
  #   (1) force TLS 1.2 for OkHttp connections
  #   (2) add enableChunkedTransfer() helper method from patch file
  # ----------------------------------------------------------------------
  $apiClientPath = Join-Path $clientDir "src\main\java\org\openapitools\client\ApiClient.java"
  $apiClientContent = Read-TextFile $apiClientPath

  # (1) Insert TLS 1.2 connectionSpecs inside initHttpClient(...) after builder creation
  if ($apiClientContent -notmatch 'tlsVersions\(TlsVersion\.TLS_1_2\)') {

    $tlsSnippet = @'
        // Force TLS 1.2 (some environments default to TLS 1.0/1.1 which many APIs block)
        builder.connectionSpecs(Arrays.asList(
                new ConnectionSpec.Builder(ConnectionSpec.MODERN_TLS)
                        .tlsVersions(TlsVersion.TLS_1_2)
                        .build(),
                ConnectionSpec.CLEARTEXT
        ));
'@

    $pattern = 'OkHttpClient\.Builder\s+builder\s*=\s*new\s+OkHttpClient\.Builder\(\)\s*;'
    $m = [System.Text.RegularExpressions.Regex]::Match($apiClientContent, $pattern)
    if (-not $m.Success) { throw "Could not find OkHttpClient.Builder initialization in ApiClient.java" }

    $insertPos = $m.Index + $m.Length
    $apiClientContent = $apiClientContent.Insert($insertPos, "`r`n" + $tlsSnippet)
  }

  # (2) Inject enableChunkedTransfer() before final class closing brace
  if ($apiClientContent -notmatch '\benableChunkedTransfer\s*\(') {
    $chunkedSnippet = Read-TextFile $patchChunkedMethod

    $lastBrace = $apiClientContent.LastIndexOf("}")
    if ($lastBrace -lt 0) { throw "Could not find class closing brace in ApiClient.java" }

    $apiClientContent = $apiClientContent.Insert($lastBrace, "`r`n" + $chunkedSnippet + "`r`n")
  }

  # Write ApiClient.java without BOM
  Write-Utf8NoBom -Path $apiClientPath -Content $apiClientContent

  # Safety net: strip UTF-8 BOM from ALL generated Java files
  Get-ChildItem -Path (Join-Path $clientDir "src\main\java") -Recurse -Filter '*.java' |
    ForEach-Object { Remove-Utf8BomInFile -Path $_.FullName }

  # Copy README
  Copy-Item -Path (Join-Path $clientDir "README.md") -Destination (Join-Path $root "README.md") -Force

  # Build
  & mvn -f (Join-Path $clientDir "pom.xml") clean package -DskipTests

} finally {
  Pop-Location
}
