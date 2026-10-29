param([string]$PaperPath = '.')
$ErrorActionPreference = 'Stop'
$stagedPackage = $null

function Invoke-SibirLuaLatex([string]$TexFile, [string]$PassName) {
    # Windows PowerShell turns redirected native stderr into error records.
    # Keep streaming the compiler output, then diagnose its actual exit status.
    $ErrorActionPreference = 'Continue'
    $compilerOutput = New-Object 'System.Collections.Generic.List[string]'
    & lualatex -interaction=nonstopmode -halt-on-error $TexFile 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $compilerOutput.Add($line)
        Write-Host $line
    }
    $compilerStatus = $LASTEXITCODE
    if ($compilerStatus -ne 0) {
        if (($compilerOutput -join "`n") -match 'file name database is damaged') {
            throw "$PassName failed. MiKTeX reports a damaged file name database/cache; this is a TeX installation error and may occur before a paper log is created. Close other TeX programs and run: miktex fndb refresh. If the error persists, rebuild the database with: miktex fndb remove, then miktex fndb refresh."
        }
        $logName = [IO.Path]::GetFileNameWithoutExtension($TexFile) + '.log'
        throw "$PassName failed. Inspect $logName and the compiler output above for the cause."
    }
}

try {
    . (Join-Path $PSScriptRoot 'Sibir.Common.ps1')
    $tex = Get-SibirPaper $PaperPath
    Set-Location -LiteralPath $tex.DirectoryName
    Write-Host ('Paper: ' + $tex.FullName)
    $text = Get-Content -LiteralPath $tex.FullName -Raw -Encoding UTF8
    Assert-SibirSource $text

    $installedPackage = Join-Path $PSScriptRoot 'jacowbibextract.sty'
    if (!(Test-Path -LiteralPath $installedPackage)) {
        throw 'SIBIR installation is missing jacowbibextract.sty. Restore it beside the scripts.'
    }
    foreach ($command in @('lualatex', 'biber')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "$command was not found on PATH. Check the editor computer's TeX installation."
        }
    }
    # Keep TeX's search settings exactly as the editor configured them.
    # TeX finds a temporary local package just as in the original workflow.
    $localPackage = Join-Path $tex.DirectoryName 'jacowbibextract.sty'
    if (!(Test-Path -LiteralPath $localPackage)) {
        Copy-Item -LiteralPath $installedPackage -Destination $localPackage -ErrorAction Stop
        $stagedPackage = $localPackage
    } elseif ((Get-FileHash -LiteralPath $installedPackage).Hash -ne (Get-FileHash -LiteralPath $localPackage).Hash) {
        Write-Warning 'Using the paper folder''s existing jacowbibextract.sty. It differs from the installed SIBIR package.'
    }
    $outBase = $tex.BaseName + '-bibitem-extract'
    $outTex = $outBase + '.tex'
    $outPdf = $outBase + '.pdf'

    $text = Replace-TexCommand $text '\\documentclass\s*(\[[^\]]*\])?\s*\{jacow\}' {
        param($command)
        # JACoW templates put comments inside the multiline option list.
        # Preserve the working declaration when biblatex is already active.
        $options = @([regex]::Match((Get-TexCode $command), '\[([^\]]*)\]').Groups[1].Value -split ',' |
            ForEach-Object { $_.Trim() } | Where-Object { $_ })
        if ($options -contains 'biblatex') { return $command }
        $options += 'biblatex'
        '\documentclass[' + ($options -join ',') + ']{jacow}'
    }
    if ((Get-TexCode $text) -match '\\usepackage(?:\s*\[[^\]]*\])?\s*\{[^}]*\bjacowbibextract\b') {
        throw 'The original paper already loads jacowbibextract. Select an unmodified source paper.'
    }
    $text = Replace-TexCommand $text '\\begin\s*\{document\}' {
        param($command)
        "\usepackage{jacowbibextract}`r`n$command"
    }
    $text = Replace-TexCommand $text '\\printbibliography\b(?:\s*\[[^\]]*\])?' {
        param($command)
        "$command`r`n\printbibitembibliography"
    }
    Set-Content -LiteralPath $outTex -Value $text -Encoding UTF8

    Invoke-SibirLuaLatex $outTex 'First LuaLaTeX pass'
    & biber $outBase
    if ($LASTEXITCODE -ne 0) { throw "Biber failed. Inspect $outBase.blg for missing databases or invalid bibliography entries." }
    foreach ($pass in 2..3) {
        Invoke-SibirLuaLatex $outTex "LuaLaTeX pass $pass"
    }
    if (!(Test-Path -LiteralPath $outPdf)) { throw 'No extraction PDF was generated. Do not continue with old clipboard contents.' }

    $warnings = @(foreach ($log in @("$outBase.log", "$outBase.blg")) {
        if (Test-Path -LiteralPath $log) {
            Select-String -LiteralPath $log -Pattern '(?i)warning|undefined|missing character' | ForEach-Object { $_.Line.Trim() }
        }
    })
    if ($warnings.Count -gt 0) {
        Write-Warning ('The paper or bibliography has compilation warnings. Review the PDF and retained .log/.blg files:' + [Environment]::NewLine + ($warnings -join [Environment]::NewLine))
    }
    Write-Host 'Opening the PDF. Copy ONLY the extraction block, from \begin{thebibliography}{...} through \end{thebibliography}, including both lines.'
    Write-Host 'Review all extracted references before returning to the command window. Extraction files are retained for troubleshooting.'
    Invoke-Item -LiteralPath $outPdf
}
catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    if ($outBase -and (Test-Path -LiteralPath ($outBase + '.log'))) {
        $logText = Get-Content -LiteralPath ($outBase + '.log') -Raw
        if ($logText.Contains("Unknown option ``zerostyle=d'")) {
            Write-Host 'TeX could not enable newtxtt''s dotted-zero option. That option requires xkeyval.sty. Check the active MiKTeX package tree and xkeyval installation; SIBIR leaves TeX search settings unchanged.' -ForegroundColor Yellow
        }
    }
    exit 1
}
finally {
    # Never remove or overwrite a package that was already in the paper folder.
    if ($stagedPackage) { Remove-Item -LiteralPath $stagedPackage -Force -ErrorAction SilentlyContinue }
}
