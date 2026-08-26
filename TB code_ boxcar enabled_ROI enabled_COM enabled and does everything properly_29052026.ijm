macro "ROI Temporal Boxcar with Heatmap Center of Mass Analysis - Fixed Saving" {
    // =========================================================================
    // SECTION 1: USER INPUT, ROI SELECTION & SETUP (UNCHANGED)
    // =========================================================================
    path = File.openDialog("Select your time-series TIFF stack");
    open(path);
    originalImage = getTitle();

    nFrames = nSlices;
    if (nFrames <= 1) {
        exit("Error: The selected image must be a multi-frame time-series stack.");
    }

    run("32-bit");

    setTool("freehand"); 
    waitForUser("ROI Selection", "1. Draw your ROI on the image stack window.\n2. Click 'OK' when you are done to begin analysis.");
    
    if (selectionType() == -1) {
        exit("Error: You must draw a selection ROI on the image to run this macro.");
    }

    Roi.getContainedPoints(xROI, yROI);
    totalROIPixels = xROI.length;

    Dialog.create("Boxcar Parameters");
    Dialog.addNumber("Boxcar Window Size (frames):", minOf(100, nFrames - 1));
    Dialog.show();
    box = Dialog.getNumber();

    if (box > nFrames || box <= 1) {
        exit("Error: Boxcar size must be greater than 1 and smaller than total stack frames (" + nFrames + ").");
    }
    
    w = getWidth();
    h = getHeight();

    newImage("Mean_For_Plot", "32-bit black", w, h, 1);
    imgMeanID = getImageID();
    
    newImage("Temporal_Brightness_Map", "32-bit black", w, h, 1);
    imgBrightID = getImageID();

    meanArr = newArray(totalROIPixels);
    brightArr = newArray(totalROIPixels);

    // =========================================================================
    // SECTION 2: PER-PIXEL SLIDING BOXCAR LOOP (UNCHANGED CORE LOGIC)
    // =========================================================================
    setBatchMode(true); 
    iterations = nFrames - box + 1; 

    for (pIdx = 0; pIdx < totalROIPixels; pIdx++) {
        imgX = xROI[pIdx];
        imgY = yROI[pIdx];
        
        selectWindow(originalImage);
        onda = newArray(nFrames);
        for (f = 0; f < nFrames; f++) {
            onda[f] = getStackPixelValue(imgX, imgY, f);
        }

        k_total = 0;
        b_total = 0;

        for (i = 0; i <= (nFrames - box); i++) {
            sum = 0;
            for (p = 0; p < box; p++) {
                sum += onda[i + p];
            }
            v_avg = sum / box; 

            sumSquares = 0;
            for (p = 0; p < box; p++) {
                diff = onda[i + p] - v_avg;
                sumSquares += diff * diff;
            }
            v_sdev = sqrt(sumSquares / (box - 1)); 

            if (v_avg != 0) {
                tempb = (v_sdev * v_sdev) / v_avg;
            } else {
                tempb = 0; 
            }

            k_total += v_avg;
            b_total += tempb;
        }

        meanArr[pIdx] = k_total / iterations;
        brightArr[pIdx] = b_total / iterations;

        selectImage(imgMeanID);
        setPixel(imgX, imgY, meanArr[pIdx]);

        selectImage(imgBrightID);
        setPixel(imgX, imgY, brightArr[pIdx]);
    }
    
    selectWindow(originalImage);
    run("Select None");
    
    setBatchMode(false); 

    // Style underlying maps
    selectImage(imgBrightID);
    run("Fire"); resetMinAndMax(); 
    run("Calibration Bar...", "location=[Upper Right] fill=None label=White number=5 font=12 show overlay");
    selectImage(imgMeanID); resetMinAndMax();

    // Standard correlation plots
    Plot.create("Correlation Plot (ROI)", "Boxcar Mean Intensity", "Boxcar Molecular Brightness");
    Plot.add("dots", meanArr, brightArr);
    Plot.show();

    Plot.create("ROI Brightness Histogram", "Molecular Brightness (X)", "Occurrence Count (Y)");
    Plot.addHistogram(brightArr, 0); 
    Plot.show();

    // =========================================================================
    // SECTION 3: 2D DENSITY HEATMAP GENERATION (UNCHANGED)
    // =========================================================================
    Array.getStatistics(meanArr, minI_data, maxI_data);
    Array.getStatistics(brightArr, minB_data, maxB_data);

    Dialog.create("Heatmap Configuration");
    Dialog.addMessage("Specify density limits for Intensity (X) and Brightness (Y):");
    Dialog.addNumber("Min Intensity:", Math.floor(minI_data));
    Dialog.addNumber("Max Intensity:", Math.ceil(maxI_data));
    Dialog.addNumber("Intensity Bin Width (X):", 20); 
    Dialog.addNumber("Min Brightness:", 0.0);
    Dialog.addNumber("Max Brightness:", Math.ceil(maxB_data * 1.2));
    Dialog.addNumber("Brightness Bin Height (Y):", 0.05);
    Dialog.show();

    minInt = Dialog.getNumber(); maxInt = Dialog.getNumber(); intBin = Dialog.getNumber();
    minBright = Dialog.getNumber(); maxBright = Dialog.getNumber(); brightBin = Dialog.getNumber();

    // Calculate Grid structures
    xBins = Math.ceil((maxInt - minInt) / intBin);
    yBins = Math.ceil((maxBright - minBright) / brightBin);
    nBins = xBins * yBins;

    grid = newArray(nBins);
    totalInGatedRange = 0;

    // Distribute data points inside the requested coordinates
    for (i = 0; i < totalROIPixels; i++) {
        vI = meanArr[i];
        vB = brightArr[i];
        
        if (vI >= minInt && vI < maxInt && vB >= minBright && vB < maxBright) {
            xi = Math.floor((vI - minInt) / intBin);
            yi = Math.floor((vB - minBright) / brightBin);
            idx = yi * xBins + xi;
            grid[idx]++;
            totalInGatedRange++;
        }
    }

    if (totalInGatedRange == 0) {
        exit("Error: No data points fell within your coordinate boundary limits.");
    }

    zoom = 10; // Pixel scaling factor for viewability

    // A. Generate Raw Counts Heatmap & Legend
    newImage("Raw_Counts_Heatmap", "32-bit", xBins, yBins, 1);
    maxRaw = 0;
    for (i = 0; i < nBins; i++) {
        y = Math.floor(i / xBins); x = i % xBins;
        val = grid[i];
        setPixel(x, (yBins - 1 - y), val);
        if (val > maxRaw) maxRaw = val;
    }
    run("16 Colors"); setMinAndMax(0, maxRaw);
    run("Size...", "width="+(xBins*zoom)+" height="+(yBins*zoom)+" depth=1 average interpolation=None");

    newImage("Legend_Raw_Counts", "32-bit", 150, 400, 1);
    run("16 Colors"); setMinAndMax(0, maxRaw);
    run("Calibration Bar...", "location=[Upper Left] fill=None label=White number=5 decimal=0 font=14 zoom=2 overlay");

    // B. Generate Normalized Density Heatmap
    newImage("Normalized_Density_Heatmap", "32-bit", xBins, yBins, 1);
    idNormHeatmap = getImageID();
    maxNorm = -1;
    for (i = 0; i < nBins; i++) {
        normVal = grid[i] / totalInGatedRange;
        y = Math.floor(i / xBins); x = i % xBins;
        canvasY = yBins - 1 - y;
        setPixel(x, canvasY, normVal);
        if (normVal > maxNorm) maxNorm = normVal;
    }
    run("Fire"); setMinAndMax(0, maxNorm);
    
    // Scale up for user interaction visibility
    run("Size...", "width="+(xBins*zoom)+" height="+(yBins*zoom)+" depth=1 average interpolation=None");

    newImage("Legend_Normalized", "32-bit", 150, 400, 1);
    run("Fire"); setMinAndMax(0, maxNorm);
    run("Calibration Bar...", "location=[Upper Left] fill=None label=White number=5 decimal=4 font=14 zoom=2 overlay");

    // =========================================================================
    // SECTION 4: INTERACTIVE CLUSTER CENTER OF MASS (COM) ANALYSIS (UNCHANGED)
    // =========================================================================
    selectImage(idNormHeatmap);
    setTool("oval"); 
    
    waitForUser("Cluster Analysis Selection", "1. Use the armed Circle/Ellipse Tool to select your population cluster on the Normalized Heatmap.\n2. Click 'OK' to calculate its Center of Mass parameters.");

    if (selectionType() == -1) {
        exit("Error: You must draw a circle selection on the heatmap to analyze the center of mass.");
    }

    run("Set Measurements...", "center redirect=None decimal=6");
    run("Measure");
    
    visualComX = getResult("XM", nResults-1);
    visualComY = getResult("YM", nResults-1);
    
    run("Clear Results");

    comX = visualComX / zoom;
    comY = visualComY / zoom;
    cartesianComY = (yBins) - comY;

    comIntensity = minInt + (comX * intBin);
    comBrightness = minBright + (cartesianComY * brightBin);

    setTool("point");
    makePoint(visualComX, visualComY);

    // =========================================================================
    // SECTION 5: OUTPUT TABLES & DETAILED REPORT LOG (UNCHANGED)
    // =========================================================================
    for (i = 0; i < totalROIPixels; i++) {
        setResult("ROI Pixel Index", i, i);
        setResult("Spatial X", i, xROI[i]);
        setResult("Spatial Y", i, yROI[i]);
        setResult("Intensity (X)", i, meanArr[i]); 
        setResult("Brightness (Y)", i, brightArr[i]);
    }
    updateResults(); 

    coverage = (totalInGatedRange / totalROIPixels) * 100;

    print("\\Clear");
    print("=== ROI TEMPORAL BOXCAR ANALYSIS REPORT ===");
    print("Source Image File:            " + originalImage);
    print("Total ROI Pixels Extracted:   " + totalROIPixels);
    print("Boxcar Integration Size:      " + box + " frames");
    print("Total Sliding Windows Run:    " + iterations);
    print("");
    print("=== NORMALIZED HEATMAP BINNING PARAMETERS ===");
    print("Intensity Axis Boundary (X):  " + minInt + " to " + maxInt);
    print("Intensity Bin Width (dX):     " + intBin);
    print("Total Columns (X-Bins):       " + xBins);
    print("---------------------------------------------");
    print("Brightness Axis Boundary (Y): " + minBright + " to " + maxBright);
    print("Brightness Bin Height (dY):   " + d2s(brightBin, 4));
    print("Total Rows (Y-Bins):          " + yBins);
    print("---------------------------------------------");
    print("Total 2D Grid Bin Quantities: " + nBins + " total density pixels");
    print("Points Inside Density Range:  " + totalInGatedRange + " / " + totalROIPixels + " (" + d2s(coverage, 2) + "%)");
    print("");
    print("=== SELECTED CLUSTER CENTER OF MASS (COM) ===");
    print("Heatmap Subgrid COM Address:  " + "Column X: " + d2s(comX, 2) + ", Row Y: " + d2s(comY, 2));
    print("Calculated COM Intensity:     " + d2s(comIntensity, 2));
    print("Calculated COM Brightness:    " + d2s(comBrightness, 4));
    print("=============================================");

    // =========================================================================
    // SECTION 6: STREAMLINED FORCED FILE SAVING ENGINE
    // =========================================================================
    // Ask for folder path up front
    dir = getDirectory("Choose a destination folder to save outputs");
    
    if (dir != "") {
        // Enforce visible screen rendering to guarantee file creation
        setBatchMode(false);
        
        // Define explicit saving targets
        outputs = newArray(
            "Normalized_Density_Heatmap", 
            "Legend_Normalized", 
            "Raw_Counts_Heatmap", 
            "Legend_Raw_Counts", 
            "Mean_For_Plot", 
            "Temporal_Brightness_Map",
            "Correlation Plot (ROI)",
            "ROI Brightness Histogram"
        );

        for (i = 0; i < outputs.length; i++) {
            if (isOpen(outputs[i])) {
                selectWindow(outputs[i]);
                if (indexOf(outputs[i], "Plot") >= 0 || indexOf(outputs[i], "Histogram") >= 0 || indexOf(outputs[i], "Legend") >= 0) {
                    saveAs("Png", dir + outputs[i] + ".png");
                } else {
                    saveAs("Tiff", dir + outputs[i] + ".tif");
                }
                close();
            }
        }

        // Save Results Table Data Matrix
        if (isOpen("Results")) {
            selectWindow("Results");
            saveAs("Results", dir + "ROI_Pixel_Analysis_Matrix.csv");
            run("Clear Results");
        }

        // Save Log Parameters Report
        if (isOpen("Log")) {
            selectWindow("Log");
            saveAs("Text", dir + "Heatmap_Parameter_Log_Report.txt");
        }
        
        showMessage("Success!", "All analysis items saved smoothly to:\n" + dir);
    }
}

function getStackPixelValue(x, y, sliceIndex) {
    setSlice(sliceIndex + 1);
    return getPixel(x, y);
}