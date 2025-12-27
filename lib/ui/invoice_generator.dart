import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'invoice_form_screen.dart'; // for InvoiceData model
import 'package:intl/intl.dart';

class InvoiceGenerator {
  static Future<Uint8List> generate(InvoiceData data) async {
    final pdf = pw.Document();

    // Use built-in Japanese font support from printing package
    final font = await PdfGoogleFonts.notoSansJPRegular();
    final boldFont = await PdfGoogleFonts.notoSansJPBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Center(
                child: pw.Text(
                  '未払い賃金等請求通知書', 
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)
                ),
              ),
              pw.SizedBox(height: 32),

              // To
              pw.Text('${data.companyName}', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('代表者 ${data.bossName} 殿', style: const pw.TextStyle(fontSize: 14)),
              
              pw.SizedBox(height: 32),
              
              // From
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('日付: ${DateFormat('yyyy年MM月dd日').format(DateTime.now())}'),
                    pw.Text('請求者: ${data.userName}'),
                    pw.Text('(印)', style: const pw.TextStyle(color: PdfColors.grey)),
                  ],
                ),
              ),

              pw.SizedBox(height: 32),

              // Body
              pw.Text(
                '冠省\n\n'
                '私は、貴社に対し、労働基準法に基づき、以下の期間における未払い賃金（時間外労働割増賃金を含む）の支払いを請求いたします。\n\n'
                '対象期間: ${DateFormat('yyyy年MM月dd日').format(data.startDate)} 〜 ${DateFormat('yyyy年MM月dd日').format(data.endDate)}\n\n'
                '本通知書受領後、7日以内に指定口座へお支払いください。'
                '万が一、支払いや誠実な回答がない場合は、労働基準監督署への申告または法的措置を講じる準備があることを申し添えます。',
                style: const pw.TextStyle(lineSpacing: 4),
              ),
              
              pw.SizedBox(height: 32),

              // Table (Mock for MVP - data link needs Phase 4)
              pw.Text('【計算明細 (概算)】', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  children: [
                    _row('未払い残業時間', '48.5 時間'),
                    _row('平均時給', '1,500 円'),
                    pw.Divider(),
                    _row('請求合計額', '72,750 円', isBold: true),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 8),
              pw.Text('※ 詳細なログ記録（GPS証拠データ）は別紙の通り保持しております。', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _row(String label, String value, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
        pw.Text(value, style: isBold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
      ],
    );
  }
}
