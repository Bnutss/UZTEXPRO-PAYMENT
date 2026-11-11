import Intents
import UserNotifications

/// Puts the sender's photo into a chat notification, as Telegram does.
///
/// The server marks a chat push `mutable_content` and adds `sender_photo` (a
/// full address) to the data. This extension downloads the picture and turns
/// the notification into a "communication notification" (the photo at the left,
/// like in Messages); if the system will not take it, the photo goes in as an
/// attachment instead. Anything that fails leaves the notification as it came.
final class NotificationService: UNNotificationServiceExtension {
  private var handler: ((UNNotificationContent) -> Void)?
  private var current: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    handler = contentHandler
    let content = (request.content.mutableCopy() as? UNMutableNotificationContent)
      ?? UNMutableNotificationContent()
    current = content
    let info = request.content.userInfo

    guard (info["type"] as? String) == "chat",
          let raw = info["sender_photo"] as? String, !raw.isEmpty,
          let url = URL(string: raw) else {
      contentHandler(content)
      return
    }

    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 10
    URLSession(configuration: config).dataTask(with: url) { [weak self] data, response, _ in
      guard let self = self else { return }
      let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
      guard ok, let data = data, !data.isEmpty else {
        self.deliver(content)
        return
      }
      self.deliver(self.withPhoto(content, info: info, data: data))
    }.resume()
  }

  /// The system is about to cut the extension off: show what there is.
  override func serviceExtensionTimeWillExpire() {
    if let content = current { deliver(content) }
  }

  private func deliver(_ content: UNNotificationContent) {
    handler?(content)
    handler = nil
  }

  private func withPhoto(
    _ content: UNMutableNotificationContent,
    info: [AnyHashable: Any],
    data: Data
  ) -> UNNotificationContent {
    let isGroup = (info["group"] as? Bool) == true || (info["group"] as? String) == "true"
    // In a group the system's title is the person of the intent: make it the
    // group (as Telegram does); the author stays in front of the text, which
    // the server already put there ("Surname Name: text").
    let fullName = (info["sender_name"] as? String) ?? content.title
    // Surname and first name only, without the patronymic.
    let shortName = fullName.split(whereSeparator: { $0.isWhitespace }).prefix(2).joined(separator: " ")
    let senderName = isGroup ? content.title : shortName
    let senderId = "\(info["sender"] ?? "0")"
    let conversationId = "\(info["conversation"] ?? "0")"

    if #available(iOS 15.0, *) {
      let person = INPerson(
        personHandle: INPersonHandle(value: senderId, type: .unknown),
        nameComponents: nil,
        displayName: senderName,
        image: INImage(imageData: data),
        contactIdentifier: nil,
        customIdentifier: senderId
      )
      let intent = INSendMessageIntent(
        recipients: nil,
        content: content.body,
        speakableGroupName: nil,
        conversationIdentifier: conversationId,
        serviceName: nil,
        sender: person
      )
      let interaction = INInteraction(intent: intent, response: nil)
      interaction.direction = .incoming
      interaction.donate(completion: nil)
      if let updated = try? content.updating(from: intent) {
        return updated // the photo at the left, the app icon on it
      }
    }

    // Fallback (the system did not take the sender): the photo as an
    // attachment, a thumbnail on the right.
    if let attachment = attachment(from: data) {
      content.attachments = [attachment]
    }
    return content
  }

  private func attachment(from data: Data) -> UNNotificationAttachment? {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
    do {
      try data.write(to: file)
      return try UNNotificationAttachment(identifier: "photo", url: file, options: nil)
    } catch {
      return nil
    }
  }
}
