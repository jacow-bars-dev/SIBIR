# Shared helpers for Windows PowerShell 5.1 and later.
function Get-TexCode([string]$Text) {
    # Direct URL commands read their arguments verbatim: % is URL data there.
    # Match comments in the same pass so a commented-out \url cannot hide them.
    $pattern = '(?<url>(?<!\\)(?:\\\\)*\\(?:url|nolinkurl)\s*\{(?:\\[^\r\n]|[^\\{}])*\})|(?<slashes>(?<!\\)(?:\\\\)*)%[^\r\n]*'
    [regex]::Replace($Text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        if ($match.Groups['url'].Success) { return $match.Value }
        return $match.Groups['slashes'].Value
    })
}

function Replace-TexCommand([string]$Text, [string]$Pattern, [scriptblock]$Replacement) {
    $expression = '(?m)(?<comment>(?<!\\)(?:\\\\)*%[^\r\n]*)|(?<command>' + $Pattern + ')'
    [regex]::Replace($Text, $expression, [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        if ($match.Groups['comment'].Success) { return $match.Value }
        & $Replacement $match.Groups['command'].Value
    })
}

function Get-SibirPaper([string]$PaperPath) {
    $item = Get-Item -LiteralPath $PaperPath -ErrorAction Stop
    if ($item.PSIsContainer) {
        $files = @(Get-ChildItem -LiteralPath $item.FullName -File -Filter '*.tex' |
            Where-Object { $_.BaseName -notmatch '-(bibitem-extract|final-bibitems)$' })
    } else {
        if ($item.Extension -ne '.tex') { throw 'Select a .tex paper or its folder.' }
        $files = @($item)
    }
    $candidates = @($files | Where-Object {
        (Get-TexCode (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8)) -match '\\documentclass\s*(\[[^\]]*\])?\s*\{jacow\}'
    })
    if ($candidates.Count -eq 0) { throw 'No JACoW paper found. Run from the paper folder or pass its .tex path.' }
    if ($candidates.Count -gt 1) {
        throw ('Several JACoW papers found: ' + ($candidates.Name -join ', ') + '. Pass the intended .tex path to bib2items.cmd.')
    }
    $candidates[0]
}

function Assert-SibirSource([string]$Text) {
    $code = Get-TexCode $Text
    $prints = [regex]::Matches($code, '\\printbibliography\b(?:\s*\[[^\]]*\])?')
    if ($prints.Count -ne 1) {
        throw ('Expected one active \printbibliography command; found ' + $prints.Count + '. Use the JACoW biblatex/Biber template with one bibliography.')
    }
    if ($prints[0].Value -match '(?:\[|,)\s*(?:type|nottype|keyword|notkeyword|category|notcategory|filter|segment|section|check)\s*=') {
        throw 'The paper filters or subdivides its bibliography. This needs manual conversion; SIBIR cannot safely match its entries.'
    }
    if ($code -notmatch '\\addbibresource\b') { throw 'No active \addbibresource found. Check that this is the JACoW biblatex/Biber source.' }
    if ([regex]::Matches($code, '\\begin\s*\{document\}').Count -ne 1) { throw 'Expected one \begin{document}. Check the selected main paper.' }
    if ($code -match '\\begin\s*\{thebibliography\}') { throw 'The paper already contains a static bibliography. Check that you selected the original biblatex paper.' }
}
