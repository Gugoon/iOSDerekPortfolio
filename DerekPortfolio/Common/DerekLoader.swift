//
//  DerekLoader.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  사진을 둥글게 잘라 넣고 그 둘레로 호가 도는 로딩 표시와, 가는 막대 위를 사진이
//  따라 달리는 진행 표시. Flutter lib/widgets/derek_loader.dart 자리.
//

import SwiftUI

enum DerekImage {
    /// 로딩 표시에 쓰는 사진. 인물 쪽만 정사각형으로 잘라 낸 것이다.
    static let loader: UIImage? = {
        guard let url = Bundle.main.url(forResource: "derek_loader", withExtension: "jpg") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()
}

private struct Portrait: View {
    var body: some View {
        ZStack {
            Circle().fill(AppTheme.surfaceHover)
            if let image = DerekImage.loader {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            }
        }
    }
}

/// ProgressView 자리를 대신하는 무한 진행 표시.
struct DerekSpinner: View {
    var size: CGFloat = 56
    var color: Color = AppTheme.primary
    var strokeWidth: CGFloat?

    /// 한 바퀴 도는 데 걸리는 시간.
    private let period: Double = 1.4

    var body: some View {
        let stroke = strokeWidth ?? min(max(size * 0.06, 1.5), 3.5)
        // 링과 사진 사이에 틈을 두어야 호가 사진 가장자리에 묻히지 않는다.
        let gap = min(max(size * 0.05, 1), 4)

        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            ZStack {
                Circle()
                    .stroke(color.opacity(0.14), lineWidth: stroke)
                    .padding(stroke / 2)

                // 호의 길이를 한 바퀴마다 늘였다 줄인다. 길이가 고정이면 멈춘 그림처럼 보인다.
                let sweep = 0.5 * (0.55 + 0.35 * sin(t * .pi * 2)) // 원 둘레 대비 비율
                Circle()
                    .trim(from: 0, to: sweep)
                    .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.radians(t * .pi * 2 - .pi / 2))
                    .padding(stroke / 2)

                Portrait().padding(stroke + gap)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("불러오는 중")
    }
}

/// 화면 꼭대기에 띄워 쓰는 가는 진행 막대. 사진이 막대 머리에 붙어 간다.
struct DerekProgressBar: View {
    var barHeight: CGFloat = 3
    var avatarSize: CGFloat = 26
    var color: Color = AppTheme.primary

    private let period: Double = 1.8

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                let width = proxy.size.width
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                // 머리가 먼저 빠르게 치고 나가고 꼬리가 뒤늦게 따라붙는다.
                let head = width * (easeOutCubic(t) * 1.3 - 0.1)
                let tail = width * (easeInCubic(t) * 1.3 - 0.3)
                let avatarX = min(max(head - avatarSize / 2, 0), max(0, width - avatarSize))

                ZStack(alignment: .topLeading) {
                    UnevenRoundedRectangle(bottomTrailingRadius: barHeight, topTrailingRadius: barHeight)
                        .fill(color)
                        .frame(width: max(0, head - tail), height: barHeight)
                        .offset(x: tail)

                    Portrait()
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(Circle().stroke(color, lineWidth: 1.5))
                        .cardShadow()
                        .offset(x: avatarX, y: barHeight * 0.5 - avatarSize * 0.25)
                }
            }
        }
        .frame(height: barHeight + avatarSize * 0.75)
        .allowsHitTesting(false)
        .accessibilityLabel("불러오는 중")
    }

    private func easeOutCubic(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    private func easeInCubic(_ t: Double) -> Double { t * t * t }
}
