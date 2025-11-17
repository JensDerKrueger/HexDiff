import Foundation

enum HexFormatting {

  static func addressString(for index: Int?) -> String {
    guard let index else { return "        " }
    return String(format: "%08X", index)
  }

  static func hexString(for byte: UInt8?) -> String {
    guard let byte else { return "  " }
    return String(format: "%02X", byte)
  }

  static func asciiString(for byte: UInt8?) -> String {
    guard let byte else { return " " }
    let scalarValue = UInt32(byte)
    if let scalar = Unicode.Scalar(scalarValue),
       scalar.isASCII,
       scalarValue >= 0x20,
       scalarValue <= 0x7E {
      return String(Character(scalar))
    } else {
      return "."
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
