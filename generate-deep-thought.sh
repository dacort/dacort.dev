#!/usr/bin/env bash
set -euo pipefail

# Generate a Deep Thought art piece using Claude Code
# Usage: ./generate-deep-thought.sh <thought-id>

THOUGHT_ID="${1:-}"
DATA_FILE="site/data/deep-thoughts.yaml"
CONTENT_DIR="site/content/deep-thoughts-by-ai"

if [[ -z "$THOUGHT_ID" ]]; then
  echo "Usage: $0 <thought-id>"
  echo ""
  echo "Available thoughts:"
  yq '.thoughts[].id' "$DATA_FILE"
  exit 1
fi

# Read thought data from YAML
TEXT=$(yq ".thoughts[] | select(.id == \"$THOUGHT_ID\") | .text" "$DATA_FILE")
DATE=$(yq ".thoughts[] | select(.id == \"$THOUGHT_ID\") | .date" "$DATA_FILE")
MOOD=$(yq ".thoughts[] | select(.id == \"$THOUGHT_ID\") | .mood" "$DATA_FILE")

if [[ -z "$TEXT" || "$TEXT" == "null" ]]; then
  echo "Error: Thought '$THOUGHT_ID' not found in $DATA_FILE"
  exit 1
fi

echo "Generating art for: $TEXT"
echo "  Date: $DATE | Mood: $MOOD"

# Create page bundle directory
BUNDLE_DIR="$CONTENT_DIR/$THOUGHT_ID"
if [[ -d "$BUNDLE_DIR" ]]; then
  read -r -p "Directory $BUNDLE_DIR already exists. Overwrite? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi
mkdir -p "$BUNDLE_DIR"

# Generate title from ID (capitalize words, replace hyphens with spaces)
TITLE=$(echo "$THOUGHT_ID" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')

# Write index.md frontmatter
cat > "$BUNDLE_DIR/index.md" << EOF
---
title: "$TITLE"
description: "$TEXT"
date: $DATE
mood: "$MOOD"
hideMeta: true
disableShare: true
---
EOF
echo "Created $BUNDLE_DIR/index.md"

# Generate the art piece via Claude Code
FORMATTED_PROMPT="Create a self-contained HTML file that is a bespoke generative art installation for this philosophical quote:

QUOTE: \"$TEXT\"
MOOD: $MOOD

Requirements:
- Single HTML file with inline CSS and JS, no external dependencies
- Dark aesthetic (background near #000 or very dark)
- Canvas-based generative art that visually interprets the quote
- The quote text should appear subtly within the art (faded, drifting, or integrated)
- Mouse/touch interaction (particles respond to cursor, elements react to movement)
- Smooth animation via requestAnimationFrame
- Web Audio API ambient sound that matches the mood (start silent, fade in gently)
  - Audio MUST only start when receiving a postMessage('start-audio') from the parent window
  - Use window.addEventListener('message', ...) to listen for this
- Keep file size under 50KB
- Must work in a sandboxed iframe (sandbox=\"allow-scripts\")
- No alert(), confirm(), or prompt() calls
- Responsive: fill the full viewport, handle resize
- The art should feel unique and crafted, not generic

Output ONLY the HTML file contents, no markdown fences, no explanation."

echo "Invoking Claude Code to generate art..."
env -u CLAUDECODE claude --print "$FORMATTED_PROMPT" > "$BUNDLE_DIR/thought.html"

# Strip markdown code fences if present
if head -1 "$BUNDLE_DIR/thought.html" | grep -q '```'; then
  sed -i '' '1{/^```/d;}' "$BUNDLE_DIR/thought.html"
  sed -i '' '${/^```/d;}' "$BUNDLE_DIR/thought.html"
fi

# Report
FILE_SIZE=$(wc -c < "$BUNDLE_DIR/thought.html" | tr -d ' ')
echo ""
echo "Generated: $BUNDLE_DIR/thought.html ($FILE_SIZE bytes)"
if [[ "$FILE_SIZE" -gt 51200 ]]; then
  echo "WARNING: File exceeds 50KB limit!"
fi
echo ""
echo "Preview: cd site && hugo server -D"
echo "  Gallery: http://localhost:1313/deep-thoughts-by-ai/"
echo "  Thought: http://localhost:1313/deep-thoughts-by-ai/$THOUGHT_ID/"
