//
//  PortfolioViewModel.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  포트폴리오 첫 화면의 상태. Flutter main.dart 의 _PortfolioPageState 자리.
//

import Foundation
import Combine

@MainActor
final class PortfolioViewModel: NetworkViewModel {
    /// Firestore 로드 결과. 로딩 중에는 nil 이다.
    @Published private(set) var content: SiteContent?

    /// 관리자 화면에서 돌아온 뒤 다시 읽는 중인지.
    @Published private(set) var isRefreshing = false

    /// 스크롤을 충분히 내렸을 때만 '맨 위로' 버튼을 보인다.
    @Published private(set) var showScrollToTop = false

    /// 스크롤 위치(위에서부터 내려간 거리)를 흘려 보내는 곳.
    let scrollOffset = PassthroughSubject<CGFloat, Never>()

    /// 새로고침 요청 세대. 관리자 화면을 여러 번 드나들면 읽기가 겹칠 수 있는데,
    /// 늦게 끝난 쪽이 오래된 내용을 덮어쓰지 않도록 마지막 요청만 반영한다.
    private var refreshGeneration = 0

    override init() {
        super.init()

        scrollOffset
            .map { $0 > 400 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in self?.showScrollToTop = show }
            .store(in: &subscriptions)
    }

    /// 첫 로드. 실패해도 폴백을 받으므로 화면은 반드시 뜬다.
    func loadContent() async {
        guard content == nil else { return }
        apply(await loadSiteContent())
    }

    /// 관리자 화면에서 돌아왔을 때의 새로고침.
    ///
    /// 첫 로드와 달리 이미 보여 주고 있는 내용이 있으므로 화면을 비우지 않는다.
    /// 읽기에 실패하면 폴백이 돌아오는데, 그걸 그대로 덮어쓰면 멀쩡히 보고 있던 내용이
    /// 기본값으로 바뀌어 버린다. 그래서 실패했을 때는 지금 것을 유지한 채 알린다.
    /// 시드 전이라 폴백이 온 경우는 읽기에는 성공했으므로 그대로 반영한다.
    func refreshContent() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true

        let result = await fetchSiteContent()
        // 뒤이어 시작된 읽기가 있으면 이 결과는 버린다.
        guard generation == refreshGeneration else { return }

        isRefreshing = false

        guard !result.readFailed else {
            await setToastMessage(
                content?.fromFirestore == true
                    ? "최신 내용을 불러오지 못했습니다. 화면은 이전 내용 그대로입니다."
                    : "최신 내용을 불러오지 못했습니다. 내장 데이터로 표시하고 있습니다.",
                type: .error
            )
            return
        }

        apply(result.content)
        await setToastMessage("최신 내용을 불러왔습니다.")
    }

    private func apply(_ newContent: SiteContent) {
        content = newContent
        // 버튼을 누른 뒤에 조판을 시작하면 그만큼 빈 미리보기를 보게 된다.
        ResumePDFService.shared.warmUp(newContent)
    }
}
