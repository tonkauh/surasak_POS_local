import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class PrinterTest {
  static BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // --- ฟังก์ชันแปลงไทย Unicode เป็น TIS-620 ---
  static Uint8List _thaiToBytes(String text) {
    List<int> bytes = [];
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0E01 && code <= 0x0E5B) {
        bytes.add(code - 0x0E00 + 0xA0);
      } else if (code < 0x80) {
        bytes.add(code);
      } else {
        bytes.add(0x3F);
      }
    }
    return Uint8List.fromList(bytes);
  }

  // --- ฟังก์ชัน Hunter สำหรับเทส CodePage ทั้งหมดที่มีโอกาสเป็นไปได้ ---
  static Future<void> runThaiHunter() async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      // รายชื่อเลข CodePage ที่เครื่อง WNN58E มักจะใช้
      List<int> testCodes = [13, 14, 16, 17, 18, 21, 26, 28, 30, 255];

      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x40])); // Reset
      await bluetooth.writeBytes(_thaiToBytes("--- เริ่มการทดสอบ CodePage ---\n"));

      for (int code in testCodes) {
        // ESC t [n] สลับตารางตัวอักษร
        await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x74, code]));
        
        // พิมพ์เลข Code และคำทดสอบสระที่มีปัญหา (เ ไ ใ)
        String testText = "Code $code: เป๋าตุง (เ ไ ใ)\n";
        await bluetooth.writeBytes(_thaiToBytes(testText));
      }

      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
      // เลื่อนกระดาษ
      await bluetooth.writeBytes(Uint8List.fromList([0x1D, 0x56, 0x42, 0x00]));
    }
  }
}