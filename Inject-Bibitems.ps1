param([string]$PaperPath = '.')
$ErrorActionPreference = 'Stop'

try {
    . (Join-Path $PSScriptRoot 'Sibir.Common.ps1')
    $tex = Get-SibirPaper $PaperPath
    $text = Get-Content -LiteralPath $tex.FullName -Raw -Encoding UTF8
    Assert-SibirSource $text
    $bibitems = Get-Clipboard -Raw
    if ([string]::IsNullOrWhiteSpace($bibitems)) { throw 'Clipboard is empty. Copy the complete extraction block from Adobe Acrobat.' }
    $bibitems = $bibitems.Trim()
    if ($bibitems -notmatch '\A\\begin\{thebibliography\}\{[0-9]+\}[\s\S]*\\end\{thebibliography\}\z') {
        throw 'Incomplete or extra copied text. Copy ONLY from \begin{thebibliography}{...} through \end{thebibliography}, including both lines and all pages. Do not copy the heading.'
    }
    $code = Get-TexCode $bibitems
    if ($code -ne $bibitems) {
        throw 'Copied bibliography contains an unescaped percent sign (%) outside a URL command, which would comment out reference text. Use \% for a literal percent sign in prose. Percent signs inside \url{...} and \nolinkurl{...} are accepted.'
    }
    if ([regex]::Matches($code, '\\(?:begin|end)\{thebibliography\}').Count -ne 2) {
        throw 'Several bibliography blocks were copied. Copy exactly one complete extraction block.'
    }
    $entries = [regex]::Matches($code, '\\bibitem\s*(?:\[[^\]]*\]\s*)?\{([^{}\s]+)\}')
    if ($entries.Count -eq 0 -or $entries.Count -ne [regex]::Matches($code, '\\bibitem\b').Count) {
        throw 'No valid entries, or a damaged \bibitem key. Recopy the extraction block; check for line breaks inside keys.'
    }
    # Our extraction package writes its actual entry count into the width argument.
    $expectedCount = [regex]::Match($code, '\A\\begin\{thebibliography\}\{([0-9]+)\}').Groups[1].Value
    if ([int]$expectedCount -ne $entries.Count) {
        throw "The extraction header indicates $expectedCount entries, but $($entries.Count) were copied. Check for missed or duplicated pages; copy the full block from the latest extraction PDF."
    }
    $keys = @($entries | ForEach-Object { $_.Groups[1].Value })
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $key = $keys[$i]
        if (-not $seen.Add($key)) { throw "Duplicate bibliography key '$key'. Check whether a page or entry was copied twice." }
        $start = $entries[$i].Index + $entries[$i].Length
        $end = $code.LastIndexOf('\end{thebibliography}', [StringComparison]::Ordinal)
        if ($i + 1 -lt $entries.Count) { $end = $entries[$i + 1].Index }
        if ([string]::IsNullOrWhiteSpace($code.Substring($start, $end - $start))) {
            throw "Entry '$key' has no reference text. Recopy the complete entry and check the paper's bibliography data."
        }
    }
    $depth = 0
    foreach ($brace in [regex]::Matches($code, '(?<!\\)(?:\\\\)*([{}])')) {
        if ($brace.Groups[1].Value -eq '{') { $depth++ } else { $depth-- }
        if ($depth -lt 0) { throw 'Copied bibliography has unbalanced braces. Recopy it and inspect the affected entry.' }
    }
    if ($depth -ne 0) { throw 'Copied bibliography has unbalanced braces. Recopy it and inspect the affected entry.' }

    $sourceCode = Get-TexCode $text
    $missing = @()
    foreach ($citation in [regex]::Matches($sourceCode, '\\(?:[A-Za-z]*cite[A-Za-z]*|nocite)\*?(?:\s*\[[^\]]*\]){0,2}\s*\{([^{}]+)\}')) {
        foreach ($key in ($citation.Groups[1].Value -split ',')) {
            $key = $key.Trim()
            if ($key -ne '*' -and -not $seen.Contains($key)) { $missing += $key }
        }
    }
    if ($missing.Count -gt 0) {
        throw ('Copied bibliography is missing cited keys: ' + (($missing | Select-Object -Unique) -join ', ') + '. Check for missed pages, the wrong PDF, or unresolved citations in the paper.')
    }
    if ($sourceCode -match '\\(?:[A-Za-z]*cite[A-Za-z]*)\b' -and
        $sourceCode -match '\\(?:parencite|textcite|autocite|footcite|smartcite|supercite|fullcite|citeauthor|citetitle|citeyear|cites)\b') {
        Write-Warning 'The paper uses biblatex-specific citation commands. Review these commands in the final source; they may need conversion to \cite for a static bibliography.'
    }
    if ($sourceCode -match '\\usepackage(?:\s*\[[^\]]*\])?\s*\{[^}]*\bbiblatex\b') {
        Write-Warning 'The paper explicitly loads biblatex. Review and remove that package and any dependent bibliography setup in the final source before compiling.'
    }

    # Apply only to prose, leaving braced arguments (URLs, DOIs, keys, etc.) alone.
    $months = '(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\.?'
    $spacing = [regex]('(?i)(?<![\w\\])((?:n|no|nos|v|vol|vols|p|pp|ch|chap|sec|secs|fig|figs|eq|eqs)\.|' + $months + ')[\s\u00A0]+(?=[0-9])')
    $changes = 0
    $depth = 0
    $segments = [regex]::Split($bibitems, '((?<!\\)(?:\\\\)*[{}])')
    for ($i = 0; $i -lt $segments.Count; $i++) {
        if ($i % 2 -eq 1) {
            if ($segments[$i].EndsWith('{')) { $depth++ } else { $depth-- }
        } elseif ($depth -eq 0) {
            $changes += $spacing.Matches($segments[$i]).Count
            $segments[$i] = $spacing.Replace($segments[$i], '${1}~')
        }
    }
    $bibitems = $segments -join ''

    # Put each key on its own line, with a blank line between entries. Keep
    # copied line breaks and indent every nonempty reference line consistently.
    $formatted = New-Object 'System.Collections.Generic.List[string]'
    $formatted.Add('\begin{thebibliography}{' + $expectedCount + '}')
    $formattedEntries = [regex]::Matches($bibitems, '\\bibitem\s*(?:\[[^\]]*\]\s*)?\{([^{}\s]+)\}')
    for ($i = 0; $i -lt $formattedEntries.Count; $i++) {
        $entry = $formattedEntries[$i]
        $start = $entry.Index + $entry.Length
        $end = $bibitems.LastIndexOf('\end{thebibliography}', [StringComparison]::Ordinal)
        if ($i + 1 -lt $formattedEntries.Count) { $end = $formattedEntries[$i + 1].Index }
        $body = $bibitems.Substring($start, $end - $start).Trim()
        $formatted.Add('')
		$formatted.Add('%[' + ($i + 1) + ']')
        $formatted.Add($entry.Value)
        foreach ($line in [regex]::Split($body, '\r\n|\n|\r')) {
            if ($line.Trim().Length -gt 0) {
                $formatted.Add('  ' + $line.TrimStart())
            } else {
                $formatted.Add('')
            }
        }
    }
    $formatted.Add('')
    $formatted.Add('\end{thebibliography}')
    $bibitems = $formatted -join "`r`n"

    $text = Replace-TexCommand $text '\\documentclass\s*(\[[^\]]*\])?\s*\{jacow\}' {
        param($command)
        $options = @([regex]::Match((Get-TexCode $command), '\[([^\]]*)\]').Groups[1].Value -split ',' |
            ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne 'biblatex' })
        if ($options.Count -gt 0) { '\documentclass[' + ($options -join ',') + ']{jacow}' }
        else { '\documentclass{jacow}' }
    }
    $text = Replace-TexCommand $text '\\addbibresource\b(?:\s*\[[^\]]*\])?\s*\{[^}]*\}' { param($command) '' }
    # Match biblatex's default punctuation breakpoints, without its optional
    # letter/digit breaks. The environment keeps this setup local to references,
    # including when the author's preamble already loads xurl.
    $urlSetup = @'
% SIBIR: bibliography URL breaks at punctuation, following biblatex's defaults.
\AddToHook{env/thebibliography/begin}{%
  \Urlmuskip=0mu plus 3mu\relax
  \mathchardef\UrlBigBreakPenalty=100\relax
  \mathchardef\UrlBreakPenalty=200\relax
  \def\UrlBigBreaks{\do\:\do\-}%
  \def\UrlBreaks{%
    \do\.\do\@\do\/\do\\\do\!\do\_\do\|\do\;\do\>\do\]\do\)\do\}%
    \do\,\do\?\do\'\do\+\do\=\do\#\do\$\do\&\do\*\do\^\do\"}%
}
'@
    $text = Replace-TexCommand $text '\\begin\s*\{document\}' {
        param($command)
        $urlSetup + "`r`n" + $command
    }
    $text = Replace-TexCommand $text '\\printbibliography\b(?:\s*\[[^\]]*\])?' { param($command) $bibitems }
    $out = Join-Path $tex.DirectoryName ($tex.BaseName + '-final-bibitems.tex')
    if (Test-Path -LiteralPath $out) { Write-Warning "Replacing previous output: $out" }
    Set-Content -LiteralPath $out -Value $text -Encoding UTF8
    Write-Host "Created: $out"
    Write-Host ("Checked $($entries.Count) bibliography entries; added $changes nonbreaking spaces.")
    Write-Host 'Compile the final paper and check citations, reference text, and line breaks. Citations in included files or custom macros are not checked by this script.'
}
catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
