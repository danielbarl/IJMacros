/*
 * DEFINE VARIABLES
 */

// Path for export
var exportPath = "D:/Export/";
//exportPath = getDirectory("Choose export path: " + exportPath);

// true  = LSFM naming: [MAX_]<ID>_<Acquisition>[_SB<n>um]_<Channel>_<min>-<max>.png
//         channel names come from <ID>_channels.txt (created and opened if missing)
// false = plain naming (window name + -Ch<n>), e.g. to white balance macro images
var LSFM_nameformatting = true;

/*
 * ITERATE THROUGH ALL OPEN IMAGES
 */

openWindows = getList("image.titles");

for (i = 0; i < openWindows.length; i++) {
    selectWindow(openWindows[i]);
    //cleanUpBlazeImageNames();

    // Set contrast automatically
    //run("Enhance Contrast", "saturated=0.35");
    //autoHiLoImage(openWindows[i], 0.05, 0.1, true);

    //setColors("Cyan", "Red", "Yellow", "Grays");
    //setColors("Grays", "Grays", "Grays", "Grays");
    //setColors("Red", "Grays", "", "");
    //Stack.setActiveChannels("10");
    //Stack.setChannel(2);

    //rename("WP06-" + (i + 1) + "-Overview");
    //rename("X91-1");

    //saveOpenImages(openWindows, "PNG");
    //saveVideos(openWindows);
    //saveAllChannels(openWindows[i]);
    //saveMergeAndChannels(openWindows[i], 11);

    // Create MIP
    //run("Z Project...", "projection=[Max Intensity]");
    //closeNonMipWindows();

    // Scale bar in the file name (0 = none).
    var scaleBarUm = 500;
    // Insert Scale bar automatically
    if (scaleBarUm > 0) run("Scale Bar...", "width=" + scaleBarUm + " height=0 thickness=40 font=80 bold overlay");

    // Change image type to RGB
    //run("RGB Color");

    // White Balance of RGB images
    //roiManager("Select", 0);
    //run("IJP White Balance...", "averaging=Median");
    //closeNonWBWindows();
}

//generateMarketingData();

/**
 * DEFINE FUNCTIONS
 */

// Folder of the <ID>_channels.txt files
var channelDir = exportPath;

// shared between the helper functions below (var = global, so a value set in one function is visible in the next)
var sampleID = "";
var expID = "";
var acqName = "";
var baseName = "";
var lsfmName = "";
var cleanedLabel = "";
var chNames = newArray(10);


// Helpers below set global variables (ImageJ macro functions cannot return strings cleanly
// when called inside an expression). Call them, then read the globals.

// sets sampleID from the window name, e.g. X100-1
function getSampleId(title) {
    sampleID = "";
    if (matches(title, ".*X[0-9]+-[0-9]+.*")) sampleID = replace(title, ".*(X[0-9]+-[0-9]+).*", "$1");
}

// sets expID from the window name, e.g. X100
function getExpId(title) {
    getSampleId(title);
    expID = replace(sampleID, "-[0-9]+$", "");
}

// sets acqName (Overview, Details2, ...) from the window name; stops if there is none
function getAcquisition(title) {
    acqName = "";
    if (matches(title, ".*Overview.*")) acqName = "Overview";
    if (matches(title, ".*Details[0-9]*.*")) acqName = replace(title, ".*(Details[0-9]*).*", "$1");
    if (acqName == "") exit("No acquisition (Overview / Details) in window name: " + title);
}

// sets baseName = [MAX_]<ID>_<Acquisition>[_SB<n>um] for the window
function getBaseName(title) {
    getSampleId(title);
    getAcquisition(title);
    if (sampleID == "") exit("No sample ID (X100-1) in window name: " + title);
    baseName = "";
    if (startsWith(title, "MAX_")) baseName = "MAX_";
    baseName = baseName + sampleID + "_" + acqName;
    if (scaleBarUm > 0) baseName = baseName + "_SB" + d2s(scaleBarUm, 0) + "um";
}

// sets lsfmName = <[MAX_]<ID>_<Acq>[_SB]>_<Channel>_<min>-<max>
function getLsfmName(title, label, lo, hi) {
    getBaseName(title);
    lsfmName = baseName + "_" + label + "_" + d2s(lo, 0) + "-" + d2s(hi, 0);
}

// letters, digits and dashes only: underscores separate the fields of the file name
function cleanLabel(s) {
    cleanedLabel = replace(s, "[^A-Za-z0-9-]", "");
}

// true if the channel file already has a [acq] block
function hasChannelBlock(path, acq) {
    lines = split(File.openAsString(path), "\n");
    for (i = 0; i < lines.length; i++) {
        if (String.trim(lines[i]) == "[" + acq + "]") return true;
    }
    return false;
}

// adds a [acq] block with the channel numbers filled in (creates the file if needed)
function writeChannelBlock(path, acq, nCh) {
    block = "[" + acq + "]\n";
    for (c = 1; c <= nCh; c++) block = block + c + "=\n";
    block = block + "\n";
    if (File.exists(path)) {
        File.append(block, path);
    } else {
        header = "# Channel names for this experiment, one block per sample and acquisition.\n";
        header = header + "# Block name: [sample_acquisition], e.g. [X103-1_Details]\n";
        header = header + "# Several [headers] in a row share the names listed below them (same panel).\n";
        header = header + "# Fill in the names after the = : letters, digits and dashes only.\n";
        header = header + "# NOT allowed: underscores (_), spaces, dots or any other symbol.\n";
        header = header + "# Example: 1=NeuN-Vio667   2=AF   3=CD146-Vio570\n\n";
        File.saveString(header + block, path);
    }
}

// fills chNames[] for the block key; "" where a channel has no name yet.
// Consecutive [header] lines form a group, and the names below the group apply to all of them.
function readChannelNames(path, key, nCh) {
    chNames = newArray(nCh);
    for (c = 0; c < nCh; c++) chNames[c] = "";
    lines = split(File.openAsString(path), "\n");
    groupHas = false;   // the current header group contains key
    inNames = false;    // names have started after the current header group
    done = false;
    for (i = 0; i < lines.length && !done; i++) {
        line = String.trim(lines[i]);
        if (lengthOf(line) > 0 && !startsWith(line, "#")) {
            if (startsWith(line, "[")) {
                if (inNames) {
                    // a new group starts: the previous group was complete
                    if (groupHas) done = true;
                    groupHas = false;
                    inNames = false;
                }
                if (line == "[" + key + "]") groupHas = true;
            } else if (indexOf(line, "=") > 0) {
                inNames = true;
                if (groupHas) {
                    eq = indexOf(line, "=");
                    n = parseInt(substring(line, 0, eq));
                    if (!isNaN(n) && n >= 1 && n <= nCh) {
                        cleanLabel(String.trim(substring(line, eq + 1)));
                        chNames[n - 1] = cleanedLabel;
                    }
                }
            }
        }
    }
}

// opens the channel file in a text editor and stops, so the names are filled in before the next run
function editChannelFile(path, msg) {
    exec("notepad.exe", path);
    exit(msg + "\nFill in the channel names in:\n" + path + "\nthen run the macro again.");
}

// fills chNames[] for the window's sample and acquisition; opens the channel file if a block or name is missing
function channelNamesOf(title, nCh) {
    getExpId(title);
    getSampleId(title);
    getAcquisition(title);
    // one block per sample and acquisition, e.g. [X103-1 Details]: samples can carry different stainings
    blockKey = sampleID + "_" + acqName;
    // explicit "/" so the path is right even if channelDir lost its trailing slash
    if (!File.isDirectory(channelDir)) File.makeDirectory(channelDir);
    channelPath = channelDir + "/" + expID + "_channels.txt";
    // nested, not "||": ImageJ evaluates both sides of || and would read a missing file
    if (!File.exists(channelPath)) {
        writeChannelBlock(channelPath, blockKey, nCh);
        editChannelFile(channelPath, "Created " + expID + "_channels.txt.");
    }
    if (!hasChannelBlock(channelPath, blockKey)) {
        writeChannelBlock(channelPath, blockKey, nCh);
        editChannelFile(channelPath, "Added a block [" + blockKey + "] with " + nCh + " channels.");
    }
    readChannelNames(channelPath, blockKey, nCh);
    for (c = 0; c < nCh; c++) {
        if (chNames[c] == "") editChannelFile(channelPath, "Channel " + (c + 1) + " of [" + blockKey + "] has no name.");
    }
}

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
    if (LSFM_nameformatting) {
        getBaseName(openWindows[i]);
        saveAs(saveFormat, exportPath + baseName);
    } else {
        saveAs(saveFormat, exportPath + openWindows[i]);
    }
    print("Image saved.");
}

function saveVideos(openWindows) {
    if (LSFM_nameformatting) {
        getBaseName(openWindows[i]);
        run("AVI... ", "compression=JPEG frame=7 save=" + exportPath + baseName + ".avi");
    } else {
        run("AVI... ", "compression=JPEG frame=7 save=" + exportPath + openWindows[i] + ".avi");
    }
    print("Video saved as: " + filePath);
}

function saveAllChannels(currentImage) {
    getDimensions(width, height, channels, slices, frames);
    if (LSFM_nameformatting) channelNamesOf(currentImage, channels);
    // Iterate through channels
    for (c = 1; c <= channels; c++) {
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
        if (LSFM_nameformatting) {
            getLsfmName(currentImage, chNames[c - 1], min, max);
            filename = lsfmName;
        } else {
            filename = currentImage + "-Ch" + c;
        }
        saveAs("PNG", exportPath + filename);
        print("Channel " + c + " saved as: " + filename + ".png");
    }
    // Restore all channels visible
    allActive = "";
    for (j = 1; j <= channels; j++) allActive += "1";
    Stack.setActiveChannels(allActive);
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
        autoHiLo(c, cz, ct, isStack, lowPct, highPct, ignoreZero);
    }

    if (isStack) Stack.setPosition(cc, cz, ct);
}

// Sets min/max + HiLo LUT for channel c of the active image.
function autoHiLo(c, z, t, isStack, lowPct, highPct, ignoreZero) {
    nBins = 65536;

    // pass 1: bound the value range for this channel on this slice
    if (isStack) Stack.setPosition(c, z, t);
    getRawStatistics(a, mean, gmin, gmax, sd);

    lo = floor(gmin);
    hi = floor(gmax);
    if (hi < gmax) hi = hi + 1;
    if (hi > 65535) hi = 65535;
    if (hi <= lo) return;

    // pass 2: histogram of this slice
    getHistogram(vals, hist, nBins);
    if (ignoreZero) { hist[0] = 0; if (lo < 1) lo = 1; }

    total = 0;
    for (j = lo; j <= hi; j++) total += hist[j];
    if (total == 0) return;

    nLow = total * lowPct / 100;
    nHigh = total * highPct / 100;

    cnt = 0; dmin = lo;
    for (j = lo; j <= hi; j++) { cnt += hist[j]; if (cnt >= nLow) { dmin = j; break; } }
    cnt = 0; dmax = hi;
    for (j = hi; j >= lo; j--) { cnt += hist[j]; if (cnt >= nHigh) { dmax = j; break; } }
    if (dmax <= dmin) dmax = dmin + 1;

    setMinAndMax(dmin, dmax);
    run("HiLo");
}

function closeNonMipWindows() {
    openWindowsMips = getList("image.titles");
    for (y = 0; y < openWindowsMips.length; y++) {
        selectWindow(openWindowsMips[y]);
        if (startsWith(openWindowsMips[y], "MAX_")) {
        } else {
            close();
        }
    }
}

function closeNonWBWindows() {
    openWindows = getList("image.titles");
    for (z = 0; z < openWindows.length; z++) {
        selectWindow(openWindows[z]);
        if (endsWith(openWindows[z], "balance")) {
        } else {
            close();
        }
    }
}

function generateMarketingData() {
    currentImage = getTitle();
    //saveAs("tiff", exportPath + currentImage);
    Stack.getPosition(channel, slice, frame);
    getDimensions(width, height, channels, slices, frames);
    run("Duplicate...", "duplicate slices=" + slice);
    run("Size...", "width=1250 height=1250 depth=" + channels + " constrain average interpolation=Bilinear");
    if (scaleBarUm > 0) run("Scale Bar...", "width=" + scaleBarUm + " height=0 thickness=40 font=80 bold overlay");
    // Create a string of "1"s for all channels
    activeChannelString = "";
    for (ch = 0; ch < channels; ch++) {
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
    if (LSFM_nameformatting) channelNamesOf(currentImage, channels);

    // Convert channelSelection integer to a zero-padded string (e.g. 110 -> "110")
    channelSelectionStr = "" + channelSelection;
    while (lengthOf(channelSelectionStr) < channels) {
        channelSelectionStr = "0" + channelSelectionStr;
    }

    // --- Save individual channels ---
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
        if (LSFM_nameformatting) {
            getLsfmName(currentImage, chNames[c - 1], min, max);
            filename = lsfmName;
        } else {
            filename = currentImage + "-Ch" + c;
        }
        saveAs("PNG", exportPath + filename);
        print("Channel " + c + " saved as: " + filename + ".png");
    }

    // --- Save merge of selected channels (no gray range: it is a colour composite) ---
    Stack.setActiveChannels(channelSelectionStr);
    print("Displaying merge channels: " + channelSelectionStr);
    if (LSFM_nameformatting) {
        getBaseName(currentImage);
        mergeFilename = baseName + "_Merge" + channelSelectionStr;
    } else {
        mergeFilename = currentImage + "-MERGE_" + channelSelectionStr;
    }
    saveAs("PNG", exportPath + mergeFilename);
    print("Merge saved as: " + mergeFilename + ".png");

    // Restore all channels visible
    allActive = "";
    for (j = 1; j <= channels; j++) allActive += "1";
    Stack.setActiveChannels(allActive);
    rename(currentImage);
}
