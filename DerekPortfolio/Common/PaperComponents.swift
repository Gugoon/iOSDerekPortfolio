//
//  PaperComponents.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  여러 섹션이 함께 쓰는 작은 부품들.
//

import SwiftUI

/// 'SKILLS & COMPETENCIES' 소제목 + 명조 제목 + 짧은 밑줄.
struct SectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 0) {
            Text(subtitle)
                .font(AppFonts.mono(11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
            Text(title)
                .font(AppFonts.serif(26, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            Rectangle()
                .fill(AppTheme.primary)
                .frame(width: 36, height: 2)
                .padding(.top, 10)
        }
    }
}

/// 누르는 동안 살짝 눌리는 버튼. 웹의 hover 강조를 터치 환경에 맞게 옮긴 것이다.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 카테고리 · 기간 같은 작은 배지.
struct PaperBadge: View {
    let text: String
    var font: Font = AppFonts.mono(11, weight: .semibold)
    var foreground: Color = AppTheme.textSecondary
    var fill: Color = Color(argb: 0xFFF3ECE1)
    var stroke: Color? = nil
    var horizontal: CGFloat = 7
    var vertical: CGFloat = 2

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(RoundedRectangle(cornerRadius: 3).fill(fill))
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(stroke, lineWidth: 1)
                }
            }
    }
}

/// 가로 폭에 따른 배치 구분. Flutter 의 MediaQuery 폭 분기와 같은 기준이다.
struct LayoutMetrics {
    let width: CGFloat

    var isDesktop: Bool { width > 900 }
    var isTablet: Bool { width > 600 }
    var sidePadding: CGFloat { isDesktop ? 80 : 20 }
}

private struct LayoutWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 390
}

extension EnvironmentValues {
    /// 화면 전체 폭. 섹션들이 반응형 분기에 쓴다.
    var layoutWidth: CGFloat {
        get { self[LayoutWidthKey.self] }
        set { self[LayoutWidthKey.self] = newValue }
    }
}

enum ExternalLink {
    /// 외부 앱(사파리, 앱스토어, 메일, 전화)으로 연다. 여는 데 실패하면 조용히 넘어간다.
    @MainActor
    static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}
