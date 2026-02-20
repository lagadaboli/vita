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
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml">
          <w:body>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- HEADER BAND                                                      -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="none" w:sz="0"/><w:left w:val="none" w:sz="0"/>
                  <w:bottom w:val="none" w:sz="0"/><w:right w:val="none" w:sz="0"/>
                  <w:insideH w:val="none" w:sz="0"/><w:insideV w:val="none" w:sz="0"/>
                </w:tblBorders>
                <w:tblCellMar>
                  <w:top w:w="160" w:type="dxa"/>
                  <w:left w:w="180" w:type="dxa"/>
                  <w:bottom w:w="160" w:type="dxa"/>
                  <w:right w:w="180" w:type="dxa"/>
                </w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="0F766E"/><w:tcW w:w="3500" w:type="dxa"/></w:tcPr>
                  <w:p><w:pPr><w:jc w:val="left"/></w:pPr>
                    <w:r><w:rPr><w:b/><w:sz w:val="52"/><w:color w:val="FFFFFF"/></w:rPr><w:t>VITA</w:t></w:r>
                    <w:r><w:rPr><w:sz w:val="22"/><w:color w:val="A7D8D4"/></w:rPr><w:t xml:space="preserve">  Personal Health Causality Engine</w:t></w:r>
                  </w:p>
                  <w:p><w:pPr><w:jc w:val="left"/></w:pPr>
                    <w:r><w:rPr><w:sz w:val="18"/><w:color w:val="CCF0ED"/></w:rPr><w:t>Clinical Pattern Report  ·  AI Generated</w:t></w:r>
                  </w:p>
                </w:tc>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="0D6560"/><w:tcW w:w="1500" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                  <w:p><w:pPr><w:jc w:val="right"/></w:pPr>
                    <w:r><w:rPr><w:sz w:val="18"/><w:color w:val="A7D8D4"/></w:rPr><w:t>{{ reportDate }}</w:t></w:r>
                  </w:p>
                  <w:p><w:pPr><w:jc w:val="right"/></w:pPr>
                    <w:r><w:rPr><w:sz w:val="16"/><w:color w:val="7BB8B4"/></w:rPr><w:t>{{ reportId }}</w:t></w:r>
                  </w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="80"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- USER QUESTION (prominent)                                        -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="none" w:sz="0"/><w:bottom w:val="none" w:sz="0"/>
                  <w:left w:val="single" w:sz="16" w:color="0F766E"/>
                  <w:right w:val="none" w:sz="0"/>
                  <w:insideH w:val="none" w:sz="0"/><w:insideV w:val="none" w:sz="0"/>
                </w:tblBorders>
                <w:tblCellMar><w:left w:w="200" w:type="dxa"/></w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="F4FCFB"/></w:tcPr>
                  <w:p>
                    <w:r><w:rPr><w:sz w:val="16"/><w:color w:val="5EA8A4"/></w:rPr><w:t>YOU ASKED</w:t></w:r>
                  </w:p>
                  <w:p>
                    <w:r><w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="1A1A1A"/></w:rPr><w:t>{{ primaryConcern }}</w:t></w:r>
                  </w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="120"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- AI SUMMARY CARD                                                  -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F766E"/></w:rPr><w:t>AI ANALYSIS SUMMARY</w:t></w:r></w:p>
            <w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="4" w:color="0F766E"/></w:pBdr><w:spacing w:after="60"/></w:pPr></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="4" w:color="A7D8D4"/>
                  <w:left w:val="single" w:sz="4" w:color="A7D8D4"/>
                  <w:bottom w:val="single" w:sz="4" w:color="A7D8D4"/>
                  <w:right w:val="single" w:sz="4" w:color="A7D8D4"/>
                  <w:insideH w:val="single" w:sz="2" w:color="D0EEEC"/>
                  <w:insideV w:val="none" w:sz="0"/>
                </w:tblBorders>
                <w:tblCellMar>
                  <w:top w:w="120" w:type="dxa"/>
                  <w:left w:w="160" w:type="dxa"/>
                  <w:bottom w:w="120" w:type="dxa"/>
                  <w:right w:w="160" w:type="dxa"/>
                </w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/><w:tcW w:w="3600" w:type="dxa"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="0F766E"/></w:rPr><w:t>{{ aiSummaryTitle }}</w:t></w:r></w:p>
                  <w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr><w:r><w:rPr><w:sz w:val="20"/><w:color w:val="333333"/></w:rPr><w:t>{{ aiSummaryBody }}</w:t></w:r></w:p>
                </w:tc>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="D0EEEC"/><w:tcW w:w="1400" w:type="dxa"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="5EA8A4"/></w:rPr><w:t>CONFIDENCE</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="0F766E"/></w:rPr><w:t>{{ confidenceBand }}</w:t></w:r></w:p>
                  <w:p><w:pPr><w:spacing w:before="120"/></w:pPr><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="5EA8A4"/></w:rPr><w:t>SLEEP</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="1A1A1A"/></w:rPr><w:t>{{ sleepQuality }}</w:t></w:r></w:p>
                  <w:p><w:pPr><w:spacing w:before="120"/></w:pPr><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="5EA8A4"/></w:rPr><w:t>ACTIVITY</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="1A1A1A"/></w:rPr><w:t>{{ exerciseFrequency }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
              <w:tr>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/><w:tcW w:w="3600" w:type="dxa"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="5EA8A4"/></w:rPr><w:t>CAUSAL CHAIN IDENTIFIED</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="1A1A1A"/></w:rPr><w:t>{{ likelyReason }}</w:t></w:r></w:p>
                </w:tc>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="D0EEEC"/><w:tcW w:w="1400" w:type="dxa"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="5EA8A4"/></w:rPr><w:t>HEALTH SCORE</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="0F766E"/></w:rPr><w:t>{{ healthScore }}/100</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:tcPr><w:gridSpan w:val="2"/><w:shd w:val="clear" w:fill="F4FCFB"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="5EA8A4"/></w:rPr><w:t>NEXT BEST ACTION</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="1A1A1A"/></w:rPr><w:t>{{ nextBestAction }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="160"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- HEALTH METRICS (4-column grid)                                   -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F766E"/></w:rPr><w:t>HEALTH METRICS SNAPSHOT</w:t></w:r></w:p>
            <w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="4" w:color="0F766E"/></w:pBdr><w:spacing w:after="60"/></w:pPr></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="2" w:color="D9D9D9"/>
                  <w:left w:val="none" w:sz="0"/>
                  <w:bottom w:val="single" w:sz="2" w:color="D9D9D9"/>
                  <w:right w:val="none" w:sz="0"/>
                  <w:insideH w:val="single" w:sz="2" w:color="EFEFEF"/>
                  <w:insideV w:val="single" w:sz="2" w:color="E0E0E0"/>
                </w:tblBorders>
                <w:tblCellMar>
                  <w:top w:w="100" w:type="dxa"/>
                  <w:left w:w="140" w:type="dxa"/>
                  <w:bottom w:w="100" w:type="dxa"/>
                  <w:right w:w="140" w:type="dxa"/>
                </w:tblCellMar>
              </w:tblPr>
              <!-- Header row -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>Metric</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>Value</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>Metric</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>Value</w:t></w:r></w:p></w:tc>
              </w:tr>
              <!-- Row 1 -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Health Score</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>{{ healthScore }}/100</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>HRV</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>{{ hrv }}</w:t></w:r></w:p></w:tc>
              </w:tr>
              <!-- Row 2 -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Heart Rate</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>{{ heartRate }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Glucose</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>{{ glucose }}</w:t></w:r></w:p></w:tc>
              </w:tr>
              <!-- Row 3 -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Sleep</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>{{ sleepHours }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Steps</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>{{ steps }}</w:t></w:r></w:p></w:tc>
              </w:tr>
              <!-- Row 4 -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Skin Score</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/></w:rPr><w:t>{{ skinScore }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Digestive Signal</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="18"/></w:rPr><w:t>{{ digestiveIssues }}</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="160"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- CAUSAL CHAIN FINDINGS                                            -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F766E"/></w:rPr><w:t>CAUSAL CHAIN FINDINGS</w:t></w:r></w:p>
            <w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="4" w:color="0F766E"/></w:pBdr><w:spacing w:after="80"/></w:pPr></w:p>
            <!-- Finding 1 -->
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="none" w:sz="0"/><w:bottom w:val="none" w:sz="0"/>
                  <w:left w:val="single" w:sz="12" w:color="0F766E"/>
                  <w:right w:val="none" w:sz="0"/>
                  <w:insideH w:val="none" w:sz="0"/><w:insideV w:val="none" w:sz="0"/>
                </w:tblBorders>
                <w:tblCellMar><w:left w:w="160" w:type="dxa"/></w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="F7FDFC"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F766E"/></w:rPr><w:t>Chain 1</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="1A1A1A"/></w:rPr><w:t>{{ causalInsight1 }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="80"/></w:pPr></w:p>
            <!-- Finding 2 -->
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="none" w:sz="0"/><w:bottom w:val="none" w:sz="0"/>
                  <w:left w:val="single" w:sz="12" w:color="5EA8A4"/>
                  <w:right w:val="none" w:sz="0"/>
                  <w:insideH w:val="none" w:sz="0"/><w:insideV w:val="none" w:sz="0"/>
                </w:tblBorders>
                <w:tblCellMar><w:left w:w="160" w:type="dxa"/></w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="F7FDFC"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="5EA8A4"/></w:rPr><w:t>Chain 2</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:sz w:val="20"/><w:color w:val="333333"/></w:rPr><w:t>{{ causalInsight2 }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="80"/></w:pPr></w:p>
            <!-- Finding 3 -->
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="none" w:sz="0"/><w:bottom w:val="none" w:sz="0"/>
                  <w:left w:val="single" w:sz="12" w:color="A7D8D4"/>
                  <w:right w:val="none" w:sz="0"/>
                  <w:insideH w:val="none" w:sz="0"/><w:insideV w:val="none" w:sz="0"/>
                </w:tblBorders>
                <w:tblCellMar><w:left w:w="160" w:type="dxa"/></w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc>
                  <w:tcPr><w:shd w:val="clear" w:fill="FAFFFE"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="A7D8D4"/></w:rPr><w:t>Chain 3</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:sz w:val="20"/><w:color w:val="555555"/></w:rPr><w:t>{{ causalInsight3 }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="160"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- MEAL & GLUCOSE PATTERNS                                          -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F766E"/></w:rPr><w:t>MEAL &amp; GLUCOSE PATTERNS</w:t></w:r></w:p>
            <w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="4" w:color="0F766E"/></w:pBdr><w:spacing w:after="60"/></w:pPr></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="2" w:color="D9D9D9"/>
                  <w:left w:val="none"/><w:right w:val="none"/>
                  <w:bottom w:val="single" w:sz="2" w:color="D9D9D9"/>
                  <w:insideH w:val="single" w:sz="2" w:color="EFEFEF"/>
                  <w:insideV w:val="none"/>
                </w:tblBorders>
                <w:tblCellMar>
                  <w:top w:w="80" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="80" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>#</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>Meal &amp; Source · Glycemic Load · Glucose Impact</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F766E"/></w:rPr><w:t>1</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>{{ mealInsight1 }}</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F766E"/></w:rPr><w:t>2</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="F9F9F9"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>{{ mealInsight2 }}</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F766E"/></w:rPr><w:t>3</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr><w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>{{ mealInsight3 }}</w:t></w:r></w:p></w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="160"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- SKIN HEALTH                                                      -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F766E"/></w:rPr><w:t>SKIN HEALTH (PerfectCorp AI)</w:t></w:r></w:p>
            <w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="4" w:color="0F766E"/></w:pBdr><w:spacing w:after="60"/></w:pPr></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="2" w:color="D9D9D9"/>
                  <w:left w:val="none"/><w:right w:val="none"/>
                  <w:bottom w:val="single" w:sz="2" w:color="D9D9D9"/>
                  <w:insideH w:val="single" w:sz="2" w:color="EFEFEF"/>
                  <w:insideV w:val="none"/>
                </w:tblBorders>
                <w:tblCellMar>
                  <w:top w:w="80" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="80" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/><w:tcW w:w="1200" w:type="dxa"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>Overall Score</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/></w:tcPr><w:p><w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="FFFFFF"/></w:rPr><w:t>Detected Conditions</w:t></w:r></w:p></w:tc>
              </w:tr>
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/><w:vAlign w:val="center"/></w:tcPr><w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="40"/><w:color w:val="0F766E"/></w:rPr><w:t>{{ skinScore }}</w:t></w:r></w:p></w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>{{ skinInsight1 }}</w:t></w:r></w:p>
                  <w:p><w:r><w:rPr><w:sz w:val="20"/></w:rPr><w:t>{{ skinInsight2 }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="160"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- RECOMMENDED INTERVENTIONS                                         -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:p><w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F766E"/></w:rPr><w:t>RECOMMENDED INTERVENTIONS</w:t></w:r></w:p>
            <w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="4" w:color="0F766E"/></w:pBdr><w:spacing w:after="80"/></w:pPr></w:p>
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="none" w:sz="0"/><w:bottom w:val="none" w:sz="0"/>
                  <w:left w:val="none" w:sz="0"/><w:right w:val="none" w:sz="0"/>
                  <w:insideH w:val="single" w:sz="2" w:color="EFEFEF"/>
                  <w:insideV w:val="none"/>
                </w:tblBorders>
                <w:tblCellMar>
                  <w:top w:w="100" w:type="dxa"/>
                  <w:left w:w="120" w:type="dxa"/>
                  <w:bottom w:w="100" w:type="dxa"/>
                  <w:right w:w="120" w:type="dxa"/>
                </w:tblCellMar>
              </w:tblPr>
              <!-- Rec 1 -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="0F766E"/><w:tcW w:w="400" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                  <w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="FFFFFF"/></w:rPr><w:t>1</w:t></w:r></w:p>
                </w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="EAF7F6"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="20"/><w:color w:val="1A1A1A"/></w:rPr><w:t>{{ recommendation1 }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
              <!-- Rec 2 -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="5EA8A4"/><w:tcW w:w="400" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                  <w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="FFFFFF"/></w:rPr><w:t>2</w:t></w:r></w:p>
                </w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="FFFFFF"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="20"/><w:color w:val="333333"/></w:rPr><w:t>{{ recommendation2 }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
              <!-- Rec 3 -->
              <w:tr>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="A7D8D4"/><w:tcW w:w="400" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                  <w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="FFFFFF"/></w:rPr><w:t>3</w:t></w:r></w:p>
                </w:tc>
                <w:tc><w:tcPr><w:shd w:val="clear" w:fill="F4FCFB"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="20"/><w:color w:val="444444"/></w:rPr><w:t>{{ recommendation3 }}</w:t></w:r></w:p>
                </w:tc>
              </w:tr>
            </w:tbl>
            <w:p><w:pPr><w:spacing w:after="200"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- SUPPORTING EVIDENCE                                              -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="5EA8A4"/></w:rPr><w:t>SUPPORTING EVIDENCE</w:t></w:r></w:p>
            <w:p><w:r><w:rPr><w:sz w:val="18"/><w:color w:val="555555"/></w:rPr><w:t>{{ supportingEvidence }}</w:t></w:r></w:p>
            <w:p><w:pPr><w:spacing w:after="120"/></w:pPr></w:p>

            <!-- ═══════════════════════════════════════════════════════════════ -->
            <!-- FOOTER                                                           -->
            <!-- ═══════════════════════════════════════════════════════════════ -->
            <w:tbl>
              <w:tblPr>
                <w:tblW w:w="5000" w:type="pct"/>
                <w:tblBorders>
                  <w:top w:val="single" w:sz="4" w:color="0F766E"/>
                  <w:left w:val="none"/><w:bottom w:val="none"/><w:right w:val="none"/>
                  <w:insideH w:val="none"/><w:insideV w:val="none"/>
                </w:tblBorders>
                <w:tblCellMar><w:top w:w="80" w:type="dxa"/></w:tblCellMar>
              </w:tblPr>
              <w:tr>
                <w:tc><w:tcPr><w:tcW w:w="3200" w:type="dxa"/></w:tcPr>
                  <w:p><w:r><w:rPr><w:sz w:val="16"/><w:color w:val="888888"/></w:rPr><w:t>This report is AI-generated and does not constitute a medical diagnosis. Share with a licensed clinician for clinical interpretation.</w:t></w:r></w:p>
                </w:tc>
                <w:tc><w:tcPr><w:tcW w:w="1800" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
                  <w:p><w:pPr><w:jc w:val="right"/></w:pPr>
                    <w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="0F766E"/></w:rPr><w:t>VITA</w:t></w:r>
                    <w:r><w:rPr><w:sz w:val="16"/><w:color w:val="888888"/></w:rPr><w:t xml:space="preserve">  Personal Health Causality Engine</w:t></w:r>
                  </w:p>
                  <w:p><w:pPr><w:jc w:val="right"/></w:pPr>
                    <w:r><w:rPr><w:sz w:val="16"/><w:color w:val="AAAAAA"/></w:rPr><w:t>{{ reportId }}</w:t></w:r>
                  </w:p>
                </w:tc>
              </w:tr>
            </w:tbl>

            <w:sectPr>
              <w:pgMar w:top="720" w:right="900" w:bottom="720" w:left="900"/>
            </w:sectPr>
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
