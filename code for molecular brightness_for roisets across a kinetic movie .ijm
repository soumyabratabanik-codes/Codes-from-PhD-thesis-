// Molecular Brightness (B) Tool - Kinetic Sync Version
// Logic: Frame 1 uses ROI 0, Frame 2 uses ROI 1, and so on.

if (nImages == 0) exit("No image open.");
roiCount = roiManager("count");
if (roiCount == 0) exit("The ROI Manager is empty.");

// Match iterations to the number of ROIs or Frames (whichever is smaller)
n = minOf(roiCount, nSlices);

run("Clear Results");

for (i = 0; i < n; i++) {
    // Sync: Select the ROI and move the stack to that frame
    roiManager("select", i);
    setSlice(i + 1); // Frames are 1-indexed, ROIs are 0-indexed
   
    // --- YOUR ORIGINAL CALCULATION LOGIC ---
    getSelectionBounds(bx, by, bw, bh);
    nonzeroArray = newArray();
    zeroCount = 0;
   
    for (y=by; y<by+bh; y++) {
        for (x=bx; x<bx+bw; x++) {
            if (selectionContains(x, y)) {
                v = getPixel(x, y);
                if (v > 0) {
                    nonzeroArray[nonzeroArray.length] = v;
                } else {
                    zeroCount++;
                }
            }
        }
    }

    validCount = nonzeroArray.length;
    mu = 0; variance = 0; brightness = 0;

    if (validCount > 1) {
        sum = 0;
        for (j = 0; j < validCount; j++) sum += nonzeroArray[j];
        mu = sum / validCount;

        sqSum = 0;
        for (j = 0; j < validCount; j++) {
            sqSum += pow(nonzeroArray[j] - mu, 2);
        }
        variance = sqSum / (validCount - 1);
        brightness = variance / mu;
    }
    // --- END OF LOGIC ---

    // Output to Results Table
    setResult("Frame", i, i + 1);
    setResult("ROI_Index", i, i);
    setResult("Mean_Mu", i, mu);
    setResult("Variance_Sigma2", i, variance);
    setResult("Brightness_B", i, brightness);
}

updateResults();
roiManager("deselect"); // Clean up selection at the end
print("Analysis complete: Synced " + n + " ROIs to " + n + " frames.");