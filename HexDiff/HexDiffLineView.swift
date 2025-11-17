import SwiftUI

struct HexDiffLineView: View {

  @EnvironmentObject var viewModel: HexDiffViewModel

  let line: DiffLine

  var body: some View {
    HStack(spacing: 16) {
      sideView(
        baseAddress: line.lineOffsetLeft,
        cells: line.cells,
        side: .left
      )

      Divider()
        .frame(height: 14)

      sideView(
        baseAddress: line.lineOffsetRight,
        cells: line.cells,
        side: .right
      )
    }
    .font(.system(.body, design: .monospaced))
    .padding(.horizontal, 4)
    .padding(.vertical, 1)
  }

  private func sideView(
    baseAddress: Int?,
    cells: [ByteDiff],
    side: HoverSide
  ) -> some View {
    HStack(spacing: 8) {
      Text(HexFormatting.addressString(for: baseAddress))
        .frame(width: 85, alignment: .leading)

      HStack(spacing: 4) {
        ForEach(Array(0..<16), id: \.self) { (index: Int) in
          let result: (byte: UInt8?, offset: Int?, kind: DiffKind) = {
            if index < cells.count {
              let diff = cells[index]
              switch side {
                case .left:
                  return (diff.leftByte, diff.leftIndex, diff.kind)
                case .right:
                  return (diff.rightByte, diff.rightIndex, diff.kind)
              }
            } else {
              return (nil, nil, .equal)
            }
          }()

          let byte = result.byte
          let offset = result.offset
          let kind = result.kind

          Text(HexFormatting.hexString(for: byte))
            .frame(width: 24, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(cellBackgroundColor(byte: byte, kind: kind))
            .cornerRadius(3)
            .onHover { inside in
              if inside {
                viewModel.setHoveredOffset(side: side, offset: offset)
              } else {
                viewModel.setHoveredOffset(side: nil, offset: nil)
              }
            }
        }
      }

      Rectangle()
        .frame(width: 1)
        .foregroundColor(Color.secondary.opacity(0.4))

      HStack(spacing: 2) {
        ForEach(Array(0..<16), id: \.self) { (index: Int) in
          let result: (byte: UInt8?, offset: Int?, kind: DiffKind) = {
            if index < cells.count {
              let diff = cells[index]
              switch side {
                case .left:
                  return (diff.leftByte, diff.leftIndex, diff.kind)
                case .right:
                  return (diff.rightByte, diff.rightIndex, diff.kind)
              }
            } else {
              return (nil, nil, .equal)
            }
          }()

          let byte = result.byte
          let offset = result.offset
          let kind = result.kind

          Text(HexFormatting.asciiString(for: byte))
            .frame(width: 11, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(cellBackgroundColor(byte: byte, kind: kind))
            .cornerRadius(3)
            .onHover { inside in
              if inside {
                viewModel.setHoveredOffset(side: side, offset: offset)
              } else {
                viewModel.setHoveredOffset(side: nil, offset: nil)
              }
            }
        }
      }
    }
  }

  private func cellBackgroundColor(byte: UInt8?, kind: DiffKind) -> Color {
    guard byte != nil else { return Color.clear }

    switch kind {
      case .equal:
        return Color.clear
      case .changed:
        return Color.yellow.opacity(0.4)
      case .inserted:
        return Color.green.opacity(0.35)
      case .removed:
        return Color.red.opacity(0.35)
    }
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

