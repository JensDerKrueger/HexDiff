import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

  @EnvironmentObject var viewModel: HexDiffViewModel

  private enum ImportSide {
    case left
    case right
  }

  @State private var activeImportSide: ImportSide?
  @State private var isImportingFile: Bool = false

  @State private var isTargetedLeftDrop: Bool = false
  @State private var isTargetedRightDrop: Bool = false

  var body: some View {
    ZStack {
      mainContent
        .blur(radius: viewModel.isProcessing ? 2 : 0)
        .disabled(viewModel.isProcessing)

      if viewModel.isProcessing {
        overlayView
      }
    }
    .padding(16)
    .fileImporter(
      isPresented: $isImportingFile,
      allowedContentTypes: [UTType.data],
      allowsMultipleSelection: false
    ) { result in
      handleFileImport(result: result)
    }
  }

  private var mainContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("content.title")
        .font(.title)
        .bold()

      fileSelectionRow
      diffStatusRow

      if let error = viewModel.errorMessage {
        Text(error)
          .foregroundColor(.red)
          .font(.footnote)
      }

      Divider()

      if viewModel.leftData != nil && viewModel.rightData != nil {
        HexDiffView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        placeholderView
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      Divider()

      statusBar
    }
  }

  private var statusBar: some View {
    HStack {
      if let hover = viewModel.hoverStatus {
        Text(hover)
      } else {
        Text("status.ready")
      }
      Spacer()
    }
    .font(.footnote)
    .foregroundColor(.secondary)
  }

  private var overlayView: some View {
    ZStack {
      Color.black.opacity(0.25)
        .ignoresSafeArea()

      VStack(spacing: 12) {
        ProgressView()
        if let msg = viewModel.processingMessage {
          Text(msg)
            .font(.body)
        }
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(NSColor.windowBackgroundColor))
      )
      .shadow(radius: 10)
    }
  }

  private var fileSelectionRow: some View {
    HStack(spacing: 16) {
      dropZoneView(
        title: "filePicker.left.button",
        fileName: viewModel.leftURL?.lastPathComponent,
        isTargeted: $isTargetedLeftDrop,
        tapSide: .left,
        dropSide: .left
      )

      dropZoneView(
        title: "filePicker.right.button",
        fileName: viewModel.rightURL?.lastPathComponent,
        isTargeted: $isTargetedRightDrop,
        tapSide: .right,
        dropSide: .right
      )

      Spacer()
    }
  }

  private func dropZoneView(
    title: LocalizedStringKey,
    fileName: String?,
    isTargeted: Binding<Bool>,
    tapSide: ImportSide,
    dropSide: ImportSide
  ) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(
          isTargeted.wrappedValue ? Color.accentColor : Color.secondary,
          lineWidth: isTargeted.wrappedValue ? 2 : 1
        )
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(
              isTargeted.wrappedValue
              ? Color.accentColor.opacity(0.08)
              : Color.clear
            )
        )

      VStack(alignment: .leading, spacing: 2) {
        Button(action: {
          activeImportSide = tapSide
          isImportingFile = true
        }) {
          Text(title)
        }

        if let name = fileName {
          Text(name)
            .font(.footnote)
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        } else {
          Text("filePicker.drop.hint")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
    }
    .frame(minWidth: 260, minHeight: 44)
    .frame(maxHeight: 70)
    .onDrop(
      of: [UTType.fileURL],
      isTargeted: isTargeted,
      perform: { providers in
        handleDrop(providers: providers, isLeft: (dropSide == .left))
      }
    )
  }

  private var diffStatusRow: some View {
    HStack(spacing: 12) {
      Text("status.differences.count \(viewModel.differenceCount)")

      if viewModel.differenceCount > 0 {
        if let current = viewModel.currentDifferenceDisplayIndex {
          Text("status.current.difference \(current) \(viewModel.differenceCount)")
            .font(.footnote)
            .foregroundColor(.secondary)
        }

        Button("status.previousButton") {
          viewModel.goToPreviousDifference()
        }
        Button("status.nextButton") {
          viewModel.goToNextDifference()
        }
      }

      Spacer()

      if viewModel.leftData != nil || viewModel.rightData != nil {
        Button("status.closeBothButton") {
          viewModel.reset()
        }
      }
    }
    .font(.body)
  }

  private var placeholderView: some View {
    VStack {
      Spacer()
      Text("placeholder.noFiles")
        .foregroundColor(.secondary)
      Spacer()
    }
  }

  private func handleFileImport(result: Result<[URL], Error>) {
    defer {
      activeImportSide = nil
    }

    switch result {
      case .success(let urls):
        guard let url = urls.first, let side = activeImportSide else { return }
        switch side {
          case .left:
            viewModel.loadLeftFile(from: url)
          case .right:
            viewModel.loadRightFile(from: url)
        }
      case .failure(let error):
        viewModel.errorMessage =
        String(
          format: NSLocalizedString("error.fileImporter",
                                    comment: "Error selecting file"),
          error.localizedDescription
        )
    }
  }

  private func handleDrop(
    providers: [NSItemProvider],
    isLeft: Bool
  ) -> Bool {
    guard let provider = providers.first(where: {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }) else {
      return false
    }

    provider.loadItem(
      forTypeIdentifier: UTType.fileURL.identifier,
      options: nil
    ) { item, error in
      if let error = error {
        DispatchQueue.main.async {
          viewModel.errorMessage =
          String(
            format: NSLocalizedString("error.drop",
                                      comment: "Error during drop"),
            error.localizedDescription
          )
        }
        return
      }

      var url: URL?

      if let data = item as? Data {
        url = URL(dataRepresentation: data, relativeTo: nil)
      } else if let droppedURL = item as? URL {
        url = droppedURL
      }

      guard let fileURL = url else { return }

      DispatchQueue.main.async {
        if isLeft {
          viewModel.loadLeftFile(from: fileURL)
        } else {
          viewModel.loadRightFile(from: fileURL)
        }
      }
    }

    return true
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
