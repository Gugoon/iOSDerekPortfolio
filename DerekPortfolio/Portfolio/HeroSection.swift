//
//  HeroSection.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  이름 · 직함 · 소개가 담긴 첫 종이 시트. Flutter lib/widgets/hero_section.dart 자리.
//

import SwiftUI

struct HeroSection: View {
    let profile: ProfileData
    var onViewProjectsTap: () -> Void

    @Environment(\.layoutWidth) private var width
    @State private var appeared = false

    var body: some View {
        let metrics = LayoutMetrics(width: width)

        VStack(spacing: 0) {
            sheet(metrics)
                .frame(maxWidth: 860)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.sidePadding)
        .padding(.vertical, metrics.isDesktop ? 70 : 40)
        .background(AppTheme.background)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { appeared = true }
        }
    }

    private func sheet(_ metrics: LayoutMetrics) -> some View {
        VStack(spacing: 0) {
            // Header Tape / Document Index bar
            HStack {
                Circle().fill(AppTheme.accent).frame(width: 9, height: 9)
                Text("CURRICULUM VITAE • PORTFOLIO")
                    .font(AppFonts.mono(11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text("EDITION 2026")
                    .font(AppFonts.mono(11, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.headerTape)
            .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.border).frame(height: 1) }

            // Main Sheet Content
            VStack(spacing: 0) {
                Text(profile.name)
                    .font(AppFonts.serif(metrics.isDesktop ? 46 : 32, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text(profile.title)
                    .font(AppFonts.sans(metrics.isDesktop ? 18 : 15, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(AppTheme.primary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)

                // Double ruled line (Editorial separator)
                VStack(spacing: 3) {
                    Rectangle().fill(AppTheme.border).frame(height: 1.5)
                    Rectangle().fill(AppTheme.borderLight).frame(height: 0.8)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                Text(profile.bio)
                    .font(AppFonts.sans(15))
                    .lineHeight(1.85, fontSize: 15)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 680)
                    .padding(.top, 24)

                // Action Buttons
                FlowLayout(spacing: 12, lineSpacing: 12, alignment: .center) {
                    HeroButton(label: "프로젝트 열람하기", icon: "books.vertical.fill", solid: true, action: onViewProjectsTap)
                    if let github = profile.github {
                        HeroButton(label: "GitHub", icon: "chevron.left.forwardslash.chevron.right") {
                            ExternalLink.open(github)
                        }
                    }
                    if let notion = profile.notion {
                        HeroButton(label: "Notion 상세 경력서", icon: "doc.text.fill") {
                            ExternalLink.open(notion)
                        }
                    }
                }
                .padding(.top, 36)
            }
            .padding(.horizontal, metrics.isDesktop ? 48 : 24)
            .padding(.vertical, metrics.isDesktop ? 48 : 32)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMd))
        .paperCard(radius: AppTheme.radiusMd, lineWidth: 1.5)
        .cardShadow()
    }
}

private struct HeroButton: View {
    let label: String
    let icon: String
    var solid = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15))
                Text(label).font(AppFonts.sans(14, weight: .semibold))
            }
            .foregroundStyle(solid ? .white : AppTheme.textSecondary)
            .padding(.horizontal, solid ? 24 : 22)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusSm)
                    .fill(solid ? AppTheme.primary : AppTheme.surfaceCard)
            )
            .overlay {
                if !solid {
                    RoundedRectangle(cornerRadius: AppTheme.radiusSm).strokeBorder(AppTheme.border, lineWidth: 1.2)
                }
            }
            .modifier(ConditionalCardShadow(enabled: solid))
        }
        .buttonStyle(PressableStyle())
    }
}

struct ConditionalCardShadow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled { content.cardShadow() } else { content }
    }
}
