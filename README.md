# SIBIR: Static Injection of Bibitems Into References

SIBIR helps JACoW room editors turn a paper's biblatex/Biber bibliography into editable, static `\bibitem` references. The editor reviews the extracted references in Adobe Acrobat Pro, copies them, and reviews and compiles the resulting paper.

## Requirements

- Windows with Windows PowerShell 5.1 or later.
- A working TeX installation with `lualatex` and `biber` on PATH.
- Adobe Acrobat Pro installed as the default PDF viewer.
- A JACoW paper using the biblatex/Biber template: `\addbibresource{...}` and one `\printbibliography` command.
- The paper's `.bib` database and required JACoW files (`jacow.cls`, `jacow.cbx`, `jacow.bbx`), available in the paper folder or through the TeX installation.

Classic BibTeX sources using `\bibliographystyle` and `\bibliography`, filtered bibliographies, and multiple bibliography blocks need manual conversion. Presentation options such as `[heading=none]` are accepted.

## Install once

Keep these five files together in one permanent folder, for example `C:\Tools\SIBIR`:

- `bib2items.cmd`
- `Extract-Bibitems.ps1`
- `Inject-Bibitems.ps1`
- `Sibir.Common.ps1`
- `jacowbibextract.sty`

You do not need to copy SIBIR into each paper folder. The extraction script temporarily copies `jacowbibextract.sty` beside the paper and removes its copy when finished, including on failure. An existing local package is preserved and used. TeX search settings, including `TEXINPUTS`, are left unchanged. A class declaration that already enables biblatex is also preserved.

For a desktop drop target, also keep `Create-DesktopShortcut.cmd`, `Create-DesktopShortcut.ps1`, and the `assets` folder in that folder. Double-click `Create-DesktopShortcut.cmd` once. It creates a **SIBIR** shortcut on your Windows desktop with the custom bibliography icon in `assets/sibir-jacow.ico`. Drop one `.tex` file or paper folder onto that shortcut to run the usual workflow. Keep the SIBIR folder in place; run the installer again if you move it. Double-clicking the shortcut alone does not select a paper. The icon includes sizes from 16 to 256 pixels for different display scales. Its JACoW label and blue palette (`#0066FF` and `#5D9EFF`) identify the utility's purpose; the colors come from the [JACoW website stylesheet](https://www.jacow.org/pub/skins/Main/style.css).

## Repository files

This repository contains ten files. The five core files must stay together; the three shortcut files support the optional desktop drop target.

| File | Purpose | Needed for |
| --- | --- | --- |
| `bib2items.cmd` | Runs extraction, pauses for the editor to copy the bibliography, then runs injection. Accepts a dropped paper or folder. | Core workflow |
| `Extract-Bibitems.ps1` | Builds the extraction paper with LuaLaTeX and Biber and opens its PDF for copying. | Core workflow |
| `Inject-Bibitems.ps1` | Validates clipboard references and creates the formatted final paper with URL and spacing settings. | Core workflow |
| `Sibir.Common.ps1` | Shared paper-selection and LaTeX parsing helpers used by both PowerShell scripts. | Core workflow |
| `jacowbibextract.sty` | LaTeX package that prints the source-like bibliography block in the extraction PDF. | Core workflow |
| `Create-DesktopShortcut.cmd` | Double-clickable launcher for the shortcut installer. | Easy desktop setup |
| `Create-DesktopShortcut.ps1` | Creates the desktop shortcut with the correct target, working folder, and icon. | Desktop setup |
| `assets/sibir-jacow.ico` | Current JACoW-colored Windows shortcut icon. Keep it in place after creating the shortcut. | Custom shortcut icon |
| `README.md` | Installation instructions, workflow, limitations, and troubleshooting. | Documentation |
| `LICENSE` | License terms for redistribution. | Redistribution |

Test scripts and the icon-generation script are development tools, not runtime dependencies. They are omitted from this lean distribution, along with obsolete icons and PNG previews. No test or icon-building step is required to use SIBIR.

## Run for a paper

From a command prompt in the paper folder:

```cmd
C:\Tools\SIBIR\bib2items.cmd
```

Or pass the paper folder or a specific main `.tex` file from anywhere:

```cmd
C:\Tools\SIBIR\bib2items.cmd "C:\Papers\My Paper"
C:\Tools\SIBIR\bib2items.cmd "C:\Papers\My Paper\paper.tex"
```

You can also drag a paper folder or `.tex` file onto `bib2items.cmd`. If a folder contains several JACoW papers, pass the intended `.tex` file explicitly. A shortcut can use the paper folder as its **Start in** directory, or include the paper path in its **Target**.

## Editor workflow

1. Launch SIBIR for the paper. It compiles an extraction copy with LuaLaTeX, Biber, and two further LuaLaTeX passes. Compilation failures stop the workflow. Warnings are displayed for review.
2. Acrobat opens the extraction PDF. Review the references on the extraction pages.
3. Copy **only** the entire source-like bibliography block, from `\begin{thebibliography}{...}` through `\end{thebibliography}`, including both lines and every entry across all pages. Exclude the extraction heading and the paper's ordinary rendered references. Keep the number in the opening line unchanged: it records the extracted entry count.
4. Return to the command window and press a key. SIBIR checks the clipboard and reports specific errors before writing the final paper.
5. Review and compile `paper-final-bibitems.tex`. Check all citations, bibliography text, special characters, and line breaks before submission.

The original `.tex` file is preserved. A later successful run replaces the previous final file with a visible warning; retain a separate copy if you have edited it. Generated extraction files, including `.log` and `.blg`, remain in the paper folder for troubleshooting. Generated extraction and final papers are excluded from automatic source selection.

If copying fails validation, correct the selection and copy again. To retry only injection from the paper folder:

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Tools\SIBIR\Inject-Bibitems.ps1"
```

## What the checks catch

SIBIR stops on missing bibliography boundaries, extra copied headings, an incorrect entry count, duplicate or damaged keys, empty entries, unbalanced braces, and unescaped percent signs outside URL commands. Percent signs inside direct `\url{...}` and `\nolinkurl{...}` arguments are accepted and preserved, including `\url {https://example.org/My%20Paper.pdf}`. In ordinary reference text, write `50\%` for a literal percent sign. It also checks that keys in ordinary citation commands directly in the main paper appear in the copied bibliography. Literal `$` sequences are preserved during injection.

Errors identify likely causes: missed pages, duplicated selections, the wrong PDF, or unresolved citations in the paper. Compilation warnings are shown and retained in the extraction logs. The script warns about explicit biblatex package loading and common biblatex-specific citation commands that may require manual changes in the final source.

During injection, SIBIR removes an `http://doi.org/`, `https://doi.org/`, or legacy `dx.doi.org` resolver prefix from a literal `\doi{...}` argument. It reports each normalization with the reference number and bibliography key. It does not alter ordinary `\url{...}` values.

These checks cannot prove that every reference's text was copied correctly. Citations inside included files, custom macros, and complex multi-citation commands are not fully checked. The editor's final compilation and visual review remain essential.

## Generated source formatting and URL breaks

The final paper adds a bibliography environment hook that uses biblatex's default URL punctuation breakpoints and penalties, including breaks at hyphens and slashes. It does not enable breaks inside runs of letters or digits. This setup applies only to the static references and also overrides `xurl`'s letter/digit breakpoints there if the author's preamble loads it. SIBIR no longer adds `xurl` itself; the JACoW class already loads `url`.

Exact line endings can still differ from biblatex because the surrounding bibliography layout can differ. An exceptionally long URL segment without punctuation may still overflow; review such links manually. Existing final files created by older SIBIR versions must be regenerated to get the new setup.

Bibliography entries are separated by a blank line, with each `\bibitem` on its own line and reference text indented by two spaces:

```tex
\begin{thebibliography}{2}

\bibitem{first}
  A. Author, First reference.

\bibitem{second}
  B. Author, Second reference.

\end{thebibliography}
```

Copied line breaks are retained. Every nonempty reference line starts with two spaces, including continuation lines inside braced arguments. The extra source whitespace separates entries for editing; it does not add blank reference lines in the PDF.

## Nonbreaking spaces

During injection, SIBIR changes spaces before numeric values after common abbreviations and English month names to LaTeX nonbreaking spaces:

```tex
vol. 12, n. 3, pp. 34--38  ->  vol.~12, n.~3, pp.~34--38
v. 2, no. 4, p. 19        ->  v.~2, no.~4, p.~19
Jan. 2005, May 2017      ->  Jan.~2005, May~2017
```

Recognized abbreviations are `n.`, `no.`, `nos.`, `v.`, `vol.`, `vols.`, `p.`, `pp.`, `ch.`, `chap.`, `sec.`, `secs.`, `fig.`, `figs.`, `eq.`, and `eqs.` (case insensitive). Spaces, nonbreaking Unicode spaces, and copied line breaks before a digit are normalized. Existing `~` separators are preserved.

All twelve English month names are recognized, including abbreviated forms with or without a period (`Jan.`, `Jun`, `Sep.`, `Sept.`, etc.). The month is kept with a following year or day number, such as `January~2005` or `May~12, 2008`.

Nonbreaking-space normalization applies to unbraced bibliography prose. It does not change abbreviations inside braced text or command arguments, including keys, URLs, DOIs, and formatting commands. Leading source indentation is formatted separately as described above. Review any abbreviation and number wrapped inside formatting commands manually.

## MiKTeX database errors

If LuaLaTeX reports **The file name database is damaged**, compilation may stop before creating a paper `.log`. This is a MiKTeX database/cache error; SIBIR displays repair guidance instead of treating it as a paper syntax error. Close other TeX programs and run `miktex fndb refresh` in a command prompt. If that fails to resolve it, run `miktex fndb remove` followed by `miktex fndb refresh` to rebuild the generated file index. These are MiKTeX's database maintenance commands; they do not remove installed packages or paper sources. See the [MiKTeX database command documentation](https://docs.miktex.org/manual/miktex-fndb.html).

## Credits & license

The extraction package `jacowbibextract.sty` is based on `biblatex2bibitem` v0.2.2 by Nikolai Avdeev (@nickkolok) and @odomanov, distributed under LPPL 1.3c. Its header describes the local modifications. See `LICENSE`.
