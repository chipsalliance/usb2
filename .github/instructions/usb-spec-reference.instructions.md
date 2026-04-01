# USB 2.0 Specification Reference

## Source

The USB 2.0 specification (extracted from `usb_20.pdf`) lives in `../usb_spec/extracted/` relative to this repository root. It contains ~32,800 lines of markdown across 95 section files plus three index files and a figures directory.

## How to answer USB questions

### 1. Start with the indexes — never read full_spec.md

Three index files let you jump straight to the right content:

| Index | Purpose | Example query |
|-------|---------|---------------|
| `topic_index.md` | Back-of-book keyword → section numbers | `grep -i 'bit stuffing' topic_index.md` |
| `section_index.md` | Section number → file + line range | `grep '7.1.9' section_index.md` |
| `xref_index.md` | Figure / Table / Section → file:line + back-refs | `grep 'Table 8-1' xref_index.md` |

### 2. Lookup workflow

1. **Identify the topic.** Grep `topic_index.md` for keywords (case-insensitive). This returns one or more section references.
2. **Locate the file.** Grep `section_index.md` for the section number to get the filename and line range under `text/`.
3. **Read only the relevant lines.** Open `text/<filename>` and read the line range from the index. Do not read entire chapter files.
4. **For figures/tables.** Grep `xref_index.md` for the figure or table ID. The index gives the defining file, line, image filename (under `figures/`), and which files reference it.

### 3. File layout

```
../usb_spec/extracted/
├── topic_index.md        # keyword → sections
├── section_index.md      # section → file:lines
├── xref_index.md         # figures/tables → location
├── full_spec.md          # concatenated spec (use only as last resort)
├── text/                 # per-section markdown files
│   ├── ch01_introduction.md
│   ├── ch02_terms_and_abbreviations.md
│   ├── ...
│   └── 11.24_requests.md
└── figures/              # extracted PNG diagrams
    ├── index.md
    └── fig_*.png
```

### 4. Rules

- **Cite your source.** Always include the section number (e.g., §7.1.9) and, where applicable, the figure/table ID when answering.
- **Stay faithful to the spec text.** Quote or closely paraphrase; do not invent requirements.
- **Prefer narrow reads.** Use the line ranges from the index rather than scanning whole files.
- **Chain lookups when needed.** A topic-index hit may reference multiple sections — check each one for the most relevant detail.
- **Use `ch02_terms_and_abbreviations.md`** to resolve acronyms or definitions before guessing.
