#!/usr/bin/env bash
set -euo pipefail

# Parse arguments: INDIR OUTPUT [-s] [-v] [-d]
parse_arguments() {
  INDIR="${1:-.}"
  OUTPUT="${2:-output/test.pdf}"
  CSS_FILE="${3:-}"
  [[ "$CSS_FILE" =~ ^- ]] && CSS_FILE=""
  HTML_OUTPUT="NONE"
  VERSION_OVERRIDE=""
  [[ " $* " =~ " -s " ]] && CSS_FILE="$(dirname "$0")/styles.css"
  [[ " $* " =~ " -v " ]] && VERSION_OVERRIDE="AUTO"
  [[ " $* " =~ " -d " ]] && HTML_OUTPUT="${OUTPUT%.pdf}.html"
  if [[ -f "$INDIR" ]]; then
    BASE_URL="file://$(realpath "$(dirname "$INDIR")")/"
  else
    BASE_URL="file://$(realpath "$INDIR")/"
  fi
}

# Extract document title from filename or first heading in index.md
extract_title() {
  DOCUMENT_TITLE="Document"
  if [[ -f "$INDIR" ]]; then
    DOCUMENT_TITLE=$(basename "$INDIR" .md | sed 's/_/ /g; s/-/ /g')
  elif [[ -f "$INDIR/index.md" ]]; then
    DOCUMENT_TITLE=$(grep -m1 '^# ' "$INDIR/index.md" | sed 's/^# //' || echo "Document")
  else
    DOCUMENT_TITLE=$(basename "$INDIR" | sed 's/_/ /g; s/-/ /g')
  fi
}

# Read version string from release_version.txt if -v flag is set
read_version() {
  DOCUMENT_VERSION="User Documentation"
  VERSION_NUMBER=""
  [[ -z "$VERSION_OVERRIDE" ]] && return
  if [[ "$VERSION_OVERRIDE" != "AUTO" ]]; then
    VERSION_NUMBER="$VERSION_OVERRIDE"
  elif [[ -f "$(dirname "$0")/release_version.txt" ]]; then
    VERSION_NUMBER=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$(dirname "$0")/release_version.txt")
  fi
  if [[ -n "$VERSION_NUMBER" ]]; then
    DOCUMENT_VERSION="Version $VERSION_NUMBER"
  fi
}

# Find and sort markdown files by section number (e.g., 1_intro, 2_setup)
find_and_sort_files() {
  if [[ -f "$INDIR" ]]; then
    files=("$INDIR")
    echo "==> Processing single file: $(basename "$INDIR")"
    return
  fi

  local mindepth=2
  mapfile -t files < <(
    find "$INDIR" -mindepth $mindepth -type f -name '*.md' ! -name 'README.md' |
    awk '{
      orig = $0
      filename = $0
      sub(/.*\//, "", filename)

      section = ""
      temp = filename
      while (match(temp, /^[0-9]+_/)) {
        section = section substr(temp, RSTART, RLENGTH)
        temp = substr(temp, RSTART + RLENGTH)
      }
      gsub(/_$/, "", section)
      gsub(/_/, ".", section)

      sortkey = ($0 ~ /index\.md$/) ? "0." section : "1." section

      dir = $0
      gsub(/\/[^\/]+$/, "", dir)
      printf "%s\t%s\t%s\n", dir, sortkey, orig
    }' |
    LC_ALL=C sort -t$'\t' -k1,1V -k2,2V |
    cut -f3
  )

  if (( ${#files[@]} == 0 )); then
    mapfile -t files < <(find "$INDIR" -mindepth 1 -type f -name '*.md' ! -name 'README.md' ! -name 'index.md' | LC_ALL=C sort)
  fi

  (( ${#files[@]} )) || { echo "❌ no .md files in $INDIR"; exit 1; }
  echo "==> Merging ${#files[@]} files to $OUTPUT"
}

# Recursively resolve JSX export statements to actual content
resolve_export() {
  local file="$1"
  local export_line=$(grep "^export {default} from" "$file" 2>/dev/null || true)

  if [[ -n "$export_line" ]]; then
    local target_path=$(echo "$export_line" | sed "s/.*from '\(.*\)'.*/\1/")
    local target_file="$(dirname "$file")/$target_path"

    if [[ -f "$target_file" ]]; then
      resolve_export "$target_file"
    else
      cat "$file"
    fi
  else
    cat "$file"
  fi
}

# Fix relative image paths when merging files from subdirectories
fix_image_paths() {
  local rel_path=$(realpath --relative-to="$INDIR" "$(dirname "$1")")
  echo "$2" | sed "s|!\[\](\./|![]($rel_path/|g; s|!\[\([^]]*\)\](\./|![\1]($rel_path/|g; s|src=\"\./|src=\"$rel_path/|g; s|require('\./|require('$rel_path/|g; s|require(\"\./|require(\"$rel_path/|g" | \
              sed "s|!\[\](\.\./|![](|g; s|!\[\([^]]*\)\](\.\./|![\1](|g; s|src=\"\.\./|src=\"|g; s|require('\.\./|require('|g; s|require(\"\.\./|require(\"|g"
}

# Process all markdown files: resolve exports, fix paths, convert links
process_markdown() {
  for i in "${!files[@]}"; do
    (( i )) && printf '\n\n---\n\n'
    local file="${files[$i]}"
    local content
    if grep -q "^export {default} from" "$file" 2>/dev/null; then
      content=$(resolve_export "$file")
    else
      content=$(cat "$file")
    fi
    if [[ ! -f "$INDIR" ]] && echo "$content" | grep -qE '!\[.*\]\(\.\.?/|src="\.\.?/|require\(['"'"'"]\.\.?/' ; then
      content=$(fix_image_paths "$file" "$content")
    fi
    local file_dir=$(dirname "$file")
    echo "$content" | \
    sed 's/@[a-zA-Z0-9_.-]*//g' | \
    PERL_FILE_DIR="$file_dir" perl -CSD -pe '
      s/^## Table of Contents/#### Table of Contents {.unlisted}/;
      s/^(# \d+\.\s.*)$/$1 {.chapter-index}/;
      # Convert <ul><li> in pipe table rows to inline bullets
      # (pandoc strips block-level HTML from pipe table cells)
      if (/^\s*\|.*<ul>/) {
        while (s{<ul>((?:(?!<ul>|</ul>).)*)</ul>}{
          my $c = $1;
          $c =~ s{</li>\s*<li>}{<br>\x{2022} }g;
          $c =~ s{<li>}{\x{2022} }g;
          $c =~ s{</li>}{}g;
          "<br>" . $c;
        }se) {}
        s/\|\s*<br>/| /g;
      }
      s{\[([^\]]+)\]\(((?!https?://|mailto:|/|#)[^)#]+(?:\.md)?)(#[^)]+)?\)}{
        my $text = $1;
        my $path = $2;
        my $fragment = $3 || "";
        my $file_dir = $ENV{PERL_FILE_DIR};

        my $target_file = "$file_dir/$path";
        $target_file .= ".md" unless $target_file =~ /\.md$/;

        my $heading = "";
        if (open(my $fh, "<", $target_file)) {
          while (my $line = <$fh>) {
            if ($line =~ /^#\s+(.+)$/) {
              $heading = $1;
              chomp($heading);
              last;
            }
          }
          close($fh);
        }

        my $anchor = $heading || $text;
        $anchor =~ s/^[\d\.\s]+//;
        $anchor = lc($anchor);
        $anchor =~ s/[\x27\/:"()]//g;
        $anchor =~ s/[^a-z0-9._]+/-/g;
        $anchor =~ s/-+/-/g;
        $anchor =~ s/^-|-$//g;

        $fragment ? "[$text]($fragment)" : "[$text](#$anchor)"
      }ge
    '
  done
}

# Convert merged markdown to HTML5 with metadata
convert_to_html() {
  pandoc --standalone --toc --toc-depth=3 --from markdown-tex_math_dollars --to html5 \
    --metadata title="$DOCUMENT_TITLE" \
    --metadata author="$DOCUMENT_VERSION" \
    --metadata date="$(date +'%B, %Y')" \
    --resource-path="$INDIR" --wrap=none --highlight-style=pygments -o -
}

# Convert JSX inline styles to standard CSS syntax and resolve require() imports
convert_jsx_styles() {
  perl -0777 -pe '
    s/\{require\(['"'"'"]([^'"'"'"]+)['"'"'"]\)\.default\}/"$1"/g;
    s/style=\{\{([^}]+)\}\}/convert_jsx_to_css($1)/ge;
    s/<style>\{\`(.*?)\`\}<\/style>/<style>$1<\/style>/gs;

    sub convert_jsx_to_css {
      my $jsx = shift;
      my @props = split /,\s*/, $jsx;
      my @css_props;

      foreach my $prop (@props) {
        if ($prop =~ /^\s*(\w+):\s*['"'"'"]([^'"'"'"]+)['"'"'"]\s*$/) {
          my $name = $1;
          my $value = $2;
          $name =~ s/([A-Z])/-\L$1/g;
          push @css_props, "$name: $value";
        }
      }

      return "style=\"" . join("; ", @css_props) . ";\"";
    }
  '
}

# Style table of contents with hierarchy classes and remove unnumbered entries
style_toc() {
  perl -0777 -pe '
    s{<nav id="TOC"[^>]*>.*?</nav>}{
      my $toc = $&;
      $toc =~ s/<li>(<a[^>]*>)(?!\d+[\.\s]).*?<\/li>\n?//gs;
      $toc =~ s/<ul>\s*<\/ul>\n?//gs;
      $toc =~ s/\n<\/ul><\/li>\n/<\/li>\n/gs;
      $toc =~ s{<li>(<a[^>]*>)(\d+(?:\.\d+)*)(?:\.\s|\s)}{
        my $prefix = $1;
        my $num = $2;
        my $lvl = ($num =~ tr/.//) + 1;
        qq{<li class="toc-l$lvl">$prefix$num. }
      }ge;
      $toc;
    }se;
  '
}

emit_preface() {
  local file="$INDIR/../_shared/pdf_preface.txt"
  [[ -f "$file" ]] || return
  cat "$file"
  printf '\n\n---\n\n'
}

# Main execution pipeline: parse args, process markdown, generate PDF
main() {
  parse_arguments "$@"
  extract_title
  read_version
  export DOCUMENT_TITLE DOCUMENT_VERSION
  local weasy_cmd="weasyprint"
  [[ -x "$(dirname "$0")/venv/bin/weasyprint" ]] && weasy_cmd="$(dirname "$0")/venv/bin/weasyprint"
  find_and_sort_files
  # Process HTML and prepare code attachments
  local code_dir=$(mktemp -d /tmp/pdf_code_attachments.XXXXXX)
  export CODE_OUTPUT_DIR="$code_dir"

  local html_content=$({ emit_preface; process_markdown; } | convert_to_html | perl -0777 -pe 's/<style>(?!\{`).*?<\/style>//gs' | convert_jsx_styles | style_toc)

  # Prepare code attachments if Python is available
  if command -v python3 >/dev/null && [[ -f "$(dirname "$0")/code_attachments.py" ]]; then
    html_content=$(echo "$html_content" | python3 "$(dirname "$0")/code_attachments.py")
  fi

  if [[ "$HTML_OUTPUT" != "NONE" ]]; then
    mkdir -p "$(dirname "$HTML_OUTPUT")"
    echo "$html_content" > "$HTML_OUTPUT"
    echo "✅ HTML saved to $HTML_OUTPUT"
  fi

  mkdir -p "$(dirname "$OUTPUT")"

  # Build attachment arguments for weasyprint
  attachment_args=()
  if [[ -d "$code_dir" ]] && ls "$code_dir"/*.* >/dev/null 2>&1; then
    for file in "$code_dir"/*.*; do
      attachment_args+=(--attachment "$file")
    done
  fi

  if [[ -n "$CSS_FILE" ]]; then
    echo "$html_content" | "$weasy_cmd" -p -s "$CSS_FILE" - "$OUTPUT" --base-url="$BASE_URL" "${attachment_args[@]}"
  else
    echo "$html_content" | "$weasy_cmd" -p - "$OUTPUT" --base-url="$BASE_URL" "${attachment_args[@]}"
  fi

  # Clean up temporary code files
  if [[ -d "$code_dir" ]]; then
    rm -rf "$code_dir"
  fi

  echo "✅ $OUTPUT"
}

main "$@"