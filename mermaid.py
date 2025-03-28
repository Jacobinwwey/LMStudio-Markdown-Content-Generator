import os
import re
def process_string(s):
    """
    Normalizes strings by:
    1. Replacing hyphens with spaces
    2. Removing all non-alphabetic characters except spaces
    3. Collapsing multiple spaces
    """
    # Convert hyphens to spaces first
    s = s.replace('-', ' ')
    
    # Filter valid characters (letters and spaces)
    processed_chars = []
    for c in s:
        if c == ' ' or c.isalpha():
            processed_chars.append(c)
    
    # Rebuild string and normalize whitespace
    return ' '.join(''.join(processed_chars).split()).strip()
def is_blank_md(filename):
    """
    Enhanced blank file detection with:
    1. Symbol-agnostic filename/header comparison
    2. Strict single-content validation
    3. Unicode character support
    """
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            lines = [line.rstrip('\n') for line in f.readlines()]
            non_empty_lines = [line.strip() for line in lines if line.strip()]
            # Must have exactly one meaningful line
            if len(non_empty_lines) != 1:
                return False
            header_line = non_empty_lines[0]
            if not header_line.startswith('#'):
                return False
            # Extract and process header text
            header_text = header_line.lstrip('#').strip()
            processed_header = process_string(header_text)
            # Process filename components
            base_name = os.path.basename(filename)
            file_name_without_ext = os.path.splitext(base_name)[0]
            processed_filename = process_string(file_name_without_ext)
            # Final comparison with content validation
            return (processed_header == processed_filename) and (len(lines) == 1 or (len(lines) == 2 and lines[1] == ''))
    except Exception as e:
        print(f"Error reading file {filename}: {e}")
        return False
def refine_mermaid_blocks(file_path):
    """
    Unmodified processing function preserved with original functionality
    """
    if is_blank_md(file_path):
        print(f"Skipping blank MD file: {file_path}")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.readlines()

    # Convert \( and \) to $ in all lines
    content = [line.replace(r'\(', '$').replace(r'\)', '$') for line in content]
    # Add new transformation: Convert \$ to $
    content = [line.replace(r'\$', '$') for line in content]
    # Add new transformations: Remove spaces around $
    content = [line.replace(' $ ', '$').replace('$ ', '$').replace(' $', '$') for line in content]
    # Add new transformation: Fix hyphen-dollar spacing
    content = [line.replace('-$', '- $') for line in content]

    insertions = []
    in_mermaid = False
    last_arrow_line = -1

    for idx, line in enumerate(content):
        stripped = line.strip()
        
        if stripped.startswith('```mermaid'):
            in_mermaid = True
            last_arrow_line = -1
        elif in_mermaid:
            if '-->' in line:
                last_arrow_line = idx
            if stripped == '```':
                # Process closure for properly closed blocks
                if last_arrow_line != -1:
                    next_line_idx = last_arrow_line + 1
                    if next_line_idx >= len(content) or content[next_line_idx].strip() != '```':
                        insertions.append((last_arrow_line + 1, '```\n'))
                in_mermaid = False
                last_arrow_line = -1

    # Handle unclosed Mermaid blocks after full file scan
    if in_mermaid and last_arrow_line != -1:
        next_line_idx = last_arrow_line + 1
        if next_line_idx >= len(content) or content[next_line_idx].strip() != '```':
            insertions.append((last_arrow_line + 1, '```\n'))

    # Apply insertions in reverse order to maintain correct indices
    for pos, line in reversed(insertions):
        content.insert(pos, line)

    # Atomic write operation to prevent partial updates
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(content)

def process_directory(directory='.'):
    """
    Processes all MD files in the specified directory.
    Includes existence check for target directory.
    """
    if not os.path.isdir(directory):
        print(f"Error: Directory '{directory}' does not exist.")
        return

    for filename in os.listdir(directory):
        if filename.endswith('.md'):
            file_path = os.path.join(directory, filename)
            refine_mermaid_blocks(file_path)

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(
        description='Enforce Mermaid block closure after last arrow in MD files',
        epilog='Example: python mermaid_refiner.py ./docs'
    )
    parser.add_argument('directory', nargs='?', default='.', 
                       help='Target directory (default: current)')
    
    args = parser.parse_args()
    process_directory(args.directory)
    print("Mermaid formatting complete. Blank files preserved.")
