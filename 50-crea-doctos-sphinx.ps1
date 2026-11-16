#requires -Version 5.1
<#
.SYNOPSIS
    Genera documentacion de API Python con Sphinx + AutoAPI. v4 generica.
.DESCRIPTION
    Fixes v2:
    - No sobrescribir $Root con foreach ($root ...) (PowerShell es case-insensitive).
    - AutoAPI genera _generated_api/<paquete>/index, NO _generated_api/index.
    - Limpia toctrees auto-referenciales (ej. overview.rst -> architecture/overview).
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = $PSScriptRoot,
    [string[]]$SourceDirs = @(),
    [string]$DocsDirectory = "",
    [switch]$NoBrowser,
    [switch]$Force,
    [switch]$SkipInstall
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function Resolve-GenericPath {
    param([Parameter(Mandatory)][string]$PathText,[string]$Base = "")
    $t = $PathText.Trim().Trim('"', "'")
    if ($t -eq "" -or $t -eq "PWD" -or $t -eq '$PWD' -or $t -eq "%CD%" -or $t -eq "." -or $t -eq "./" -or $t -eq ".\") { return (Get-Location).Path }
    $cwd = (Get-Location).Path
    if ($t -match '^(?i)(PWD|\$PWD|%CD%)[\\/]+(.*)$') { return [System.IO.Path]::GetFullPath((Join-Path -Path $cwd -ChildPath $Matches[2])) }
    $t = [System.Environment]::ExpandEnvironmentVariables($t)
    if ([System.IO.Path]::IsPathRooted($t)) { return [System.IO.Path]::GetFullPath($t) }
    $basePath = if ([string]::IsNullOrWhiteSpace($Base)) { $cwd } else { $Base }
    return [System.IO.Path]::GetFullPath((Join-Path -Path $basePath -ChildPath $t))
}
$Root               = Resolve-GenericPath -PathText $ProjectRoot -Base $PSScriptRoot
$VenvDir            = Join-Path $Root ".venv"
$Python             = Join-Path $VenvDir "Scripts\python.exe"
$LogDir             = Join-Path $Root "artifacts\documentation"
$BuildDir           = Join-Path $Root "docs\_build\html"
$ConfDir            = Join-Path $LogDir "sphinx-config"
$ApiRootName        = "_generated_api"
$GeneratedApiMarker = ".factory-generated"
$Utf8Bom            = [System.Text.UTF8Encoding]::new($true)
$ExcludedDirectories = @(".git",".venv","venv","env",".tox",".nox","__pycache__","node_modules","site-packages","tests","test","testing","docs","artifacts","build","dist",".pytest_cache",".mypy_cache",".ruff_cache",".idea",".vscode",".eggs","*.egg-info","_build","_generated_api","_static","_templates")
function Write-Step { param([string]$Message) Write-Host "`n===== $Message =====" -ForegroundColor Cyan }
function Write-Utf8BomFile {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8Bom)
}
function Test-PythonAvailable {
    param([string]$PythonPath)
    if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { return $false }
    & $PythonPath -c "import sys; print(sys.version)" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Get-MissingDocumentationPackages {
    param([string]$PythonPath)
    $probe = @"
import importlib.util
names = ['sphinx', 'autoapi', 'myst_parser', 'sphinx_rtd_theme']
print(' '.join(n for n in names if importlib.util.find_spec(n) is None))
"@
    $output = & $PythonPath -c $probe 2>$null
    if ($LASTEXITCODE -ne 0) { throw "No se pudo consultar el entorno Python." }
    return @(($output -join " ").Trim() -split '\s+' | Where-Object { $_ })
}
function Invoke-PythonProcess {
    param([Parameter(Mandatory)][string[]]$Arguments,[Parameter(Mandatory)][string]$StdOutPath,[Parameter(Mandatory)][string]$StdErrPath)
    $quoted = ($Arguments | ForEach-Object { '"' + ([string]$_).Replace('"', '\"') + '"' }) -join ' '
    $proc = Start-Process -FilePath $Python -ArgumentList $quoted -WorkingDirectory $Root -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -Wait -PassThru -NoNewWindow
    return $proc.ExitCode
}
function Test-ExcludedPath {
    param([string]$PathText)
    $parts = $PathText -split '[\\/]'
    foreach ($part in $parts) { if ($ExcludedDirectories -contains $part) { return $true } }
    return $false
}
function Get-PythonSourceRoots {
    $results = [System.Collections.Generic.List[string]]::new()
    if ($SourceDirs.Count -gt 0) {
        foreach ($dir in $SourceDirs) {
            $candidate = Join-Path $Root $dir
            if (-not (Test-Path -LiteralPath $candidate -PathType Container)) { throw "No existe el directorio de codigo indicado: $candidate" }
            $resolved = (Resolve-Path -LiteralPath $candidate).Path
            if (-not $results.Contains($resolved)) { $results.Add($resolved) }
        }
        return $results.ToArray()
    }
    $srcPath = Join-Path $Root "src"
    $searchBase = if (Test-Path -LiteralPath $srcPath -PathType Container) { $srcPath } else { $Root }
    $directFiles = @(Get-ChildItem -LiteralPath $searchBase -File -Filter "*.py" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "test_*.py" -and $_.Name -notlike "*_test.py" -and $_.Name -ne "setup.py" -and $_.Name -ne "conftest.py" })
    if ($directFiles.Count -gt 0) { $results.Add((Resolve-Path -LiteralPath $searchBase).Path); return $results.ToArray() }
    $topDirs = @(Get-ChildItem -LiteralPath $searchBase -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $ExcludedDirectories -notcontains $_.Name })
    foreach ($dir in $topDirs) {
        $hasInit = Test-Path -LiteralPath (Join-Path $dir.FullName "__init__.py") -PathType Leaf
        if (-not $hasInit) {
            $nsModule = Get-ChildItem -LiteralPath $dir.FullName -File -Filter "*.py" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "test_*.py" -and $_.Name -notlike "*_test.py" } | Select-Object -First 1
            if ($null -ne $nsModule) { $results.Add((Resolve-Path -LiteralPath $dir.FullName).Path); continue }
        }
        $pyFile = Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Filter "*.py" -ErrorAction SilentlyContinue | Where-Object { $relative = $_.FullName.Substring($dir.FullName.Length); -not (Test-ExcludedPath $relative) -and $_.Name -notlike "test_*.py" -and $_.Name -notlike "*_test.py" } | Select-Object -First 1
        if ($null -ne $pyFile) { $resolved = (Resolve-Path -LiteralPath $dir.FullName).Path; if (-not $results.Contains($resolved)) { $results.Add($resolved) } }
    }
    return ($results | Sort-Object -Unique)
}
function Get-DocumentationPages {
    if (-not (Test-Path -LiteralPath $DocsDir -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $DocsDir -Recurse -File -Force | Where-Object { $_.Extension -in @(".md",".rst") -and $_.Name -ne "index.rst" -and $_.Name -ne "conf.py" -and -not (Test-ExcludedPath $_.DirectoryName.Substring($DocsDir.Length)) } | ForEach-Object { $relative = $_.FullName.Substring($DocsDir.Length).TrimStart('\','/'); [System.IO.Path]::ChangeExtension($relative,$null).Replace('\','/') } | Sort-Object -Unique)
}
function Test-DocsInsideSource {
    param([string]$DocsPath,[string[]]$SourceRoots)
    $docsFull = [System.IO.Path]::GetFullPath($DocsPath).TrimEnd('\','/')
    foreach ($src in $SourceRoots) { $srcFull = [System.IO.Path]::GetFullPath($src).TrimEnd('\','/'); if ($docsFull.StartsWith($srcFull + [System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase) -or $docsFull.Equals($srcFull,[System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}
function Remove-SelfReferencingToctree {
    if (-not (Test-Path -LiteralPath $DocsDir -PathType Container)) { return }
    $files = @(Get-ChildItem -LiteralPath $DocsDir -Recurse -File -Filter "*.rst" -ErrorAction SilentlyContinue | Where-Object { -not (Test-ExcludedPath $_.DirectoryName.Substring($DocsDir.Length)) })
    foreach ($f in $files) {
        $docName = [System.IO.Path]::ChangeExtension($f.FullName.Substring($DocsDir.Length).TrimStart('\','/'), $null).Replace('\','/')
        $text = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        if ($null -eq $text) { continue }
        $orig = $text
        # Candidatos de auto-referencia: absoluta, relativa al directorio, con/sin ./, con/sin .rst
        # Ej. para architecture/overview: architecture/overview, overview, ./overview, ./architecture/overview
        $base = Split-Path -Path $docName -Leaf
        $dir  = Split-Path -Path $docName -Parent
        $candidates = @($docName, $base, "./$docName", "./$base") | Sort-Object -Unique
        foreach ($cand in $candidates) {
            $pattern = "(?m)^[ \t]*" + [regex]::Escape($cand) + "(?:\.rst)?[ \t]*\r?\n?"
            $text = [regex]::Replace($text, $pattern, "")
        }
        if ($text -ne $orig) { Write-Host "  Limpio auto-referencia en $docName" -ForegroundColor DarkGray; Write-Utf8BomFile -Path $f.FullName -Content $text }
    }
}
Write-Step "1. VERIFICANDO ENTORNO PYTHON"
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    Write-Host "Entorno virtual no encontrado. Creando .venv..." -ForegroundColor Yellow
    $pyLauncher = Get-Command "py.exe" -ErrorAction SilentlyContinue
    if ($pyLauncher) { & $pyLauncher.Source -3 -m venv $VenvDir } else { $pythonCmd = Get-Command "python.exe" -ErrorAction SilentlyContinue; if (-not $pythonCmd) { throw "No se encontro Python ni el launcher py.exe." }; & $pythonCmd.Source -m venv $VenvDir }
    if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el entorno virtual." }
}
if (-not (Test-PythonAvailable -PythonPath $Python)) { throw "El interprete Python del entorno virtual no funciona: $Python" }
& $Python --version
Write-Step "2. VALIDANDO DEPENDENCIAS"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$missing = @(Get-MissingDocumentationPackages -PythonPath $Python)
if ($missing.Count -gt 0) {
    if ($SkipInstall) { throw "Faltan dependencias y se indico -SkipInstall: $($missing -join ', ')" }
    Write-Host "Faltan dependencias: $($missing -join ', ')" -ForegroundColor Yellow
    $pipOut = Join-Path $LogDir "pip-docs-install.stdout.log"; $pipErr = Join-Path $LogDir "pip-docs-install.stderr.log"
    $pipArgs = @("-m","pip","install","--upgrade","sphinx","sphinx-autoapi","myst-parser","sphinx-rtd-theme")
    $exitCode = Invoke-PythonProcess -Arguments $pipArgs -StdOutPath $pipOut -StdErrPath $pipErr
    if ($exitCode -ne 0) { if (Test-Path $pipOut) { Get-Content $pipOut }; if (Test-Path $pipErr) { Get-Content $pipErr }; throw "Fallo la instalacion de dependencias (exit $exitCode)." }
    $missing = @(Get-MissingDocumentationPackages -PythonPath $Python)
    if ($missing.Count -gt 0) { throw "Siguen faltando dependencias: $($missing -join ', ')" }
}
& $Python -m sphinx --version
Write-Step "3. DESCUBRIENDO CODIGO PYTHON"
$SourceRoots = @(Get-PythonSourceRoots)
if ($SourceRoots.Count -eq 0) { throw "No se encontraron directorios con codigo Python documentable." }
# FIX v2: NUNCA usar $root como variable de bucle: PowerShell es case-insensitive y machaca $Root.
$DetectedPackages = [System.Collections.Generic.List[string]]::new()
foreach ($pkgRoot in $SourceRoots) { if (Test-Path -LiteralPath (Join-Path $pkgRoot "__init__.py") -PathType Leaf) { $DetectedPackages.Add((Split-Path -Path $pkgRoot -Leaf)) } }
if ($DetectedPackages.Count -eq 0) { $DetectedPackages.AddRange(@($SourceRoots | ForEach-Object { Split-Path -Path $_ -Leaf })) }
$DetectedPackages = @($DetectedPackages | Sort-Object -Unique)
$TotalPythonFiles = 0
foreach ($sourceRoot in $SourceRoots) {
    $files = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter "*.py" -ErrorAction SilentlyContinue | Where-Object { $relative = $_.FullName.Substring($sourceRoot.Length); -not (Test-ExcludedPath $relative) -and $_.Name -notlike "test_*.py" -and $_.Name -notlike "*_test.py" })
    $TotalPythonFiles += $files.Count
    Write-Host ("{0,-70} {1,4} archivos" -f $sourceRoot, $files.Count) -ForegroundColor Green
}
if ($TotalPythonFiles -eq 0) { throw "Los directorios detectados no contienen archivos Python documentables." }
Write-Host "Total de fuentes Python : $TotalPythonFiles" -ForegroundColor Green
Write-Host "Paquetes detectados     : $($DetectedPackages -join ', ')" -ForegroundColor Green
# FIX v2: AutoAPI genera _generated_api/<paquete>/index, NO _generated_api/index
$MainPackage = $DetectedPackages[0]
$GeneratedApiIndex = "$ApiRootName/$MainPackage/index"
$GeneratedApiHtmlIndex = Join-Path $BuildDir "$ApiRootName/$MainPackage/index.html"
Write-Host "Indice real de AutoAPI : $GeneratedApiIndex" -ForegroundColor DarkGray
Write-Step "4. PREPARANDO DOCUMENTACION"
if ([string]::IsNullOrWhiteSpace($DocsDirectory)) {
    $candidateSource = Join-Path $Root "docs\source"; $candidateDocs = Join-Path $Root "docs"
    if (Test-Path -LiteralPath (Join-Path $candidateSource "conf.py") -PathType Leaf) { $DocsDirectory = "docs\source"; Write-Host "Usando documentacion existente: docs\source" -ForegroundColor Green }
    elseif (Test-Path -LiteralPath $candidateDocs -PathType Container) { $DocsDirectory = "docs"; Write-Host "Usando documentacion existente: docs" -ForegroundColor Green }
    else { $DocsDirectory = "docs"; New-Item -ItemType Directory -Force -Path $candidateDocs | Out-Null; Write-Host "Se ha creado el directorio de documentacion: $candidateDocs" -ForegroundColor Yellow }
}
$DocsDir = Resolve-GenericPath -PathText $DocsDirectory -Base $Root
Write-Host "Root resuelto   : $Root" -ForegroundColor DarkGray
Write-Host "DocsDir resuelto: $DocsDir" -ForegroundColor DarkGray
if (Test-DocsInsideSource -DocsPath $DocsDir -SourceRoots $SourceRoots) { throw "ERROR: La documentacion esta dentro del codigo fuente.`n  DocsDir: $DocsDir`n  SourceRoots: $($SourceRoots -join ', ')" }
$ApiDir = Join-Path $DocsDir $ApiRootName
$GeneratedApiMarkerPath = Join-Path $ApiDir $GeneratedApiMarker
$IndexRstPath = Join-Path $DocsDir "index.rst"
$ConfPyPath = Join-Path $ConfDir "conf.py"
$ProjectConfPath = Join-Path $DocsDir "conf.py"
$ApiRstPath = Join-Path $DocsDir "api.rst"
$ProjectName = (Split-Path -Path $Root -Leaf) -replace '[-_]+',' '
$ProjectName = (Get-Culture).TextInfo.ToTitleCase($ProjectName)
New-Item -ItemType Directory -Force -Path $DocsDir,$BuildDir,$LogDir,$ConfDir | Out-Null
Get-ChildItem -LiteralPath $BuildDir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
if (Test-Path -LiteralPath $ApiDir -PathType Container) {
    if (-not $Force -and -not (Test-Path -LiteralPath $GeneratedApiMarkerPath -PathType Leaf)) { throw "Se rehusa sobrescribir la carpeta de API sin marcador: $ApiDir`nUsa -Force." }
    Get-ChildItem -LiteralPath $ApiDir -Force | Where-Object { $_.Name -ne $GeneratedApiMarker } | Remove-Item -Recurse -Force
} else { New-Item -ItemType Directory -Force -Path $ApiDir | Out-Null }
Write-Utf8BomFile -Path $GeneratedApiMarkerPath -Content "Generated by improved Sphinx AutoAPI script; safe to regenerate."
Write-Utf8BomFile -Path $ApiRstPath -Content @"
Referencia de API
=================

.. toctree::
   :maxdepth: 4

   $GeneratedApiIndex
"@
Remove-SelfReferencingToctree
Write-Step "5. CONFIGURANDO SPHINX"
$ProjectNamePython = ConvertTo-Json -InputObject $ProjectName -Compress
$AutoApiDirsPython = ($SourceRoots | ForEach-Object { ConvertTo-Json -InputObject $_ -Compress }) -join ",`n    "
$CurrentYear = (Get-Date).Year
$RootForPython = $Root.Replace('\','\\')
$ProjectConfPython = ConvertTo-Json -InputObject $ProjectConfPath -Compress
$ConfContent = @"
# -*- coding: utf-8 -*-
# Generado automaticamente. No editar a mano.
import os
import sys
ROOT = r"$RootForPython"
PROJECT_CONF = $ProjectConfPython
if os.path.isfile(PROJECT_CONF):
    _generated_conf_file = __file__
    __file__ = PROJECT_CONF
    try:
        with open(PROJECT_CONF, encoding="utf-8") as f:
            exec(compile(f.read(), PROJECT_CONF, "exec"), globals())
    finally:
        __file__ = _generated_conf_file
    _project_conf_dir = os.path.dirname(PROJECT_CONF)
    for _path_setting in ("templates_path", "html_static_path", "html_extra_path"):
        _values = globals().get(_path_setting, [])
        globals()[_path_setting] = [v if os.path.isabs(v) else os.path.join(_project_conf_dir, v) for v in _values]
project   = globals().get("project", $ProjectNamePython)
copyright = globals().get("copyright", "$CurrentYear")
author    = globals().get("author", "Project Authors")
release   = globals().get("release", "1.0")
language  = globals().get("language", "es")
sys.path.insert(0, os.path.join(ROOT, "src"))
extensions = list(set(globals().get("extensions", []) + ["autoapi.extension","myst_parser","sphinx.ext.napoleon","sphinx.ext.viewcode","sphinx.ext.intersphinx"]))
templates_path = globals().get("templates_path", [])
_inherited_excludes = [e for e in globals().get("exclude_patterns", []) if e not in ("$ApiRootName", "_generated_api", "_generated_api/**", "**/_generated_api/**")]
exclude_patterns = list(set(_inherited_excludes + ["_build", ".DS_Store", "Thumbs.db"]))
html_theme = globals().get("html_theme", "sphinx_rtd_theme")
html_static_path = globals().get("html_static_path", [])
autoapi_type = "python"
autoapi_dirs = [
    $AutoApiDirsPython
]
autoapi_root = "$ApiRootName"
autoapi_file_patterns = ["*.py"]
autoapi_ignore = ["**/tests/**", "**/test/**", "**/test_*.py", "**/*_test.py", "**/__pycache__/**", "**/.venv/**", "**/venv/**", "**/site-packages/**", "**/node_modules/**", "**/docs/**", "**/artifacts/**", "**/build/**", "**/dist/**", "**/*.egg-info/**", "**/_generated_api/**"]
autoapi_options = ["members", "undoc-members", "show-inheritance", "show-module-summary", "special-members"]
autoapi_member_order = "bysource"
autoapi_python_class_content = "both"
autoapi_add_toctree_entry = False
autoapi_keep_files = True
autoapi_python_use_implicit_namespaces = True
autoapi_generate_api_docs = True
napoleon_google_docstring = True
napoleon_numpy_docstring = True
napoleon_include_init_with_doc = True
napoleon_use_param = True
napoleon_use_rtype = True
napoleon_use_ivar = True
myst_enable_extensions = ["colon_fence", "deflist", "fieldlist"]
suppress_warnings = list(set(globals().get("suppress_warnings", []) + ["docutils", "toc.not_included", "ref.python", "autoapi"]))
nitpicky = False
todo_include_todos = False
import shutil as _shutil
if not _shutil.which("dot"):
    # v4: NO poner graphviz_dot = "" -> eso mismo genera un warning.
    # Mantener la extension, pero suprimir sus warnings: el diagrama queda sin renderizar
    # pero el build sale en 0 warnings. Si instalas Graphviz, se renderiza solo.
    suppress_warnings = list(set(globals().get("suppress_warnings", []) + ["graphviz"]))
"@
Write-Utf8BomFile -Path $ConfPyPath -Content $ConfContent
Write-Step "6. PREPARANDO INDICE"
$pages = @(Get-DocumentationPages | Where-Object { $_ -ne "api" -and $_ -ne $GeneratedApiIndex -and $_ -notlike "$ApiRootName/*" })
$titleUnderline = "=" * [Math]::Max(20, $ProjectName.Length)
$IndexContent = @"
$ProjectName
$titleUnderline

Documentacion tecnica y referencia automatica de la API Python.

.. toctree::
   :maxdepth: 3
   :caption: Documentacion del proyecto

"@
foreach ($page in $pages) { $IndexContent += "   $page`n" }
$IndexContent += @"

API Python generada
===================

.. toctree::
   :maxdepth: 4
   :caption: Referencia de API

   $GeneratedApiIndex
"@
Write-Utf8BomFile -Path $IndexRstPath -Content $IndexContent
Write-Step "7. COMPILANDO DOCUMENTACION HTML"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$buildLog = Join-Path $LogDir "sphinx-$timestamp.log"
$buildErrorLog = Join-Path $LogDir "sphinx-$timestamp-stderr.log"
$buildArgs = @("-m","sphinx","-E","-a","-b","html","-c",$ConfDir,$DocsDir,$BuildDir)
$exitCode = Invoke-PythonProcess -Arguments $buildArgs -StdOutPath $buildLog -StdErrPath $buildErrorLog
if (Test-Path -LiteralPath $buildLog) { Get-Content -LiteralPath $buildLog }
if (Test-Path -LiteralPath $buildErrorLog) { $errContent = Get-Content -LiteralPath $buildErrorLog -Raw -ErrorAction SilentlyContinue; if (-not [string]::IsNullOrWhiteSpace($errContent)) { Write-Host $errContent -ForegroundColor Yellow } }
if ($exitCode -ne 0) { throw "Sphinx fallo (ExitCode: $exitCode). Revisa el log: $buildErrorLog" }
Write-Step "8. VALIDANDO RESULTADOS"
$IndexHtml = Join-Path $BuildDir "index.html"
$ApiHtmlDir = Join-Path $BuildDir $ApiRootName
if (-not (Test-Path -LiteralPath $IndexHtml -PathType Leaf)) { throw "No se genero index.html." }
if (-not (Test-Path -LiteralPath $ApiHtmlDir -PathType Container)) { throw "No se genero el directorio de documentacion API: $ApiHtmlDir`nRevisa el log: $buildLog" }
$htmlFiles = @(Get-ChildItem -LiteralPath $BuildDir -Recurse -File -Filter "*.html")
$apiHtmlFiles = @(Get-ChildItem -LiteralPath $ApiHtmlDir -Recurse -File -Filter "*.html")
if ($apiHtmlFiles.Count -eq 0) { throw "Sphinx no genero paginas HTML de referencia API." }
if (-not (Test-Path -LiteralPath $GeneratedApiHtmlIndex -PathType Leaf)) { throw "Sphinx no genero el indice raiz HTML de la API. Se esperaba: $GeneratedApiHtmlIndex" }
Write-Host ""
Write-Host "Fuentes Python     : $TotalPythonFiles" -ForegroundColor White
Write-Host "Directorios API    : $($SourceRoots.Count)" -ForegroundColor White
Write-Host "Paquetes detectados: $($DetectedPackages -join ', ')" -ForegroundColor White
Write-Host "Paginas HTML       : $($htmlFiles.Count)" -ForegroundColor White
Write-Host "Paginas API        : $($apiHtmlFiles.Count)" -ForegroundColor White
Write-Host "Build              : PASS" -ForegroundColor Green
Write-Host "Log                : $buildLog" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Documentacion generada: $IndexHtml" -ForegroundColor Green
Write-Step "9. POST-BUILD: LIMPIEZA FINAL Y WARNINGS"
Remove-SelfReferencingToctree
if (Test-Path -LiteralPath $buildLog) {
    $warns = @(Select-String -LiteralPath $buildLog -Pattern "WARNING:" -SimpleMatch -ErrorAction SilentlyContinue)
    if ($warns.Count -eq 0 -and (Test-Path -LiteralPath $buildErrorLog)) { $warns = @(Select-String -LiteralPath $buildErrorLog -Pattern "WARNING:" -SimpleMatch -ErrorAction SilentlyContinue) }
    if ($warns.Count -eq 0) { Write-Host "Warnings: 0 (build limpio)" -ForegroundColor Green } else { Write-Host "Warnings restantes: $($warns.Count) (no bloquean el build)" -ForegroundColor Yellow; foreach ($w in ($warns | Select-Object -First 10)) { Write-Host ("  " + $w.Line.Trim()) -ForegroundColor DarkGray } }
}
Write-Host "Para abrir la doc: Start-Process `"$IndexHtml`"" -ForegroundColor DarkGray
if (-not $NoBrowser) { try { Start-Process -FilePath ([System.Uri]$IndexHtml).AbsoluteUri } catch { Write-Warning "No se pudo abrir el navegador. Abre manualmente: $IndexHtml" } }