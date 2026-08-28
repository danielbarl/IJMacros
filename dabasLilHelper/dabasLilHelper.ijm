/**
 * DEFINE FUNCTIONS
 */

function setColors(color1, color2, color3, color4) {
 	// Set color for channel 1 if provided
    if (color1 != "") {
        Stack.setChannel(1);
        run(color1);
    }
    // Set color for channel 2 if provided
    if (color2 != "") {
        Stack.setChannel(2);
        run(color2);
    }
    // Set color for channel 3 if provided
    if (color3 != "") {
        Stack.setChannel(3);
        run(color3);
    }
    // Set color for channel 4 if provided
    if (color4 != "") {
        Stack.setChannel(4);
        run(color4);
    }
}

function saveOpenImages(openWindows, saveFormat) {
    getMinAndMax(min, max);
    saveAs(saveFormat, exportPath + openWindows[i]);
    print("Image saved.");
    // Initialize the log file if it doesn't exist
	if (!File.exists(logFilePath)) {
        header = "Image Name, Min-Max Values\n";
        File.saveString(header, logFilePath);
        print("Initialized logfile in " + logFilePath);
    } else {
        print("Using existing logfile: " + logFilePath);
    }
    // Append the image name and min-max values to the log file
    File.append(openWindows[i] + ", " + min + "-" + max, logFilePath);
    print("Logged to " + logFilePath);
}

function saveVideos(openWindows) {
    run("AVI... ", "compression=JPEG frame=7 save=" + exportPath + openWindows[i] + ".avi");
    print("Video saved as: " + filePath);
}

function saveAllChannels(currentImage) {
	getDimensions(width, height, channels, slices, frames);
	// Initialize the log file if it doesn't exist
    if (!File.exists(logFilePath)) {
        header = "Image Name, Channel, Min-Max Values\n";
        File.saveString(header, logFilePath);
        print("Initialized logfile in " + logFilePath);
    } else {
        print("Using existing logfile: " + logFilePath);
    }
	// Iterate through channels
	for (c=1; c<= channels; c++) {
		 // Set the active channel string with 1 for the current channel, 0 for others
        activeChannels = "";
        for (j = 1; j <= channels; j++) {
            if (j == c) {
                activeChannels += "1"; // Active channel
            } else {
                activeChannels += "0"; // Non-active channel
            }
        }
        Stack.setActiveChannels(activeChannels); // Set only the current channel as visible
        print("Displaying channels: " + activeChannels);
		Stack.setChannel(c);
		getMinAndMax(min, max);
		filename = currentImage + "-Ch" + c;
		saveAs("PNG", exportPath + filename);
		print("Channel " + c + " saved as: " + filename + ".png");		
    	// Append the image name, channel, and min-max values to the log file
        File.append(filename + ", " + min + "-" + max, logFilePath);
        print("Logged to " + logFilePath + " for Channel " + c);
	}
}

function autoHiLoImage(title, lowPct, highPct, ignoreZero) {
    selectWindow(title);
    if (bitDepth() != 16) { print("skipped (not 16-bit): " + title); return; }

    getDimensions(w, h, nc, nz, nt);
    isStack = (nSlices > 1);
    if (isStack) Stack.getPosition(cc, cz, ct);
    else { cc = 1; cz = 1; ct = 1; }

    for (c = 1; c <= nc; c++) {
        if (isStack) Stack.setChannel(c);
        autoHiLo(c, nz, nt, isStack, lowPct, highPct, ignoreZero);
    }

    if (isStack) Stack.setPosition(cc, cz, ct);
}

// Sets min/max + HiLo LUT for channel c of the active image.
function autoHiLo(c, nz, nt, isStack, lowPct, highPct, ignoreZero) {
    nBins = 65536;

    // pass 1: bound the value range for this channel only
    gmin = 65535; gmax = 0;
    for (z = 1; z <= nz; z++) {
        for (t = 1; t <= nt; t++) {
            if (isStack) Stack.setPosition(c, z, t);
            getRawStatistics(a, mean, smin, smax, sd);
            if (smin < gmin) gmin = smin;
            if (smax > gmax) gmax = smax;
        }
    }
	lo = floor(gmin);
    hi = floor(gmax);
    if (hi < gmax) hi = hi + 1;
    if (hi > 65535) hi = 65535;
    if (hi <= lo) return;

    // pass 2: pooled histogram over the channel
    hist = newArray(nBins);
    for (z = 1; z <= nz; z++) {
        for (t = 1; t <= nt; t++) {
            if (isStack) Stack.setPosition(c, z, t);
            getHistogram(vals, hh, nBins);
            for (j = lo; j <= hi; j++) hist[j] += hh[j];
        }
    }
    if (ignoreZero) { hist[0] = 0; if (lo < 1) lo = 1; }

    total = 0;
    for (j = lo; j <= hi; j++) total += hist[j];
    if (total == 0) return;

    nLow  = total * lowPct  / 100;
    nHigh = total * highPct / 100;

    cnt = 0; dmin = lo;
    for (j = lo; j <= hi; j++) { cnt += hist[j]; if (cnt >= nLow)  { dmin = j; break; } }
    cnt = 0; dmax = hi;
    for (j = hi; j >= lo; j--) { cnt += hist[j]; if (cnt >= nHigh) { dmax = j; break; } }
    if (dmax <= dmin) dmax = dmin + 1;

    setMinAndMax(dmin, dmax);
    run("HiLo");
}

function closeNonMipWindows() {
	var openWindowsMips = getList("image.titles");
	for (var y = 0; y < openWindowsMips.length; y++) {
		selectWindow(openWindowsMips[y]);
	    if (startsWith(openWindowsMips[y], "MAX_")) {
	    }else{
	      close();}
	}
}

function closeNonWBWindows() {
	var openWindows = getList("image.titles");
	for (var z = 0; z < openWindows.length; z++) {
		selectWindow(openWindows[z]);
	    if (endsWith(openWindows[z], "balance")) {
	    }else{
	      close();}
	}
}

function generateMarketingData() {
	currentImage = getTitle();
	//saveAs("tiff", exportPath + currentImage);
	Stack.getPosition(channel, slice, frame);
	getDimensions(width, height, channels, slices, frames);
	run("Duplicate...", "duplicate slices=" + slice);
	run("Size...", "width=1250 height=1250 depth="+ channels +" constrain average interpolation=Bilinear");
    run("Scale Bar...", "width=300 height=12 thickness=12 font=0 bold overlay");
	// Create a string of "1"s for all channels
	activeChannelString = "";
	for (i = 0; i < channels; i++) {
    	activeChannelString += "1";
	}
	// Set all channels active
	Stack.setActiveChannels(activeChannelString);
	if (!File.exists(exportPath)) {
    	File.makeDirectory(exportPath);
	}
	saveAs("png", exportPath + currentImage + "+S" + slice);
    saveAllChannels(currentImage);
}

function cleanUpBlazeImageNames() {
	title = getTitle();
	if (startsWith(title, "Blaze_")) {
		title = replace(title, "^Blaze_", "");
		title = replace(title, "_[0-9]{6}.*$", "");
		rename(title);
	}
}

function saveMergeAndChannels(currentImage, channelSelection) {
    getDimensions(width, height, channels, slices, frames);

    // Initialize the log file if it doesn't exist
    if (!File.exists(logFilePath)) {
        header = "Image Name, Channel, Min-Max Values\n";
        File.saveString(header, logFilePath);
        print("Initialized logfile in " + logFilePath);
    } else {
        print("Using existing logfile: " + logFilePath);
    }

    // Convert channelSelection integer to a zero-padded string (e.g. 110 -> "110")
    channelSelectionStr = "" + channelSelection;
    while (lengthOf(channelSelectionStr) < channels) {
        channelSelectionStr = "0" + channelSelectionStr;
    }

    // --- Save individual channels and log min-max values ---
    for (c = 1; c <= channels; c++) {
        activeChannels = "";
        for (j = 1; j <= channels; j++) {
            if (j == c) {
                activeChannels += "1";
            } else {
                activeChannels += "0";
            }
        }
        Stack.setActiveChannels(activeChannels);
        print("Displaying channels: " + activeChannels);
        Stack.setChannel(c);
        getMinAndMax(min, max);
        filename = currentImage + "-Ch" + c;
        saveAs("PNG", exportPath + filename);
        print("Channel " + c + " saved as: " + filename + ".png");
        File.append(filename + ", " + min + "-" + max, logFilePath);
        print("Logged to " + logFilePath + " for Channel " + c);
    }

    // --- Save merge of selected channels (no logging) ---
    Stack.setActiveChannels(channelSelectionStr);
    print("Displaying merge channels: " + channelSelectionStr);
    mergeFilename = currentImage + "-MERGE_" + channelSelectionStr;
    saveAs("PNG", exportPath + mergeFilename);
    print("Merge saved as: " + mergeFilename + ".png");

    // Restore all channels visible
    allActive = "";
    for (j = 1; j <= channels; j++) allActive += "1";
    Stack.setActiveChannels(allActive);
    rename(currentImage);
}

/*
 * DEFINE VARIABLES
 */

// Path for export
exportPath = "E:/Export/";
//exportPath = getDirectory("Choose export path: " + exportPath);

// Path for logging gray values
logFilePath = exportPath + "grayValues.txt";

/*
 * ITERATE THROUGH ALL OPEN IMAGES
 */

openWindows = getList("image.titles");

// Create array of all open Mips
openMips = newArray();

//generateMarketingData();

for (i = 0; i < lengthOf(openWindows); i++) {
    if (startsWith(openWindows[i], "MAX")) {
        openMips = Array.concat(openMips, openWindows[i]);
    }
}

for (var i = 0; i < openWindows.length; i++) {
    selectWindow(openWindows[i]);
    cleanUpBlazeImageNames();
	//roiManager("Select", 0);
	//setColors("Cyan", "Red", "Yellow", "Grays");
	//setColors("Grays", "Grays", "Grays", "Grays");
	//setColors("Red", "Yellow", "Grays", "");
	//Stack.setActiveChannels("1000");
	//Stack.setChannel(1);
	//rename("WP06-" + (i + 1) + "-Overview");
	//rename("X91-1");
	
	//saveOpenImages(openWindows, "PNG");
	//saveVideos(openWindows);
	//saveAllChannels(openWindows[i]);
	//saveMergeAndChannels(openWindows[i], 1110);
    
	// Create MIP
	//run("Z Project...", "projection=[Max Intensity]");
	//closeNonMipWindows();
	
	//autoHiLoImage(openWindows[i], 0.0005, 0.1, true);
    
    // Insert Scale bar (optional)
    //run("Scale Bar...", "width=500 height=0 thickness=20 font=60 bold overlay");

    // Set contrast automatically
    //run("Enhance Contrast", "saturated=0.35");

	// Change image type to RGB
	//run("RGB Color");
	
	// White Balance of RGB images
	//roiManager("Select", 0);
	//run("IJP White Balance...", "averaging=Median");
	//closeNonWBWindows();
}
