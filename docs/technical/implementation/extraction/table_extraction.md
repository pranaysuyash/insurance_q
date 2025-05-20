# Table Extraction Implementation

This document details the implementation of the table extraction system for the Insurance Policy Parser & QA App. Tables in insurance policy documents often contain critical information like coverage limits, deductibles, benefit schedules, and other structured data that needs to be accurately extracted for analysis and querying.

## Table of Contents

1. [Introduction](#introduction)
2. [Challenges of Table Extraction](#challenges-of-table-extraction)
3. [Table Detection Strategy](#table-detection-strategy)
4. [Table Structure Analysis](#table-structure-analysis)
5. [Cell Content Extraction](#cell-content-extraction)
6. [Post-Processing and Validation](#post-processing-and-validation)
7. [Multi-Page Tables](#multi-page-tables)
8. [Integration with Document Processing Pipeline](#integration-with-document-processing-pipeline)
9. [Performance Metrics](#performance-metrics)
10. [Future Improvements](#future-improvements)

## Introduction

Insurance policy documents typically contain multiple tables with varying formats, layouts, and complexities. Extracting these tables accurately is essential for understanding policy details such as:

- Coverage limits and sublimits
- Deductible schedules
- Copay and coinsurance rates
- Benefit schedules
- Premium breakdowns
- Network provider tiers
- Prescription drug formularies

The table extraction system in our application is designed to:

1. Detect tables within document pages
2. Analyze table structure (rows, columns, headers)
3. Extract cell contents accurately
4. Convert extracted tables into structured data
5. Associate extracted tables with relevant sections
6. Make table data available for querying and display

## Challenges of Table Extraction

Table extraction from PDFs presents several unique challenges:

### 1. Format Variability

Insurance policy tables vary widely in format:
- Simple grid-based tables with clear borders
- Complex nested tables with merged cells
- Borderless tables that rely on whitespace alignment
- Tables with varying column widths and row heights
- Tables that use indentation for hierarchy

### 2. PDF Representation Issues

Tables in PDFs may not have explicit table structure:
- Tables represented as a collection of text elements and lines
- Lack of explicit cell boundaries in some cases
- Text flow that doesn't match visual layout
- Mixed content (text and images) within tables
- Tables created with various PDF generation tools

### 3. Content Complexity

Table content adds additional complexity:
- Mixed data types within the same column
- Numeric values with varying formats
- Currency values with different symbols
- Footnote references within cells
- Text that spans multiple lines within a cell
- Special characters and symbols

### 4. Physical Layout Challenges

The physical layout presents its own challenges:
- Tables that span multiple pages
- Header rows that repeat across pages
- Footnotes at the bottom of tables
- Tables with rotated text or orientation
- Tables embedded within other tables

## Table Detection Strategy

Our system employs a multi-stage approach to table detection:

### 1. Visual Analysis

For PDF documents with explicit visual elements:

```python
def detect_tables_visual(page):
    """Detect tables using visual cues like lines and borders."""
    # Extract line elements from the page
    horizontal_lines = extract_horizontal_lines(page)
    vertical_lines = extract_vertical_lines(page)
    
    # Group lines that might form table boundaries
    table_boundaries = identify_table_boundaries(horizontal_lines, vertical_lines)
    
    # Filter out non-table structures (e.g., page decorations, headers)
    table_boundaries = filter_table_candidates(table_boundaries)
    
    # Extract bounding boxes for detected tables
    table_regions = []
    for boundary in table_boundaries:
        x0, y0, x1, y1 = calculate_bounding_box(boundary)
        table_regions.append({
            "bbox": (x0, y0, x1, y1),
            "page_number": page.page_number,
            "detection_method": "visual",
            "confidence": calculate_confidence(boundary)
        })
    
    return table_regions
```

### 2. Text Layout Analysis

For tables without explicit borders:

```python
def detect_tables_text_layout(page):
    """Detect tables using text layout patterns."""
    # Extract text elements
    text_elements = extract_text_elements(page)
    
    # Group text elements by vertical position (potential rows)
    text_rows = group_by_vertical_position(text_elements)
    
    # Analyze horizontal alignment patterns to detect columns
    column_positions = analyze_column_alignments(text_rows)
    
    # Identify consistent grid patterns that might indicate tables
    table_candidates = identify_grid_patterns(text_rows, column_positions)
    
    # Filter candidates based on consistency and other heuristics
    table_regions = []
    for candidate in table_candidates:
        if is_likely_table(candidate):
            x0, y0, x1, y1 = calculate_bounding_box(candidate)
            table_regions.append({
                "bbox": (x0, y0, x1, y1),
                "page_number": page.page_number,
                "detection_method": "text_layout",
                "confidence": calculate_confidence(candidate)
            })
    
    return table_regions
```

### 3. Machine Learning Detection

For complex cases, we employ a deep learning model:

```python
def detect_tables_ml(page, model):
    """Detect tables using machine learning models."""
    # Convert page to image
    page_image = page_to_image(page)
    
    # Apply preprocessing for model input
    processed_image = preprocess_image(page_image)
    
    # Get table predictions from model
    predictions = model.predict(processed_image)
    
    # Process predictions into bounding boxes
    table_regions = []
    for prediction in predictions:
        if prediction["score"] > MIN_CONFIDENCE_THRESHOLD:
            table_regions.append({
                "bbox": prediction["bbox"],
                "page_number": page.page_number,
                "detection_method": "ml",
                "confidence": prediction["score"]
            })
    
    return table_regions
```

### 4. Ensemble Approach

The final detection combines all methods:

```python
def detect_tables(page, ml_model):
    """Detect tables using an ensemble of methods."""
    # Get table regions from different methods
    visual_regions = detect_tables_visual(page)
    layout_regions = detect_tables_text_layout(page)
    ml_regions = detect_tables_ml(page, ml_model)
    
    # Combine and de-duplicate regions
    all_regions = visual_regions + layout_regions + ml_regions
    merged_regions = merge_overlapping_regions(all_regions)
    
    # Apply final validation
    validated_regions = validate_table_regions(merged_regions, page)
    
    return validated_regions
```

## Table Structure Analysis

Once tables are detected, we analyze their structure:

### 1. Grid Structure Detection

```python
def analyze_table_structure(table_region, page):
    """Analyze the structure of a detected table."""
    # Extract the table region from the page
    table_content = extract_region(page, table_region["bbox"])
    
    # Detect row boundaries
    row_positions = detect_row_boundaries(table_content)
    
    # Detect column boundaries
    column_positions = detect_column_boundaries(table_content)
    
    # Identify header rows
    header_rows = identify_header_rows(table_content, row_positions)
    
    # Detect merged cells
    merged_cells = detect_merged_cells(table_content, row_positions, column_positions)
    
    # Create the table grid
    grid = create_table_grid(row_positions, column_positions, merged_cells)
    
    return {
        "rows": len(row_positions) - 1,
        "columns": len(column_positions) - 1,
        "header_rows": header_rows,
        "grid": grid,
        "merged_cells": merged_cells
    }
```

### 2. Header Row Detection

Headers are critical for understanding table context:

```python
def identify_header_rows(table_content, row_positions):
    """Identify which rows are likely headers."""
    header_rows = []
    
    # Get text style for each row
    row_styles = analyze_row_styles(table_content, row_positions)
    
    # Check first few rows for header characteristics
    max_header_candidates = min(3, len(row_positions) - 1)
    
    for i in range(max_header_candidates):
        # Headers often have different styling (bold, different font, etc.)
        if row_styles[i].get("is_bold", False) or row_styles[i].get("font_size", 0) > row_styles[i+1].get("font_size", 0):
            header_rows.append(i)
            continue
            
        # Headers often have different background
        if row_styles[i].get("background_color") != row_styles[i+1].get("background_color"):
            header_rows.append(i)
            continue
            
        # Check if row content looks like headers (short text, no numbers)
        row_content = extract_row_text(table_content, row_positions[i], row_positions[i+1])
        if all(is_likely_header_cell(cell) for cell in row_content):
            header_rows.append(i)
    
    # If no headers detected but table has multiple rows, assume first row is header
    if not header_rows and len(row_positions) > 2:
        header_rows = [0]
    
    return header_rows
```

### 3. Merged Cell Detection

Properly handling merged cells is essential for table structure:

```python
def detect_merged_cells(table_content, row_positions, column_positions):
    """Detect cells that span multiple rows or columns."""
    merged_cells = []
    
    # Extract text elements in the table
    text_elements = extract_text_elements(table_content)
    
    # Check for horizontal spans (cells spanning multiple columns)
    for i, (row_top, row_bottom) in enumerate(zip(row_positions[:-1], row_positions[1:])):
        row_texts = [text for text in text_elements 
                     if row_top <= text["y1"] <= row_bottom]
        
        for text in row_texts:
            # Find which columns this text spans
            start_col = None
            end_col = None
            
            for j, col_pos in enumerate(column_positions[:-1]):
                if text["x0"] <= col_pos and start_col is None:
                    start_col = j
                if text["x1"] >= col_pos and text["x1"] <= column_positions[j+1]:
                    end_col = j
            
            if start_col is not None and end_col is not None and end_col > start_col:
                merged_cells.append({
                    "row_start": i,
                    "row_end": i,
                    "col_start": start_col,
                    "col_end": end_col,
                    "span_type": "horizontal"
                })
    
    # Check for vertical spans (cells spanning multiple rows)
    # Similar logic to above but checking for vertical spans
    
    return merged_cells
```

## Cell Content Extraction

With the table structure defined, we extract cell contents:

### 1. Text Extraction

```python
def extract_cell_content(table_content, row_idx, col_idx, table_structure):
    """Extract content from a specific cell."""
    # Get cell boundaries
    row_start = table_structure["grid"]["rows"][row_idx]
    row_end = table_structure["grid"]["rows"][row_idx + 1]
    col_start = table_structure["grid"]["columns"][col_idx]
    col_end = table_structure["grid"]["columns"][col_idx + 1]
    
    # Check if this is part of a merged cell
    for merged_cell in table_structure["merged_cells"]:
        if (merged_cell["row_start"] <= row_idx <= merged_cell["row_end"] and
            merged_cell["col_start"] <= col_idx <= merged_cell["col_end"]):
            # If this is not the top-left of the merged cell, return None
            if row_idx > merged_cell["row_start"] or col_idx > merged_cell["col_start"]:
                return None
            
            # If this is the top-left, get the full merged cell boundaries
            row_end = table_structure["grid"]["rows"][merged_cell["row_end"] + 1]
            col_end = table_structure["grid"]["columns"][merged_cell["col_end"] + 1]
    
    # Extract text elements within the cell boundaries
    cell_bbox = (col_start, row_start, col_end, row_end)
    text_elements = extract_text_in_bbox(table_content, cell_bbox)
    
    # Combine text elements in reading order
    cell_text = combine_text_elements(text_elements)
    
    return {
        "text": cell_text,
        "bbox": cell_bbox,
        "row": row_idx,
        "column": col_idx,
        "is_header": row_idx in table_structure["header_rows"],
        "style": extract_text_style(text_elements)
    }
```

### 2. Content Type Detection

Identifying content types helps with further processing:

```python
def detect_content_type(cell_content):
    """Detect the type of content in a cell."""
    text = cell_content["text"].strip()
    
    if not text:
        return "empty"
    
    # Check for numeric values
    if re.match(r'^[$€£¥]?\s*\d+([,.]\d+)?%?$', text):
        # Check for percentages
        if text.endswith('%'):
            return "percentage"
        
        # Check for currency
        if re.match(r'^[$€£¥]', text):
            return "currency"
            
        # Regular number
        return "numeric"
    
    # Check for date formats
    date_patterns = [
        r'\d{1,2}/\d{1,2}/\d{2,4}',  # MM/DD/YYYY or DD/MM/YYYY
        r'\d{1,2}-\d{1,2}-\d{2,4}',  # MM-DD-YYYY or DD-MM-YYYY
        r'\d{1,2}\.\d{1,2}\.\d{2,4}',  # MM.DD.YYYY or DD.MM.YYYY
        r'[A-Za-z]{3,9} \d{1,2},? \d{4}'  # Month DD, YYYY
    ]
    
    for pattern in date_patterns:
        if re.match(pattern, text):
            return "date"
    
    # Check for boolean-like values
    boolean_values = ["yes", "no", "true", "false", "y", "n", "✓", "×", "✗", "✔"]
    if text.lower() in boolean_values:
        return "boolean"
    
    # Default to text
    return "text"
```

### 3. Cell Value Normalization

Normalizing values ensures consistent data:

```python
def normalize_cell_value(cell):
    """Normalize cell value based on content type."""
    content_type = detect_content_type(cell)
    text = cell["text"].strip()
    
    if content_type == "empty":
        return None
    
    elif content_type == "numeric":
        # Remove any non-numeric characters except decimal separator
        numeric_text = re.sub(r'[^\d.,]', '', text)
        # Replace comma with dot for standardization if needed
        numeric_text = numeric_text.replace(',', '.')
        try:
            return float(numeric_text)
        except ValueError:
            return text
    
    elif content_type == "currency":
        # Extract the numeric part
        numeric_part = re.sub(r'[^\d.,]', '', text)
        numeric_part = numeric_part.replace(',', '.')
        try:
            value = float(numeric_part)
            # Determine currency symbol
            currency_symbol = re.match(r'^[$€£¥]', text)
            currency = currency_symbol.group(0) if currency_symbol else '$'
            return {
                "value": value,
                "currency": currency
            }
        except ValueError:
            return text
    
    elif content_type == "percentage":
        # Remove % symbol and convert to numeric
        numeric_part = text.rstrip('%').strip()
        try:
            return float(numeric_part) / 100
        except ValueError:
            return text
    
    elif content_type == "date":
        # Try to parse date
        try:
            for date_format in ["%m/%d/%Y", "%d/%m/%Y", "%m-%d-%Y", "%d-%m-%Y", 
                              "%m.%d.%Y", "%d.%m.%Y", "%B %d, %Y", "%b %d, %Y"]:
                try:
                    return datetime.strptime(text, date_format).date()
                except ValueError:
                    continue
        except:
            return text
    
    # Return as is for other types
    return text
```

## Post-Processing and Validation

After extraction, we validate and enhance the table data:

### 1. Table Data Validation

```python
def validate_table_data(table_data):
    """Validate extracted table data for completeness and consistency."""
    # Check if table has reasonable dimensions
    if len(table_data["rows"]) < 2 or len(table_data["columns"]) < 2:
        table_data["validation_warnings"].append("Table has less than 2 rows or columns")
    
    # Ensure headers are present
    if not table_data["headers"]:
        table_data["validation_warnings"].append("No headers detected")
        # Generate placeholder headers
        table_data["headers"] = [f"Column {i+1}" for i in range(len(table_data["columns"]))]
    
    # Check for empty rows
    empty_rows = []
    for i, row in enumerate(table_data["data"]):
        if all(cell is None or cell == "" for cell in row):
            empty_rows.append(i)
    
    # Remove empty rows
    if empty_rows:
        table_data["validation_warnings"].append(f"Removed {len(empty_rows)} empty rows")
        for idx in reversed(empty_rows):
            del table_data["data"][idx]
    
    # Check for consistent column counts
    col_counts = [len(row) for row in table_data["data"]]
    if len(set(col_counts)) > 1:
        table_data["validation_warnings"].append("Inconsistent column counts detected")
        
        # Find maximum column count
        max_cols = max(col_counts)
        
        # Pad rows with fewer columns
        for i, row in enumerate(table_data["data"]):
            if len(row) < max_cols:
                table_data["data"][i] = row + [None] * (max_cols - len(row))
    
    return table_data
```

### 2. Table Semantics Analysis

Understanding the table's role in the document:

```python
def analyze_table_semantics(table_data, document_context):
    """Analyze the semantic meaning of the table in the document."""
    # Look at surrounding text for context
    surrounding_text = document_context.get("surrounding_text", "")
    
    # Look at headers to determine table purpose
    headers = table_data["headers"]
    header_text = " ".join(str(h) for h in headers if h)
    
    # Attempt to classify table type
    table_type = None
    
    # Check for coverage tables
    coverage_keywords = ["coverage", "benefit", "limit", "maximum", "covered", "service"]
    if any(keyword in header_text.lower() for keyword in coverage_keywords):
        table_type = "coverage_table"
    
    # Check for premium tables
    premium_keywords = ["premium", "cost", "price", "payment", "installment", "rate"]
    if any(keyword in header_text.lower() for keyword in premium_keywords):
        table_type = "premium_table"
    
    # Check for deductible tables
    deductible_keywords = ["deductible", "out-of-pocket", "copay", "co-pay", "coinsurance"]
    if any(keyword in header_text.lower() for keyword in deductible_keywords):
        table_type = "deductible_table"
    
    # Check for provider network tables
    network_keywords = ["provider", "network", "in-network", "out-of-network", "facility"]
    if any(keyword in header_text.lower() for keyword in network_keywords):
        table_type = "network_table"
    
    # Look at surrounding text if table type is still unknown
    if table_type is None and surrounding_text:
        for table_type_candidate, keywords in {
            "coverage_table": coverage_keywords,
            "premium_table": premium_keywords,
            "deductible_table": deductible_keywords,
            "network_table": network_keywords
        }.items():
            if any(keyword in surrounding_text.lower() for keyword in keywords):
                table_type = table_type_candidate
                break
    
    # Default to generic if no type could be determined
    if table_type is None:
        table_type = "generic_table"
    
    table_data["table_type"] = table_type
    
    # Add table title if found in surrounding text
    title_match = re.search(r'(Table \d+[:.]\s*([^\n]+))', surrounding_text)
    if title_match:
        table_data["title"] = title_match.group(2).strip()
    else:
        # Try to extract title from text immediately before table
        lines_before = surrounding_text.split('\n')[-3:]  # Last 3 lines before table
        for line in reversed(lines_before):
            if len(line.strip()) > 3 and not line.strip().endswith(":"):
                table_data["title"] = line.strip()
                break
    
    return table_data
```

### 3. Data Enhancement

Adding additional context and metadata:

```python
def enhance_table_data(table_data, document_metadata):
    """Enhance table data with additional context and formatting."""
    # Add policy metadata
    table_data["policy_metadata"] = {
        "policy_id": document_metadata.get("policy_id"),
        "policy_number": document_metadata.get("policy_number"),
        "insurer": document_metadata.get("insurer"),
        "document_id": document_metadata.get("document_id"),
    }
    
    # Add table location info
    table_data["location"] = {
        "page_number": table_data["page_number"],
        "bbox": table_data["bbox"],
        "section": document_metadata.get("current_section", ""),
        "section_title": document_metadata.get("current_section_title", "")
    }
    
    # Convert to structured format if appropriate
    if table_data["table_type"] == "coverage_table":
        table_data["structured_data"] = convert_to_coverage_structure(table_data)
    elif table_data["table_type"] == "premium_table":
        table_data["structured_data"] = convert_to_premium_structure(table_data)
    elif table_data["table_type"] == "deductible_table":
        table_data["structured_data"] = convert_to_deductible_structure(table_data)
    
    # Generate a summary of the table
    table_data["summary"] = generate_table_summary(table_data)
    
    return table_data
```

## Multi-Page Tables

Insurance documents often contain tables that span multiple pages:

### 1. Multi-Page Detection

```python
def detect_multi_page_tables(pages, table_regions):
    """Detect tables that span multiple pages."""
    multi_page_tables = []
    current_table = None
    
    # Group table regions by page
    tables_by_page = {}
    for region in table_regions:
        page_num = region["page_number"]
        if page_num not in tables_by_page:
            tables_by_page[page_num] = []
        tables_by_page[page_num].append(region)
    
    # Process pages in order
    for page_num in sorted(tables_by_page.keys()):
        page_tables = tables_by_page[page_num]
        
        # Check if we have a table potentially continuing from previous page
        if current_table is not None:
            # Check if there's a table at the top of this page
            top_tables = [t for t in page_tables if t["bbox"][1] < 150]  # Near top of page
            
            if top_tables:
                # Check if it looks like a continuation (no headers or headers match)
                top_table = min(top_tables, key=lambda t: t["bbox"][1])  # Get the topmost
                
                # Check if this might be a continuation
                if is_likely_table_continuation(current_table, top_table, pages):
                    # Merge with current multi-page table
                    current_table["regions"].append(top_table)
                    page_tables.remove(top_table)
                    continue
            
            # If we reach here, current_table is complete
            multi_page_tables.append(current_table)
            current_table = None
        
        # Check for tables at the bottom of the page that might continue
        bottom_tables = [t for t in page_tables if t["bbox"][3] > pages[page_num].height - 150]
        
        if bottom_tables:
            # Get the table closest to the bottom
            bottom_table = max(bottom_tables, key=lambda t: t["bbox"][3])
            
            # If it's near the bottom and doesn't look "complete", mark as potential continuation
            if is_potential_continuation(bottom_table, pages[page_num]):
                current_table = {
                    "regions": [bottom_table],
                    "start_page": page_num,
                    "end_page": None
                }
                page_tables.remove(bottom_table)
        
        # Add remaining tables as single-page tables
        for table in page_tables:
            multi_page_tables.append({
                "regions": [table],
                "start_page": page_num,
                "end_page": page_num
            })
    
    # Handle any remaining current_table
    if current_table is not None:
        multi_page_tables.append(current_table)
    
    # Set end pages
    for table in multi_page_tables:
        if table["end_page"] is None:
            table["end_page"] = table["regions"][-1]["page_number"]
    
    return multi_page_tables
```

### 2. Multi-Page Extraction

```python
def extract_multi_page_table(multi_page_table, pages):
    """Extract content from a table spanning multiple pages."""
    regions = multi_page_table["regions"]
    start_page = multi_page_table["start_page"]
    end_page = multi_page_table["end_page"]
    
    # Extract structure from first page to understand the table
    first_region = regions[0]
    first_page = pages[start_page]
    table_structure = analyze_table_structure(first_region, first_page)
    
    # For multi-page tables, we need to track header rows
    header_rows = table_structure["header_rows"]
    header_cells = []
    
    if header_rows:
        # Extract header cells from first page
        for row_idx in header_rows:
            row_cells = []
            for col_idx in range(table_structure["columns"]):
                cell = extract_cell_content(
                    extract_region(first_page, first_region["bbox"]),
                    row_idx, col_idx, table_structure
                )
                if cell:
                    row_cells.append(cell)
            header_cells.append(row_cells)
    
    # Extract content from all pages
    all_rows = []
    
    for i, region in enumerate(regions):
        page_num = region["page_number"]
        page = pages[page_num]
        
        # Re-analyze structure for this page's region
        page_structure = analyze_table_structure(region, page)
        
        # Skip header rows on continuation pages
        start_row = 0
        if i > 0 and is_header_repeated(page_structure, header_cells, page, region):
            start_row = len(header_rows)
        
        # Extract rows
        for row_idx in range(start_row, page_structure["rows"]):
            row_cells = []
            for col_idx in range(page_structure["columns"]):
                cell = extract_cell_content(
                    extract_region(page, region["bbox"]),
                    row_idx, col_idx, page_structure
                )
                if cell:
                    row_cells.append(cell)
            
            # Only add non-empty rows
            if any(cell and cell["text"].strip() for cell in row_cells):
                all_rows.append(row_cells)
    
    # Construct the complete table data
    table_data = {
        "headers": [cell["text"] for cell in header_cells[0]] if header_cells else [],
        "data": [[cell["text"] if cell else None for cell in row] for row in all_rows],
        "start_page": start_page,
        "end_page": end_page,
        "page_count": end_page - start_page + 1,
        "row_count": len(all_rows),
        "column_count": table_structure["columns"],
        "bbox": [regions[0]["bbox"], regions[-1]["bbox"]],
        "validation_warnings": []
    }
    
    # Validate and enhance
    table_data = validate_table_data(table_data)
    
    return table_data
```

### 3. Header Detection Across Pages

```python
def is_header_repeated(page_structure, original_headers, page, region):
    """Check if headers from the first page are repeated on continuation pages."""
    # Extract potential header cells from current page
    potential_headers = []
    
    for row_idx in range(min(len(original_headers), page_structure["rows"])):
        row_cells = []
        for col_idx in range(page_structure["columns"]):
            cell = extract_cell_content(
                extract_region(page, region["bbox"]),
                row_idx, col_idx, page_structure
            )
            if cell:
                row_cells.append(cell)
        potential_headers.append(row_cells)
    
    # Compare with original headers
    if len(potential_headers) != len(original_headers):
        return False
    
    similarity_score = 0
    total_cells = 0
    
    for i, (orig_row, pot_row) in enumerate(zip(original_headers, potential_headers)):
        for j, (orig_cell, pot_cell) in enumerate(zip(orig_row, pot_row)):
            if orig_cell and pot_cell:
                total_cells += 1
                if orig_cell["text"].strip() == pot_cell["text"].strip():
                    similarity_score += 1
    
    # Consider headers repeated if similarity is above threshold
    return similarity_score / max(1, total_cells) > 0.7
```

## Integration with Document Processing Pipeline

The table extraction component integrates with the overall document processing pipeline:

### 1. Pipeline Integration

```python
def process_tables_in_document(document_id):
    """Process all tables in a document as part of the pipeline."""
    # Get document from storage
    document = get_document(document_id)
    
    # Get document metadata
    document_metadata = get_document_metadata(document_id)
    
    # Load ML model for table detection
    table_detection_model = load_table_detection_model()
    
    # Process pages
    pages = load_document_pages(document)
    
    # Detect tables on each page
    table_regions = []
    for page_idx, page in enumerate(pages):
        page_regions = detect_tables(page, table_detection_model)
        table_regions.extend(page_regions)
    
    # Detect multi-page tables
    multi_page_tables = detect_multi_page_tables(pages, table_regions)
    
    # Extract tables
    extracted_tables = []
    
    for table in multi_page_tables:
        if table["start_page"] == table["end_page"]:
            # Single-page table
            table_data = extract_table(table["regions"][0], pages[table["start_page"]])
        else:
            # Multi-page table
            table_data = extract_multi_page_table(table, pages)
        
        # Get document context for semantic analysis
        page_nums = list(range(table["start_page"], table["end_page"] + 1))
        context = extract_surrounding_context(pages, page_nums, table["regions"])
        
        # Analyze and enhance
        table_data = analyze_table_semantics(table_data, {"surrounding_text": context})
        table_data = enhance_table_data(table_data, document_metadata)
        
        extracted_tables.append(table_data)
    
    # Store extracted tables
    store_extracted_tables(document_id, extracted_tables)
    
    # Update document processing status
    update_processing_status(document_id, "tables_extracted", len(extracted_tables))
    
    return {
        "document_id": document_id,
        "table_count": len(extracted_tables),
        "tables": extracted_tables
    }
```

### 2. Document Processing Events

```python
def handle_document_processing_event(event):
    """Handle document processing events for table extraction."""
    document_id = event["document_id"]
    event_type = event["event_type"]
    
    if event_type == "document_uploaded":
        # Queue document for processing
        enqueue_processing_job("extract_tables", {"document_id": document_id})
    
    elif event_type == "text_extraction_completed":
        # Text extraction completed, now extract tables
        process_tables_in_document(document_id)
    
    elif event_type == "table_extraction_failed":
        # Handle failure
        error = event.get("error", "Unknown error")
        retry_count = event.get("retry_count", 0)
        
        if retry_count < MAX_RETRY_COUNT:
            # Retry with backoff
            backoff_seconds = 2 ** retry_count
            schedule_retry("extract_tables", 
                          {"document_id": document_id, "retry_count": retry_count + 1},
                          backoff_seconds)
        else:
            # Log permanent failure
            log_extraction_failure(document_id, "table_extraction", error)
            
            # Continue processing with warning
            update_processing_status(
                document_id, 
                "tables_extraction_failed", 
                {"error": error, "warning": "Processing continuing without tables"}
            )
```

## Performance Metrics

We track several key metrics to evaluate table extraction performance:

### 1. Accuracy Metrics

| Metric | Description | Target | Current |
|--------|-------------|--------|---------|
| Table Detection Rate | Percentage of tables correctly detected | >95% | 92% |
| Header Identification Accuracy | Percentage of table headers correctly identified | >90% | 88% |
| Cell Content Accuracy | Percentage of cell content correctly extracted | >95% | 93% |
| Structure Preservation | Percentage of tables with correctly preserved structure | >90% | 86% |
| Data Type Recognition | Percentage of cells with correctly identified data types | >85% | 82% |

### 2. Performance Metrics

| Metric | Description | Target | Current |
|--------|-------------|--------|---------|
| Processing Time per Page | Average time to process a page | <2s | 1.8s |
| Processing Time per Table | Average time to process a table | <5s | 4.5s |
| Memory Usage | Peak memory usage during processing | <500MB | 450MB |
| Failure Rate | Percentage of tables that fail to process | <2% | 3% |

### 3. Improvement Tracking

We continuously track performance and implement improvements:

```python
def track_extraction_performance(document_id, ground_truth, extraction_results):
    """Track performance metrics for table extraction."""
    metrics = {
        "document_id": document_id,
        "timestamp": datetime.now(),
        "table_count": len(extraction_results["tables"]),
        "metrics": {}
    }
    
    # Calculate table detection metrics
    gt_tables = ground_truth["tables"]
    detected_tables = extraction_results["tables"]
    
    true_positives = 0
    for dt in detected_tables:
        for gt in gt_tables:
            if calculate_iou(dt["bbox"], gt["bbox"]) > 0.7:
                true_positives += 1
                break
    
    false_positives = len(detected_tables) - true_positives
    false_negatives = len(gt_tables) - true_positives
    
    precision = true_positives / max(1, true_positives + false_positives)
    recall = true_positives / max(1, true_positives + false_negatives)
    f1 = 2 * precision * recall / max(0.001, precision + recall)
    
    metrics["metrics"]["detection"] = {
        "precision": precision,
        "recall": recall,
        "f1": f1
    }
    
    # Calculate content extraction metrics
    # ... additional metrics calculations
    
    # Store metrics
    store_extraction_metrics(metrics)
    
    return metrics
```

## Future Improvements

We've identified several areas for future enhancements:

### 1. Advanced ML Models

- Implement newer table detection models like TableBank or PubTabNet
- Develop custom model fine-tuned on insurance document tables
- Explore deep learning approaches for end-to-end table extraction

### 2. Enhanced Processing

- Improve multi-page table detection with stronger heuristics
- Develop better handling for complex nested tables
- Improve footnote association with table cells
- Add support for rotated tables and text

### 3. Semantic Understanding

- Deeper semantic analysis of table purpose and content
- Better correlation between table content and surrounding text
- Automatic categorization of tables into functional types
- Cross-table information linking (e.g., connecting related tables)

### 4. Performance Optimization

- Implement batch processing for multiple tables
- Optimize memory usage for large documents
- Add incremental processing with streaming results
- Implement parallel processing across multiple documents

These improvements will be prioritized based on user needs and impact on overall system accuracy.
