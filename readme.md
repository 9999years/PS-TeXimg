# PS-TeXimg

PS-TeXimg is a PowerShell module that exports a cmdlet `TeXimg` which renders
LaTeX equation and saves them as images / copies them to the clipboard.

PS-TeXimg requires `pdflatex` ([TeX][1]), `gs` ([Ghost Script][2], which may require an
alias from `gswin64c` ⇒ `gs`), and `magick` ([Image Magick][3]).

## Examples

For a trivial example, run

    teximg "\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"

Which will output (something like) this to the console:

    Rendering LaTeX
    Rendering PDF as PNG
    Trimming PNG
    Image written to `~\Pictures\Screenshots\2017-04-18T15-11-35_teximg.png in 00:00::01.616
    Image copied to clipboard

And save / copy this image:

![Quadratic formula][example-1]

## Missing / To-Do

* Documentation
* Better error-handling, particularly for LaTeX (doesn’t really output errors
  without `-Verbose`) and Image Magick (outputs to `stderr` [I think] thereby
  skipping `-Verbose` *and* error-handling methods) (also
  `GeometryDoesNotContainImage` is ignored).
* Implementation of more options (like extra preamble code) (suggestions?)
* Implementation of hashes in output filenames
* Integration of Ghost Script and Image Magick into a single binary to be
  distributed along the cmdlet (might be out of scope).

[1]: https://en.wikibooks.org/wiki/LaTeX/Installation#Distributions
[2]: https://ghostscript.com/download/
[3]: https://www.imagemagick.org/script/download.php
[example-1]: http://i.imgur.com/hAL2MHL.png
