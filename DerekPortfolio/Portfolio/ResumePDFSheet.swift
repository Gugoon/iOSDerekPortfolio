//
//  ResumePDFSheet.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  이력서 PDF 미리보기. Flutter lib/widgets/resume_pdf_dialog.dart 자리.
//
//  웹은 브라우저 내장 뷰어에 미리보기를 맡겼고 모바일 브라우저에서는 기능을 감췄다.
//  네이티브 앱은 PDFKit 으로 바로 그리고, 공유 시트로 파일 저장·전송을 연다.
//  조판 결과는 시트가 열릴 때 한 번 받아 미리보기 · 공유 · 인쇄가 같은 문서를 쓴다.
//

import SwiftUI
import PDFKit

struct ResumePDFSheet: View {
    let content: SiteContent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutWidth) private var layoutWidth

    @State private var pdfData: Data?
    @State private var loadError: String?
    @State private var fileURL: URL?
    /// 공유 · 인쇄가 실패했을 때 시트 안에 띄울 문구.
    @State private var actionError: String?

    private var fileName: String { "\(content.profile.name)_이력서.pdf" }
    private var isCompact: Bool { layoutWidth < 640 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.border)
            ZStack {
                AppTheme.background
                preview
            }
            Divider().overlay(AppTheme.border)
            actions
        }
        .background(AppTheme.surface)
        .task { await load() }
    }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("이력서 미리보기")
                    .font(AppFonts.serif(isCompact ? 16 : 18))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("A4 · \(fileName)")
                    .font(AppFonts.sans(11.5))
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("닫기")
        }
        .padding(.leading, isCompact ? 16 : 24)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
    }

    // MARK: 본문

    @ViewBuilder
    private var preview: some View {
        if let loadError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(AppTheme.accent)
                Text("미리보기를 표시하지 못했습니다.\n잠시 후 다시 열어 주세요.")
                    .font(AppFonts.sans(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Text(loadError)
                    .font(AppFonts.sans(11))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        } else if let pdfData {
            PDFKitView(data: pdfData)
        } else {
            VStack(spacing: 14) {
                DerekSpinner(size: 56)
                Text("이력서를 조판하는 중입니다…")
                    .font(AppFonts.sans(12.5))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }

    // MARK: 동작

    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let actionError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                    Text(actionError)
                        .font(AppFonts.sans(12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .paperCard(fill: AppTheme.accent.opacity(0.06), radius: AppTheme.radiusSm, stroke: AppTheme.accent.opacity(0.35), lineWidth: 1)
            }

            HStack(spacing: 8) {
                if !isCompact {
                    Text("미리보기를 확인한 뒤 PDF로 저장하거나 공유할 수 있습니다.")
                        .font(AppFonts.sans(12))
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer(minLength: 0)

                Button(action: print) {
                    Label {
                        Text("인쇄").font(AppFonts.sans(13, weight: .semibold))
                    } icon: {
                        Image(systemName: "printer")
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .disabled(pdfData == nil)

                shareButton
            }
        }
        .padding(.horizontal, isCompact ? 16 : 24)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var shareButton: some View {
        let label = Label {
            Text("PDF 저장 · 공유").font(AppFonts.sans(13, weight: .semibold))
        } icon: {
            Image(systemName: "square.and.arrow.down")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: AppTheme.radiusSm).fill(AppTheme.primary))

        if let fileURL {
            ShareLink(item: fileURL) { label }
                .buttonStyle(PressableStyle())
        } else {
            label.opacity(0.5)
        }
    }

    private func load() async {
        do {
            let data = try await ResumePDFService.shared.pdf(for: content)
            pdfData = data
            do {
                // 공유 시트에 파일 이름이 그대로 보이도록 임시 폴더에 이름을 붙여 둔다.
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: url, options: .atomic)
                fileURL = url
            } catch {
                actionError = "PDF 파일을 준비하지 못했습니다: \(error.localizedDescription)"
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func print() {
        guard let pdfData else { return }
        actionError = nil

        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = fileName

        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = pdfData
        controller.present(animated: true) { _, _, error in
            if let error {
                actionError = "인쇄를 시작하지 못했습니다: \(error.localizedDescription)"
            }
        }
    }
}

/// PDFKit 뷰. 확대 · 스크롤 같은 뷰어 기능이 따라온다.
struct PDFKitView: UIViewRepresentable {
    let data: Data

    final class Coordinator {
        /// 지금 뷰에 넣어 둔 문서의 원본 바이트.
        var loadedData: Data?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(AppTheme.background)
        load(into: view, context: context)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        // 문서가 실제로 바뀌었을 때만 갈아 끼운다. dataRepresentation() 은 PDF 를 다시 직렬화해
        // 원본과 거의 항상 달라서, 그걸로 비교하면 다시 그릴 때마다 확대 · 스크롤 위치가 초기화된다.
        guard context.coordinator.loadedData != data else { return }
        load(into: view, context: context)
    }

    private func load(into view: PDFView, context: Context) {
        view.document = PDFDocument(data: data)
        context.coordinator.loadedData = data
    }
}
