$ErrorActionPreference = 'Stop'


$files = Get-ChildItem -File -Filter '*.tex' |
    Where-Object {
        $_.BaseName -notmatch '-bibitem-extract$' -and
        $_.BaseName -notmatch '-final-bibitems$'
    }

$candidates = @()

foreach ($f in $files) {
    $t = Get-Content $f.FullName -Raw -Encoding UTF8
    if ($t -match '\\documentclass\s*(\[[\s\S]*?\])?\s*\{jacow\}') {
        $candidates += $f
    }
}

if ($candidates.Count -eq 0) {
    throw 'No JACoW .tex file found.'
}

if ($candidates.Count -gt 1) {
    throw "More than one JACoW .tex file found: $($candidates.Name -join ', ')"
}

$tex = $candidates[0]
$name = [IO.Path]::GetFileNameWithoutExtension($tex.Name)
$out = "$name-final-bibitems.tex"

$bibitems = Get-Clipboard -Raw

if ($bibitems -notmatch '\\bibitem') {
    throw 'Clipboard does not appear to contain \bibitem entries.'
}

$text = Get-Content $tex.FullName -Raw -Encoding UTF8

# Remove biblatex option from \documentclass[...]{jacow}
$text = [regex]::Replace(
    $text,
    '(?is)(\\documentclass\s*\[[^\]]*?)\s*,?\s*\bbiblatex\b\s*,?\s*([^\]]*\]\s*\{jacow\})',
    {
        param($m)

        $s = $m.Groups[1].Value + "," + $m.Groups[2].Value

        $s = $s -replace ',\s*,', ','
        $s = $s -replace '\[\s*,', '['
        $s = $s -replace ',\s*\]', ']'

        return $s
    },
    1
)
# Remove \addbibresource{...}
$text = [regex]::Replace(
    $text,
    '^[ \t]*\\addbibresource(?:\[[^\]]*\])?\{[^}]*\}[ \t]*\r?\n?',
    '',
    'Multiline'
)

# Replace \printbibliography[...] with clipboard bibliography
$text = [regex]::Replace(
    $text,
    '\\printbibliography(?:\s*\[[^\]]*\])?',
    $bibitems,
    1
)

Set-Content $out $text -Encoding UTF8

Write-Host "Created: $out"
