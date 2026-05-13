#!/bin/bash
# Scans Literature/inbox/ for unprocessed files and notifies Claude to process them.
# Runs as a UserPromptSubmit hook at the start of each Claude Code session.

VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INBOX="$VAULT_DIR/Literature/inbox"

FILES=$(find "$INBOX" -type f ! -name ".gitkeep" 2>/dev/null | sort)

if [ -z "$FILES" ]; then
    exit 0
fi

echo ""
echo "LITERATURE INBOX: Unprocessed files detected in Literature/inbox/"
echo ""
while IFS= read -r file; do
    BASENAME=$(basename "$file")
    EXT="${BASENAME##*.}"
    echo "  - $BASENAME"
    if [ "$EXT" = "txt" ]; then
        CONTENT=$(cat "$file" 2>/dev/null | tr -d '[:space:]')
        echo "    Content: $CONTENT"
    fi
done <<< "$FILES"
echo ""
echo "Before responding to the user's message, process each inbox file:"
echo "  - .txt files: fetch the PMID, DOI, or URL (PubMed MCP if available, WebFetch otherwise)"
echo "  - .pdf files: read the PDF directly"
echo "  - For each: fill the Literature MD template (see Literature/example-paper.md) and write to Literature/"
echo "  - After creating the MD: delete the processed file from Literature/inbox/"
echo "  - Then update Literature/INDEX.md to include the new paper"
echo ""
