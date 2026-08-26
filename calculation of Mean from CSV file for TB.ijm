// 1. Prompt the user to select the CSV file
path = File.openDialog("Select your CSV file");

// 2. Read the entire file into a raw text string
fileContent = File.openAsString(path);

// 3. Split the text string into individual lines
lines = split(fileContent, "\n");

sum = 0;
count = 0;
brightnessColumnIndex = -1;

// 4. Read the header (Line 0) to automatically find where "Brightness (Y)" is located
headerLine = lines[0];
headers = split(headerLine, ",");

for (j = 0; j < headers.length; j++) {
    // Clean up spaces/quotes from the column name
    cleanHeader = replace(headers[j], "\"", "");
    cleanHeader = trim(cleanHeader);
    
    if (indexOf(cleanHeader, "Brightness") >= 0) {
        brightnessColumnIndex = j;
    }
}

// Fallback to Column 4 if auto-detection gets confused by hidden layout characters
if (brightnessColumnIndex == -1) {
    brightnessColumnIndex = 4; 
}

// 5. Loop through all data rows (starting at line 1)
for (i = 1; i < lines.length; i++) {
    if (lengthOf(lines[i]) > 0) { // Skip empty rows
        columns = split(lines[i], ",");
        
        if (columns.length > brightnessColumnIndex) {
            // Grab the raw text value from the brightness column slot
            rawVal = columns[brightnessColumnIndex];
            val = parseFloat(rawVal);
            
            // If it's a valid number, add it to our calculations
            if (!isNaN(val)) {
                sum += val;
                count++;
            }
        }
    }
}

// 6. Output the final calculation to the log window
print("\\Clear"); 
print("=== Raw Text Parser Results ===");
print("Target Column Position: Index " + brightnessColumnIndex);
print("Total Data Points Counted: " + count);

if (count > 0) {
    average = sum / count;
    print("Average Brightness: " + average);
} else {
    print("Error: No numeric data could be extracted from the file.");
}
print("===============================");