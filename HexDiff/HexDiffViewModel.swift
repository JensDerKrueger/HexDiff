import Foundation
import Combine

enum DiffKind {
  case equal
  case changed
  case inserted
  case removed
}

struct ByteDiff {
  let leftIndex: Int?
  let rightIndex: Int?

  let leftByte: UInt8?
  let rightByte: UInt8?

  let kind: DiffKind
}

struct DiffLine: Identifiable {
  let id: Int

  let lineOffsetLeft: Int?
  let lineOffsetRight: Int?

  let cells: [ByteDiff]
}

enum DiffEngine {

  static func makeByteDiffs(left: Data, right: Data) -> [ByteDiff] {
    let leftBytes = [UInt8](left)
    let rightBytes = [UInt8](right)

    let difference = rightBytes.difference(from: leftBytes)

    var insertedOffsets = Set<Int>()
    var removedOffsets = Set<Int>()

    for change in difference {
      switch change {
        case .insert(let offset, _, _):
          insertedOffsets.insert(offset)
        case .remove(let offset, _, _):
          removedOffsets.insert(offset)
      }
    }

    var results: [ByteDiff] = []
    results.reserveCapacity(max(leftBytes.count, rightBytes.count))

    var indexLeft = 0
    var indexRight = 0

    while indexLeft < leftBytes.count || indexRight < rightBytes.count {
      let leftAvailable = indexLeft < leftBytes.count
      let rightAvailable = indexRight < rightBytes.count

      let isRemoved = leftAvailable && removedOffsets.contains(indexLeft)
      let isInserted = rightAvailable && insertedOffsets.contains(indexRight)

      if isRemoved && !isInserted {
        let diff = ByteDiff(
          leftIndex: indexLeft,
          rightIndex: nil,
          leftByte: leftBytes[indexLeft],
          rightByte: nil,
          kind: .removed
        )
        results.append(diff)
        indexLeft += 1
      } else if isInserted && !isRemoved {
        let diff = ByteDiff(
          leftIndex: nil,
          rightIndex: indexRight,
          leftByte: nil,
          rightByte: rightBytes[indexRight],
          kind: .inserted
        )
        results.append(diff)
        indexRight += 1
      } else if leftAvailable && rightAvailable {
        let leftByte = leftBytes[indexLeft]
        let rightByte = rightBytes[indexRight]

        let kind: DiffKind = (leftByte == rightByte) ? .equal : .changed

        let diff = ByteDiff(
          leftIndex: indexLeft,
          rightIndex: indexRight,
          leftByte: leftByte,
          rightByte: rightByte,
          kind: kind
        )
        results.append(diff)

        indexLeft += 1
        indexRight += 1
      } else if leftAvailable {
        let diff = ByteDiff(
          leftIndex: indexLeft,
          rightIndex: nil,
          leftByte: leftBytes[indexLeft],
          rightByte: nil,
          kind: .removed
        )
        results.append(diff)
        indexLeft += 1
      } else if rightAvailable {
        let diff = ByteDiff(
          leftIndex: nil,
          rightIndex: indexRight,
          leftByte: nil,
          rightByte: rightBytes[indexRight],
          kind: .inserted
        )
        results.append(diff)
        indexRight += 1
      }
    }

    return results
  }

  static func makeDiffLines(
    left: Data,
    right: Data,
    bytesPerLine: Int = 16,
    differenceLineLimit: Int? = nil
  ) -> (lines: [DiffLine], hitLimit: Bool) {
    let byteDiffs = makeByteDiffs(left: left, right: right)
    guard !byteDiffs.isEmpty else { return ([], false) }

    let totalLines = (byteDiffs.count + bytesPerLine - 1) / bytesPerLine
    var lines: [DiffLine] = []
    lines.reserveCapacity(min(totalLines, differenceLineLimit ?? totalLines))

    for lineIndex in 0..<totalLines {
      let start = lineIndex * bytesPerLine
      let end = min(start + bytesPerLine, byteDiffs.count)
      let slice = Array(byteDiffs[start..<end])

      let hasDifference = slice.contains { $0.kind != .equal }
      if !hasDifference {
        continue
      }

      let leftOffsets = slice.compactMap { $0.leftIndex }
      let rightOffsets = slice.compactMap { $0.rightIndex }

      let line = DiffLine(
        id: lineIndex,
        lineOffsetLeft: leftOffsets.min(),
        lineOffsetRight: rightOffsets.min(),
        cells: slice
      )

      lines.append(line)

      if let limit = differenceLineLimit,
         lines.count > limit {
        return (lines, true)
      }
    }

    return (lines, false)
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
