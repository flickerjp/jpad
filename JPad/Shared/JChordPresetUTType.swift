import UniformTypeIdentifiers

extension UTType {
  /// SHARE / IMPORT 用（`PresetImportExportService.fileExtension` と一致）。
  static let jchordPreset = UTType(
    exportedAs: "com.flickerproduct.jpad",
    conformingTo: .data
  )

  static let jchordPresetImportTypes: [UTType] = {
    var types: [UTType] = [.jchordPreset, .zip]
    if let jpd = UTType(filenameExtension: PresetImportExportService.shareArchiveExtension, conformingTo: .data),
       !types.contains(jpd)
    {
      types.append(jpd)
    }
    return types
  }()
}
