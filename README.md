# HexDiff for macOS

**HexDiff** is a lightweight, high-performance macOS application for inspecting binary differences between two files. It displays both files side by side in a classic hex-editor layout (hex + ASCII) and highlights every changed, inserted, or removed byte. The tool is optimized for clarity, speed, and large datasets, making it suitable for research, debugging, digital forensics, and low-level systems analysis.

HexDiff was developed by the  
**Computer Graphics and Visualization Group (CGVis)**  
University of Duisburg-Essen  
https://www.cgvis.de

---

## Features

- **Side-by-side hex comparison**  
  Displays both input files in parallel (left/right), each showing:
  - hexadecimal bytes  
  - ASCII representation  
  - address offsets

- **Difference highlighting**  
  - Changed bytes  
  - Inserted bytes  
  - Removed bytes  
  Only rows containing differences are shown, keeping the view compact and focused.

- **Navigation between differences**  
  Quickly jump to the previous or next differing line.

- **Performance-aware diff engine**
  - Processes files asynchronously  
  - Shows a progress overlay during analysis  
  - Automatically aborts detailed diffing when the number of differing lines exceeds a configurable threshold

- **Drag & Drop support**  
  Drop files directly onto the selection targets.

- **Fully sandbox-compatible**  
  Works with macOS security-scoped bookmarks when opening external files.

- **Localized UI**  
  Supports English and German so far.
---

## Build Requirements

- **Xcode 15 or later**
- **macOS 13+ (Ventura)**
- Swift & SwiftUI

The project uses:
- `SwiftUI` for the UI  
- `Combine` for state propagation  
- `Data.difference(from:)` for byte-level diffing

---

## How to Use

1. Launch HexDiff.
2. Select the left and right file via:
   - the file selection buttons, or  
   - Drag & Drop onto the drop targets.
3. The application analyzes both files and displays:
   - total number of differing lines  
   - a detailed hex/ASCII diff (if below threshold)
4. Use **Next** and **Previous** to navigate through differences.
5. Use **Close both files** to reset the application.
