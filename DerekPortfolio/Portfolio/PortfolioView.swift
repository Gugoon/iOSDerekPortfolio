//
//  PortfolioView.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  포트폴리오 첫 화면. Flutter main.dart 의 PortfolioPage 자리.
//

import SwiftUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct PortfolioView: View {
    @StateObject private var viewModel = PortfolioViewModel()

    @State private var showAdmin = false
    @State private var showResume = false

    private enum Anchor: Hashable { case top, projects }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let content = viewModel.content {
                    page(content, width: geometry.size.width)
                } else {
                    ZStack {
                        AppTheme.background.ignoresSafeArea()
                        DerekSpinner(size: 72)
                    }
                }
            }
            .environment(\.layoutWidth, geometry.size.width)
        }
        .task { await viewModel.loadContent() }
        // 관리자 화면이 닫히고 이 화면이 다시 앞으로 나왔다. 그 사이 고친 내용이 있을 수 있으므로 다시 읽는다.
        .fullScreenCover(isPresented: $showAdmin, onDismiss: {
            Task { await viewModel.refreshContent() }
        }) {
            AdminRootView()
        }
    }

    private func page(_ content: SiteContent, width: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        HeroSection(profile: content.profile) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                proxy.scrollTo(Anchor.projects, anchor: .top)
                            }
                        }
                        .id(Anchor.top)

                        SkillsSection(profile: content.profile, projects: content.projects)

                        ProjectsSection(projects: content.projects)
                            .id(Anchor.projects)

                        ContactSection(profile: content.profile)

                        // Firebase 설정이 없으면 관리자 화면을 열어도 할 수 있는 일이 없다. 진입 버튼을 감춘다.
                        FooterSection(
                            name: content.profile.name,
                            onAdminTap: FirebaseConfig.isConfigured ? { showAdmin = true } : nil
                        )
                    }
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(
                                key: ScrollOffsetKey.self,
                                value: -inner.frame(in: .named("portfolio-scroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "portfolio-scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { viewModel.scrollOffset.send($0) }
                .background(AppTheme.background)

                floatingActions(content, width: width) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        proxy.scrollTo(Anchor.top, anchor: .top)
                    }
                }
            }
            // 관리자 화면에서 돌아와 다시 읽는 중임을 알리는 가는 띠.
            // 보고 있던 내용을 그대로 두고 갱신하므로, 이것마저 없으면 아무 일도 없는 것처럼 보인다.
            .overlay(alignment: .top) {
                if viewModel.isRefreshing {
                    DerekProgressBar()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isRefreshing)
            .toastOverlay()
            .sheet(isPresented: $showResume) {
                ResumePDFSheet(content: content)
                    .environment(\.layoutWidth, width)
            }
        }
    }

    /// 맨 위로 · 이력서 PDF 플로팅 버튼.
    private func floatingActions(_ content: SiteContent, width: CGFloat, scrollToTop: @escaping () -> Void) -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            // 사라질 때도 자리는 남겨 두어야 아래 이력서 버튼이 흔들리지 않는다.
            Button(action: scrollToTop) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppTheme.surfaceCard))
                    .overlay(Circle().strokeBorder(AppTheme.primary, lineWidth: 1.5))
                    .cardShadow()
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("맨 위로")
            .opacity(viewModel.showScrollToTop ? 1 : 0)
            .offset(y: viewModel.showScrollToTop ? 0 : 22)
            .allowsHitTesting(viewModel.showScrollToTop)
            .animation(.easeOut(duration: 0.3), value: viewModel.showScrollToTop)

            // 좁은 화면에서는 원형 아이콘만 남겨 본문을 가리지 않게 한다.
            let showLabel = width >= 720
            Button { showResume = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 18))
                    if showLabel {
                        Text("이력서 PDF")
                            .font(AppFonts.sans(13.5, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, showLabel ? 20 : 14)
                .frame(height: 48)
                .background(Capsule().fill(AppTheme.primary))
                .cardShadow()
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("이력서 PDF 미리보기 · 저장")
        }
        .padding(.trailing, width > 600 ? 32 : 20)
        .padding(.bottom, width > 600 ? 32 : 20)
    }
}
