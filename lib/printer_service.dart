import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';

class PrinterService {
  static BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  static const int maxChars = 32;

  // ฟังก์ชันแปลง Unicode เป็น TIS-620 (เพื่อให้เครื่อง Code 21 อ่านออก)
  static Uint8List _thaiToBytes(String text) {
    List<int> bytes = [];
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0E01 && code <= 0x0E5B) {
        bytes.add(code - 0x0E00 + 0xA0);
      } else if (code < 0x80) {
        bytes.add(code);
      } else {
        bytes.add(0x3F); // ตัวที่อ่านไม่ออกให้เป็น ?
      }
    }
    return Uint8List.fromList(bytes);
  }

  // ฟังก์ชันคำนวณความยาวของตัวอักษรที่มองเห็นจริง (ไม่นับสระบน/ล่าง และวรรณยุกต์)
  static int _getVisibleLength(String text) {
    int length = 0;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      // รหัส Unicode ของสระและวรรณยุกต์ไทยที่ลอยอยู่ (Non-spacing marks) จะไม่ถูกนับรวม
      if ([
        0x0E31, 0x0E34, 0x0E35, 0x0E36, 0x0E37, 0x0E38, 0x0E39, 0x0E3A,
        0x0E47, 0x0E48, 0x0E49, 0x0E4A, 0x0E4B, 0x0E4C, 0x0E4D, 0x0E4E
      ].contains(code)) {
        continue;
      }
      length++;
    }
    return length;
  }

  // จัดหน้าชิดซ้าย-ขวา
  static Uint8List _formatLine(String left, String right) {
    int spaceCount = maxChars - (_getVisibleLength(left) + _getVisibleLength(right));
    if (spaceCount < 0) spaceCount = 1;
    return _thaiToBytes(left + (" " * spaceCount) + right + "\n");
  }

  static Future<List<BluetoothDevice>> getPairedDevices() async {
    return await bluetooth.getBondedDevices();
  }

  static Future<void> printReceiptImage(Uint8List imageBytes) async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      // 1. [CRITICAL] Hard Reset & Alignment Initialization
      // 0x1B, 0x40 = ESC @ (Initialize)
      // 0x1B, 0x53 = ESC S (Standard Mode)
      // 0x1B, 0x61, 0x00 = ESC a 0 (Force Align Left - ป้องกันการเยื้อง)
      // 0x1D, 0x4C, 0x00, 0x00 = GS L 0 0 (Set Left Margin to 0)
      await bluetooth.writeBytes(Uint8List.fromList([
        0x1B, 0x40, 
        0x1B, 0x53, 
        0x1B, 0x61, 0x00, 
        0x1D, 0x4C, 0x00, 0x00
      ]));

      // 2. Delay ให้ Hardware เคลียร์ Buffer (สั้นๆ 500ms)
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. สั่งพิมพ์รูปภาพ
      await bluetooth.printImageBytes(imageBytes);

      // 4. จบงานด้วยการเว้นบรรทัดและล้างสถานะอีกครั้งเพื่อกันบิลถัดไปเพี้ยน
      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x40])); 
      
      await bluetooth.paperCut();
    }
  }

  // ฟังก์ชันพิมพ์ใบเสร็จหลัก
  static Future<void> printReceipt({
    required String tableName,
    required double total,
    required List<Map<String, dynamic>> cart,
  }) async {
    if (await bluetooth.isConnected == true) {
      // --- [STEP 1] Reset และเปิดโหมดไทยเบอร์ 21 ---
      // 0x1B, 0x40 = Reset
      // 0x1B, 0x74, 21 = เลือก CodePage 21 (ไทยที่ถูกต้องของเครื่องนี้)
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x40, 0x1B, 0x74, 21]));

      // --- [STEP 2] พิมพ์เนื้อหา ---
      // เปิดโหมดตัวหนาและขนาดใหญ่ (Bold + Double Size) สำหรับชื่อร้าน
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x45, 0x01, 0x1D, 0x21, 0x11]));
      // พิมพ์ชื่อร้าน (ลดช่องว่างข้างหน้าลงเหลือ 2 ช่อง เพราะตัวหนังสือใหญ่ขึ้น)
      await bluetooth.writeBytes(_thaiToBytes("  เป๋าตุง บ่อนไก่\n"));
      // ปิดโหมดตัวหนาและขนาดใหญ่ กลับเป็นปกติสำหรับข้อความบรรทัดถัดไป
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x45, 0x00, 0x1D, 0x21, 0x00]));

      await bluetooth.writeBytes(_thaiToBytes("      095-532-5638\n"));
      await bluetooth.writeBytes(_thaiToBytes("--------------------------------\n"));

      String dateStr = DateFormat('dd/MM/yy HH:mm').format(DateTime.now());
      await bluetooth.writeBytes(_formatLine("โต๊ะ: $tableName", dateStr));
      await bluetooth.writeBytes(_thaiToBytes("--------------------------------\n"));

      for (var item in cart) {
        String name = "${item['name']} x${item['qty']}";
        String price = "${(item['price'] * item['qty']).toInt()}";
        await bluetooth.writeBytes(_formatLine(name, price));
      }

      // --- [ยอดรวม - ปรับให้ใหญ่พิเศษ] ---
      await bluetooth.writeBytes(_thaiToBytes("--------------------------------\n"));
      
      // 1. เปิดโหมด ตัวหนา (Bold) และ ขนาดใหญ่ 2 เท่า (Double Size)
      // 0x1B, 0x45, 0x01 = Bold ON
      // 0x1D, 0x21, 0x11 = Double Height + Double Width (2x)
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x45, 0x01, 0x1D, 0x21, 0x11]));
      
      // 2. พิมพ์ยอดรวม (เนื่องจากตัวใหญ่ขึ้น พื้นที่บรรทัดจะลดลงเหลือประมาณ 16-20 ตัวอักษร)
      await bluetooth.writeBytes(_thaiToBytes("รวมเงิน: ${total.toInt()}.-\n"));

      // 3. ปิดโหมดตัวใหญ่ กลับมาเป็นขนาดปกติ (สำคัญมาก! ไม่งั้นบรรทัดถัดไปจะใหญ่ตาม)
      // 0x1B, 0x45, 0x00 = Bold OFF
      // 0x1D, 0x21, 0x00 = Normal Size
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x45, 0x00, 0x1D, 0x21, 0x00]));
      
      await bluetooth.writeBytes(_thaiToBytes("--------------------------------\n"));

      // --- [STEP 3] ท้ายบิลและเลื่อนกระดาษ ---
      await bluetooth.writeBytes(_thaiToBytes("\n      ขอบคุณที่ใช้บริการครับ\n\n\n\n"));
      
      // สั่งตัดกระดาษ (GS V 66 0)
      await bluetooth.writeBytes(Uint8List.fromList([0x1D, 0x56, 0x42, 0x00]));
    }
  }

  // --- ฟังก์ชันสั่งเปิดลิ้นชักเก็บเงิน ---
  static Future<void> openCashDrawer() async {
    bool? isConnected = await bluetooth.isConnected;
    if (isConnected == true) {
      // คำสั่งมาตรฐานสำหรับเปิดลิ้นชัก (Standard Kick-Out Connector)
      // 0x1B, 0x70 คือ ESC p (คำสั่งเปิดลิ้นชัก)
      // 0x00 คือเลือก Pin 2 (มาตรฐานส่วนใหญ่)
      // 0x19, 0xFA คือระยะเวลาการส่งกระแสไฟฟ้า (Pulse duration)
      await bluetooth.writeBytes(Uint8List.fromList([0x1B, 0x70, 0x00, 0x19, 0xFA]));
    }
  }
}
