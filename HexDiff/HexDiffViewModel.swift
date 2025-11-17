import Foundation
import Combine

enum HoverSide {
  case left
  case right
}

/// Art des Unterschieds zwischen zwei Bytes.
enum DiffKind {
  case equal
  case changed
  case inserted
  case removed
}

/// Diff-Information für eine einzelne Byte-Position (links/rechts).
struct ByteDiff {
  let leftIndex: Int?
  let rightIndex: Int?

  let leftByte: UInt8?
  let rightByte: UInt8?

  let kind: DiffKind
}

/// Eine Zeile mit bis zu 16 Bytes links/rechts.
struct DiffLine: Identifiable {
  let id: Int
  let lineOffsetLeft: Int?
  let lineOffsetRight: Int?
  let cells: [ByteDiff]
}

enum DiffEngine {

  private static let maxLookahead = 100

  static func makeDiffLines(
    left: Data,
    right: Data,
    bytesPerLine: Int = 16,
    differenceLineLimit: Int? = nil
  ) -> (lines: [DiffLine], hitLimit: Bool) {
    let leftBytes = [UInt8](left)
    let rightBytes = [UInt8](right)

    let leftCount = leftBytes.count
    let rightCount = rightBytes.count

    if leftCount == 0 && rightCount == 0 {
      return ([], false)
    }

    var lines: [DiffLine] = []
    var hitLimit = false

    var lineId = 0

    var iL = 0
    var iR = 0

    while iL < leftCount || iR < rightCount {
      var cells: [ByteDiff] = []
      cells.reserveCapacity(bytesPerLine)
      var hasDifferenceInLine = false

      while cells.count < bytesPerLine && (iL < leftCount || iR < rightCount) {
        let leftAvailable = iL < leftCount
        let rightAvailable = iR < rightCount

        let leftByte = leftAvailable ? leftBytes[iL] : nil
        let rightByte = rightAvailable ? rightBytes[iR] : nil

        let cell: ByteDiff

        if let l = leftByte, let r = rightByte {
          if l == r {
            cell = ByteDiff(
              leftIndex: iL,
              rightIndex: iR,
              leftByte: l,
              rightByte: r,
              kind: .equal
            )
            iL += 1
            iR += 1
          } else {
            var leftAheadMatches = false
            var rightAheadMatches = false

            let maxLookL = min(DiffEngine.maxLookahead, leftCount - iL - 1)
            let maxLookR = min(DiffEngine.maxLookahead, rightCount - iR - 1)

            var j = 1
            while j <= maxLookL || j <= maxLookR {
              if j <= maxLookL, !leftAheadMatches {
                if leftBytes[iL + j] == r {
                  leftAheadMatches = true
                }
              }
              if j <= maxLookR, !rightAheadMatches {
                if rightBytes[iR + j] == l {
                  rightAheadMatches = true
                }
              }
              if leftAheadMatches && rightAheadMatches {
                break
              }
              j += 1
            }

            if leftAheadMatches && !rightAheadMatches {
              cell = ByteDiff(
                leftIndex: iL,
                rightIndex: nil,
                leftByte: l,
                rightByte: nil,
                kind: .removed
              )
              iL += 1
            } else if rightAheadMatches && !leftAheadMatches {
              cell = ByteDiff(
                leftIndex: nil,
                rightIndex: iR,
                leftByte: nil,
                rightByte: r,
                kind: .inserted
              )
              iR += 1
            } else {
              cell = ByteDiff(
                leftIndex: iL,
                rightIndex: iR,
                leftByte: l,
                rightByte: r,
                kind: .changed
              )
              iL += 1
              iR += 1
            }
          }
        } else if let l = leftByte {
          cell = ByteDiff(
            leftIndex: iL,
            rightIndex: nil,
            leftByte: l,
            rightByte: nil,
            kind: .removed
          )
          iL += 1
        } else if let r = rightByte {
          cell = ByteDiff(
            leftIndex: nil,
            rightIndex: iR,
            leftByte: nil,
            rightByte: r,
            kind: .inserted
          )
          iR += 1
        } else {
          break
        }

        if cell.kind != .equal {
          hasDifferenceInLine = true
        }

        cells.append(cell)
      }

      if hasDifferenceInLine {
        let leftOffsets = cells.compactMap { $0.leftIndex }
        let rightOffsets = cells.compactMap { $0.rightIndex }

        let line = DiffLine(
          id: lineId,
          lineOffsetLeft: leftOffsets.min(),
          lineOffsetRight: rightOffsets.min(),
          cells: cells
        )
        lines.append(line)

        if let limit = differenceLineLimit,
           lines.count > limit {
          hitLimit = true
          break
        }
      }

      lineId += 1

      if !(iL < leftCount || iR < rightCount) {
        break
      }
    }

    return (lines, hitLimit)
  }
}

final class HexDiffViewModel: ObservableObject {

  @Published var leftURL: URL?
  @Published var rightURL: URL?

  @Published var leftData: Data?
  @Published var rightData: Data?

  @Published var diffLines: [DiffLine] = []

  @Published var errorMessage: String?

  @Published var currentDifferenceIndex: Int?

  @Published var isProcessing: Bool = false
  @Published var processingMessage: String? = nil

  @Published var hoverStatus: String? = nil

  private let differenceLineLimit = 1000

  var differenceCount: Int {
    diffLines.count
  }

  var currentDifferenceDisplayIndex: Int? {
    guard let idx = currentDifferenceIndex else { return nil }
    return idx + 1
  }

  var selectedLineID: Int? {
    guard let idx = currentDifferenceIndex,
          idx >= 0,
          idx < diffLines.count else {
      return nil
    }
    return diffLines[idx].id
  }

  func loadLeftFile(from url: URL) {
    loadFile(from: url, isLeft: true)
  }

  func loadRightFile(from url: URL) {
    loadFile(from: url, isLeft: false)
  }

  private func loadFile(from url: URL, isLeft: Bool) {
    DispatchQueue.main.async {
      self.isProcessing = true
      self.processingMessage = NSLocalizedString(
        "processing.loading",
        comment: "Status message while file is being loaded and analyzed"
      )
      self.errorMessage = nil
    }

    let isLeftLocal = isLeft

    DispatchQueue.global(qos: .userInitiated).async {
      let needsStop = url.startAccessingSecurityScopedResource()
      defer {
        if needsStop {
          url.stopAccessingSecurityScopedResource()
        }
      }

      do {
        let data = try Data(contentsOf: url)

        DispatchQueue.main.async {
          if isLeftLocal {
            self.leftURL = url
            self.leftData = data
          } else {
            self.rightURL = url
            self.rightData = data
          }

          self.recomputeDiffAsync()
        }
      } catch {
        DispatchQueue.main.async {
          self.errorMessage = String(
            format: NSLocalizedString(
              "error.fileLoad",
              comment: "Error while loading a file"
            ),
            error.localizedDescription
          )
          self.isProcessing = false
          self.processingMessage = nil
        }
      }
    }
  }

  private func recomputeDiffAsync() {
    guard let leftData = leftData, let rightData = rightData else {
      diffLines = []
      currentDifferenceIndex = nil
      isProcessing = false
      processingMessage = nil
      return
    }

    let left = leftData
    let right = rightData

    processingMessage = NSLocalizedString(
      "processing.diff",
      comment: "Status message while differences are being analyzed"
    )

    DispatchQueue.global(qos: .userInitiated).async {
      let result = DiffEngine.makeDiffLines(
        left: left,
        right: right,
        bytesPerLine: 16,
        differenceLineLimit: self.differenceLineLimit
      )

      DispatchQueue.main.async {
        if result.hitLimit {
          self.diffLines = []
          self.currentDifferenceIndex = nil
          self.errorMessage = String(
            format: NSLocalizedString(
              "error.tooManyDifferences",
              comment: "Message shown when too many differing lines exist"
            ),
            self.differenceLineLimit
          )
        } else {
          self.diffLines = result.lines
          self.currentDifferenceIndex =
          result.lines.isEmpty ? nil : 0
          self.errorMessage = nil
        }

        self.isProcessing = false
        self.processingMessage = nil
      }
    }
  }

  func goToNextDifference() {
    guard !diffLines.isEmpty else { return }
    if let current = currentDifferenceIndex {
      currentDifferenceIndex = (current + 1) % diffLines.count
    } else {
      currentDifferenceIndex = 0
    }
  }

  func goToPreviousDifference() {
    guard !diffLines.isEmpty else { return }
    if let current = currentDifferenceIndex {
      let next = (current - 1 + diffLines.count) % diffLines.count
      currentDifferenceIndex = next
    } else {
      currentDifferenceIndex = 0
    }
  }

  func setHoveredOffset(side: HoverSide?, offset: Int?) {
    guard let side = side, let offset = offset else {
      hoverStatus = nil
      return
    }

    let address = HexFormatting.addressString(for: offset)
    let key: String
    switch side {
      case .left:
        key = "status.hover.left %@"   // Left: %@
      case .right:
        key = "status.hover.right %@"
    }
    let format = NSLocalizedString(
      key,
      comment: "Status bar hover address"
    )
    hoverStatus = String(format: format, address)
  }

  func reset() {
    leftURL = nil
    rightURL = nil
    leftData = nil
    rightData = nil
    diffLines = []
    errorMessage = nil
    currentDifferenceIndex = nil
    isProcessing = false
    processingMessage = nil
    hoverStatus = nil
  }
}

/*
 Copyright (c) 2025 Computer Graphics and Visualization Group, University of
 Duisburg-Essen

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in the
 Software without restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
 Software, and to permit persons to whom the Software is furnished to do so, subject
 to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
