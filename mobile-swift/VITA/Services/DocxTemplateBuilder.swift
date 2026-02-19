import Foundation

/// Builds an in-memory `.docx` (ZIP of XML) using pure Swift — no external dependencies.
struct DocxTemplateBuilder {

    // MARK: - Public entry point

    static func build() -> Data {
        let entries: [(name: String, content: String)] = [
            ("[Content_Types].xml", contentTypesXML),
            ("_rels/.rels", rootRelsXML),
            ("word/_rels/document.xml.rels", documentRelsXML),
            ("word/document.xml", documentXML),
            ("word/settings.xml", settingsXML),
        ]

        let entryData: [(name: String, bytes: Data)] = entries.map { name, content in
            (name, Data(content.utf8))
        }

        var zipData = Data()
        var localOffsets = [UInt32]()

        for entry in entryData {
            localOffsets.append(UInt32(zipData.count))
            zipData += makeLocalEntry(name: entry.name, data: entry.bytes)
        }

        let centralDirOffset = UInt32(zipData.count)
        var centralDir = Data()
        for (idx, entry) in entryData.enumerated() {
            centralDir += makeCentralEntry(
                name: entry.name,
                data: entry.bytes,
                localOffset: localOffsets[idx]
            )
        }

        zipData += centralDir
        zipData += makeEndOfCentralDir(
            entryCount: entryData.count,
            centralDirSize: UInt32(centralDir.count),
            centralDirOffset: centralDirOffset
        )

        return zipData
    }

    // MARK: - XML content

    private static let contentTypesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
        </Types>
        """

    private static let rootRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """

    private static let documentRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
        </Relationships>
        """

    private static let settingsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"/>
        """

    // swiftlint:disable line_length
    private static let documentXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>

            <!-- Title -->
            <w:p>
              <w:pPr><w:jc w:val="center"/></w:pPr>
              <w:r><w:rPr><w:b/><w:sz w:val="48"/></w:rPr><w:t>VITA Personal Health Report</w:t></w:r>
            </w:p>

            <!-- Report metadata -->
            <w:p><w:r><w:t xml:space="preserve">Report Date:  {{ reportDate }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Report ID:    {{ reportId }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>

            <!-- Clinical notes -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Clinical Notes</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Primary Concern:     {{ primaryConcern }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Recent Sleep Quality: {{ sleepQuality }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Digestive Symptoms:  {{ digestiveIssues }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Exercise This Week:  {{ exerciseFrequency }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Goal for Visit:      {{ providerGoal }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>

            <!-- Health metrics -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Health Metrics (Apple Watch)</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Health Score: {{ healthScore }}/100</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">HRV:          {{ hrv }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Heart Rate:   {{ heartRate }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Glucose:      {{ glucose }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Sleep:        {{ sleepHours }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Steps Today:  {{ steps }}</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve">Skin Score:   {{ skinScore }}/100</w:t></w:r></w:p>
            <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>

            <!-- Recent meals table -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Recent Meals</w:t></w:r></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                </w:tblBorders>
              </w:tblPr>
              <w:tr>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Meal</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Source</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Glycemic Load</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Glucose Impact</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:p><w:r><w:t>{{ TableStart:recentMeals }}{{ meal }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ source }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ glycemicLoad }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ impact }}{{ TableEnd:recentMeals }}</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>

            <!-- Skin conditions table -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Skin Health Analysis</w:t></w:r></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                </w:tblBorders>
              </w:tblPr>
              <w:tr>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Condition</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Severity</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Zone</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Confidence</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:p><w:r><w:t>{{ TableStart:skinConditions }}{{ condition }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ severity }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ zone }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ confidence }}{{ TableEnd:skinConditions }}</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>

            <!-- Causal findings table -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Causal Chain Findings</w:t></w:r></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                </w:tblBorders>
              </w:tblPr>
              <w:tr>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Finding</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Detail</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Source</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:p><w:r><w:t>{{ TableStart:causalFindings }}{{ finding }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ detail }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:p><w:r><w:t>{{ source }}{{ TableEnd:causalFindings }}</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>

            <!-- Recommendations table -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>Recommendations</w:t></w:r></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                  <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                </w:tblBorders>
              </w:tblPr>
              <w:tr>
                <w:tc><w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Recommendation</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:p><w:r><w:t>{{ TableStart:recommendations }}{{ rec }}{{ TableEnd:recommendations }}</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>

            <w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>
            <w:p>
              <w:pPr><w:jc w:val="center"/></w:pPr>
              <w:r><w:rPr><w:color w:val="888888"/></w:rPr><w:t>Generated by VITA — Personal Health Causality Engine</w:t></w:r>
            </w:p>

            <w:sectPr/>
          </w:body>
        </w:document>
        """
    // swiftlint:enable line_length

    // MARK: - ZIP builder

    private static func makeLocalEntry(name: String, data: Data) -> Data {
        let nameBytes = Array(name.utf8)
        let crc = crc32(data)
        let size = UInt32(data.count)

        var header = [UInt8]()
        header += [0x50, 0x4B, 0x03, 0x04]     // local file header signature
        header += le16(20)                       // version needed to extract (2.0)
        header += le16(0)                        // general purpose bit flag
        header += le16(0)                        // compression method: STORED
        header += le16(0)                        // last mod file time
        header += le16(0x5821)                   // last mod file date (2024-01-01)
        header += le32(crc)                      // CRC-32
        header += le32(size)                     // compressed size
        header += le32(size)                     // uncompressed size
        header += le16(UInt16(nameBytes.count))  // file name length
        header += le16(0)                        // extra field length
        header += nameBytes                      // file name

        return Data(header) + data
    }

    private static func makeCentralEntry(name: String, data: Data, localOffset: UInt32) -> Data {
        let nameBytes = Array(name.utf8)
        let crc = crc32(data)
        let size = UInt32(data.count)

        var entry = [UInt8]()
        entry += [0x50, 0x4B, 0x01, 0x02]     // central directory file header signature
        entry += le16(20)                       // version made by (2.0)
        entry += le16(20)                       // version needed to extract (2.0)
        entry += le16(0)                        // general purpose bit flag
        entry += le16(0)                        // compression method: STORED
        entry += le16(0)                        // last mod file time
        entry += le16(0x5821)                   // last mod file date (2024-01-01)
        entry += le32(crc)                      // CRC-32
        entry += le32(size)                     // compressed size
        entry += le32(size)                     // uncompressed size
        entry += le16(UInt16(nameBytes.count))  // file name length
        entry += le16(0)                        // extra field length
        entry += le16(0)                        // file comment length
        entry += le16(0)                        // disk number start
        entry += le16(0)                        // internal file attributes
        entry += le32(0)                        // external file attributes
        entry += le32(localOffset)             // relative offset of local file header
        entry += nameBytes                      // file name

        return Data(entry)
    }

    private static func makeEndOfCentralDir(
        entryCount: Int,
        centralDirSize: UInt32,
        centralDirOffset: UInt32
    ) -> Data {
        var eocd = [UInt8]()
        eocd += [0x50, 0x4B, 0x05, 0x06]        // end of central directory signature
        eocd += le16(0)                           // number of this disk
        eocd += le16(0)                           // disk where central directory starts
        eocd += le16(UInt16(entryCount))          // number of entries on this disk
        eocd += le16(UInt16(entryCount))          // total number of entries
        eocd += le32(centralDirSize)              // size of central directory
        eocd += le32(centralDirOffset)            // offset of central directory
        eocd += le16(0)                           // comment length
        return Data(eocd)
    }

    // MARK: - CRC-32 (standard ZIP polynomial)

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return ~crc
    }

    // MARK: - Little-endian helpers

    private static func le16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private static func le32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ]
    }
}
