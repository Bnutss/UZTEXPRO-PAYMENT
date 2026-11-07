import Flutter
import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    VoiceBar.channel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "voiceBarHide" {
        VoiceBar.hide()
        result(nil)
        return
      }
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "voiceBarShow":
        VoiceBar.show(args)
        result(nil)
      case "showSheet":
        NativeSheet.present(args)
        result(nil)
      case "pickContacts":
        ContactPicker.present(args, result: result)
      case "attachSheet":
        AttachSheet.present(args, result: result)
      case "editGroup":
        GroupEditor.present(args, result: result)
      case "pickPhoto":
        PhotoPickerPresenter.present(result: result)
      case "photoViewer":
        PhotoViewerPresenter.present(args)
        result(nil)
      case "chatPreview":
        ChatPreviewPresenter.present(args, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // System spell check (UITextChecker) for the chat input: the red dotted
    // underline of the misspelled words, in the language the text is written in.
    let spell = FlutterMethodChannel(
      name: "uztexpro/spellcheck",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    spell.setMethodCallHandler { call, result in
      guard call.method == "check", let text = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(SpellChecker.check(text))
    }
  }
}

// MARK: - Spell check

enum SpellChecker {
  private static let checker = UITextChecker()
  private static let cyrillic: Set<String> = ["ru", "uk", "bg", "be", "sr", "mk", "kk", "ky", "mn", "tg"]

  /// The dictionaries to check with: those of the keyboards the person has
  /// installed, plus Russian and English, as the checker names them
  /// ("ru_RU", "en_US"…). A language the system has no dictionary for (Uzbek)
  /// is simply not here.
  private static func languages() -> [String] {
    var wanted: [String] = UITextInputMode.activeInputModes.compactMap { $0.primaryLanguage }
    wanted += ["ru", "en"]
    var out: [String] = []
    for w in wanted {
      let code = String(w.lowercased().prefix(2))
      if let match = UITextChecker.availableLanguages.first(where: { $0.lowercased().hasPrefix(code) }),
         !out.contains(match) {
        out.append(match)
      }
    }
    return out
  }

  private static func isCyrillic(_ lang: String) -> Bool {
    cyrillic.contains(String(lang.lowercased().prefix(2)))
  }

  private static func isCyrillicWord(_ word: String) -> Bool {
    guard let u = word.unicodeScalars.first(where: { CharacterSet.letters.contains($0) }) else { return false }
    return (0x0400...0x052F).contains(Int(u.value))
  }

  /// [{start, end, suggestions}] in UTF-16 offsets, as Flutter counts them.
  /// A word is underlined only when EVERY dictionary of its script (Cyrillic or
  /// Latin) calls it a mistake, so a word that is right in one of the person's
  /// languages is never marked.
  static func check(_ text: String) -> [[String: Any]] {
    let ns = text as NSString
    let langs = languages()
    guard ns.length > 0, ns.length <= 2000, !langs.isEmpty else { return [] }

    // language -> [location: range] of the misspelled words
    var found: [String: [Int: NSRange]] = [:]
    for lang in langs {
      var map: [Int: NSRange] = [:]
      var offset = 0
      while offset < ns.length {
        let r = checker.rangeOfMisspelledWord(
          in: text, range: NSRange(location: 0, length: ns.length),
          startingAt: offset, wrap: false, language: lang)
        if r.location == NSNotFound { break }
        map[r.location] = r
        offset = r.location + max(r.length, 1)
      }
      found[lang] = map
    }

    var out: [[String: Any]] = []
    let locations = Set(found.values.flatMap { $0.keys }).sorted()
    for loc in locations {
      guard let range = langs.compactMap({ found[$0]?[loc] }).first else { continue }
      let word = ns.substring(with: range)
      let cyr = isCyrillicWord(word)
      let relevant = langs.filter { isCyrillic($0) == cyr }
      guard !relevant.isEmpty,
            relevant.allSatisfy({ found[$0]?[loc]?.length == range.length }) else { continue }
      let guesses = checker.guesses(forWordRange: range, in: text, language: relevant[0]) ?? []
      out.append([
        "start": range.location,
        "end": range.location + range.length,
        "suggestions": Array(guesses.prefix(5)),
      ])
    }
    return out
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
      if args["tall"] as? Bool == true {
        // A card that opens to the full height at once (attendance).
        sheet.detents = [.large()]
        sheet.selectedDetentIdentifier = .large
      } else if #available(iOS 16.0, *) {
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

  static func topViewControllerForPresenting() -> UIViewController? { topViewController() }

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


// MARK: - Contact picker (new group)
//
// A native sheet that opens almost to the top: a list of people to tick, the
// system search field, a back button and "Next". It answers with the ticked
// ids ({"ids": [...]}) on Next, or nil when it is closed.

enum ContactPicker {
  private static var delegate: PickerDismissDelegate?

  static func present(_ args: [String: Any], result: @escaping FlutterResult) {
    let people: [PickerPerson] = (args["contacts"] as? [[String: Any]] ?? []).compactMap { c in
      guard let id = (c["id"] as? NSNumber)?.intValue else { return nil }
      return PickerPerson(
        id: id,
        name: c["name"] as? String ?? "",
        subtitle: c["subtitle"] as? String ?? "",
        status: c["status"] as? String ?? "",
        photo: c["photo"] as? String ?? ""
      )
    }
    var finished = false
    let finish: ([String: Any]?) -> Void = { payload in
      if finished { return }
      finished = true
      delegate = nil
      result(payload)
    }

    // The buttons close the sheet through this box: the controller does not
    // exist yet when the view (and its closures) is built, and a `[weak host]`
    // capture would have captured nil, so Create and Close did nothing.
    let box = WeakBox()
    let view = ContactPickerView(
      people: people,
      title: args["title"] as? String ?? "",
      searchPrompt: args["searchPrompt"] as? String ?? "",
      nextTitle: args["next"] as? String ?? "",
      createTitle: args["create"] as? String ?? "",
      addMode: args["addMode"] as? Bool ?? false,
      namePlaceholder: args["namePlaceholder"] as? String ?? "",
      onBack: {
        if let vc = box.vc {
          vc.dismiss(animated: true) { finish(nil) }
        } else {
          finish(nil)
        }
      },
      onCreate: { ids, name, photo in
        var payload: [String: Any] = ["ids": ids, "name": name]
        if let photo = photo { payload["photo"] = FlutterStandardTypedData(bytes: photo) }
        if let vc = box.vc {
          vc.dismiss(animated: true) { finish(payload) }
        } else {
          finish(payload)
        }
      }
    )
    let host = UIHostingController(rootView: view)
    box.vc = host
    host.modalPresentationStyle = .pageSheet
    if let sheet = host.sheetPresentationController {
      sheet.detents = [.large()]
      sheet.prefersGrabberVisible = true
    }
    // A swipe down closes it too.
    let d = PickerDismissDelegate { finish(nil) }
    delegate = d
    host.presentationController?.delegate = d
    NativeSheet.topViewControllerForPresenting()?.present(host, animated: true)
  }
}

/// "Edit group": the same card as the second step of creating one (the photo
/// and the name), in a native sheet with "Save".
enum GroupEditor {
  private static var delegate: PickerDismissDelegate?

  static func present(_ args: [String: Any], result: @escaping FlutterResult) {
    var finished = false
    let finish: ([String: Any]?) -> Void = { payload in
      if finished { return }
      finished = true
      delegate = nil
      result(payload)
    }
    let box = WeakBox()
    let view = GroupEditView(
      title: args["title"] as? String ?? "",
      saveTitle: args["save"] as? String ?? "",
      removePhotoTitle: args["removePhoto"] as? String ?? "",
      namePlaceholder: args["namePlaceholder"] as? String ?? "",
      initialName: args["name"] as? String ?? "",
      photoURL: args["photo"] as? String ?? "",
      membersTitle: args["membersTitle"] as? String ?? "",
      members: (args["members"] as? [[String: Any]] ?? []).compactMap { c in
        guard let id = (c["id"] as? NSNumber)?.intValue else { return nil }
        return EditMember(
          person: PickerPerson(
            id: id,
            name: c["name"] as? String ?? "",
            subtitle: "",
            status: c["status"] as? String ?? "",
            photo: c["photo"] as? String ?? ""
          ),
          role: c["role"] as? String ?? ""
        )
      },
      onClose: {
        if let vc = box.vc { vc.dismiss(animated: true) { finish(nil) } } else { finish(nil) }
      },
      onSave: { name, photo, removed in
        var payload: [String: Any] = ["name": name, "removePhoto": removed]
        if let photo = photo { payload["photo"] = FlutterStandardTypedData(bytes: photo) }
        if let vc = box.vc { vc.dismiss(animated: true) { finish(payload) } } else { finish(payload) }
      }
    )
    let host = UIHostingController(rootView: view)
    box.vc = host
    host.modalPresentationStyle = .pageSheet
    if let sheet = host.sheetPresentationController {
      sheet.detents = [.large()]
      sheet.prefersGrabberVisible = true
    }
    let d = PickerDismissDelegate { finish(nil) }
    delegate = d
    host.presentationController?.delegate = d
    NativeSheet.topViewControllerForPresenting()?.present(host, animated: true)
  }
}

struct EditMember: Identifiable {
  let person: PickerPerson
  let role: String   // "owner" / "admin" (already translated), or empty
  var id: Int { person.id }
}

struct GroupEditView: View {
  let title: String
  let saveTitle: String
  let removePhotoTitle: String
  let namePlaceholder: String
  let initialName: String
  let photoURL: String
  let membersTitle: String
  let members: [EditMember]
  let onClose: () -> Void
  let onSave: (String, Data?, Bool) -> Void

  @State private var name = ""
  @State private var photo: UIImage?
  @State private var removed = false
  @State private var pickingPhoto = false
  @FocusState private var nameFocused: Bool

  private var hasCurrentPhoto: Bool { !photoURL.isEmpty && !removed }
  private var hasAnyPhoto: Bool { photo != nil || hasCurrentPhoto }
  private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

  var body: some View {
    if #available(iOS 16.0, *) {
      NavigationStack { content }
    } else {
      NavigationView { content }
    }
  }

  private func save() {
    let data = photo.flatMap { ContactPickerView.downscaledImage($0, maxSide: 1024).jpegData(compressionQuality: 0.85) }
    onSave(trimmed, data, removed && photo == nil)
  }

  private var content: some View {
    ScrollView {
      VStack(spacing: 14) {
        HStack(spacing: 16) {
          Button { pickingPhoto = true } label: {
            ZStack {
              Circle().fill(Color(red: 0.90, green: 0.94, blue: 1.0))
              if let photo = photo {
                Image(uiImage: photo).resizable().scaledToFill().clipShape(Circle())
              } else if hasCurrentPhoto, let url = URL(string: photoURL), #available(iOS 15.0, *) {
                AsyncImage(url: url) { phase in
                  if let image = phase.image { image.resizable().scaledToFill() }
                }
                .clipShape(Circle())
              } else {
                Image(systemName: "camera.fill")
                  .font(.system(size: 28))
                  .foregroundColor(Color(red: 0.2, green: 0.47, blue: 0.96))
              }
            }
            .frame(width: 84, height: 84)
          }
          .buttonStyle(.plain)
          TextField(namePlaceholder, text: $name)
            .font(.title3)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit { if !trimmed.isEmpty { save() } }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

        if hasAnyPhoto {
          Button(role: .destructive) {
            photo = nil
            removed = true
          } label: {
            Text(removePhotoTitle).font(.body)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(Color(.systemBackground))
              .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          }
        }

        if !members.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Text("\(membersTitle.uppercased()) · \(members.count)")
              .font(.footnote)
              .foregroundColor(.secondary)
              .padding(.leading, 16)
            VStack(spacing: 0) {
              ForEach(Array(members.enumerated()), id: \.element.id) { index, m in
                HStack(spacing: 12) {
                  PickerAvatar(person: m.person, size: 40)
                  VStack(alignment: .leading, spacing: 1) {
                    Text(m.person.name).font(.body).lineLimit(1)
                    if !m.person.status.isEmpty {
                      Text(m.person.status).font(.footnote).foregroundColor(.secondary).lineLimit(1)
                    }
                  }
                  Spacer(minLength: 0)
                  if !m.role.isEmpty {
                    Text(m.role).font(.footnote).foregroundColor(Color(red: 1.0, green: 0.416, blue: 0.0))
                  }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                if index < members.count - 1 {
                  Divider().padding(.leading, 68)
                }
              }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
          }
        }
      }
      .padding(16)
    }
    .background(Color(.systemGroupedBackground))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button { onClose() } label: { Image(systemName: "xmark") }
      }
      ToolbarItem(placement: .principal) { Text(title).font(.headline) }
      ToolbarItem(placement: .navigationBarTrailing) {
        Button { save() } label: { Text(saveTitle).font(.body.weight(.semibold)) }
          .disabled(trimmed.isEmpty)
      }
    }
    .onAppear {
      name = initialName
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { nameFocused = true }
    }
    .sheet(isPresented: $pickingPhoto) {
      PhotoPicker { image in
        photo = image
        removed = false
      }
    }
  }
}

/// Holds the sheet's controller weakly, set once it exists.
final class WeakBox {
  weak var vc: UIViewController?
}

final class PickerDismissDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
  private let onDismiss: () -> Void
  init(_ onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onDismiss()
  }
}

struct PickerPerson: Identifiable {
  let id: Int
  let name: String
  let subtitle: String   // position · department: only searched
  let status: String     // "was online recently": shown under the name
  let photo: String
}

struct ContactPickerView: View {
  let people: [PickerPerson]
  let title: String
  let searchPrompt: String
  let nextTitle: String
  let createTitle: String
  /// Adding people to an existing group: "Next" hands the chosen people back
  /// at once, there is no step for the name.
  let addMode: Bool
  let namePlaceholder: String
  let onBack: () -> Void
  let onCreate: ([Int], String, Data?) -> Void

  @State private var query = ""
  @State private var selected: [Int] = []
  /// Step two: the name and the photo of the group.
  @State private var naming = false
  @State private var name = ""
  @State private var photo: UIImage?
  @State private var pickingPhoto = false
  @FocusState private var nameFocused: Bool

  private let accent = Color(red: 1.0, green: 0.416, blue: 0.0)
  private let limit = 200

  private var filtered: [PickerPerson] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    if q.isEmpty { return people }
    return people.filter {
      $0.name.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
    }
  }

  /// The letter a person is filed under: the first letter of the name, or "#".
  private func letter(_ p: PickerPerson) -> String {
    guard let c = p.name.trimmingCharacters(in: .whitespaces).first, c.isLetter else { return "#" }
    return String(c).uppercased()
  }

  /// Latin letters first, then Cyrillic, then "#" (as in Telegram).
  private func rank(_ l: String) -> Int {
    guard let u = l.unicodeScalars.first else { return 3 }
    if l == "#" { return 2 }
    return (0x0400...0x052F).contains(Int(u.value)) ? 1 : 0
  }

  private var sections: [(letter: String, items: [PickerPerson])] {
    let grouped = Dictionary(grouping: filtered, by: letter)
    return grouped.keys
      .sorted { (rank($0), $0) < (rank($1), $1) }
      .map { (letter: $0, items: grouped[$0]!.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
  }

  private func toggle(_ id: Int) {
    if let i = selected.firstIndex(of: id) {
      selected.remove(at: i)
    } else if selected.count < limit {
      selected.append(id)
    }
  }

  var body: some View {
    if #available(iOS 16.0, *) {
      NavigationStack { content }
    } else {
      NavigationView { content }
    }
  }

  private var content: some View {
    Group {
      if naming { namingStep } else { pickingStep }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          if naming { naming = false; nameFocused = false } else { onBack() }
        } label: {
          // Step one closes the sheet (X); step two goes back to the people.
          Image(systemName: naming ? "chevron.backward" : "xmark")
        }
      }
      ToolbarItem(placement: .principal) {
        if naming {
          Text(title).font(.headline)
        } else {
          VStack(spacing: 1) {
            Text(title).font(.headline)
            Text("\(selected.count)/\(limit)").font(.caption).foregroundColor(.secondary)
          }
        }
      }
      ToolbarItem(placement: .navigationBarTrailing) {
        if naming {
          Button { create() } label: {
            Text(createTitle).font(.body.weight(.semibold))
          }
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        } else {
          Button {
            if addMode {
              onCreate(selected, "", nil)
            } else {
              naming = true
              nameFocused = true
            }
          } label: {
            Text(nextTitle).font(.body.weight(.semibold))
          }
          .disabled(selected.isEmpty)
        }
      }
    }
  }

  private func create() {
    let data = photo.flatMap { Self.downscaled($0, maxSide: 1024).jpegData(compressionQuality: 0.85) }
    onCreate(selected, name.trimmingCharacters(in: .whitespaces), data)
  }

  static func downscaledImage(_ image: UIImage, maxSide: CGFloat) -> UIImage { downscaled(image, maxSide: maxSide) }

  private static func downscaled(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let longest = max(image.size.width, image.size.height)
    guard longest > maxSide else { return image }
    let k = maxSide / longest
    let size = CGSize(width: image.size.width * k, height: image.size.height * k)
    return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
  }

  /// Step two: a card with the photo (tap: the gallery) and the name, then the
  /// chosen people.
  private var namingStep: some View {
    ScrollView {
      VStack(spacing: 22) {
        HStack(spacing: 16) {
          Button { pickingPhoto = true } label: {
            ZStack {
              Circle().fill(Color(red: 0.90, green: 0.94, blue: 1.0))
              if let photo = photo {
                Image(uiImage: photo).resizable().scaledToFill().clipShape(Circle())
              } else {
                Image(systemName: "camera.fill")
                  .font(.system(size: 28))
                  .foregroundColor(Color(red: 0.2, green: 0.47, blue: 0.96))
              }
            }
            .frame(width: 84, height: 84)
          }
          .buttonStyle(.plain)
          TextField(namePlaceholder, text: $name)
            .font(.title3)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit { if !name.trimmingCharacters(in: .whitespaces).isEmpty { create() } }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

        VStack(spacing: 0) {
          let chosen = selected.compactMap { id in people.first(where: { $0.id == id }) }
          ForEach(Array(chosen.enumerated()), id: \.element.id) { index, p in
            HStack(spacing: 12) {
              PickerAvatar(person: p, size: 40)
              VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.body).lineLimit(1)
                if !p.status.isEmpty {
                  Text(p.status).font(.footnote).foregroundColor(.secondary).lineLimit(1)
                }
              }
              Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            if index < chosen.count - 1 {
              Divider().padding(.leading, 68)
            }
          }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      }
      .padding(16)
    }
    .background(Color(.systemGroupedBackground))
    .onAppear {
      // The keyboard comes up on the name, as in Telegram.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { nameFocused = true }
    }
    .sheet(isPresented: $pickingPhoto) {
      PhotoPicker { image in photo = image }
    }
  }

  private var pickingStep: some View {
    ScrollViewReader { proxy in
      ZStack(alignment: .trailing) {
        List {
          if !selected.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(selected, id: \.self) { id in
                  if let p = people.first(where: { $0.id == id }) {
                    Button { toggle(id) } label: {
                      HStack(spacing: 4) {
                        Text(p.name.split(separator: " ").prefix(2).joined(separator: " "))
                          .font(.subheadline)
                        Image(systemName: "xmark.circle.fill").font(.subheadline)
                      }
                      .padding(.horizontal, 10).padding(.vertical, 6)
                      .background(accent.opacity(0.15))
                      .foregroundColor(accent)
                      .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
          }
          ForEach(sections, id: \.letter) { section in
            Section(header: Text(section.letter).id(section.letter)) {
              ForEach(section.items) { p in row(p) }
            }
          }
        }
        .listStyle(.plain)

        if query.isEmpty && sections.count > 1 {
          LetterIndex(letters: sections.map { $0.letter }, accent: accent) { l in
            proxy.scrollTo(l, anchor: .top)
          }
          .padding(.trailing, 2)
        }
      }
    }
    .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: searchPrompt)
  }

  private func row(_ p: PickerPerson) -> some View {
    Button { toggle(p.id) } label: {
      HStack(spacing: 12) {
        Image(systemName: selected.contains(p.id) ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundColor(selected.contains(p.id) ? accent : Color(.systemGray3))
        PickerAvatar(person: p)
        VStack(alignment: .leading, spacing: 1) {
          Text(p.name).font(.body).foregroundColor(.primary).lineLimit(1)
          if !p.status.isEmpty {
            Text(p.status).font(.footnote).foregroundColor(.secondary).lineLimit(1)
          }
        }
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

/// The column of letters on the right: tap or drag along it to jump.
struct LetterIndex: View {
  let letters: [String]
  let accent: Color
  let onPick: (String) -> Void

  @State private var last = ""

  var body: some View {
    GeometryReader { geo in
      VStack(spacing: 0) {
        ForEach(letters, id: \.self) { l in
          Text(l)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { v in
          guard !letters.isEmpty, geo.size.height > 0 else { return }
          let i = min(max(Int(v.location.y / geo.size.height * CGFloat(letters.count)), 0), letters.count - 1)
          if letters[i] != last {
            last = letters[i]
            UISelectionFeedbackGenerator().selectionChanged()
            onPick(letters[i])
          }
        }.onEnded { _ in last = "" }
      )
    }
    .frame(width: 20)
    .frame(maxHeight: CGFloat(letters.count) * 18)
  }
}

struct PickerAvatar: View {
  let person: PickerPerson
  var size: CGFloat = 46

  private static let palette: [Color] = [
    Color(red: 0.42, green: 0.45, blue: 0.95), Color(red: 0.78, green: 0.40, blue: 0.90),
    Color(red: 0.95, green: 0.65, blue: 0.30), Color(red: 0.30, green: 0.70, blue: 0.95),
    Color(red: 0.35, green: 0.78, blue: 0.55), Color(red: 0.35, green: 0.80, blue: 0.85),
    Color(red: 0.95, green: 0.45, blue: 0.50),
  ]

  private var initial: String {
    String(person.name.trimmingCharacters(in: .whitespaces).first ?? "?").uppercased()
  }

  var body: some View {
    ZStack {
      Circle().fill(Self.palette[abs(person.id) % Self.palette.count])
      Text(initial).font(.system(size: 20, weight: .medium)).foregroundColor(.white)
      if let url = URL(string: person.photo), !person.photo.isEmpty {
        if #available(iOS 15.0, *) {
          AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
          }
          .clipShape(Circle())
        }
      }
    }
    .frame(width: size, height: size)
  }
}


/// The system photo picker (the gallery), no permission needed.
struct PhotoPicker: UIViewControllerRepresentable {
  let onPick: (UIImage) -> Void

  func makeUIViewController(context: Context) -> PHPickerViewController {
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = 1
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onPick) }

  final class Coordinator: NSObject, PHPickerViewControllerDelegate {
    let onPick: (UIImage) -> Void
    init(_ onPick: @escaping (UIImage) -> Void) { self.onPick = onPick }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
      picker.dismiss(animated: true)
      guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
      item.loadObject(ofClass: UIImage.self) { object, _ in
        if let image = object as? UIImage {
          DispatchQueue.main.async { self.onPick(image) }
        }
      }
    }
  }
}


/// The gallery on its own (for a group's photo outside the "new group" sheet).
enum PhotoPickerPresenter {
  private static var holder: PhotoPickerHolder?

  static func present(result: @escaping FlutterResult) {
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = 1
    let picker = PHPickerViewController(configuration: config)
    let h = PhotoPickerHolder(result: result)
    holder = h
    picker.delegate = h
    NativeSheet.topViewControllerForPresenting()?.present(picker, animated: true)
  }

  fileprivate static func release() { holder = nil }
}

final class PhotoPickerHolder: NSObject, PHPickerViewControllerDelegate {
  private let result: FlutterResult
  init(result: @escaping FlutterResult) { self.result = result }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else {
      result(nil)
      PhotoPickerPresenter.release()
      return
    }
    item.loadObject(ofClass: UIImage.self) { object, _ in
      DispatchQueue.main.async {
        defer { PhotoPickerPresenter.release() }
        guard let image = object as? UIImage else { self.result(nil); return }
        let longest = max(image.size.width, image.size.height)
        let k = min(1, 1024 / longest)
        let size = CGSize(width: image.size.width * k, height: image.size.height * k)
        let scaled = UIGraphicsImageRenderer(size: size).image { _ in
          image.draw(in: CGRect(origin: .zero, size: size))
        }
        if let data = scaled.jpegData(compressionQuality: 0.85) {
          self.result(["photo": FlutterStandardTypedData(bytes: data)])
        } else {
          self.result(nil)
        }
      }
    }
  }
}


// MARK: - Chat preview (long press on a chat in the list)
//
// As in Telegram: the page goes dark and blurred, a card shows the chat's
// header and its last messages (and it SCROLLS), and under it a menu of
// actions. A tap on the card opens the chat. It answers {"open": true},
// {"index": n} (the action) or nil (closed).

struct ChatPreviewConfig {
  let title: String
  let subtitle: String
  let photo: String
  let conversationId: Int
  let myId: Int
  let peerId: Int
  let isGroup: Bool
  let apiBase: String
  let token: String
  let emptyText: String
  /// Where the pressed row is on the screen (points); the preview sits beside it.
  let rowTop: CGFloat
  let rowBottom: CGFloat

  init?(_ d: [String: Any]?) {
    guard let d = d,
          let id = (d["conversationId"] as? NSNumber)?.intValue,
          let base = d["apiBase"] as? String, !base.isEmpty else { return nil }
    conversationId = id
    apiBase = base
    token = d["token"] as? String ?? ""
    title = d["title"] as? String ?? ""
    subtitle = d["subtitle"] as? String ?? ""
    photo = d["photo"] as? String ?? ""
    myId = (d["myId"] as? NSNumber)?.intValue ?? 0
    peerId = (d["peerId"] as? NSNumber)?.intValue ?? 0
    isGroup = (d["isGroup"] as? NSNumber)?.boolValue ?? false
    emptyText = d["emptyText"] as? String ?? ""
    rowTop = CGFloat((d["rowTop"] as? NSNumber)?.doubleValue ?? 0)
    rowBottom = CGFloat((d["rowBottom"] as? NSNumber)?.doubleValue ?? 0)
  }
}

struct PreviewAction: Identifiable {
  let id: Int
  let label: String
  let symbol: String
  let destructive: Bool
}

enum ChatPreviewPresenter {
  private static var finishing = false

  static func present(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let config = ChatPreviewConfig(args["preview"] as? [String: Any]),
          let top = NativeSheet.topViewControllerForPresenting() else {
      result(nil)
      return
    }
    let actions: [PreviewAction] = (args["actions"] as? [[String: Any]] ?? []).enumerated().map { i, a in
      PreviewAction(
        id: i,
        label: a["label"] as? String ?? "",
        symbol: a["symbol"] as? String ?? "",
        destructive: (a["destructive"] as? NSNumber)?.boolValue ?? false
      )
    }
    finishing = false
    var host: UIViewController!
    let close: ([String: Any]?) -> Void = { payload in
      if finishing { return }
      finishing = true
      host.dismiss(animated: false) { result(payload) }
    }
    let view = ChatPreviewScreen(
      config: config,
      actions: actions,
      onPick: { index in close(["index": index]) },
      onOpen: { close(["open": true]) },
      onClose: { close(nil) }
    )
    let controller = UIHostingController(rootView: view)
    controller.view.backgroundColor = .clear
    controller.modalPresentationStyle = .overFullScreen
    controller.modalTransitionStyle = .crossDissolve
    host = controller
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    top.present(controller, animated: true)
  }
}

struct PreviewMessage: Identifiable {
  let id: Int
  let sender: Int
  let senderName: String
  let text: String
  let time: String
  let isSystem: Bool
}

final class ChatPreviewModel: ObservableObject {
  @Published var messages: [PreviewMessage] = []
  @Published var loading = true
  let config: ChatPreviewConfig

  init(_ config: ChatPreviewConfig) { self.config = config }

  func load() {
    guard let url = URL(string: "\(config.apiBase)/conversations/\(config.conversationId)/messages/?limit=40") else {
      loading = false
      return
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 8
    URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
      let parsed = Self.parse(data)
      DispatchQueue.main.async {
        self?.messages = parsed
        self?.loading = false
      }
    }.resume()
  }

  private static func parse(_ data: Data?) -> [PreviewMessage] {
    guard let data = data,
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rows = root["messages"] as? [[String: Any]] else { return [] }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    let clock = DateFormatter()
    clock.dateFormat = "HH:mm"
    return rows.compactMap { r in
      guard let id = (r["id"] as? NSNumber)?.intValue else { return nil }
      let created = (r["created_at"] as? String).flatMap { iso.date(from: $0) ?? plain.date(from: $0) }
      // Voice messages and media have no text of their own: a line with an icon.
      var text = r["text"] as? String ?? ""
      let media = r["media"] as? [String: Any]
      switch r["kind"] as? String {
      case "voice": text = "🎤 " + text
      case "image": text = "📷 " + (text.isEmpty ? "Фото" : text)
      case "video": text = "🎥 " + (text.isEmpty ? "Видео" : text)
      case "file": text = "📎 " + (text.isEmpty ? (media?["name"] as? String ?? "Файл") : text)
      default: break
      }
      return PreviewMessage(
        id: id,
        sender: (r["sender"] as? NSNumber)?.intValue ?? 0,
        senderName: r["sender_name"] as? String ?? "",
        text: text,
        time: created.map { clock.string(from: $0) } ?? "",
        isSystem: (r["kind"] as? String) == "system"
      )
    }
  }
}

/// The chat wallpaper (the app's own picture, from the Flutter assets).
enum ChatWallpaperImage {
  static let image: UIImage? = {
    let key = FlutterDartProject.lookupKey(forAsset: "assets/images/background.jpg")
    guard let path = Bundle.main.path(forResource: key, ofType: nil) else { return nil }
    return UIImage(contentsOfFile: path)
  }()
}

struct BlurBackground: UIViewRepresentable {
  func makeUIView(context: Context) -> UIVisualEffectView {
    UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
  }
  func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}

struct ChatPreviewScreen: View {
  @StateObject private var model: ChatPreviewModel
  let actions: [PreviewAction]
  let onPick: (Int) -> Void
  let onOpen: () -> Void
  let onClose: () -> Void

  @State private var appeared = false
  private let paper = Color(red: 1.0, green: 0.945, blue: 0.902)
  private let mineGreen = Color(red: 0.882, green: 1.0, blue: 0.78)
  private let accent = Color(red: 1.0, green: 0.416, blue: 0.0)

  init(config: ChatPreviewConfig, actions: [PreviewAction],
       onPick: @escaping (Int) -> Void, onOpen: @escaping () -> Void, onClose: @escaping () -> Void) {
    _model = StateObject(wrappedValue: ChatPreviewModel(config))
    self.actions = actions
    self.onPick = onPick
    self.onOpen = onOpen
    self.onClose = onClose
  }

  var body: some View {
    GeometryReader { geo in
      let layout = placement(in: geo)
      ZStack(alignment: .topLeading) {
        BlurBackground().ignoresSafeArea().opacity(appeared ? 1 : 0)
        Color.black.opacity(0.06).ignoresSafeArea().onTapGesture { onClose() }
        VStack(alignment: .leading, spacing: 12) {
          card
            .frame(width: geo.size.width - 32, height: layout.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 18, y: 6)
          menu
        }
        .padding(.leading, 16)
        .offset(y: layout.top)
        .scaleEffect(appeared ? 1 : 0.92, anchor: .top)
        .opacity(appeared ? 1 : 0)
      }
      .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
    }
    .onAppear {
      model.load()
      withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { appeared = true }
    }
  }

  /// The card and the menu go below the pressed row when there is room, else
  /// above it, so the row stays in sight (as in Telegram).
  private func placement(in geo: GeometryProxy) -> (top: CGFloat, cardHeight: CGFloat) {
    let menuHeight = CGFloat(actions.count) * 49 + 4
    let gap: CGFloat = 12
    let safeTop = geo.safeAreaInsets.top + 6
    let safeBottom = geo.size.height - geo.safeAreaInsets.bottom - 6
    let rowTop = model.config.rowTop, rowBottom = model.config.rowBottom
    let fixed = menuHeight + gap
    let below = safeBottom - (rowBottom + 8) - fixed
    let above = (rowTop - 8) - safeTop - fixed
    let wanted: CGFloat = min(geo.size.height * 0.55, 500)
    if rowBottom > 0 {
      if below >= 260 {
        let h = min(wanted, below)
        return (rowBottom + 8, h)
      }
      if above >= 260 {
        let h = min(wanted, above)
        return (rowTop - 8 - fixed - h, h)
      }
    }
    // No row known, or no room: centred.
    let h = min(wanted, safeBottom - safeTop - fixed)
    return (safeTop + max(0, (safeBottom - safeTop - fixed - h) / 2), h)
  }

  // The card: header over the scrolling messages. A tap on it opens the chat
  // (a drag scrolls).
  private var card: some View {
    ZStack(alignment: .top) {
      paper
      if let wallpaper = ChatWallpaperImage.image {
        // As in the chat: the picture fills the card, slightly soft.
        Image(uiImage: wallpaper)
          .resizable()
          .scaledToFill()
          .blur(radius: 3)
          .allowsHitTesting(false)
      }
      messagesView
      header
    }
    .clipped()
    .contentShape(Rectangle())
    .onTapGesture { onOpen() }
  }

  private var header: some View {
    HStack(spacing: 10) {
      PreviewAvatar(name: model.config.title, photo: model.config.photo, size: 38)
      VStack(alignment: .leading, spacing: 0) {
        Text(model.config.title).font(.system(size: 16, weight: .bold)).lineLimit(1)
        Text(model.config.subtitle).font(.system(size: 12)).foregroundColor(accent).lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .frame(height: 58)
    .frame(maxWidth: .infinity)
    .background(.ultraThinMaterial)
  }

  @ViewBuilder
  private var messagesView: some View {
    if model.loading {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if model.messages.isEmpty {
      Text(model.config.emptyText).foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollViewReader { proxy in
        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 3) {
            ForEach(Array(model.messages.enumerated()), id: \.element.id) { index, m in
              bubble(m, previous: index > 0 ? model.messages[index - 1] : nil).id(m.id)
            }
          }
          .padding(.horizontal, 10)
          .padding(.top, 66)
          .padding(.bottom, 10)
        }
        // It opens at the newest messages, and scrolls up to older ones.
        .onAppear {
          if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
        }
      }
    }
  }

  private func isMine(_ m: PreviewMessage) -> Bool {
    model.config.isGroup ? m.sender == model.config.myId : m.sender != model.config.peerId
  }

  @ViewBuilder
  private func bubble(_ m: PreviewMessage, previous: PreviewMessage?) -> some View {
    if m.isSystem {
      Text(m.text)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(Color.white.opacity(0.7))
        .clipShape(Capsule())
        .padding(.vertical, 5)
    } else {
      let mine = isMine(m)
      let showName = model.config.isGroup && !mine && (previous == nil || previous!.sender != m.sender || previous!.isSystem)
      HStack {
        if mine { Spacer(minLength: 40) }
        VStack(alignment: .leading, spacing: 2) {
          if showName && !m.senderName.isEmpty {
            Text(m.senderName.split(separator: " ").first.map(String.init) ?? "")
              .font(.system(size: 13, weight: .semibold)).foregroundColor(accent)
          }
          HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(m.text).font(.system(size: 15)).foregroundColor(.black)
            Text(m.time).font(.system(size: 11))
              .foregroundColor(mine ? Color(red: 0.36, green: 0.67, blue: 0.33) : .secondary)
          }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(mine ? mineGreen : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        if !mine { Spacer(minLength: 40) }
      }
    }
  }

  // The menu under the card: rounded, label left, icon right, red when it deletes.
  private var menu: some View {
    VStack(spacing: 0) {
      ForEach(actions) { a in
        if a.id > 0 { Divider() }
        Button { onPick(a.id) } label: {
          HStack {
            Text(a.label).font(.system(size: 17))
            Spacer(minLength: 12)
            Image(systemName: a.symbol).font(.system(size: 18))
          }
          .foregroundColor(a.destructive ? .red : .primary)
          .padding(.horizontal, 16).padding(.vertical, 13)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(width: 260)
    .modifier(MenuGlass())
  }
}

struct PreviewAvatar: View {
  let name: String
  let photo: String
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle().fill(Color(red: 0.42, green: 0.45, blue: 0.95))
      Text(String(name.trimmingCharacters(in: .whitespaces).first ?? "?").uppercased())
        .font(.system(size: size * 0.45, weight: .medium)).foregroundColor(.white)
      if let url = URL(string: photo), !photo.isEmpty {
        AsyncImage(url: url) { phase in
          if let image = phase.image { image.resizable().scaledToFill() }
        }
        .clipShape(Circle())
      }
    }
    .frame(width: size, height: size)
  }
}


/// The menu's background: Liquid Glass on iOS 26, a material before.
struct MenuGlass: ViewModifier {
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: shape)
    } else {
      content.background(.regularMaterial).clipShape(shape)
    }
  }
}

// MARK: - Photo viewer

enum PhotoViewerPresenter {
  static func present(_ args: [String: Any]) {
    guard let urlString = args["url"] as? String, let url = URL(string: urlString) else { return }
    let vc = PhotoViewerController(url: url, title: args["title"] as? String)
    let nav = UINavigationController(rootViewController: vc)
    nav.modalPresentationStyle = .overFullScreen
    nav.modalTransitionStyle = .crossDissolve
    nav.overrideUserInterfaceStyle = .dark
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
    nav.navigationBar.standardAppearance = appearance
    nav.navigationBar.scrollEdgeAppearance = appearance
    nav.navigationBar.tintColor = .white
    NativeSheet.topViewControllerForPresenting()?.present(nav, animated: true)
  }
}

final class PhotoViewerController: UIViewController, UIScrollViewDelegate {
  private let url: URL
  private let scrollView = UIScrollView()
  private let imageView = UIImageView()
  private let spinner = UIActivityIndicatorView(style: .large)

  init(url: URL, title: String?) {
    self.url = url
    super.init(nibName: nil, bundle: nil)
    self.title = title
  }
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      systemItem: .close,
      primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
    )

    scrollView.frame = view.bounds
    scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    scrollView.delegate = self
    scrollView.minimumZoomScale = 1
    scrollView.maximumZoomScale = 5
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    view.addSubview(scrollView)

    imageView.contentMode = .scaleAspectFit
    imageView.frame = scrollView.bounds
    scrollView.addSubview(imageView)

    let double = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
    double.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(double)

    spinner.color = .white
    spinner.center = view.center
    spinner.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
    view.addSubview(spinner)
    spinner.startAnimating()

    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      DispatchQueue.main.async {
        guard let self = self else { return }
        self.spinner.stopAnimating()
        if let data = data, let image = UIImage(data: data) {
          self.imageView.image = image
        }
      }
    }.resume()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if scrollView.zoomScale == 1 {
      imageView.frame = scrollView.bounds
    }
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    let bounds = scrollView.bounds.size
    var frame = imageView.frame
    frame.origin.x = frame.width < bounds.width ? (bounds.width - frame.width) / 2 : 0
    frame.origin.y = frame.height < bounds.height ? (bounds.height - frame.height) / 2 : 0
    imageView.frame = frame
  }

  @objc private func doubleTapped(_ g: UITapGestureRecognizer) {
    if scrollView.zoomScale > 1 {
      scrollView.setZoomScale(1, animated: true)
    } else {
      let point = g.location(in: imageView)
      let size = CGSize(width: scrollView.bounds.width / 2.5, height: scrollView.bounds.height / 2.5)
      let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
      scrollView.zoom(to: rect, animated: true)
    }
  }
}

// MARK: - Voice player bar

/// The player bar under the chat header while a voice message plays, as in
/// Telegram: a native Liquid Glass capsule (a blur material before iOS 26)
/// with real UIKit buttons. It lies over the Flutter view, not inside it, so
/// its touches never go through a platform view. The buttons report back over
/// the channel (`voiceBarAction`: toggle / speed / close).
final class VoiceBar: UIView {
  static var channel: FlutterMethodChannel?
  private static var current: VoiceBar?

  private let glass: UIVisualEffectView
  private let play = UIButton(type: .system)
  private let speed = UIButton(type: .system)
  private let close = UIButton(type: .system)
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private var top: CGFloat = 0
  static let barHeight: CGFloat = 52

  private static let accent = UIColor(red: 1.0, green: 0.416, blue: 0.0, alpha: 1)

  override init(frame: CGRect) {
    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect()
      effect.isInteractive = false
      glass = UIVisualEffectView(effect: effect)
      glass.cornerConfiguration = .capsule()
    } else {
      glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
      glass.layer.cornerRadius = VoiceBar.barHeight / 2
      glass.clipsToBounds = true
    }
    super.init(frame: frame)
    addSubview(glass)
    let content = glass.contentView

    var playConfig = UIButton.Configuration.filled()
    playConfig.baseBackgroundColor = VoiceBar.accent
    playConfig.baseForegroundColor = .white
    playConfig.cornerStyle = .capsule
    play.configuration = playConfig
    play.addAction(UIAction { _ in VoiceBar.send("toggle") }, for: .touchUpInside)

    titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
    titleLabel.textColor = .label
    subtitleLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    subtitleLabel.textColor = .secondaryLabel

    var speedConfig = UIButton.Configuration.tinted()
    speedConfig.baseBackgroundColor = VoiceBar.accent
    speedConfig.baseForegroundColor = VoiceBar.accent
    speedConfig.cornerStyle = .capsule
    speedConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 9, bottom: 4, trailing: 9)
    speed.configuration = speedConfig
    speed.addAction(UIAction { _ in
      UISelectionFeedbackGenerator().selectionChanged()
      VoiceBar.send("speed")
    }, for: .touchUpInside)

    close.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)), for: .normal)
    close.tintColor = .secondaryLabel
    close.addAction(UIAction { _ in
      UISelectionFeedbackGenerator().selectionChanged()
      VoiceBar.send("close")
    }, for: .touchUpInside)

    [play, titleLabel, subtitleLabel, speed, close].forEach { content.addSubview($0) }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private static func send(_ action: String) {
    channel?.invokeMethod("voiceBarAction", arguments: action)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    glass.frame = bounds
    let h = bounds.height
    play.frame = CGRect(x: 7, y: (h - 38) / 2, width: 38, height: 38)
    close.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: h)
    let speedSize = speed.sizeThatFits(CGSize(width: 80, height: 30))
    speed.frame = CGRect(
      x: close.frame.minX - speedSize.width - 2, y: (h - speedSize.height) / 2,
      width: speedSize.width, height: speedSize.height)
    let textX = play.frame.maxX + 10
    let textW = max(0, speed.frame.minX - 8 - textX)
    titleLabel.frame = CGRect(x: textX, y: h / 2 - 19, width: textW, height: 19)
    subtitleLabel.frame = CGRect(x: textX, y: h / 2, width: textW, height: 18)
  }

  private func apply(_ args: [String: Any]) {
    titleLabel.text = args["title"] as? String
    subtitleLabel.text = args["subtitle"] as? String
    let playing = args["playing"] as? Bool ?? false
    play.setImage(
      UIImage(
        systemName: playing ? "pause.fill" : "play.fill",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)),
      for: .normal)
    var config = speed.configuration
    var title = AttributedString(args["speed"] as? String ?? "1x")
    title.font = .systemFont(ofSize: 13, weight: .bold)
    config?.attributedTitle = title
    speed.configuration = config
    top = CGFloat((args["top"] as? NSNumber)?.doubleValue ?? 0)
    setNeedsLayout()
  }

  private static func hostView() -> UIView? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?.rootViewController?.view
  }

  private func place(in host: UIView) {
    frame = CGRect(x: 10, y: top, width: host.bounds.width - 20, height: VoiceBar.barHeight)
    autoresizingMask = [.flexibleWidth]
  }

  static func show(_ args: [String: Any]) {
    guard let host = hostView() else { return }
    if let bar = current, bar.superview === host {
      bar.apply(args)
      bar.place(in: host)
      return
    }
    current?.removeFromSuperview()
    let bar = VoiceBar(frame: .zero)
    bar.apply(args)
    bar.place(in: host)
    bar.alpha = 0
    bar.transform = CGAffineTransform(translationX: 0, y: -10)
    host.addSubview(bar)
    bar.layoutIfNeeded()
    current = bar
    UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
      bar.alpha = 1
      bar.transform = .identity
    }
  }

  static func hide() {
    guard let bar = current else { return }
    current = nil
    UIView.animate(
      withDuration: 0.2, delay: 0, options: [.curveEaseIn],
      animations: {
        bar.alpha = 0
        bar.transform = CGAffineTransform(translationX: 0, y: -10)
      },
      completion: { _ in bar.removeFromSuperview() })
  }
}

// MARK: - Attach sheet (photos, videos, camera, files)

/// "Attach" as in Telegram: a native sheet with the recent photos and videos
/// of the gallery in a grid (tap to select, several at once), and a glass bar
/// with Gallery / Camera / File. The photos are shrunk here (1600 px, videos to
/// 720p, with a small preview), so the Flutter side gets ready files.
final class AttachModel: ObservableObject {
  struct Album: Identifiable {
    let id: String
    let title: String
    let fetch: PHFetchResult<PHAsset>
  }

  let limit: Int
  let recentsTitle: String
  @Published var albums: [Album] = []
  @Published var album: Album?
  @Published var selected: [String] = []   // asset ids, in the order picked
  @Published var denied = false
  @Published var busy = false
  @Published var progress = ""

  let imageManager = PHCachingImageManager()

  init(limit: Int, recentsTitle: String) {
    self.limit = limit
    self.recentsTitle = recentsTitle
  }

  func load() {
    let handle: (PHAuthorizationStatus) -> Void = { status in
      DispatchQueue.main.async {
        guard status == .authorized || status == .limited else {
          self.denied = true
          return
        }
        self.buildAlbums()
      }
    }
    if #available(iOS 14.0, *) {
      PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: handle)
    } else {
      PHPhotoLibrary.requestAuthorization(handle)
    }
  }

  private func buildAlbums() {
    let opts = PHFetchOptions()
    opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    var list: [Album] = []
    let recents = PHAsset.fetchAssets(with: opts)
    list.append(Album(id: "recents", title: recentsTitle, fetch: recents))
    let smart = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
    smart.enumerateObjects { c, _, _ in
      let skip: [PHAssetCollectionSubtype] = [.smartAlbumUserLibrary, .smartAlbumAllHidden, .smartAlbumRecentlyAdded]
      if skip.contains(c.assetCollectionSubtype) { return }
      let f = PHAsset.fetchAssets(in: c, options: opts)
      if f.count > 0, let title = c.localizedTitle {
        list.append(Album(id: c.localIdentifier, title: title, fetch: f))
      }
    }
    let user = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
    user.enumerateObjects { c, _, _ in
      let f = PHAsset.fetchAssets(in: c, options: opts)
      if f.count > 0, let title = c.localizedTitle {
        list.append(Album(id: c.localIdentifier, title: title, fetch: f))
      }
    }
    albums = list
    album = list.first
  }

  func toggle(_ id: String) {
    if let i = selected.firstIndex(of: id) {
      selected.remove(at: i)
    } else if selected.count < limit {
      selected.append(id)
      UISelectionFeedbackGenerator().selectionChanged()
    }
  }

  // MARK: export

  private static func tempURL(_ ext: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
  }

  private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let longest = max(image.size.width, image.size.height)
    let k = min(1, maxSide / longest)
    let size = CGSize(width: (image.size.width * k).rounded(), height: (image.size.height * k).rounded())
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }

  /// A photo: 1600 px JPEG and a 320 px preview.
  static func exportImage(_ image: UIImage, name: String) -> [String: Any]? {
    let big = resized(image, maxSide: 1600)
    let thumb = resized(image, maxSide: 320)
    guard let data = big.jpegData(compressionQuality: 0.85),
          let tdata = thumb.jpegData(compressionQuality: 0.7) else { return nil }
    let url = tempURL("jpg")
    let turl = tempURL("jpg")
    do {
      try data.write(to: url)
      try tdata.write(to: turl)
    } catch { return nil }
    return [
      "path": url.path, "kind": "image", "name": name,
      "width": Int(big.size.width), "height": Int(big.size.height),
      "thumb": turl.path,
    ]
  }

  /// A video: 720p mp4 and a 320 px preview of its first frame.
  static func exportVideo(_ source: AVAsset, name: String, done: @escaping ([String: Any]?) -> Void) {
    guard let session = AVAssetExportSession(asset: source, presetName: AVAssetExportPreset1280x720) else {
      done(nil)
      return
    }
    let url = tempURL("mp4")
    session.outputURL = url
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true
    session.exportAsynchronously {
      guard session.status == .completed else {
        done(nil)
        return
      }
      let out = AVURLAsset(url: url)
      var width = 0, height = 0
      if let track = out.tracks(withMediaType: .video).first {
        let size = track.naturalSize.applying(track.preferredTransform)
        width = Int(abs(size.width))
        height = Int(abs(size.height))
      }
      let gen = AVAssetImageGenerator(asset: out)
      gen.appliesPreferredTrackTransform = true
      gen.maximumSize = CGSize(width: 640, height: 640)
      var thumbPath: String?
      if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil),
         let tdata = resized(UIImage(cgImage: cg), maxSide: 320).jpegData(compressionQuality: 0.7) {
        let turl = tempURL("jpg")
        if (try? tdata.write(to: turl)) != nil { thumbPath = turl.path }
      }
      var item: [String: Any] = [
        "path": url.path, "kind": "video", "name": name,
        "width": width, "height": height,
        "durationMs": Int(CMTimeGetSeconds(out.duration) * 1000),
      ]
      if let t = thumbPath { item["thumb"] = t }
      done(item)
    }
  }

  /// Exports the entries one after another (photos shrunk, videos to 720p; what
  /// the camera already made is passed through) and gives them back in order,
  /// each with its caption.
  static func exportEntries(
    _ entries: [AttachPreviewEntry],
    progress: @escaping (String) -> Void,
    done: @escaping ([[String: Any]]) -> Void
  ) {
    var out: [[String: Any]] = []
    let stamp = Int(Date().timeIntervalSince1970)

    func add(_ item: [String: Any]?, _ caption: String) {
      guard var item = item else { return }
      if !caption.isEmpty { item["caption"] = caption }
      out.append(item)
    }

    func next(_ i: Int) {
      if i >= entries.count {
        DispatchQueue.main.async { done(out) }
        return
      }
      DispatchQueue.main.async { progress("\(i + 1)/\(entries.count)") }
      let entry = entries[i]
      if let item = entry.item {
        add(item, entry.caption)
        return next(i + 1)
      }
      guard let asset = entry.asset else { return next(i + 1) }
      if asset.mediaType == .video {
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat
        PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { av, _, _ in
          guard let av = av else { return next(i + 1) }
          AttachModel.exportVideo(av, name: "VID_\(stamp)_\(i).mp4") { item in
            add(item, entry.caption)
            next(i + 1)
          }
        }
      } else {
        let opts = PHImageRequestOptions()
        opts.isNetworkAccessAllowed = true
        opts.deliveryMode = .highQualityFormat
        opts.isSynchronous = false
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
          if let data = data, let image = UIImage(data: data) {
            add(AttachModel.exportImage(image, name: "IMG_\(stamp)_\(i).jpg"), entry.caption)
          }
          next(i + 1)
        }
      }
    }
    DispatchQueue.global(qos: .userInitiated).async { next(0) }
  }
}

/// One picked photo / video in the preview: a gallery asset (exported on
/// "Send") or something the camera already made, with its caption.
struct AttachPreviewEntry: Identifiable {
  let id = UUID()
  var asset: PHAsset?
  var item: [String: Any]?
  var caption = ""

  var isVideo: Bool {
    asset?.mediaType == .video || (item?["kind"] as? String) == "video"
  }
}

final class AttachPreviewModel: ObservableObject {
  @Published var entries: [AttachPreviewEntry]
  @Published var index = 0
  @Published var busy = false
  @Published var progress = ""

  init(entries: [AttachPreviewEntry]) { self.entries = entries }

  func removeCurrent() {
    guard entries.indices.contains(index) else { return }
    entries.remove(at: index)
    index = min(index, max(0, entries.count - 1))
  }
}

struct AttachPreviewPage: View {
  let entry: AttachPreviewEntry
  @State private var image: UIImage?

  var body: some View {
    ZStack {
      Color.black
      if let image = image {
        Image(uiImage: image).resizable().scaledToFit()
      } else {
        ProgressView().progressViewStyle(.circular).tint(.white)
      }
      if entry.isVideo {
        Image(systemName: "play.circle.fill")
          .font(.system(size: 60))
          .foregroundColor(.white.opacity(0.9))
          .shadow(radius: 6)
      }
    }
    .onAppear(perform: load)
  }

  private func load() {
    if let asset = entry.asset {
      let opts = PHImageRequestOptions()
      opts.deliveryMode = .highQualityFormat
      opts.isNetworkAccessAllowed = true
      PHImageManager.default().requestImage(
        for: asset, targetSize: CGSize(width: 1600, height: 1600),
        contentMode: .aspectFit, options: opts
      ) { img, _ in
        if let img = img { DispatchQueue.main.async { self.image = img } }
      }
    } else if let item = entry.item {
      let path = (item["thumb"] as? String) ?? (item["path"] as? String) ?? ""
      let isImage = (item["kind"] as? String) == "image"
      image = UIImage(contentsOfFile: isImage ? (item["path"] as? String ?? path) : path)
    }
  }
}

/// The preview before sending, as in Telegram: the picked photos and videos
/// full screen (swipe between them), a caption field and the send button.
struct AttachPreviewView: View {
  @ObservedObject var model: AttachPreviewModel
  let placeholder: String
  let preparing: String
  let onSend: () -> Void

  private let accent = Color(red: 1.0, green: 0.416, blue: 0.0)

  private var caption: Binding<String> {
    Binding(
      get: { model.entries.indices.contains(model.index) ? model.entries[model.index].caption : "" },
      set: { v in
        if model.entries.indices.contains(model.index) { model.entries[model.index].caption = v }
      })
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      TabView(selection: $model.index) {
        ForEach(Array(model.entries.enumerated()), id: \.element.id) { i, entry in
          AttachPreviewPage(entry: entry).tag(i)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      if model.busy {
        ZStack {
          Color.black.opacity(0.45).ignoresSafeArea()
          VStack(spacing: 12) {
            ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.3)
            Text(preparing + (model.progress.isEmpty ? "" : " " + model.progress))
              .font(.subheadline).foregroundColor(.white)
          }
        }
      }
    }
    .safeAreaInset(edge: .bottom) { captionBar }
  }

  private var captionBar: some View {
    HStack(spacing: 8) {
      ZStack(alignment: .leading) {
        if caption.wrappedValue.isEmpty {
          Text(placeholder).foregroundColor(.white.opacity(0.55)).padding(.horizontal, 16)
        }
        TextField("", text: caption)
          .foregroundColor(.white)
          .accentColor(accent)
          .padding(.horizontal, 16)
      }
      .frame(height: 44)
      .background(Capsule().fill(Color.white.opacity(0.18)))
      Button(action: onSend) {
        Image(systemName: "arrow.up")
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.white)
          .frame(width: 44, height: 44)
          .background(Circle().fill(accent))
      }
      .disabled(model.busy || model.entries.isEmpty)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.black.opacity(0.55))
  }
}

struct AttachThumb: View {
  let asset: PHAsset
  let manager: PHCachingImageManager
  let size: CGFloat
  @State private var image: UIImage?

  var body: some View {
    ZStack {
      Color(.systemGray5)
      if let image = image {
        Image(uiImage: image).resizable().scaledToFill()
      }
    }
    .frame(width: size, height: size)
    .clipped()
    .onAppear {
      let scale = UIScreen.main.scale
      let opts = PHImageRequestOptions()
      opts.deliveryMode = .opportunistic
      opts.resizeMode = .fast
      opts.isNetworkAccessAllowed = true
      manager.requestImage(
        for: asset, targetSize: CGSize(width: size * scale, height: size * scale),
        contentMode: .aspectFill, options: opts
      ) { img, _ in
        if let img = img { DispatchQueue.main.async { self.image = img } }
      }
    }
  }
}

struct AttachView: View {
  @ObservedObject var model: AttachModel
  let gallery: String
  let camera: String
  let file: String
  let sendTitle: String
  let preparing: String
  let deniedText: String
  let settingsTitle: String
  let onCamera: () -> Void
  let onFile: () -> Void
  let onSend: () -> Void

  private let accent = Color(red: 1.0, green: 0.416, blue: 0.0)
  private let gap: CGFloat = 2

  var body: some View {
    ZStack(alignment: .bottom) {
      VStack(spacing: 0) {
        if model.denied {
          deniedView
        } else {
          grid
        }
      }
      bottomBar
      if model.busy { busyOverlay }
    }
    .background(Color(.systemBackground).ignoresSafeArea())
    .onAppear { model.load() }
  }

  private var grid: some View {
    GeometryReader { geo in
      let cell = (geo.size.width - gap * 2) / 3
      ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: gap), count: 3), spacing: gap) {
          cameraCell(cell)
          if let fetch = model.album?.fetch {
            ForEach(0..<fetch.count, id: \.self) { i in
              assetCell(fetch.object(at: i), size: cell)
            }
          }
        }
        .padding(.bottom, 110)
      }
    }
  }

  private func cameraCell(_ size: CGFloat) -> some View {
    Button(action: onCamera) {
      ZStack {
        Color(white: 0.12)
        Image(systemName: "camera.fill").font(.system(size: 30)).foregroundColor(.white)
      }
      .frame(width: size, height: size)
    }
    .buttonStyle(.plain)
  }

  private func assetCell(_ asset: PHAsset, size: CGFloat) -> some View {
    let id = asset.localIdentifier
    let index = model.selected.firstIndex(of: id)
    return Button { model.toggle(id) } label: {
      ZStack(alignment: .topTrailing) {
        AttachThumb(asset: asset, manager: model.imageManager, size: size)
        if index != nil { Color.black.opacity(0.18) }
        ZStack {
          Circle()
            .strokeBorder(Color.white, lineWidth: 1.6)
            .background(Circle().fill(index == nil ? Color.black.opacity(0.12) : accent))
            .frame(width: 26, height: 26)
          if let index = index {
            Text("\(index + 1)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
          }
        }
        .padding(7)
        if asset.mediaType == .video {
          VStack { Spacer()
            HStack {
              Image(systemName: "video.fill").font(.system(size: 11))
              Text(Self.duration(asset.duration)).font(.system(size: 12, weight: .semibold))
              Spacer()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6).padding(.bottom, 5)
          }
          .frame(width: size, height: size)
        }
      }
      .frame(width: size, height: size)
    }
    .buttonStyle(.plain)
  }

  private static func duration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return "\(total / 60):" + String(format: "%02d", total % 60)
  }

  private var deniedView: some View {
    VStack(spacing: 14) {
      Spacer()
      Image(systemName: "photo.on.rectangle.angled").font(.system(size: 44)).foregroundColor(.secondary)
      Text(deniedText).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal, 30)
      Button(settingsTitle) {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
      }
      .font(.body.weight(.semibold))
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder private var bottomBar: some View {
    if model.denied {
      EmptyView()
    } else if !model.selected.isEmpty {
      Button(action: onSend) {
        Text("\(sendTitle) (\(model.selected.count))")
          .font(.body.weight(.semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(Capsule().fill(accent))
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 12)
    } else {
      HStack(spacing: 0) {
        tab(icon: "photo.on.rectangle", title: gallery, selected: true, action: {})
        tab(icon: "camera.fill", title: camera, selected: false, action: onCamera)
        tab(icon: "doc.fill", title: file, selected: false, action: onFile)
      }
      .padding(6)
      .modifier(GlassCapsule())
      .padding(.horizontal, 16)
      .padding(.bottom, 12)
    }
  }

  private func tab(icon: String, title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: icon).font(.system(size: 22))
        Text(title).font(.system(size: 11))
      }
      .foregroundColor(selected ? Color(red: 0.2, green: 0.47, blue: 0.96) : .primary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(
        Capsule().fill(selected ? Color(red: 0.2, green: 0.47, blue: 0.96).opacity(0.14) : Color.clear)
      )
    }
    .buttonStyle(.plain)
  }

  private var busyOverlay: some View {
    ZStack {
      Color.black.opacity(0.25).ignoresSafeArea()
      VStack(spacing: 12) {
        ProgressView().progressViewStyle(.circular).scaleEffect(1.3)
        Text(preparing + (model.progress.isEmpty ? "" : " " + model.progress)).font(.subheadline)
      }
      .padding(24)
      .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.systemBackground)))
    }
  }
}

struct GlassCapsule: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(.regular, in: Capsule())
    } else {
      content
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }
  }
}

/// The camera (photo or video) and the document picker, presented over the sheet.
final class AttachPickers: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate,
  UIDocumentPickerDelegate {
  var onItems: (([[String: Any]]) -> Void)?
  var onBusy: ((Bool) -> Void)?
  private var bag = Set<AnyCancellable>()

  /// The title of the sheet: the album name with a system pull-down menu of
  /// the albums.
  func bind(model: AttachModel, titleButton: UIButton) {
    let update: () -> Void = { [weak titleButton, weak model] in
      guard let titleButton = titleButton, let model = model else { return }
      var config = UIButton.Configuration.plain()
      config.title = model.album?.title ?? model.recentsTitle
      config.image = UIImage(
        systemName: "chevron.down",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
      config.imagePlacement = .trailing
      config.imagePadding = 5
      config.baseForegroundColor = .label
      config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { c in
        var c = c
        c.font = .systemFont(ofSize: 17, weight: .semibold)
        return c
      }
      titleButton.configuration = config
      titleButton.menu = UIMenu(children: model.albums.map { a in
        UIAction(title: a.title, state: a.id == model.album?.id ? .on : .off) { _ in model.album = a }
      })
      titleButton.showsMenuAsPrimaryAction = true
    }
    update()
    model.$albums.combineLatest(model.$album).receive(on: DispatchQueue.main)
      .sink { _ in update() }.store(in: &bag)
  }

  func presentCamera(from vc: UIViewController) {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
    picker.videoQuality = .typeHigh
    picker.videoMaximumDuration = 180
    picker.delegate = self
    vc.present(picker, animated: true)
  }

  func presentFiles(from vc: UIViewController) {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
    picker.allowsMultipleSelection = true
    picker.delegate = self
    vc.present(picker, animated: true)
  }

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
    let stamp = Int(Date().timeIntervalSince1970)
    if let url = info[.mediaURL] as? URL {
      onBusy?(true)
      picker.dismiss(animated: true)
      AttachModel.exportVideo(AVURLAsset(url: url), name: "VID_\(stamp).mp4") { item in
        DispatchQueue.main.async {
          self.onBusy?(false)
          self.onItems?(item.map { [$0] } ?? [])
        }
      }
    } else if let image = info[.originalImage] as? UIImage {
      picker.dismiss(animated: true)
      let item = AttachModel.exportImage(image, name: "IMG_\(stamp).jpg")
      onItems?(item.map { [$0] } ?? [])
    } else {
      picker.dismiss(animated: true)
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    onItems?(urls.map { ["path": $0.path, "kind": "file", "name": $0.lastPathComponent] })
  }
}

enum AttachSheet {
  private static var delegate: PickerDismissDelegate?
  private static var pickers: AttachPickers?
  private static var previewBag = Set<AnyCancellable>()

  static func present(_ args: [String: Any], result: @escaping FlutterResult) {
    var finished = false
    let finish: ([[String: Any]]?) -> Void = { items in
      if finished { return }
      finished = true
      delegate = nil
      pickers = nil
      result(items)
    }
    let model = AttachModel(
      limit: (args["limit"] as? NSNumber)?.intValue ?? 10,
      recentsTitle: args["recents"] as? String ?? "Recents")
    let box = WeakBox()
    let helper = AttachPickers()
    pickers = helper
    let close: ([[String: Any]]?) -> Void = { items in
      if let vc = box.vc { vc.dismiss(animated: true) { finish(items) } } else { finish(items) }
    }
    helper.onBusy = { busy in model.busy = busy }

    // The preview (photos / videos with a caption) is pushed in the same
    // navigation controller; "Send" there exports and hands everything back.
    let strings = (
      caption: args["caption"] as? String ?? "",
      preparing: args["preparing"] as? String ?? ""
    )
    let showPreview: ([AttachPreviewEntry]) -> Void = { entries in
      guard let nav = box.vc as? UINavigationController, !entries.isEmpty else { return }
      let pm = AttachPreviewModel(entries: entries)
      let view = AttachPreviewView(
        model: pm, placeholder: strings.caption, preparing: strings.preparing,
        onSend: {
          pm.busy = true
          AttachModel.exportEntries(
            pm.entries,
            progress: { pm.progress = $0 },
            done: { items in
              pm.busy = false
              close(items)
            })
        })
      let host = UIHostingController(rootView: view)
      host.view.backgroundColor = .black
      host.overrideUserInterfaceStyle = .dark
      let bar = UINavigationBarAppearance()
      bar.configureWithTransparentBackground()
      host.navigationItem.standardAppearance = bar
      host.navigationItem.scrollEdgeAppearance = bar
      host.navigationItem.rightBarButtonItem = UIBarButtonItem(
        systemItem: .trash,
        primaryAction: UIAction { [weak nav] _ in
          pm.removeCurrent()
          if pm.entries.isEmpty { nav?.popViewController(animated: true) }
        }, menu: nil)
      let update: () -> Void = { [weak host] in
        host?.title = pm.entries.count > 1 ? "\(pm.index + 1) / \(pm.entries.count)" : nil
      }
      update()
      pm.$index.combineLatest(pm.$entries).receive(on: DispatchQueue.main)
        .sink { _ in update() }.store(in: &previewBag)
      nav.pushViewController(host, animated: true)
    }
    helper.onItems = { items in
      // Photos and videos from the camera go to the preview; documents go on.
      let media = items.filter { ($0["kind"] as? String) != "file" }
      if !media.isEmpty && media.count == items.count {
        showPreview(media.map { AttachPreviewEntry(asset: nil, item: $0) })
      } else {
        close(items)
      }
    }

    let view = AttachView(
      model: model,
      gallery: args["gallery"] as? String ?? "",
      camera: args["camera"] as? String ?? "",
      file: args["file"] as? String ?? "",
      sendTitle: args["send"] as? String ?? "",
      preparing: args["preparing"] as? String ?? "",
      deniedText: args["denied"] as? String ?? "",
      settingsTitle: args["settings"] as? String ?? "",
      onCamera: { if let vc = box.vc { helper.presentCamera(from: vc) } },
      onFile: { if let vc = box.vc { helper.presentFiles(from: vc) } },
      onSend: {
        let ids = model.selected
        let found = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byId: [String: PHAsset] = [:]
        found.enumerateObjects { a, _, _ in byId[a.localIdentifier] = a }
        showPreview(ids.compactMap { byId[$0] }.map { AttachPreviewEntry(asset: $0, item: nil) })
      }
    )
    // A real UINavigationController: its bar gives the system close button
    // (Liquid Glass on iOS 26) and the album menu is a system pull-down menu.
    let host = UIHostingController(rootView: view)
    host.view.backgroundColor = .systemBackground
    let nav = UINavigationController(rootViewController: host)
    box.vc = nav
    host.navigationItem.leftBarButtonItem = UIBarButtonItem(
      systemItem: .close, primaryAction: UIAction { _ in close(nil) }, menu: nil)
    let titleButton = UIButton(type: .system)
    host.navigationItem.titleView = titleButton
    helper.bind(model: model, titleButton: titleButton)
    nav.modalPresentationStyle = .pageSheet
    if let sheet = nav.sheetPresentationController {
      sheet.detents = [.large()]
      sheet.prefersGrabberVisible = true
    }
    let d = PickerDismissDelegate { finish(nil) }
    delegate = d
    nav.presentationController?.delegate = d
    NativeSheet.topViewControllerForPresenting()?.present(nav, animated: true)
  }
}
