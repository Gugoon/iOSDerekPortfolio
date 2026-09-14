//
//  ContactSection.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  연락처 · 인적 사항과 푸터. Flutter lib/widgets/contact_section.dart 자리.
//

import SwiftUI

struct ContactSection: View {
    let profile: ProfileData

    @Environment(\.layoutWidth) private var width

    var body: some View {
        let metrics = LayoutMetrics(width: width)

        VStack(spacing: 12) {
            SectionTitle(title: "연락처 및 인적 사항", subtitle: "CONTACT & CREDENTIALS")

            Text("10년 이상의 모바일 및 풀스택 개발 경험을 바탕으로\n성공적인 프로젝트와 서비스를 함께 만들어갈 기회를 언제나 환영합니다.")
                .font(AppFonts.sans(14.5))
                .lineHeight(1.8, fontSize: 14.5)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.bottom, 24)

            // 관리자 화면에서 비워 둔 항목은 감춘다("비워 두면 해당 버튼이 사이트에서 사라집니다").
            // 빈 행을 남기면 눌러도 빈 mailto: / tel: 이 열린다.
            if !profile.email.trimmed.isEmpty {
                ContactRow(icon: "at", label: "이메일 (Email)", value: profile.email) {
                    ExternalLink.open("mailto:\(profile.email.trimmed)")
                }
            }
            if !profile.phone.trimmed.isEmpty {
                ContactRow(icon: "iphone", label: "연락처 (Phone)", value: profile.phone) {
                    ExternalLink.open("tel:\(profile.phone.filter { $0.isNumber || $0 == "+" })")
                }
            }
            if let github = profile.github {
                ContactRow(icon: "chevron.left.forwardslash.chevron.right", label: "GitHub 저장소", value: github) {
                    ExternalLink.open(github)
                }
            }
            if let notion = profile.notion {
                ContactRow(icon: "doc.text", label: "Notion 상세 경력기술서", value: "노션 경력기술서 열람하기 ↗") {
                    ExternalLink.open(notion)
                }
            }
            if !profile.certificate.trimmed.isEmpty {
                ContactRow(icon: "checkmark.seal", label: "공인 자격증 (Certification)", value: profile.certificate)
            }
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.sidePadding)
        .padding(.vertical, 70)
        .background(AppTheme.surface)
    }
}

private struct ContactRow: View {
    let icon: String
    let label: String
    let value: String
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { row(clickable: true) }
                .buttonStyle(PressableStyle(scale: 0.99))
        } else {
            row(clickable: false)
        }
    }

    private func row(clickable: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 38, height: 38)
                .paperCard(fill: Color(argb: 0xFFF6F3EB), radius: 4, stroke: AppTheme.borderLight, lineWidth: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFonts.mono(11, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                Text(value)
                    .font(AppFonts.sans(14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if clickable {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .paperCard(radius: AppTheme.radiusSm)
        .contentShape(Rectangle())
    }
}

struct FooterSection: View {
    /// 저작권 줄에 넣을 이름. 프로필 이름을 받는다.
    let name: String
    /// 관리자 화면으로 들어가는 동작. 방문자에게는 의미 없는 버튼이라 눈에 띄지 않게 맨 아래에 둔다.
    /// nil 이면 진입 버튼을 아예 그리지 않는다.
    let onAdminTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppTheme.border).frame(width: 80, height: 1)

            Text("© \(String(Calendar.current.component(.year, from: Date()))) \(name) • PORTFOLIO ARCHIVE")
                .font(AppFonts.mono(12, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.top, 24)

            Text("Typeset with SwiftUI & Noto Serif KR")
                .font(AppFonts.sans(11))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.top, 4)

            if let onAdminTap {
                Button(action: onAdminTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock").font(.system(size: 11))
                        Text("관리자").font(AppFonts.mono(11, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusSm).strokeBorder(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("관리자 화면 열기")
                .padding(.top, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.bottom, 60)
        .background(AppTheme.background)
    }
}
