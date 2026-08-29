# md2pdf

`md2pdf` is a small Markdown-to-PDF toolkit built around Pandoc and WeasyPrint. It merges Markdown or MDX-style documentation sources, resolves common documentation-site patterns, applies print styling, and generates a PDF with a table of contents, title metadata, optional version text, and optional code-block attachments.

DataSunrise documentation is publicly available for viewing here: [http://datasunrise.com/resources/documentation](http://datasunrise.com/resources/documentation)

Resulting PDF examples are also publicly available for download and viewing here: [https://www.datasunrise.com/documentation/](https://www.datasunrise.com/documentation/)

## Features

- Converts a single Markdown file or a directory of Markdown files to PDF.
- Sorts documentation files by numeric section prefixes before merging.
- Generates HTML with Pandoc and renders PDF output with WeasyPrint.
- Applies print-oriented styling from `styles.css` with page headers, footers, TOC styling, tables, admonitions, and code block formatting.
- Reads `release_version.txt` when the `-v` flag is used and prints the version on the title page.
- Saves intermediate HTML with the `-d` flag for debugging.
- Resolves JSX-style `export {default} from ...` chains before conversion.
- Converts common JSX inline style syntax to plain CSS for PDF rendering.
- Rewrites relative Markdown links into PDF-friendly internal anchors where possible.
- Fixes relative image paths when multiple files are merged.
- Extracts highlighted code blocks into attachment files and injects attachment links into the generated PDF HTML.
- Includes `example-ci.yml`, a sanitized GitLab CI template for MDX validation and PDF artifact builds.

## Repository Contents

```text
md2pdf/
├── md2pdf.sh             # Main conversion script
├── code_attachments.py   # Extracts code blocks and prepares PDF attachments
├── styles.css            # WeasyPrint PDF stylesheet
├── Makefile              # Local build, install, and example guide targets
├── example-ci.yml        # Sanitized GitLab CI example
├── cover.png             # Cover image used by the stylesheet/layout
├── release_version.txt   # Version string used with the -v flag
├── README.md             # Project documentation
└── .gitignore            # Local build output ignores
```

## Requirements

- Python 3.8+
- Pandoc 3.1+
- WeasyPrint 60+
- `fontconfig`
- Lato, Source Code Pro, and DejaVu fonts for the default stylesheet

The `make install` target installs system dependencies where possible and creates a local Python virtual environment for WeasyPrint.

## Quick Start

Install dependencies:

```bash
make install
```

Convert a documentation directory:

```bash
./md2pdf.sh ../resources/documentation/example-guide output/Example_Guide.pdf -s -v
```

Convert a single Markdown file:

```bash
./md2pdf.sh ./example.md output/example.pdf -s
```

Save the intermediate HTML while debugging:

```bash
./md2pdf.sh ../resources/documentation/example-guide output/Example_Guide.pdf -s -v -d
```

## Command Syntax

```bash
./md2pdf.sh INDIR OUTPUT [-s] [-v] [-d]
```

Arguments:

- `INDIR` - Input directory containing Markdown files, or a path to one `.md` file.
- `OUTPUT` - Output PDF path.

Flags:

- `-s` - Use the default `styles.css` stylesheet.
- `-v` - Add version text from `release_version.txt` to the title page.
- `-d` - Save intermediate HTML next to the output PDF.

## Makefile Targets

```bash
make help                 # Show available targets
make install              # Install Pandoc, fonts, and WeasyPrint
make check                # Check installed versions and fonts
make clean                # Remove generated output
make all                  # Convert top-level Markdown files to PDF
make guides               # Build all configured example guide targets
make guide-cli            # Build configured CLI guide example
make guide-user           # Build configured user guide example
make guide-dcc            # Build configured DCC guide example
make guide-admin-lin      # Build configured Linux admin guide example
make guide-admin-win      # Build configured Windows admin guide example
make guide-license-server # Build configured license-server guide example
make guide-restapi        # Build configured REST API guide example
make guide-release-notes  # Build configured release notes example
make guide-dspm           # Build configured DSPM guide example
```

The guide targets assume a sibling documentation tree at `../resources/documentation/...`. Adjust the paths and output names in `Makefile` for your own repository layout.

## Code Block Attachments

When Pandoc emits syntax-highlighted code blocks, `code_attachments.py` can extract those blocks into temporary files such as `code_001.py`, `code_002.sql`, or `code_003.yaml`. The generated HTML receives small language badges with attachment links, and `md2pdf.sh` passes those files to WeasyPrint with `--attachment`.

This is useful when PDFs need readable code snippets on the page and downloadable source snippets as PDF attachments.

## CI Example

`example-ci.yml` is a generic GitLab CI example. It contains:

- an MDX validation job using `@mdx-js/mdx` and `gray-matter`;
- a PDF build job using a public Python image;
- dependency installation through `apt` and `pip`;
- generated PDFs and debug HTML as CI artifacts.

It intentionally does not contain real runner tags, internal Docker images, private infrastructure endpoints, object-storage credentials, deployment keys, or release-sync automation.

## Styling

`styles.css` defines the print layout, typography, table styling, syntax highlighting, admonition rendering, title page spacing, and page header/footer behavior. It expects Lato and Source Code Pro fonts to be installed, with DejaVu available as a fallback for broad character coverage.

## Version Management

Edit `release_version.txt` to change the version displayed when using `-v`:

```bash
echo "1.2" > release_version.txt
```

The version affects the title page metadata only. It does not change the output filename.

## Troubleshooting

If `weasyprint` is not found, run:

```bash
make install
```

If fonts look wrong, check local font availability:

```bash
make check
```

If generated layout is wrong, use `-d` and inspect the intermediate HTML before the PDF render step.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
