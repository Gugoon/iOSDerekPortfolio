//
//  AppTheme.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  Flutter lib/theme/app_theme.dart 의 종이 · 잉크 팔레트.
//

import SwiftUI

extension Color {
    /// 0xAARRGGBB
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }

    /// Flutter 의 withAlpha(0~255).
    func alpha(_ value: Int) -> Color { opacity(Double(value) / 255) }
}

enum AppTheme {
    // Paper & Parchment Backgrounds
    static let background = Color(argb: 0xFFF6F3EC)   // 미색 웜 코튼 페이퍼
    static let surface = Color(argb: 0xFFFCFBF8)      // 깔끔한 백지 시트
    static let surfaceCard = Color(argb: 0xFFFFFFFF)  // 카드 시트
    static let surfaceHover = Color(argb: 0xFFF0EBE0) // 부드러운 종이 터치
    static let border = Color(argb: 0xFFE2DDD3)       // 섬세한 연필 재단선
    static let borderLight = Color(argb: 0xFFEFEAE1)
    static let ruleLine = Color(argb: 0xFFE8E2D5)     // 노트 줄눈
    static let headerTape = Color(argb: 0xFFFAF7F0)

    // Ink Typography Colors
    static let textPrimary = Color(argb: 0xFF1E1C1A)   // 진한 인쇄 잉크
    static let textSecondary = Color(argb: 0xFF48443F) // 만년필 챠콜 잉크
    static let textMuted = Color(argb: 0xFF868077)     // 연필 스케치 그레이

    // Accent Inks & Stamp Colors
    static let primary = Color(argb: 0xFF1F3A60)      // 클래식 만년필 블루블랙
    static let primaryLight = Color(argb: 0xFF385E8E)
    static let primaryDark = Color(argb: 0xFF13253E)
    static let accent = Color(argb: 0xFFB33939)       // 붉은 인주 스탬프
    static let accentSage = Color(argb: 0xFF365A3D)   // 압화 세이지 그린
    static let accentAmber = Color(argb: 0xFF9E611A)  // 빈티지 앰버

    // Radius
    static let radiusSm: CGFloat = 4
    static let radiusMd: CGFloat = 8
    static let radiusLg: CGFloat = 12
    static let radiusXl: CGFloat = 20

    // Spacing
    static let spacingXs: CGFloat = 4
    static let spacingSm: CGFloat = 8
    static let spacingMd: CGFloat = 16
    static let spacingLg: CGFloat = 24
    static let spacingXl: CGFloat = 32
    static let spacing2xl: CGFloat = 48
    static let spacing3xl: CGFloat = 64
}

// MARK: - 종이 그림자

extension View {
    /// 실제 종이가 책상 위에 놓인 듯한 옅은 그림자.
    func cardShadow() -> some View {
        shadow(color: Color(argb: 0x0E2E2419), radius: 7, x: 0, y: 4)
            .shadow(color: Color(argb: 0x082E2419), radius: 1.5, x: 0, y: 1)
    }

    /// 눌렀을 때 조금 더 떠오르는 그림자.
    func glowShadow() -> some View {
        shadow(color: Color(argb: 0x182E2419), radius: 11, x: 0, y: 8)
            .shadow(color: Color(argb: 0x0C2E2419), radius: 3, x: 0, y: 2)
    }

    /// 테두리가 있는 둥근 종이 카드.
    func paperCard(
        fill: Color = AppTheme.surfaceCard,
        radius: CGFloat = AppTheme.radiusMd,
        stroke: Color = AppTheme.border,
        lineWidth: CGFloat = 1.2
    ) -> some View {
        background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(stroke, lineWidth: lineWidth))
    }
}
