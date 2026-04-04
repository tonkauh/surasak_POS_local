import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class PrinterService {
  static BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  static Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  // ฟังก์ชันสั่งปริ้นแบบไม่ต้องจัดช่องว่างเอง
  static Future<void> printReceipt({
    required String tableName,
    required double total,
    required List<Map<String, dynamic>> cart,
  }) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      // ส่งรหัสลับบอกเครื่อง Epson ว่าเราจะคุยภาษาไทย (Codepage 874)
      bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x74, 0x1E]));

      String dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // 1. หัวกระดาษ (จัดกลาง)
      bluetooth.printCustom("เป๋าตุงบ่อนไก่", 2, 1); // Size 2, Align Center (1)
      bluetooth.printCustom("โทร : 095-532-5638", 1, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);

      // 2. ข้อมูลโต๊ะและวันที่ (ชิดซ้าย-ขวาอัตโนมัติ)
      // ขนาดตัวอักษร 1 (ปกติ)
      bluetooth.printLeftRight("โต๊ะ : $tableName", "Date: $dateStr", 1);
      bluetooth.printCustom("--------------------------------", 1, 1);

      // 3. รายการอาหาร (วนลูปปริ้นชิดซ้าย-ขวา)
      for (var item in cart) {
        String leftText = "${item['name']} x${item['qty']}";
        String rightText = "${(item['price'] * item['qty']).toInt()}";
        
        // ใช้ฟังก์ชันนี้แทนการคำนวณเว้นวรรคเอง!
        bluetooth.printLeftRight(leftText, rightText, 1);
      }

      // 4. สรุปยอด (ตัวใหญ่ขึ้นนิดนึง)
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("TOTAL:", "${total.toInt()} THB", 2); // Size 2
      bluetooth.printCustom("--------------------------------", 1, 1);

      // 5. ท้ายบิล
      bluetooth.printNewLine();
      bluetooth.printCustom("Thank you!", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    }
  }
}