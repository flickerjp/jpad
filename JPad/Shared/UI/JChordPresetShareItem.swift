import UIKit
import UniformTypeIdentifiers

/// AirDrop 等で JPad プリセット（`.jpd`）として渡す共有アイテム。
final class JChordPresetShareItem: NSObject, UIActivityItemSource {
  let url: URL

  init(url: URL) {
    self.url = url
  }

  func activityViewControllerPlaceholderItem(
    _ activityViewController: UIActivityViewController
  ) -> Any {
    url
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    url
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    UTType.jchordPreset.identifier
  }
}
