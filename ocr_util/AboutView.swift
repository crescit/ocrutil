//
//  AboutView.swift
//  ocr_util
//
//  Static About / Privacy information window.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                Text("About This App")
                    .font(.title2)
                    .bold()

                Text("App Version: 1.0")
                Text("Developer: Trabajo Mofeta")

                Text("This app provides fast, fully local OCR (text extraction) from user-selected regions of the screen. No data ever leaves your device.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Group {
                Text("Privacy")
                    .font(.title3)
                    .bold()

                Text("All OCR processing happens on your Mac only using an offline OCR engine.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("No images, text, or usage data are sent to any server.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("The app does not store, collect, or transmit any personal information.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("The app only captures the region you manually select, and never performs automatic or background screen capture.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Group {
                Text("Technology")
                    .font(.title3)
                    .bold()

                Text("This app uses the RapidOCR engine for on-device text recognition.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("RapidOCR is MIT-licensed.")
                Text("No model downloads are required after installation.")
            }

            Divider()

            Group {
                Text("Support")
                    .font(.title3)
                    .bold()

                Text("If you encounter issues, contact: (your email)")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 360)
    }
}

#Preview {
    AboutView()
        .frame(width: 420, height: 360)
}


