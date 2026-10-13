param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseDir
)

$ErrorActionPreference = 'Stop'

$releasePath = (Resolve-Path -LiteralPath $ReleaseDir).Path
$vswherePath = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswherePath -PathType Leaf)) {
  throw 'Visual Studio Installer não encontrado.'
}

$installations = @(& $vswherePath -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
$candidates = @(
  foreach ($installation in $installations) {
    $redistRoot = Join-Path $installation 'VC\Redist\MSVC'
    if (-not (Test-Path -LiteralPath $redistRoot -PathType Container)) {
      continue
    }

    foreach ($version in Get-ChildItem -LiteralPath $redistRoot -Directory) {
      $parsedVersion = $null
      if (-not [Version]::TryParse($version.Name, [ref]$parsedVersion)) {
        continue
      }

      $x64Root = Join-Path $version.FullName 'x64'
      if (-not (Test-Path -LiteralPath $x64Root -PathType Container)) {
        continue
      }

      foreach ($crt in Get-ChildItem -LiteralPath $x64Root -Directory) {
        if ($crt.Name -match '^Microsoft\.VC\d+\.CRT$') {
          [pscustomobject]@{ Version = $parsedVersion; Path = $crt.FullName }
        }
      }
    }
  }
)

$required = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
$crt = $candidates |
  Where-Object {
    $candidate = $_
    @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $candidate.Path $_) -PathType Leaf) }).Count -eq 0
  } |
  Sort-Object Version -Descending |
  Select-Object -First 1

if ($null -eq $crt) {
  throw 'Bibliotecas Visual C++ x64 de distribuição não encontradas.'
}

$dlls = @(Get-ChildItem -LiteralPath $crt.Path -Filter '*.dll' -File)
foreach ($dll in $dlls) {
  Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $releasePath $dll.Name) -Force
}

foreach ($name in $required) {
  if (-not (Test-Path -LiteralPath (Join-Path $releasePath $name) -PathType Leaf)) {
    throw "Biblioteca obrigatória ausente: $name"
  }
}

Write-Host "Incluídas $($dlls.Count) bibliotecas Visual C++ x64 no aplicativo."
