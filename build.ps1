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
  $patchChunkedMethod = Join-Path $patchRoot "ApiClient.enableChunkedTransfer.snippet.java"

  foreach ($p in @($openapiJar, $packageConfig, $patchChunkedMethod)) {
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
  # Generate Java client (native library = java.net.http.HttpClient)
  # ----------------------------------------------------------------------
  Write-Host "Generating client -> $clientDir"
  & java -jar $openapiJar generate `
    -i $swaggerPath `
    -g java `
    --library native `
    -o $clientDir `
    -c $packageConfig

  # ----------------------------------------------------------------------
  # Patch ApiClient.java: add enableChunkedTransfer() helper method
  # ----------------------------------------------------------------------
  $apiClientPath = Join-Path $clientDir "src\main\java\org\openapitools\client\ApiClient.java"
  $apiClientContent = Read-TextFile $apiClientPath

  if ($apiClientContent -notmatch '\benableChunkedTransfer\s*\(') {
    $chunkedSnippet = Read-TextFile $patchChunkedMethod

    $lastBrace = $apiClientContent.LastIndexOf("}")
    if ($lastBrace -lt 0) { throw "Could not find class closing brace in ApiClient.java" }

    $apiClientContent = $apiClientContent.Insert($lastBrace, "`r`n" + $chunkedSnippet + "`r`n")
  }

  Write-Utf8NoBom -Path $apiClientPath -Content $apiClientContent

  # ----------------------------------------------------------------------
  # Patch API classes: replace the generated if(hasFiles)/else block and
  # the Content-Type + .method() lines that follow it.
  #
  # Generated code (for every method that uploads a file):
  #
  #   if (hasFiles) {
  #       Pipe pipe; ... entity.writeTo ... ofInputStream(pipe) ...
  #   } else {
  #       ByteArrayOutputStream ... entity.writeTo ... ofInputStream(ByteArrayInputStream) ...
  #   }
  #   localVarRequestBuilder
  #       .header("Content-Type", entity.getContentType().getValue())
  #       .method("POST", formDataPublisher);
  #
  # Replacement:
  #
  #   if (ApiClient.isChunkedTransferEnabled()) {
  #       // stream file bytes directly as application/octet-stream
  #       // (no multipart framing, unknown length -> chunked transfer)
  #   } else {
  #       // buffer multipart entity to byte array -> known Content-Length
  #   }
  #
  # The file variable (e.g. inputFile, jsonCredentialFile) is extracted
  # from the addBinaryBody() call that precedes each block.
  # ----------------------------------------------------------------------
  $apiDir = Join-Path $clientDir "src\main\java\org\openapitools\client\api"
  $apiFiles = Get-ChildItem -Path $apiDir -Filter '*.java' -Recurse

  foreach ($file in $apiFiles) {
    $content = Read-TextFile $file.FullName
    $changed = $false

    # Match the entire if(hasFiles){Pipe...}else{...} block through
    # .method("POST", formDataPublisher);
    $blockPattern = '(?s)if\s*\(\s*hasFiles\s*\)\s*\{\s*Pipe\s+pipe;.*?\.method\("POST",\s*formDataPublisher\)\s*;'
    $blockMatches = [System.Text.RegularExpressions.Regex]::Matches($content, $blockPattern)

    # Process in reverse so earlier string indices stay valid
    for ($i = $blockMatches.Count - 1; $i -ge 0; $i--) {
      $bm = $blockMatches[$i]

      # Look backward to find the nearest addBinaryBody("...", FILE_VAR)
      $preceding = $content.Substring(0, $bm.Index)
      $abm = [System.Text.RegularExpressions.Regex]::Match(
        $preceding,
        'addBinaryBody\("[^"]+",\s*(\w+)\)',
        [System.Text.RegularExpressions.RegexOptions]::RightToLeft
      )
      if (-not $abm.Success) {
        Write-Host "WARNING: no addBinaryBody found before block in $($file.Name)"
        continue
      }
      $fileVar = $abm.Groups[1].Value

      # Build the replacement.  Indentation: the matched "if" sits at the
      # same column as the original, so the replacement starts with "if".
      $replacement = "if (ApiClient.isChunkedTransferEnabled()) {" +
"`r`n        // Stream file bytes directly as application/octet-stream with chunked" +
"`r`n        // transfer encoding (no multipart framing, no Content-Length header)." +
"`r`n        formDataPublisher = HttpRequest.BodyPublishers.ofInputStream(() -> {" +
"`r`n            try { return new java.io.FileInputStream($fileVar); }" +
"`r`n            catch (java.io.FileNotFoundException e) { throw new RuntimeException(e); }" +
"`r`n        });" +
"`r`n        localVarRequestBuilder" +
"`r`n            .header(""Content-Type"", ""application/octet-stream"")" +
"`r`n            .method(""POST"", formDataPublisher);" +
"`r`n    } else {" +
"`r`n        ByteArrayOutputStream formOutputStream = new ByteArrayOutputStream();" +
"`r`n        try {" +
"`r`n            entity.writeTo(formOutputStream);" +
"`r`n        } catch (IOException e) {" +
"`r`n            throw new RuntimeException(e);" +
"`r`n        }" +
"`r`n        formDataPublisher = HttpRequest.BodyPublishers.ofByteArray(formOutputStream.toByteArray());" +
"`r`n        localVarRequestBuilder" +
"`r`n            .header(""Content-Type"", entity.getContentType().getValue())" +
"`r`n            .method(""POST"", formDataPublisher);" +
"`r`n    }"

      $content = $content.Substring(0, $bm.Index) + $replacement + $content.Substring($bm.Index + $bm.Length)
      $changed = $true
    }

    if ($changed) {
      Write-Host "Patched multipart body publisher in $($file.Name)"
      Write-Utf8NoBom -Path $file.FullName -Content $content
    }
  }

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
