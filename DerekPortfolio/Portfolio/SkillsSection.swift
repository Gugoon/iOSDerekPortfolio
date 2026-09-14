//
//  SkillsSection.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  보유 기술 스택 + 경력 이력 요약. Flutter lib/widgets/skills_section.dart 자리.
//

import SwiftUI

struct SkillsSection: View {
    let profile: ProfileData
    /// 경력 항목을 눌렀을 때 보여 줄 프로젝트를 고르기 위해 받는다.
    let projects: [ProjectData]

    private enum Tab { case all, direct, ai }

    @Environment(\.layoutWidth) private var width
    @State private var selectedTab: Tab = .all
    @State private var selectedCareer: CareerHistory?

    var body: some View {
        let metrics = LayoutMetrics(width: width)

        VStack(spacing: 0) {
            SectionTitle(title: "보유 기술 스택", subtitle: "SKILLS & COMPETENCIES")

            Text("10년 이상의 실무를 통해 직접 구축해온 모바일 네이티브 엔지니어링 기술과\n최신 AI Agent 및 AI 기반 Vibe Coding을 활용한 클라우드/데이터 아키텍처 스택입니다.")
                .font(AppFonts.sans(14.5))
                .lineHeight(1.75, fontSize: 14.5)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            // Segmented Tab Selector
            FlowLayout(spacing: 8, lineSpacing: 8, alignment: .center) {
                filterTab("전체 기술 스택", icon: "square.stack.3d.up.fill", tab: .all)
                filterTab("직접 개발 부문", icon: "chevron.left.forwardslash.chevron.right", tab: .direct)
                filterTab("AI 활용 부문", icon: "brain.head.profile", tab: .ai)
            }
            .padding(.top, 32)

            VStack(spacing: 36) {
                if selectedTab != .ai {
                    SkillSectionSheet(
                        title: "직접 개발 부문 (Core Development)",
                        subtitle: "모바일 네이티브 (iOS / Android / Flutter) & 하드웨어 제어 솔루션",
                        badgeLabel: "CORE ENGINEERING",
                        accentColor: AppTheme.primary,
                        groups: profile.directSkillGroups
                    )
                }
                if selectedTab != .direct {
                    SkillSectionSheet(
                        title: "AI 활용 부문 (AI Integration & Vibe Coding)",
                        subtitle: "OpenAI RealTime 음성 에이전트, Gemini LLM 기반 풀스택 데이터 아키텍처",
                        badgeLabel: "AI & VIBE CODING",
                        accentColor: AppTheme.accent,
                        groups: profile.aiSkillGroups
                    )
                }
            }
            .padding(.top, 36)

            // Work Experience Section
            SectionTitle(title: "경력 이력 요약", subtitle: "PROFESSIONAL EXPERIENCE")
                .padding(.top, 64)

            VStack(spacing: 14) {
                ForEach(Array(profile.careers.enumerated()), id: \.offset) { _, career in
                    let careerProjects = projectsForCareer(career, projects)
                    CareerRecord(career: career, projectCount: careerProjects.count) {
                        selectedCareer = career
                    }
                }
            }
            .padding(.top, 32)
        }
        .frame(maxWidth: 880)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.sidePadding)
        .padding(.vertical, 70)
        .background(AppTheme.surface)
        .sheet(item: Binding(
            get: { selectedCareer.map(IdentifiedCareer.init) },
            set: { selectedCareer = $0?.career }
        )) { item in
            CareerProjectsSheet(career: item.career, projects: projectsForCareer(item.career, projects))
                .environment(\.layoutWidth, width)
        }
    }

    private func filterTab(_ label: String, icon: String, tab: Tab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                Text(label)
                    .font(AppFonts.sans(13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .paperCard(
                fill: isSelected ? AppTheme.primary : AppTheme.surfaceCard,
                radius: AppTheme.radiusSm,
                stroke: isSelected ? AppTheme.primary : AppTheme.border
            )
            .modifier(ConditionalCardShadow(enabled: isSelected))
        }
        .buttonStyle(PressableStyle())
    }
}

private struct IdentifiedCareer: Identifiable {
    let career: CareerHistory
    var id: String { "\(career.company)|\(career.period)" }
}

private struct SkillSectionSheet: View {
    let title: String
    let subtitle: String
    let badgeLabel: String
    let accentColor: Color
    let groups: [SkillGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header Bar
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2).fill(accentColor).frame(width: 4, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFonts.serif(16))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(AppFonts.sans(12))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PaperBadge(
                    text: badgeLabel,
                    font: AppFonts.mono(10.5, weight: .bold),
                    foreground: accentColor,
                    fill: accentColor.alpha(20),
                    stroke: accentColor.alpha(80),
                    horizontal: 9,
                    vertical: 3
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.headerTape)
            .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.border).frame(height: 1) }

            // Group List
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(accentColor).frame(width: 5, height: 5).padding(.top, 8)
                        Text(group.category)
                            .font(AppFonts.serif(14))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(Array(group.skills.enumerated()), id: \.offset) { _, skill in
                            PaperBadge(
                                text: skill,
                                font: AppFonts.sans(12.5, weight: .medium),
                                foreground: AppTheme.textPrimary,
                                fill: Color(argb: 0xFFFAF8F3),
                                stroke: AppTheme.border,
                                horizontal: 10,
                                vertical: 5
                            )
                        }
                    }
                    .padding(.top, 10)

                    if index < groups.count - 1 {
                        Rectangle().fill(AppTheme.ruleLine).frame(height: 1).padding(.vertical, 16)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMd))
        .paperCard()
        .cardShadow()
    }
}

private struct CareerRecord: View {
    let career: CareerHistory
    /// 이 회사에서 진행한 프로젝트 수. 0 이면 눌러도 볼 것이 없으므로 누르지 못하게 한다.
    let projectCount: Int
    let onTap: () -> Void

    @Environment(\.layoutWidth) private var width

    private var isTappable: Bool { projectCount > 0 }

    var body: some View {
        if isTappable {
            Button(action: onTap) { record }
                .buttonStyle(PressableStyle(scale: 0.99))
                .accessibilityLabel("\(career.company) 프로젝트 \(projectCount)건 보기")
        } else {
            record
        }
    }

    private var record: some View {
        HStack(spacing: 0) {
            Image(systemName: "bookmark")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 34, height: 34)
                .paperCard(fill: Color(argb: 0xFFF7F4EE), radius: 4, stroke: AppTheme.borderLight, lineWidth: 1)

            VStack(alignment: .leading, spacing: 4) {
                FlowLayout(spacing: 8, lineSpacing: 4) {
                    Text(career.company)
                        .font(AppFonts.serif(16))
                        .foregroundStyle(AppTheme.textPrimary)
                    PaperBadge(text: career.duration)
                    if isTappable {
                        PaperBadge(
                            text: "프로젝트 \(projectCount)",
                            foreground: AppTheme.primary,
                            fill: AppTheme.surfaceCard,
                            stroke: AppTheme.border
                        )
                    }
                }
                Text(career.role)
                    .font(AppFonts.sans(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)

            // 좁은 화면에서는 기간이 줄바꿈되도록 둔다.
            Text(career.period)
                .font(AppFonts.mono(12, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)

            // 좁은 화면에서는 화살표를 접는다. 누를 수 있다는 신호는 건수 배지가 이미 하고 있다.
            if isTappable && width >= 480 {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .paperCard(radius: AppTheme.radiusSm)
        .contentShape(Rectangle())
    }
}
