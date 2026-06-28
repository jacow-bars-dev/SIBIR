$ErrorActionPreference = 'Stop'

function Fail($Message) {
    throw $Message
}

try {
    $workDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($workDir)) {
        $workDir = Get-Location
    }
    Set-Location -LiteralPath $workDir

    Write-Host 'JACoW bibitem extraction tool'
    Write-Host ('Working folder: ' + (Get-Location).Path)
    Write-Host ''

    if (!(Test-Path -LiteralPath '.\jacowbibextract.sty')) {
        Fail 'Missing jacowbibextract.sty in this folder.'
    }

    foreach ($cmd in @('lualatex', 'biber')) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            Fail "$cmd was not found on PATH. Please check your TeX installation."
        }
    }

    $texFiles = Get-ChildItem -File -Filter '*.tex' |
        Where-Object { $_.BaseName -notmatch '-bibitem-extract$' }

    $candidates = @()
    foreach ($f in $texFiles) {
        $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        if ($content -match '\\documentclass\s*(\[[\s\S]*?\])?\s*\{jacow\}') {
            $candidates += $f
        }
    }

    if ($candidates.Count -eq 0) {
        Fail 'No JAcoW .tex file found.'
    }

    if ($candidates.Count -gt 1) {
        $names = ($candidates | ForEach-Object { '  ' + $_.Name }) -join [Environment]::NewLine
        Fail ("More than one JAcoW .tex file found:" + [Environment]::NewLine + $names)
    }

    $tex = $candidates[0]
    $name = [System.IO.Path]::GetFileNameWithoutExtension($tex.Name)
    $outBase = $name + '-bibitem-extract'
    $outTex = $outBase + '.tex'
    $outPdf = $outBase + '.pdf'

    Write-Host ('Using source: ' + $tex.Name)
    Write-Host ('Temporary TeX: ' + $outTex)

    Copy-Item -LiteralPath $tex.FullName -Destination $outTex -Force
    $text = Get-Content -LiteralPath $outTex -Raw -Encoding UTF8

    if ($text -notmatch '\\documentclass\s*\[[\s\S]*?\bbiblatex\b[\s\S]*?\]\s*\{jacow\}') {
        $text = [regex]::Replace(
            $text,
            '\\documentclass\s*(\[[\s\S]*?\])?\s*\{jacow\}',
            {
                param($m)
                if ($m.Groups[1].Success -and $m.Groups[1].Value.Trim().Length -gt 0) {
                    $opts = $m.Groups[1].Value.Trim('[', ']').Trim()
                    if ($opts.Length -gt 0) {
                        "\documentclass[$opts,biblatex]{jacow}"
                    } else {
                        '\documentclass[biblatex]{jacow}'
                    }
                } else {
                    '\documentclass[biblatex]{jacow}'
                }
            },
            1
        )
    }

    if ($text -notmatch '\\usepackage\s*\{jacowbibextract\}') {
        $text = [regex]::Replace(
            $text,
            '\\begin\{document\}',
            "\usepackage{jacowbibextract}`r`n`r`n\begin{document}",
            1
        )
    }

    if ($text -match '\\printbibliography') {
        $text = [regex]::Replace(
            $text,
            '(\\printbibliography(?:\s*\[[^\]]*\])?)',
            "`$1`r`n`r`n\printbibitembibliography",
            1
        )
    } else {
        Fail 'No \printbibliography command found. This script is intended for the JACoW BibLaTeX template/workflow.'
    }

    Set-Content -LiteralPath $outTex -Value $text -Encoding UTF8

    Write-Host ''
    Write-Host 'Running latex...'
    & lualatex -interaction=nonstopmode -halt-on-error $outtex
    if ($LASTEXITCODE -ne 0) { throw "lualatex failed on first pass." }

    & biber $outbase
    if ($LASTEXITCODE -ne 0) { throw "biber failed." }

    & lualatex -interaction=nonstopmode -halt-on-error $outtex
    if ($LASTEXITCODE -ne 0) { throw "lualatex failed on second pass." }

    & lualatex -interaction=nonstopmode -halt-on-error $outtex
    if ($LASTEXITCODE -ne 0) { throw "lualatex failed on third pass." }
    if (!(Test-Path -LiteralPath $outPdf)) {
        Fail 'PDF was not generated.'
    }

    Write-Host ''
    Write-Host 'Cleaning temporary extraction files...'

    Get-ChildItem -File | Where-Object {
       $_.Name -like "$outBase.*" -and $_.Name -ne "$outbase.pdf"
    } | Remove-Item -Force -ErrorAction SilentlyContinue

    Remove-Item -LiteralPath $outTex -Force -ErrorAction SilentlyContinue

    Write-Host ''
    Write-Host ('Done. Kept only: ' + $outPdf)
    #Start-Process -FilePath $outPdf
    Invoke-Item $outPdf}
catch {
    Write-Host ''
    Write-Host 'ERROR:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
