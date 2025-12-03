//
//  LicensesView.swift
//  ocr_util
//
//  Shows required third-party license notices.
//

import SwiftUI

struct LicensesView: View {
    private let rapidOcrMITText: String = """
    RapidOCR License (MIT)

    MIT License

    Copyright (c) RapidAI

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    Source:
    RapidOCR GitHub MIT License
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Licenses")
                .font(.title2)
                .bold()

            Divider()

            ScrollView {
                Text(rapidOcrMITText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 400)
    }
}

#Preview {
    LicensesView()
        .frame(width: 520, height: 400)
}


