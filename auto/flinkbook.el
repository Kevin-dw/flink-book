(TeX-add-style-hook
 "flinkbook"
 (lambda ()
   (TeX-add-to-alist 'LaTeX-provided-class-options
                     '(("elegantbook" "cn" "11pt" "chinese")))
   (TeX-run-style-hooks
    "latex2e"
    "elegantbook"
    "elegantbook11"
    "tikz"
    "epigraph"
    "array")
   (TeX-add-symbols
    '("ccr" 1)))
 :latex)

