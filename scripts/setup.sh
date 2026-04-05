#!/bin/bash
# Download vendor JS/CSS libraries into Resources/vendor/
set -e
cd "$(dirname "$0")/.."

VENDOR="Resources/vendor"
mkdir -p "$VENDOR"

echo "==> Downloading marked.js ..."
curl -sL "https://cdn.jsdelivr.net/npm/marked@15.0.4/marked.min.js" -o "$VENDOR/marked.min.js"

echo "==> Downloading highlight.js ..."
curl -sL "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/highlight.min.js" -o "$VENDOR/highlight.min.js"
curl -sL "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/atom-one-light.min.css" -o "$VENDOR/hljs-light.css"
curl -sL "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/atom-one-dark.min.css" -o "$VENDOR/hljs-dark.css"

echo "==> Downloading mermaid.js ..."
curl -sL "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.min.js" -o "$VENDOR/mermaid.min.js"

echo "==> Downloading KaTeX ..."
curl -sL "https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.js" -o "$VENDOR/katex.min.js"
curl -sL "https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/katex.min.css" -o "$VENDOR/katex.min.css"
curl -sL "https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/contrib/auto-render.min.js" -o "$VENDOR/auto-render.min.js"

# KaTeX fonts
mkdir -p "$VENDOR/fonts"
echo "==> Downloading KaTeX fonts ..."
KATEX_FONTS="KaTeX_Main-Regular KaTeX_Main-Bold KaTeX_Main-Italic KaTeX_Main-BoldItalic KaTeX_Math-Italic KaTeX_Math-BoldItalic KaTeX_Size1-Regular KaTeX_Size2-Regular KaTeX_Size3-Regular KaTeX_Size4-Regular KaTeX_AMS-Regular KaTeX_Caligraphic-Regular KaTeX_Caligraphic-Bold KaTeX_Fraktur-Regular KaTeX_Fraktur-Bold KaTeX_SansSerif-Regular KaTeX_SansSerif-Bold KaTeX_SansSerif-Italic KaTeX_Script-Regular KaTeX_Typewriter-Regular"
for FONT in $KATEX_FONTS; do
    curl -sL "https://cdn.jsdelivr.net/npm/katex@0.16.21/dist/fonts/${FONT}.woff2" -o "$VENDOR/fonts/${FONT}.woff2"
done

echo "==> All vendor libraries downloaded to $VENDOR/"
echo "    marked.js, highlight.js, mermaid.js, KaTeX (with fonts)"
