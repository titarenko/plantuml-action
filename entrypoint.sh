#!/bin/bash

set -e

# Change to GitHub workspace if running in GitHub Actions
if [ -n "$GITHUB_WORKSPACE" ]; then
    cd "$GITHUB_WORKSPACE"
fi

SOURCE_PATH="${1:-.}"
FORMAT="${2:-svg}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get PlantUML version from pre-installed jar
PLANTUML_VERSION=$(cat /opt/plantuml_version.txt 2>/dev/null || echo "unknown")

echo "🔍 PlantUML Diagram Generator"
echo "================================"
echo "Source path: $SOURCE_PATH"
echo "Format: $FORMAT"
echo "Mode: Changed files only"
echo "PlantUML version: $PLANTUML_VERSION"
echo ""

# Counter for generated diagrams
diagram_count=0
diagram_paths=""

# Function to generate diagrams based on format
generate_diagram() {
    local content="$1"
    local output_file="$2"
    
    local generated_files=()
    
    if [[ "$FORMAT" == "svg" || "$FORMAT" == "both" ]]; then
        echo "$content" | plantuml -tsvg -pipe > "${output_file}.svg"
        generated_files+=("${output_file}.svg")
    fi
    
    if [[ "$FORMAT" == "png" || "$FORMAT" == "both" ]]; then
        echo "$content" | plantuml -tpng -pipe > "${output_file}.png"
        generated_files+=("${output_file}.png")
    fi
    
    echo -e "  ${GREEN}✓${NC} Generated: ${generated_files[*]}"
    
    for file in "${generated_files[@]}"; do
        diagram_paths="${diagram_paths}${file},"
        diagram_count=$((diagram_count + 1))
    done
}

# Function to extract and render PlantUML diagrams from markdown
process_markdown_file() {
    local md_file="$1"
    local relative_path="${md_file#./}"
    local base_name=$(basename "$md_file" .md)
    local dir_name=$(dirname "$md_file")
    
    echo -e "${YELLOW}Processing:${NC} $relative_path"
    
    # Extract PlantUML code blocks
    local in_plantuml=0
    local block_count=0
    local current_block=""
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Check for PlantUML code block start
        if [[ "$line" =~ ^\`\`\`(plantuml|puml) ]]; then
            in_plantuml=1
            block_count=$((block_count + 1))
            current_block=""
            continue
        fi
        
        # Check for code block end
        if [[ "$line" =~ ^\`\`\`$ ]] && [ $in_plantuml -eq 1 ]; then
            in_plantuml=0
            
            # Generate diagram filename in same directory as markdown file
            if [ $block_count -eq 1 ]; then
                output_file="$dir_name/${base_name}"
            else
                output_file="$dir_name/${base_name}_${block_count}"
            fi
            
            # Generate diagram(s)
            generate_diagram "$current_block" "$output_file"
            
            current_block=""
            continue
        fi
        
        # Accumulate PlantUML code
        if [ $in_plantuml -eq 1 ]; then
            current_block="${current_block}${line}"$'\n'
        fi
    done < "$md_file"
    
    if [ $block_count -gt 0 ]; then
        echo -e "  Found $block_count PlantUML block(s)"
    fi
}

# Function to process standalone PlantUML files
process_plantuml_file() {
    local puml_file="$1"
    local relative_path="${puml_file#./}"
    local base_name=$(basename "$puml_file")
    local file_without_ext="${base_name%.*}"
    local dir_name=$(dirname "$puml_file")
    local output_file="$dir_name/${file_without_ext}"
    
    echo -e "${YELLOW}Processing:${NC} $relative_path"
    
    # Generate diagram(s)
    generate_diagram "$(cat "$puml_file")" "$output_file"
}

# Get list of changed files from git
if [ -d ".git" ]; then
    changed_files=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")
else
    changed_files=""
fi

# Process markdown files
if [ -z "$changed_files" ]; then
    echo "No git repository found, searching for all markdown files in $SOURCE_PATH"
    md_files_list=$(find "$SOURCE_PATH" -type f \( -name "*.md" -o -name "*.markdown" \) 2>/dev/null)
else
    echo "Processing changed markdown files..."
    md_files_list="$changed_files"
fi
echo ""

md_files=0
while IFS= read -r file; do
    if [[ "$file" =~ \.(md|markdown)$ ]] && [ -f "$file" ]; then
        md_files=$((md_files + 1))
        process_markdown_file "$file"
        echo ""
    fi
done <<< "$md_files_list"

# Process standalone PlantUML files
if [ -z "$changed_files" ]; then
    echo "No git repository found, searching for all PlantUML files in $SOURCE_PATH"
    puml_files_list=$(find "$SOURCE_PATH" -type f \( -name "*.puml" -o -name "*.plantuml" \) 2>/dev/null)
else
    echo "Processing changed PlantUML files..."
    puml_files_list="$changed_files"
fi
echo ""

puml_files=0
while IFS= read -r file; do
    if [[ "$file" =~ \.(puml|plantuml)$ ]] && [ -f "$file" ]; then
        puml_files=$((puml_files + 1))
        process_plantuml_file "$file"
        echo ""
    fi
done <<< "$puml_files_list"

# Output results
echo "================================"
echo -e "${GREEN}Summary:${NC}"
echo "  Markdown files processed: $md_files"
echo "  PlantUML files processed: $puml_files"
echo "  Total files processed: $((md_files + puml_files))"
echo "  Diagrams generated: $diagram_count"
echo ""

# Remove trailing comma from diagram_paths
diagram_paths="${diagram_paths%,}"

# Set GitHub Actions outputs
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "diagrams-generated=$diagram_count" >> "$GITHUB_OUTPUT"
    echo "diagram-paths=$diagram_paths" >> "$GITHUB_OUTPUT"
fi

if [ $diagram_count -eq 0 ]; then
    echo -e "${YELLOW}⚠ No PlantUML diagrams found in markdown files${NC}"
else
    echo -e "${GREEN}✓ Successfully generated $diagram_count diagram(s)${NC}"
fi
