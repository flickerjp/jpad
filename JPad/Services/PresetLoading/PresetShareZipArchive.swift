import Foundation
import zlib

/// AirDrop 用の単一ファイル ZIP（受信側で JSON プレビューが開きにくい）。
enum PresetShareZipArchive {
  private static let localHeaderSignature: UInt32 = 0x0403_4B50
  private static let centralDirectorySignature: UInt32 = 0x0201_4B50
  private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50

  static func createZip(archiveURL: URL, fileURL: URL, entryName: String) throws {
    let fileData = try Data(contentsOf: fileURL)
    let archive = createZipData(fileData: fileData, entryName: entryName)
    try archive.write(to: archiveURL, options: .atomic)
  }

  static func createZipData(fileData: Data, entryName: String) -> Data {
    let nameData = Data(entryName.utf8)
    let crc = crc32Checksum(fileData)
    let size = UInt32(fileData.count)

    var archive = Data()
    let localHeaderOffset = UInt32(archive.count)

    archive.appendUInt32(localHeaderSignature)
    archive.appendUInt16(20) // version
    archive.appendUInt16(0) // flags
    archive.appendUInt16(0) // stored
    archive.appendUInt16(0) // mod time
    archive.appendUInt16(0) // mod date
    archive.appendUInt32(crc)
    archive.appendUInt32(size)
    archive.appendUInt32(size)
    archive.appendUInt16(UInt16(nameData.count))
    archive.appendUInt16(0) // extra length
    archive.append(nameData)
    archive.append(fileData)

    let centralDirectoryOffset = UInt32(archive.count)

    archive.appendUInt32(centralDirectorySignature)
    archive.appendUInt16(20) // version made by
    archive.appendUInt16(20) // version needed
    archive.appendUInt16(0)
    archive.appendUInt16(0)
    archive.appendUInt16(0)
    archive.appendUInt16(0)
    archive.appendUInt32(crc)
    archive.appendUInt32(size)
    archive.appendUInt32(size)
    archive.appendUInt16(UInt16(nameData.count))
    archive.appendUInt16(0)
    archive.appendUInt16(0)
    archive.appendUInt16(0)
    archive.appendUInt16(0)
    archive.appendUInt32(0)
    archive.appendUInt32(localHeaderOffset)
    archive.append(nameData)

    let centralDirectorySize = UInt32(archive.count) - centralDirectoryOffset

    archive.appendUInt32(endOfCentralDirectorySignature)
    archive.appendUInt16(0) // disk number
    archive.appendUInt16(0)
    archive.appendUInt16(1) // entries on disk
    archive.appendUInt16(1) // total entries
    archive.appendUInt32(centralDirectorySize)
    archive.appendUInt32(centralDirectoryOffset)
    archive.appendUInt16(0) // comment length
    return archive
  }

  static func firstEntryData(from archiveURL: URL) throws -> Data {
    let archive = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
    guard archive.count >= 22 else {
      throw PresetShareError.unsupportedDocumentKind
    }

    var eocdOffset: Int?
    let searchStart = max(0, archive.count - 22 - 65_535)
    for offset in stride(from: archive.count - 22, through: searchStart, by: -1) {
      if archive.readUInt32(at: offset) == endOfCentralDirectorySignature {
        eocdOffset = offset
        break
      }
    }
    guard let eocdOffset else {
      throw PresetShareError.unsupportedDocumentKind
    }

    let centralDirectoryOffset = Int(archive.readUInt32(at: eocdOffset + 16))
    guard centralDirectoryOffset + 46 <= archive.count else {
      throw PresetShareError.unsupportedDocumentKind
    }
    guard archive.readUInt32(at: centralDirectoryOffset) == centralDirectorySignature else {
      throw PresetShareError.unsupportedDocumentKind
    }

    let localHeaderOffset = Int(archive.readUInt32(at: centralDirectoryOffset + 42))
    let nameLength = Int(archive.readUInt16(at: centralDirectoryOffset + 28))
    let extraLength = Int(archive.readUInt16(at: centralDirectoryOffset + 30))
    let commentLength = Int(archive.readUInt16(at: centralDirectoryOffset + 32))
    let nameStart = centralDirectoryOffset + 46
    let nameEnd = nameStart + nameLength
    guard nameEnd <= archive.count else {
      throw PresetShareError.unsupportedDocumentKind
    }
    _ = archive.subdata(in: nameStart..<nameEnd)

    guard localHeaderOffset + 30 <= archive.count else {
      throw PresetShareError.unsupportedDocumentKind
    }
    guard archive.readUInt32(at: localHeaderOffset) == localHeaderSignature else {
      throw PresetShareError.unsupportedDocumentKind
    }

    let localNameLength = Int(archive.readUInt16(at: localHeaderOffset + 26))
    let localExtraLength = Int(archive.readUInt16(at: localHeaderOffset + 28))
    let dataOffset = localHeaderOffset + 30 + localNameLength + localExtraLength
    let compressedSize = Int(archive.readUInt32(at: localHeaderOffset + 18))
    let dataEnd = dataOffset + compressedSize
    guard dataEnd <= archive.count else {
      throw PresetShareError.unsupportedDocumentKind
    }
    guard archive.readUInt16(at: localHeaderOffset + 8) == 0 else {
      throw PresetShareError.unsupportedDocumentKind
    }

    _ = commentLength
    _ = extraLength
    return archive.subdata(in: dataOffset..<dataEnd)
  }

  private static func crc32Checksum(_ data: Data) -> UInt32 {
    data.withUnsafeBytes { buffer in
      guard let base = buffer.bindMemory(to: Bytef.self).baseAddress else { return 0 }
      return UInt32(crc32(0, base, uInt(buffer.count)))
    }
  }
}

private extension Data {
  mutating func appendUInt16(_ value: UInt16) {
    var littleEndian = value.littleEndian
    Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
  }

  mutating func appendUInt32(_ value: UInt32) {
    var littleEndian = value.littleEndian
    Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
  }

  func readUInt16(at offset: Int) -> UInt16 {
    UInt16(littleEndian: subdata(in: offset..<(offset + 2)).withUnsafeBytes { $0.load(as: UInt16.self) })
  }

  func readUInt32(at offset: Int) -> UInt32 {
    UInt32(littleEndian: subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) })
  }
}
