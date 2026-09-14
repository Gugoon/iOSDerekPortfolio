//
//  ProjectsSection.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  프로젝트 아카이브. Flutter lib/widgets/projects_section.dart 자리.
//

import SwiftUI

struct ProjectsSection: View {
    let projects: [ProjectData]

    @Environment(\.layoutWidth) private var width
    @State private var selectedCategory: ProjectCategory?

    private var filteredProjects: [ProjectData] {
        guard let selectedCategory else { return projects }
        return projects.filter { $0.category == selectedCategory }
    }

    var body: some View {
        let metrics = LayoutMetrics(width: width)
        let columnCount = metrics.isTablet ? 2 : 1

        VStack(spacing: 0) {
            SectionTitle(title: "프로젝트 아카이브", subtitle: "PROJECT PORTFOLIO ARCHIVE")

            // Index Tabs (색인 탭)
            FlowLayout(spacing: 8, lineSpacing: 8, alignment: .center) {
                indexTab("전체 (\(projects.count))", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ProjectCategory.allCases, id: \.self) { category in
                    let count = projects.filter { $0.category == category }.count
                    indexTab("\(category.label) (\(count))", isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.top, 32)

            // Project Cards Grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 24, alignment: .top), count: columnCount),
                alignment: .leading,
                spacing: 24
            ) {
                ForEach(filteredProjects, id: \.listKey) { project in
                    PaperProjectSheet(project: project)
                }
            }
            .id(selectedCategory)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: selectedCategory)
            .padding(.top, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.sidePadding)
        .padding(.vertical, 70)
        .background(AppTheme.background)
    }

    private func indexTab(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { action() }
        } label: {
            Text(label)
                .font(AppFonts.sans(13, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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

/// 프로젝트 한 건을 담는 종이 시트. 아카이브 목록과 경력 시트가 같은 카드를 쓴다.
struct PaperProjectSheet: View {
    let project: ProjectData
    /// 상세 실무 내역을 펼친 채로 열지 여부.
    var initiallyExpanded = false
    /// 회사명 배지 노출 여부. 경력 시트는 이미 제목이 그 회사라 되풀이하지 않는다.
    var showCompany = true

    @State private var isExpanded: Bool?

    private var expanded: Bool { isExpanded ?? initiallyExpanded }

    private var categoryColor: Color {
        switch project.category {
        case .mobile: return Color(argb: 0xFF2E6347)  // 세이지 잉크 그린
        case .ai: return Color(argb: 0xFFB33939)      // 인주 레드
        case .web: return Color(argb: 0xFF1F3A60)     // 만년필 블루
        case .backend: return Color(argb: 0xFF8C531B) // 빈티지 브라운
        case .other: return Color(argb: 0xFF5E3F71)   // 고문서 퍼플
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top category stripe
            Rectangle().fill(categoryColor).frame(height: 3)

            VStack(alignment: .leading, spacing: 0) {
                // Header: Category, Company & Period
                HStack(alignment: .top, spacing: 8) {
                    FlowLayout(spacing: 8, lineSpacing: 6) {
                        PaperBadge(
                            text: project.category.label,
                            font: AppFonts.sans(11, weight: .bold),
                            foreground: categoryColor,
                            fill: categoryColor.alpha(20),
                            stroke: categoryColor.alpha(80),
                            horizontal: 8,
                            vertical: 3
                        )
                        if showCompany {
                            PaperBadge(
                                text: project.company,
                                font: AppFonts.sans(11, weight: .semibold),
                                fill: Color(argb: 0xFFF5EFE6),
                                horizontal: 8,
                                vertical: 3
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(project.period)
                        .font(AppFonts.mono(11, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Text(project.title)
                    .font(AppFonts.serif(18))
                    .lineHeight(1.4, fontSize: 18)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.top, 14)

                HStack(spacing: 5) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13))
                    Text(project.role)
                        .font(AppFonts.sans(13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.primary)
                .padding(.top, 6)

                Text(project.description)
                    .font(AppFonts.sans(13.5))
                    .lineHeight(1.75, fontSize: 13.5)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 12)

                // Tech Stack (Typewriter / Mono style chips)
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(project.techStack.enumerated()), id: \.offset) { _, tech in
                        PaperBadge(
                            text: tech,
                            font: AppFonts.mono(11, weight: .medium),
                            foreground: AppTheme.textPrimary,
                            fill: Color(argb: 0xFFF7F4EE),
                            stroke: AppTheme.borderLight,
                            horizontal: 8,
                            vertical: 4
                        )
                    }
                }
                .padding(.top, 16)

                // Expand / Collapse Achievements
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded = !expanded }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "minus.circle" : "plus.circle")
                            .font(.system(size: 14))
                        Text(expanded ? "상세 실무 내역 접기" : "상세 실무 구현 및 주요 성과")
                            .font(AppFonts.sans(13, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.primary)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                if expanded {
                    achievements
                        .padding(.top, 10)
                        .transition(.opacity)
                }

                links
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMd))
        .paperCard()
        .cardShadow()
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(project.achievements.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(AppTheme.accent).frame(width: 4, height: 4).padding(.top, 8)
                    Text(item)
                        .font(AppFonts.sans(13))
                        .lineHeight(1.65, fontSize: 13)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .paperCard(fill: Color(argb: 0xFFFAF8F3), radius: 4, stroke: AppTheme.ruleLine, lineWidth: 1)
    }

    @ViewBuilder
    private var links: some View {
        let hasStore = project.appStoreUrl != nil || project.playStoreUrl != nil
        if hasStore || project.liveUrl != nil || project.githubUrl != nil {
            Rectangle().fill(AppTheme.ruleLine).frame(height: 1).padding(.top, 16)
            FlowLayout(spacing: 10, lineSpacing: 8) {
                if let url = project.appStoreUrl {
                    LinkChip(icon: "apple.logo", label: "App Store") { ExternalLink.open(url) }
                }
                if let url = project.playStoreUrl {
                    LinkChip(icon: "play.fill", label: "Google Play") { ExternalLink.open(url) }
                }
                if let url = project.liveUrl, !hasStore {
                    LinkChip(icon: "arrow.up.right.square", label: "서비스 바로가기") { ExternalLink.open(url) }
                }
                if let url = project.githubUrl {
                    LinkChip(icon: "chevron.left.forwardslash.chevron.right", label: "GitHub") { ExternalLink.open(url) }
                }
            }
            .padding(.top, 14)
        }
    }
}

private struct LinkChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(label).font(AppFonts.sans(12, weight: .semibold))
            }
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .paperCard(fill: AppTheme.headerTape, radius: 4, stroke: AppTheme.border, lineWidth: 1)
        }
        .buttonStyle(PressableStyle())
    }
}
