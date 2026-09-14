//
//  AppFonts.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  앱에 번들된 서브셋 폰트(Flutter assets/fonts 와 같은 파일).
//
//  Flutter 쪽 서브셋 원본은 굵기가 다른 파일들이 모두 같은 PostScript 이름
//  (NotoSansKR-Thin 등)을 달고 있다. 그대로 쓰면 PDF 에 폰트가 이름으로 임베딩되면서
//  굵기별 글리프가 뒤섞여 일부 줄이 사라진다. 그래서 이 앱에 넣은 사본은 이름 테이블을
//  NotoSansKR-Regular / -Bold 처럼 굵기별로 고쳐 두었다. 원본을 다시 가져오면 같은
//  작업을 해야 한다.
//
//  시스템에 등록하지 않고 파일에서 바로 CGFont 를 읽어 CTFont 로 만든다. 굵기를 파일로
//  고르기 때문에 등록 이름에 기대지 않아도 된다.
//
//  서브셋에 없는 글자는 캐스케이드 목록(Apple SD Gothic Neo)으로 떨어진다.
//  웹과 달리 관리자가 새로 쓴 글자가 두부(□)로 보이지 않는다.
//

import SwiftUI
import UIKit
import CoreText

enum FontWeightStep: Int {
    case regular = 400
    case medium = 500
    case semibold = 600
    case bold = 700
    case heavy = 800
}

enum AppFontFamily {
    case sans, serif, mono

    fileprivate var files: [FontWeightStep: String] {
        switch self {
        case .sans:
            return [.regular: "NotoSansKR-400", .medium: "NotoSansKR-500",
                    .semibold: "NotoSansKR-600", .bold: "NotoSansKR-700"]
        case .serif:
            return [.bold: "NotoSerifKR-700", .heavy: "NotoSerifKR-800"]
        case .mono:
            return [.medium: "FiraCode-500", .semibold: "FiraCode-600", .bold: "FiraCode-700"]
        }
    }

    /// 없는 굵기는 가장 가까운 파일로 맞춘다.
    fileprivate func file(for weight: FontWeightStep) -> String {
        let files = self.files
        if let exact = files[weight] { return exact }
        let nearest = files.keys.min { abs($0.rawValue - weight.rawValue) < abs($1.rawValue - weight.rawValue) }
        return files[nearest!]!
    }

    fileprivate var systemWeight: UIFont.Weight {
        switch self {
        case .sans, .mono: return .regular
        case .serif: return .bold
        }
    }
}

enum AppFonts {
    private static var graphicsFonts: [String: CGFont] = [:]
    private static var fontCache: [String: UIFont] = [:]
    private static let lock = NSLock()

    /// 한글 글리프가 없는 폰트(Fira Code)나 서브셋 밖 글자를 받아 줄 폰트들.
    private static let cascade: [CTFontDescriptor] = [
        CTFontDescriptorCreateWithNameAndSize("AppleSDGothicNeo-Regular" as CFString, 0),
    ]

    static func uiFont(_ family: AppFontFamily, _ size: CGFloat, weight: FontWeightStep) -> UIFont {
        let file = family.file(for: weight)
        let key = "\(file)@\(size)"

        lock.lock()
        defer { lock.unlock() }

        if let cached = fontCache[key] { return cached }

        guard let graphics = graphicsFont(named: file) else {
            return .systemFont(ofSize: size, weight: family.systemWeight)
        }
        let attributes = CTFontDescriptorCreateWithAttributes(
            [kCTFontCascadeListAttribute: cascade] as CFDictionary
        )
        let font = CTFontCreateWithGraphicsFont(graphics, size, nil, attributes) as UIFont
        fontCache[key] = font
        return font
    }

    private static func graphicsFont(named file: String) -> CGFont? {
        if let cached = graphicsFonts[file] { return cached }
        guard
            let url = Bundle.main.url(forResource: file, withExtension: "ttf"),
            let provider = CGDataProvider(url: url as CFURL),
            let font = CGFont(provider)
        else {
            Log("폰트를 읽지 못했습니다: \(file)")
            return nil
        }
        graphicsFonts[file] = font
        return font
    }

    // MARK: SwiftUI

    static func sans(_ size: CGFloat, weight: FontWeightStep = .regular) -> Font {
        Font(uiFont(.sans, size, weight: weight) as CTFont)
    }

    static func serif(_ size: CGFloat, weight: FontWeightStep = .bold) -> Font {
        Font(uiFont(.serif, size, weight: weight) as CTFont)
    }

    static func mono(_ size: CGFloat, weight: FontWeightStep = .medium) -> Font {
        Font(uiFont(.mono, size, weight: weight) as CTFont)
    }
}

extension View {
    /// Flutter TextStyle.height(글자 크기의 배수)를 줄 간격으로 옮긴다.
    /// Noto 계열의 기본 줄 높이가 약 1.45em 이라 그만큼을 뺀 나머지를 더한다.
    func lineHeight(_ multiple: CGFloat, fontSize: CGFloat) -> some View {
        lineSpacing(max(0, fontSize * (multiple - 1.45)))
    }
}
