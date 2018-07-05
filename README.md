# siege-mode
An emacs minor mode to surround the region with smart delimiters
interactively.

## Lay siege to the region from all sides!
### (with the power of regular expressions)

When the region is active, all input is redirected to the minibuffer
and treated as a delimeter for the region. By default the input is
used as the left delimeter from which the right one is derived using
`siege-left-to-right-regexs'. This may be reversed by default
(`siege-default-left') or during usage via "C-c r" in the minibuffer.
If regexes are not desired they may be disabled via "C-c a" in the
minibuffer or by default (`siege-default-apply-regexs').

All changes are dynamically displayed in the buffer (see
`siege-preview-face') and may be committed by "SPC" or "Ret" in the
minibuffer.

The defaults support the obvious pairings, as well as `begin <--> end'
and `left <--> right' of LaTeX fame.

## Fancy GIF demo
Accepting donations.

