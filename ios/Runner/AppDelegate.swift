import Flutter
import SwiftUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "uztexpro/native_sheet",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "showSheet", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      NativeSheet.present(args)
      result(nil)
    }
  }
}

// MARK: - Native sheet (iOS system sheet with a close button)
//
// One generic card used by several screens: a header (avatar or icon, title,
// subtitle, status), sections of rows and an optional centered phone button.

enum NativeSheet {
  static func present(_ args: [String: Any]) {
    let model = SheetModel(args)
    let host = UIHostingController(rootView: SheetView(model: model))
    let nav = UINavigationController(rootViewController: host)
    nav.setNavigationBarHidden(false, animated: false)
    host.navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .close,
      primaryAction: UIAction { [weak nav] _ in nav?.dismiss(animated: true) }
    )
    nav.modalPresentationStyle = .pageSheet
    if let sheet = nav.sheetPresentationController {
      if #available(iOS 16.0, *) {
        // Tall enough for the whole card so it opens fully instead of at the
        // half-screen detent; still pulls up to large for longer content.
        let estimate = model.estimatedHeight
        let fit = UISheetPresentationController.Detent.custom(identifier: .init("fit")) { ctx in
          min(estimate, ctx.maximumDetentValue)
        }
        sheet.detents = [fit, .large()]
        sheet.selectedDetentIdentifier = fit.identifier
      } else {
        sheet.detents = [.large()]
      }
      sheet.prefersGrabberVisible = true
    }
    topViewController()?.present(nav, animated: true)
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}

final class SheetModel: ObservableObject {
  struct Row: Identifiable {
    let id = UUID()
    let sf: String?
    let color: Color
    let label: String
    let subtitle: String
    let value: String
    let bold: Bool
    let accent: Bool
  }

  struct Section: Identifiable {
    let id = UUID()
    let title: String
    let rows: [Row]
  }

  let name: String
  let subtitle: String
  let status: String
  let isIn: Bool
  let statusColor: Color?
  let heroSf: String?
  let phone: String
  let sections: [Section]
  @Published var photo: UIImage?

  var estimatedHeight: CGFloat {
    var h: CGFloat = 175 + (status.isEmpty ? 0 : 26) + (subtitle.isEmpty ? 0 : 18)
    for s in sections {
      h += 18 + (s.title.isEmpty ? 0 : 26)
      for r in s.rows { h += r.subtitle.isEmpty ? 45 : 58 }
    }
    if !phone.isEmpty { h += 63 }
    return h
  }

  init(_ a: [String: Any]) {
    name = a["name"] as? String ?? ""
    subtitle = a["subtitle"] as? String ?? ""
    status = a["status"] as? String ?? ""
    isIn = a["isIn"] as? Bool ?? false
    statusColor = (a["statusColor"] as? NSNumber).map { Color(argb: $0.uint32Value) }
    heroSf = a["heroSf"] as? String
    phone = a["phone"] as? String ?? ""
    sections = (a["sections"] as? [[String: Any]] ?? []).map { s in
      Section(
        title: s["title"] as? String ?? "",
        rows: (s["rows"] as? [[String: Any]] ?? []).map {
          Row(sf: $0["sf"] as? String,
              color: Color(argb: ($0["color"] as? NSNumber)?.uint32Value ?? 0xFF8E8E93),
              label: $0["label"] as? String ?? "",
              subtitle: $0["subtitle"] as? String ?? "",
              value: $0["value"] as? String ?? "",
              bold: $0["bold"] as? Bool ?? false,
              accent: $0["accent"] as? Bool ?? false)
        })
    }
    if let urlString = a["photoUrl"] as? String, let url = URL(string: urlString) {
      var request = URLRequest(url: url)
      (a["headers"] as? [String: String])?.forEach {
        request.setValue($1, forHTTPHeaderField: $0)
      }
      URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
        guard let data, let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self?.photo = image }
      }.resume()
    }
  }
}

extension Color {
  init(argb: UInt32) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: 1)
  }
}

/// White glyph on a coloured rounded square, like iOS Settings / Telegram.
struct IconTile: View {
  let sf: String
  let color: Color

  var body: some View {
    Image(systemName: sf)
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.white)
      .frame(width: 30, height: 30)
      .background(
        LinearGradient(
          colors: [color.opacity(0.88), color], startPoint: .top, endPoint: .bottom)
      )
      .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
  }
}

struct SheetView: View {
  @ObservedObject var model: SheetModel

  private let brandRed = Color(argb: 0xFFCC1500)

  private var statusTint: Color {
    model.statusColor ?? (model.isIn ? .green : .gray)
  }

  private var initials: String {
    model.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
  }

  var body: some View {
    List {
      Section {
        VStack(spacing: 4) {
          avatar
            .padding(.bottom, 4)
          Text(model.name)
            .font(.system(size: 18, weight: .bold))
            .multilineTextAlignment(.center)
          if !model.subtitle.isEmpty {
            Text(model.subtitle)
              .font(.system(size: 13))
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
          }
          if !model.status.isEmpty {
            Text(model.status)
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(statusTint)
              .padding(.horizontal, 9)
              .padding(.vertical, 3)
              .background(statusTint.opacity(0.15))
              .clipShape(Capsule())
              .padding(.top, 4)
          }
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
      }

      ForEach(model.sections) { section in
        Section {
          ForEach(section.rows) { row in
            rowView(row)
              .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
          }
        } header: {
          if !section.title.isEmpty { Text(section.title) }
        }
      }

      if !model.phone.isEmpty {
        Section {
          Button {
            let digits = model.phone.filter { $0.isNumber || $0 == "+" }
            if let url = URL(string: "tel:\(digits)") { UIApplication.shared.open(url) }
          } label: {
            Text(model.phone)
              .font(.system(size: 16, weight: .semibold))
              .frame(maxWidth: .infinity)
          }
          .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
        }
      }
    }
    .listStyle(.insetGrouped)
    .environment(\.defaultMinListRowHeight, 44)
    .modifier(CompactSections())
  }

  @ViewBuilder private func rowView(_ row: SheetModel.Row) -> some View {
    HStack(spacing: 12) {
      if let sf = row.sf { IconTile(sf: sf, color: row.color) }
      if row.subtitle.isEmpty {
        Text(row.label)
          .font(.system(size: 16, weight: row.bold ? .semibold : .regular))
          .lineLimit(row.sf == nil ? 2 : 1)
          .fixedSize(horizontal: row.sf != nil, vertical: false)
        Spacer(minLength: 8)
        Text(row.value)
          .font(.system(size: 16, weight: row.bold ? .bold : .regular))
          .foregroundColor(row.accent ? brandRed : .secondary)
          .multilineTextAlignment(.trailing)
          .lineLimit(2)
      } else {
        VStack(alignment: .leading, spacing: 2) {
          Text(row.label).font(.system(size: 16)).lineLimit(2)
          Text(row.subtitle).font(.system(size: 13)).foregroundColor(.secondary)
        }
        Spacer(minLength: 8)
        Text(row.value)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(row.accent ? brandRed : .secondary)
          .multilineTextAlignment(.trailing)
      }
    }
  }

  @ViewBuilder private var avatar: some View {
    if let sf = model.heroSf {
      Image(systemName: sf)
        .font(.system(size: 28, weight: .semibold))
        .foregroundColor(.white)
        .frame(width: 68, height: 68)
        .background(
          LinearGradient(
            colors: [Color(argb: 0xFFFF8C00), Color(argb: 0xFFCC1500)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    } else {
      Group {
        if let photo = model.photo {
          Image(uiImage: photo).resizable().scaledToFill()
        } else {
          ZStack {
            LinearGradient(
              colors: [Color(argb: 0xFFFF8C00), Color(argb: 0xFFCC1500)],
              startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials).font(.system(size: 24, weight: .bold)).foregroundColor(.white)
          }
        }
      }
      .frame(width: 68, height: 68)
      .clipShape(Circle())
    }
  }
}

/// Tighter gaps between the groups (iOS 17+), as on the settings screen.
struct CompactSections: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.listSectionSpacing(14)
    } else {
      content
    }
  }
}
