/* ============================================================
   Markdown Reader — Application JavaScript
   Handles rendering, TOC, navigation, and Swift bridge
   ============================================================ */

// --- Application State ---
const state = {
    filePath: '',
    baseDir: '',
    rawMarkdown: '',
    isSourceView: false,
    siblingFiles: [],
    siblingDir: ''
};

// --- Font presets ---
const fontPresets = {
    serif:  "'New York', 'Iowan Old Style', Georgia, 'AppleMyungjo', 'Noto Serif KR', serif",
    sans:   "-apple-system, BlinkMacSystemFont, 'Apple SD Gothic Neo', 'Pretendard', sans-serif",
    system: "-apple-system, BlinkMacSystemFont, 'Apple SD Gothic Neo', sans-serif",
    mono:   "'SF Mono', Menlo, Consolas, 'JetBrains Mono', monospace"
};

// --- Width presets (px or 'none') ---
const widthPresets = { narrow: '600px', standard: '720px', wide: '900px', full: 'none' };

// --- Marked.js configuration ---
function initMarked() {
    if (typeof marked === 'undefined') return;

    const renderer = {
        heading({ tokens, depth }) {
            const text = this.parser.parseInline(tokens);
            const plain = text.replace(/<[^>]*>/g, '');
            const id = plain.toLowerCase()
                .replace(/[^\w\u3131-\uD79D]+/g, '-')
                .replace(/(^-|-$)/g, '');
            return '<h' + depth + ' id="' + id + '">'
                + '<a class="heading-anchor" href="#' + id + '">\u00B6</a>'
                + text + '</h' + depth + '>\n';
        },

        code({ text, lang }) {
            let highlighted = escapeHtml(text);
            const langClass = lang || '';
            if (lang && typeof hljs !== 'undefined') {
                try {
                    const result = hljs.getLanguage(lang)
                        ? hljs.highlight(text, { language: lang, ignoreIllegals: true })
                        : hljs.highlightAuto(text);
                    highlighted = result.value;
                } catch (e) { /* fallback to escaped */ }
            }
            return '<div class="code-block">'
                + '<div class="code-header">'
                + '<span class="code-lang">' + escapeHtml(langClass) + '</span>'
                + '<button class="code-copy-btn" onclick="copyCode(this)">Copy</button>'
                + '</div>'
                + '<pre><code class="hljs language-' + escapeHtml(langClass) + '">'
                + highlighted + '</code></pre></div>\n';
        },

        image({ href, title, text }) {
            let src = href || '';
            if (src && !/^(https?:\/\/|file:\/\/|data:)/.test(src)) {
                src = 'file://' + state.baseDir + '/' + src;
            }
            const t = title ? ' title="' + escapeHtml(title) + '"' : '';
            return '<img src="' + src + '" alt="' + escapeHtml(text || '') + '"'
                + t + ' class="zoomable" onclick="zoomImage(this)">';
        },

        listitem({ text, task, checked }) {
            if (task) {
                const c = checked ? ' checked' : '';
                return '<li class="task-item"><input type="checkbox"' + c + ' disabled> ' + text + '</li>\n';
            }
            return '<li>' + text + '</li>\n';
        }
    };

    marked.use({
        renderer: renderer,
        gfm: true,
        breaks: false
    });
}

// --- Initialize on load ---
initMarked();

// ============================================================
// Core rendering
// ============================================================

function render(markdown, filePath, baseDir) {
    state.rawMarkdown = markdown;
    state.filePath = filePath;
    state.baseDir = baseDir;
    state.isSourceView = false;

    // Strip YAML frontmatter
    const content = markdown.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, '');

    const html = marked.parse(content);
    document.getElementById('content').innerHTML = html;

    generateTOC();
    updateBreadcrumb(filePath);
    updateWordCount(content);
    processMermaid();
    processKatex();
    setupScrollTracking();
}

// Called on file-change auto-reload (preserves scroll position)
function reloadContent(markdown) {
    state.rawMarkdown = markdown;
    if (state.isSourceView) return; // don't reload source view

    const scrollY = window.scrollY;
    const content = markdown.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, '');
    document.getElementById('content').innerHTML = marked.parse(content);

    generateTOC();
    updateWordCount(content);
    processMermaid();
    processKatex();

    window.scrollTo(0, scrollY);
}

// ============================================================
// Table of Contents
// ============================================================

function generateTOC() {
    const headings = document.querySelectorAll('#content h1, #content h2, #content h3, #content h4, #content h5, #content h6');
    const tocList = document.getElementById('toc-list');
    tocList.innerHTML = '';

    headings.forEach(function(h) {
        const level = parseInt(h.tagName.charAt(1));
        const a = document.createElement('a');
        a.className = 'toc-h' + level;
        a.textContent = h.textContent.replace('\u00B6', '').trim();
        a.href = '#' + h.id;
        a.onclick = function(e) {
            e.preventDefault();
            h.scrollIntoView({ behavior: 'smooth', block: 'start' });
        };
        tocList.appendChild(a);
    });
}

function updateActiveTOC() {
    const headings = document.querySelectorAll('#content h1, #content h2, #content h3, #content h4, #content h5, #content h6');
    const links = document.querySelectorAll('#toc-list a');
    if (links.length === 0) return;

    let current = 0;
    const offset = 80;
    headings.forEach(function(h, i) {
        if (h.getBoundingClientRect().top <= offset) current = i;
    });

    links.forEach(function(link, i) {
        link.classList.toggle('active', i === current);
    });

    // Scroll active item into view in sidebar
    const activeLink = links[current];
    if (activeLink) {
        const sidebar = document.getElementById('toc-sidebar');
        const linkRect = activeLink.getBoundingClientRect();
        const sidebarRect = sidebar.getBoundingClientRect();
        if (linkRect.top < sidebarRect.top || linkRect.bottom > sidebarRect.bottom) {
            activeLink.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
    }
}

// ============================================================
// Sibling files
// ============================================================

function setSiblingFiles(files, dir) {
    state.siblingFiles = files;
    state.siblingDir = dir;

    const section = document.getElementById('file-list-section');
    const list = document.getElementById('file-list');
    list.innerHTML = '';

    if (files.length === 0) { section.style.display = 'none'; return; }
    section.style.display = '';

    files.forEach(function(f) {
        const a = document.createElement('a');
        a.textContent = f;
        const fullPath = dir + '/' + f;
        if (state.filePath === fullPath) a.className = 'current-file';
        a.onclick = function(e) {
            e.preventDefault();
            sendToSwift('openFile', { path: fullPath });
        };
        list.appendChild(a);
    });
}

// ============================================================
// Breadcrumb
// ============================================================

function updateBreadcrumb(filePath) {
    const bc = document.getElementById('breadcrumb');
    if (!filePath) { bc.innerHTML = ''; return; }

    const parts = filePath.split('/').filter(Boolean);
    const fileName = parts.pop();

    // Show last 3 directory components
    const dirs = parts.slice(-3);
    let html = '';

    if (parts.length > 3) {
        html += '<span class="breadcrumb-item">\u2026</span><span class="separator">/</span>';
    }

    dirs.forEach(function(dir, i) {
        const fullDir = '/' + parts.slice(0, parts.length - dirs.length + i + 1).join('/');
        html += '<a class="breadcrumb-item" onclick="sendToSwift(\'browseDirectory\',{path:\'' + escapeAttr(fullDir) + '\'})">'
            + escapeHtml(dir) + '</a><span class="separator">/</span>';
    });

    html += '<span class="breadcrumb-item current">' + escapeHtml(fileName) + '</span>';
    bc.innerHTML = html;
}

// ============================================================
// Word count & reading time
// ============================================================

function updateWordCount(text) {
    const clean = text.replace(/```[\s\S]*?```/g, '').replace(/[#*_\[\]()>`~|\\-]/g, '');
    // Count Korean characters as "words" too
    const koreanChars = (clean.match(/[\u3131-\uD79D]/g) || []).length;
    const latinWords = clean.trim().split(/\s+/).filter(function(w) { return w.length > 0; }).length;
    const totalWords = latinWords + Math.ceil(koreanChars / 3);
    const minutes = Math.max(1, Math.ceil(totalWords / 200));

    const el = document.getElementById('word-count');
    if (el) el.textContent = totalWords.toLocaleString() + ' words \u00B7 ' + minutes + ' min read';
}

// ============================================================
// Scroll tracking & progress bar
// ============================================================

let scrollDebounceTimer = null;

function setupScrollTracking() {
    window.removeEventListener('scroll', onScroll);
    window.addEventListener('scroll', onScroll, { passive: true });
}

function onScroll() {
    // Progress bar
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;
    const pct = docHeight > 0 ? (window.scrollY / docHeight) * 100 : 0;
    const bar = document.getElementById('progress-bar');
    if (bar) bar.style.width = Math.min(pct, 100) + '%';

    // Active TOC
    updateActiveTOC();

    // Save scroll position (debounced)
    clearTimeout(scrollDebounceTimer);
    scrollDebounceTimer = setTimeout(function() {
        if (state.filePath) {
            const pos = document.documentElement.scrollHeight > 0
                ? window.scrollY / document.documentElement.scrollHeight : 0;
            sendToSwift('saveScrollPosition', { position: pos });
        }
    }, 500);
}

function setScrollPosition(pos) {
    const target = pos * document.documentElement.scrollHeight;
    window.scrollTo(0, target);
}

// ============================================================
// Source view toggle
// ============================================================

function toggleSource() {
    state.isSourceView = !state.isSourceView;
    const contentEl = document.getElementById('content');

    if (state.isSourceView) {
        contentEl.innerHTML = '<pre class="source-view"><code>' + escapeHtml(state.rawMarkdown) + '</code></pre>';
    } else {
        const content = state.rawMarkdown.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, '');
        contentEl.innerHTML = marked.parse(content);
        generateTOC();
        processMermaid();
        processKatex();
    }
}

// ============================================================
// Code copy
// ============================================================

function copyCode(btn) {
    var codeEl = btn.closest('.code-block').querySelector('code');
    var text = codeEl.textContent;
    sendToSwift('copyToClipboard', { text: text });

    btn.textContent = 'Copied!';
    btn.classList.add('copied');
    setTimeout(function() {
        btn.textContent = 'Copy';
        btn.classList.remove('copied');
    }, 2000);
}

// ============================================================
// Image zoom
// ============================================================

function zoomImage(img) {
    var overlay = document.getElementById('image-overlay');
    var overlayImg = overlay.querySelector('img');
    overlayImg.src = img.src;
    overlay.classList.add('visible');
}

function closeImageOverlay() {
    document.getElementById('image-overlay').classList.remove('visible');
}

// ============================================================
// Mermaid
// ============================================================

function processMermaid() {
    if (typeof mermaid === 'undefined') return;

    var blocks = document.querySelectorAll('.code-block');
    var hasMermaid = false;

    blocks.forEach(function(block) {
        var langSpan = block.querySelector('.code-lang');
        if (langSpan && langSpan.textContent.trim().toLowerCase() === 'mermaid') {
            var code = block.querySelector('code').textContent;
            var div = document.createElement('div');
            div.className = 'mermaid';
            div.textContent = code;
            block.replaceWith(div);
            hasMermaid = true;
        }
    });

    if (hasMermaid) {
        try {
            mermaid.initialize({
                startOnLoad: false,
                theme: document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'default'
            });
            mermaid.run();
        } catch (e) { console.error('Mermaid error:', e); }
    }
}

// ============================================================
// KaTeX
// ============================================================

function processKatex() {
    if (typeof renderMathInElement === 'undefined') return;

    try {
        renderMathInElement(document.getElementById('content'), {
            delimiters: [
                { left: '$$', right: '$$', display: true },
                { left: '$', right: '$', display: false },
                { left: '\\(', right: '\\)', display: false },
                { left: '\\[', right: '\\]', display: true }
            ],
            throwOnError: false
        });
    } catch (e) { console.error('KaTeX error:', e); }
}

// ============================================================
// Settings application
// ============================================================

function applySettings(s) {
    var root = document.documentElement;

    // Theme
    if (s.theme === 'auto') {
        root.removeAttribute('data-theme');
    } else {
        root.setAttribute('data-theme', s.theme);
    }

    // Highlight.js theme
    var isDark = s.theme === 'dark' ||
        (s.theme === 'auto' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    var lightCSS = document.getElementById('hljs-light-theme');
    var darkCSS = document.getElementById('hljs-dark-theme');
    if (lightCSS) lightCSS.disabled = isDark;
    if (darkCSS) darkCSS.disabled = !isDark;

    // Font
    if (s.fontFamily && fontPresets[s.fontFamily]) {
        root.style.setProperty('--font-family', fontPresets[s.fontFamily]);
    }

    // Font size
    if (s.fontSize) {
        root.style.setProperty('--font-size', s.fontSize + 'px');
    }

    // Content width
    if (s.contentWidth && widthPresets[s.contentWidth]) {
        root.style.setProperty('--content-width', widthPresets[s.contentWidth]);
    }

    // TOC sidebar
    var sidebar = document.getElementById('toc-sidebar');
    var body = document.body;
    if (s.showTOC) {
        sidebar.classList.add('visible');
        body.classList.add('toc-visible');
    } else {
        sidebar.classList.remove('visible');
        body.classList.remove('toc-visible');
    }

    // Breadcrumb
    var bc = document.getElementById('breadcrumb');
    if (bc) bc.style.display = s.showBreadcrumb ? '' : 'none';

    // Word count
    var sb = document.getElementById('status-bar');
    if (sb) sb.style.display = s.showWordCount ? '' : 'none';

    // Progress bar
    var pb = document.getElementById('progress-bar');
    if (pb) pb.style.display = s.showProgress ? '' : 'none';
}

// ============================================================
// Welcome screen
// ============================================================

function showWelcome(recentFiles) {
    var contentEl = document.getElementById('content');
    var recentHTML = '';

    if (recentFiles && recentFiles.length > 0) {
        recentHTML = '<div class="welcome-recent"><h3>Recent Files</h3><ul>';
        recentFiles.forEach(function(f) {
            var parts = f.split('/');
            var name = parts.pop();
            var dir = parts.slice(-3).join('/');
            recentHTML += '<li><a onclick="sendToSwift(\'openFile\',{path:\''
                + escapeAttr(f) + '\'})">' + escapeHtml(name)
                + '<span class="file-path">' + escapeHtml(dir) + '</span></a></li>';
        });
        recentHTML += '</ul></div>';
    }

    contentEl.innerHTML = '<div class="welcome">'
        + '<div class="welcome-icon">MD</div>'
        + '<h1>Markdown Reader</h1>'
        + '<p>Open a Markdown file to get started</p>'
        + '<p class="welcome-hint">Double-click a .md file in Finder, or use File \u2192 Open (\u2318O)</p>'
        + recentHTML
        + '</div>';
}

// ============================================================
// Link click handling
// ============================================================

document.addEventListener('click', function(e) {
    var link = e.target.closest('a');
    if (!link) return;

    var href = link.getAttribute('href');
    if (!href) return;

    // Heading anchor — copy link
    if (link.classList.contains('heading-anchor')) {
        e.preventDefault();
        sendToSwift('copyToClipboard', { text: href });
        return;
    }

    // In-page anchor
    if (href.startsWith('#')) {
        e.preventDefault();
        var target = document.getElementById(href.substring(1));
        if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        return;
    }

    // External URL
    if (/^https?:\/\//.test(href)) {
        e.preventDefault();
        sendToSwift('openExternal', { url: href });
        return;
    }

    // Internal .md link
    if (/\.(md|markdown|mdown|mkd|mdx)$/i.test(href)) {
        e.preventDefault();
        var absPath = href.startsWith('/') ? href : state.baseDir + '/' + href;
        sendToSwift('openFile', { path: absPath });
        return;
    }
});

// ============================================================
// Keyboard shortcuts
// ============================================================

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeImageOverlay();
    }
});

// ============================================================
// System dark mode change listener
// ============================================================

if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function() {
        // Re-apply highlight.js theme
        var theme = document.documentElement.getAttribute('data-theme');
        if (!theme || theme === 'auto') {
            var isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
            var lightCSS = document.getElementById('hljs-light-theme');
            var darkCSS = document.getElementById('hljs-dark-theme');
            if (lightCSS) lightCSS.disabled = isDark;
            if (darkCSS) darkCSS.disabled = !isDark;
        }
    });
}

// ============================================================
// Helpers
// ============================================================

function escapeHtml(text) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
}

function escapeAttr(text) {
    return text.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function sendToSwift(type, data) {
    try {
        var msg = Object.assign({ type: type }, data || {});
        window.webkit.messageHandlers.app.postMessage(msg);
    } catch (e) {
        console.log('Swift bridge unavailable:', type, data);
    }
}
