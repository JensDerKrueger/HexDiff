import SwiftUI

struct HexDiffView: View {

  @EnvironmentObject var viewModel: HexDiffViewModel

  var body: some View {
    ScrollView(.horizontal) {
      ScrollViewReader { proxy in
        VStack(alignment: .leading, spacing: 0) {
          headerRow()

          Divider()

          ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
              ForEach(viewModel.diffLines) { line in
                HexDiffLineView(line: line)
                  .id(line.id)
              }
            }
            .padding(8)
          }
        }
        .onChange(of: viewModel.selectedLineID) { _, newValue in
          guard let id = newValue else { return }
          proxy.scrollTo(id, anchor: .center)
        }
      }
    }
  }

  private func headerRow() -> some View {
    let addressWidth: CGFloat = 85
    let hexBlockWidth: CGFloat = 515
    let asciiBlockWidth: CGFloat = 265

    return HStack(spacing: 16) {
      HStack(spacing: 8) {
        Text("hexHeader.addrL")
          .frame(width: addressWidth, alignment: .leading)

        Text("hexHeader.hexL")
          .frame(width: hexBlockWidth, alignment: .leading)

        Text("hexHeader.asciiL")
          .frame(width: asciiBlockWidth, alignment: .leading)
      }
      .padding(.leading, 14)

      Divider()
        .frame(height: 14)

      HStack(spacing: 8) {
        Text("hexHeader.addrR")
          .frame(width: addressWidth, alignment: .leading)

        Text("hexHeader.hexR")
          .frame(width: hexBlockWidth, alignment: .leading)

        Text("hexHeader.asciiR")
          .frame(width: asciiBlockWidth, alignment: .leading)
      }
    }
    .font(.system(.caption, design: .monospaced))
    .foregroundColor(.secondary)
    .padding(.bottom, 2)
    .padding(.leading, 5)
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
