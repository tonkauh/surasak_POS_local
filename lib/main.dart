import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'printer_service.dart'; // เพิ่มบรรทัดนี้ต่อจาก import ตัวอื่น
import 'package:my_pos_app/printer_test.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [const POSScreen(), const DashboardScreen(), const ManageMenuScreen()];
  final List<String> _titles = ['หน้าขาย (POS)', 'Dashboard', 'จัดการร้าน'];

  void _showPrinterSetup() async {
    // 1. ดึงรายชื่อทั้งหมดมาก่อน
    List<BluetoothDevice> allDevices = await PrinterService.getPairedDevices();
    
    // 2. กรองเฉพาะตัวที่มีคำว่า Printer หรือชื่อยี่ห้อ (หรือจะโชว์ทั้งหมดแต่แยกประเภทก็ได้)
    // ในที่นี้ผมจะลอง Filter ตัวที่ชื่อน่าจะเป็นเครื่องปริ้นมาไว้บนสุดครับ
    List<BluetoothDevice> printerDevices = allDevices.where((d) {
      String name = d.name?.toLowerCase() ?? "";
      return name.contains("print") || name.contains("epson") || name.contains("tm-") || name.contains("mpt");
    }).toList();

    // ถ้ากรองแล้วไม่เจออะไรเลย ให้ใช้รายชื่อทั้งหมด (เผื่อเครื่องปริ้นชื่อแปลกๆ)
    List<BluetoothDevice> displayList = printerDevices.isEmpty ? allDevices : printerDevices;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.print, size: 50, color: Colors.indigo),
            const SizedBox(height: 10),
            const Text("เลือกเครื่องปริ้นบลูทูธ", style: TextStyle(fontSize: 18)),
            if (printerDevices.isNotEmpty)
              const Text("(พบเครื่องที่น่าจะเป็นเครื่องปริ้น)", style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: displayList.isEmpty 
            ? const Center(child: Text("ไม่พบอุปกรณ์ที่ Pair ไว้\nกรุณาไป Pair ใน Setting ของมือถือก่อนครับ", textAlign: TextAlign.center))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: displayList.length,
                itemBuilder: (ctx, i) => Card(
                  elevation: 0,
                  color: Colors.grey[100],
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.blue),
                    title: Text(displayList[i].name ?? "Unknown Device", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(displayList[i].address ?? ""),
                    onTap: () async {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กำลังเชื่อมต่อ...")));
                      await PrinterService.bluetooth.connect(displayList[i]);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("เชื่อมต่อ ${displayList[i].name} สำเร็จ!"), backgroundColor: Colors.green)
                      );
                    },
                  ),
                ),
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      drawer: Drawer(
        child: Column(children: [
          const UserAccountsDrawerHeader(decoration: BoxDecoration(color: Colors.indigo), accountName: Text("รักน้ำรักปลารักแม่"), accountEmail: Text("ระบบจัดการร้านค้า")),
          ListTile(leading: const Icon(Icons.shopping_cart), title: const Text("หน้าขาย"), onTap: () { setState(() => _selectedIndex = 0); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.bar_chart), title: const Text("Dashboard"), onTap: () { setState(() => _selectedIndex = 1); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.settings), title: const Text("จัดการเมนู"), onTap: () { setState(() => _selectedIndex = 2); Navigator.pop(context); }),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.print_sharp, color: Colors.indigo),
            title: const Text("ตั้งค่าเครื่องปริ้น", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.pop(context);
              _showPrinterSetup();
            },
          ),
        ]),
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
    );
  }
}

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  String selectedTable = "1";
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadTableOrder(selectedTable); // โหลดของโต๊ะ 1 มาก่อน
  }

  void _loadProducts() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() { products = data; });
  }

  // โหลดรายการที่พักไว้ของโต๊ะนั้นๆ
  void _loadTableOrder(String tableName) async {
    final pending = await DatabaseHelper.instance.getPendingOrder(tableName);
    setState(() {
      selectedTable = tableName;
      cart = pending;
    });
  }

  // บันทึกรายการลงที่พักบิล (Auto-Save)
  void _autoPark() async {
    await DatabaseHelper.instance.savePendingOrder(selectedTable, cart);
  }

  double get total => cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));

  void _showChangeCalculator(double totalAmount) {
    // ใช้ Controller เพื่อควบคุมตัวเลขในช่องกรอก
    final TextEditingController receivedCtrl = TextEditingController();
    double received = 0;
    final List<int> quickMoney = [1000, 500, 100, 20, 10, 5];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // คำนวณเงินทอนแบบ Real-time
            double change = received - totalAmount;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Center(
                child: Text("ชำระเงินเงินสด", style: TextStyle(fontWeight: FontWeight.bold))
              ),
              content: SingleChildScrollView( // แก้บั๊ก UI ตอนคีย์บอร์ดขึ้น
                child: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("ยอดรวม: ${totalAmount.toInt()} ฿", style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 15),
                      
                      // ช่องกรอกจำนวนเงิน (พิมพ์เลขแทน)
                      TextField(
                        controller: receivedCtrl,
                        autofocus: true, // ให้แป้นพิมพ์เด้งรอเลย
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                        decoration: InputDecoration(
                          hintText: "0",
                          labelText: "รับเงินมา (บาท)",
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          suffixText: "฿",
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            received = double.tryParse(value) ?? 0;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 15),
                      // แสดงเงินทอน
                      Text(
                        "เงินทอน: ${change < 0 ? 0 : change.toInt()} ฿", 
                        style: const TextStyle(fontSize: 34, color: Colors.green, fontWeight: FontWeight.bold)
                      ),
                      
                      // แสดงยอดที่ยังขาด (ถ้ามี)
                      if (change < 0 && received > 0) 
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text("ยังขาดอีก ${-(change.toInt())} ฿", style: const TextStyle(color: Colors.red)),
                        ),
                      
                      const Divider(height: 40),

                      // ปุ่มแบงก์ทางลัด (Quick Add)
                      const Text("ปุ่มทางลัดเพิ่มเงิน", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: quickMoney.map((money) => SizedBox(
                          width: 80,
                          child: OutlinedButton(
                            onPressed: () {
                              setDialogState(() {
                                received += money;
                                // อัปเดตตัวเลขในช่องพิมพ์ให้ตรงกัน
                                receivedCtrl.text = received.toInt().toString(); 
                              });
                            },
                            child: Text("$money"),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Column(
                  children: [
                    Row(
                      children: [
                        // --- ปุ่มจ่ายพอดี (ข้ามการทอน) ---
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                            onPressed: () async {
                              await DatabaseHelper.instance.saveSale(selectedTable, totalAmount, cart);
                              setState(() { cart = []; });
                              Navigator.pop(ctx); // ปิดหน้าเงินทอน
                              Navigator.pop(context); // ปิดหน้าพรีวิว
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("จ่ายพอดี / บันทึกขายเรียบร้อย"), backgroundColor: Colors.indigo)
                              );
                            },
                            child: const Text("จ่ายพอดี (ข้าม)"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // --- ปุ่มยืนยัน (กดได้เมื่อเงินครบเท่านั้น) ---
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo, 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                            onPressed: (received < totalAmount) ? null : () async {
                              await DatabaseHelper.instance.saveSale(selectedTable, totalAmount, cart);
                              setState(() { cart = []; }); 
                              Navigator.pop(ctx); 
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("เช็คบิลเรียบร้อย!"), backgroundColor: Colors.green)
                              );
                            }, 
                            child: const Text("ยืนยันบันทึก"),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx), 
                      child: const Text("ย้อนกลับ", style: TextStyle(color: Colors.grey))
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPreview() {
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    String customerStatus = selectedTable == "กลับบ้าน" ? " สถานะ: สั่งกลับบ้าน" : " สถานะ: โต๊ะหมายเลข $selectedTable";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Center(child: Text("ตรวจสอบออเดอร์", style: TextStyle(fontWeight: FontWeight.bold))),
        content: Container(
          width: 350, padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("เป๋าตุง บ่อนไก่....", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const Text("โทร: 095-532-5638"),
                const SizedBox(height: 10),
                const Text("------------------------------------------"),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                  decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                  child: Text(customerStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("วันที่: $formattedDate", style: const TextStyle(fontSize: 12, color: Colors.grey)), const Text("ใบเสร็จชั่วคราว", style: TextStyle(fontSize: 12, color: Colors.grey))]),
                const Text("------------------------------------------"),
                ...cart.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text("${item['name']} x${item['qty']}", style: const TextStyle(fontSize: 16))), Text("${(item['price'] * item['qty']).toInt()} ฿")]))).toList(),
                const Text("------------------------------------------"),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("ยอดรวมทั้งสิ้น", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("${total.toInt()} บาท", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.indigo))]),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange, // สีส้มเด่นๆ ให้รู้ว่าเป็นปุ่มเทส
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.build, color: Colors.white),
                  label: const Text("ทดสอบภาษาไทย (Hunter Mode)", style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    // เรียกใช้ฟังก์ชันจากไฟล์ printer_test.dart ที่เราแยกไว้
                    await PrinterTest.runThaiHunter();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("กำลังพิมพ์รหัสทดสอบ... เช็คที่กระดาษได้เลย")),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.print, color: Colors.white),
            label: const Text("พิมพ์ใบเสร็จ", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              // เรียกใช้ระบบ Native Text ตรงๆ (ไวและแม่นยำกว่า)
              await PrinterService.printReceipt(
                tableName: selectedTable,
                total: total,
                cart: cart,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("พิมพ์ใบเสร็จสำเร็จ")),
              );
            },
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("แก้ไขรายการ")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () { _autoPark(); _showChangeCalculator(total); }, 
            child: const Text("ยืนยันออเดอร์", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(children: [
        // ซ้าย: โต๊ะ (เพิ่มระบบโหลดเมื่อคลิกสลับโต๊ะ)
        Container(width: 120, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)), child: Column(children: [
          Expanded(child: GridView.builder(padding: const EdgeInsets.all(5), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 5, crossAxisSpacing: 5), itemCount: 12, itemBuilder: (ctx, i) {
            String tableNum = "${i+1}";
            return InkWell(
              onTap: () { _autoPark(); _loadTableOrder(tableNum); }, // สลับโต๊ะ: พักอันเก่า โหลดอันใหม่
              child: Container(decoration: BoxDecoration(color: selectedTable == tableNum ? Colors.indigo : Colors.white, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(tableNum, style: TextStyle(color: selectedTable == tableNum ? Colors.white : Colors.black)))),
            );
          })),
          Padding(padding: const EdgeInsets.all(8), child: ChoiceChip(label: const Text("กลับบ้าน"), selected: selectedTable == "กลับบ้าน", onSelected: (v) { _autoPark(); _loadTableOrder("กลับบ้าน"); })),
        ])),
        const SizedBox(width: 10),
        // กลาง: เมนู (เพิ่ม Auto-Park เมื่อเพิ่มของ)
        Expanded(flex: 3, child: products.isEmpty ? const Center(child: Text("ไปเพิ่มเมนูที่หน้าจัดการก่อนครับ")) : GridView.builder(gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1), itemCount: products.length, itemBuilder: (ctx, i) => Card(child: InkWell(onTap: () {
          setState(() {
            int idx = cart.indexWhere((it) => it['id'] == products[i]['id']);
            if(idx != -1) cart[idx]['qty']++; else cart.add({...products[i], 'qty': 1});
          });
          _autoPark(); // บันทึกทันทีเมื่อมีการเปลี่ยนแปลง
        }, child: Center(child: Text(products[i]['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))))))),
        const SizedBox(width: 10),
        // ขวา: ตะกร้า (เพิ่ม Auto-Park เมื่อแก้จำนวน)
        Container(width: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]), child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.vertical(top: Radius.circular(15))), child: Text(selectedTable == "กลับบ้าน" ? "สั่งกลับบ้าน" : "โต๊ะ $selectedTable", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(child: ListView.builder(itemCount: cart.length, itemBuilder: (ctx, i) => ListTile(title: Text(cart[i]['name'], maxLines: 1), subtitle: Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () { setState(() { if(cart[i]['qty'] > 1) cart[i]['qty']--; else cart.removeAt(i); }); _autoPark(); }),
            Text("${cart[i]['qty']}"),
            IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () { setState(() { cart[i]['qty']++; }); _autoPark(); }),
          ]), trailing: Text("${(cart[i]['price']*cart[i]['qty']).toInt()}")))),
          Padding(padding: const EdgeInsets.all(15), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("รวม:"), Text("${total.toInt()} ฿", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo))]), const SizedBox(height: 10), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: cart.isEmpty ? null : _showPreview, child: const Text("ยืนยันออเดอร์")))]))
        ])),
      ]),
    );
  }
}

// ... ส่วน Dashboard และ ManageMenu คงเดิมตามที่คุณส่งมา ...
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime selectedDate = DateTime.now();
  double dailyTotal = 0;
  List<Map<String, dynamic>> salesList = [];
  List<Map<String, dynamic>> topItemsList = [];

  @override
  void initState() { super.initState(); _loadDashboardData(); }

  void _loadDashboardData() async {
    String formattedDate = selectedDate.toString().split(' ')[0];
    final sales = await DatabaseHelper.instance.getSalesByDate(formattedDate);
    final tops = await DatabaseHelper.instance.getTopItems(formattedDate);
    double totalSum = 0;
    for (var s in sales) { totalSum += s['total']; }
    setState(() { salesList = sales; topItemsList = tops; dailyTotal = totalSum; });
  }

  void _deleteSaleRecord(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: const Text("คุณแน่ใจใช่ไหมที่จะลบประวัติบิลนี้?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
            await DatabaseHelper.instance.deleteSale(id);
            Navigator.pop(ctx); _loadDashboardData();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ลบรายการเรียบร้อย")));
          }, child: const Text("ลบทิ้ง", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  void _editSaleRecord(Map<String, dynamic> sale) {
    final tableController = TextEditingController(text: sale['tableName']);
    final totalController = TextEditingController(text: sale['total'].toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("แก้ไขข้อมูลบิล"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: tableController, decoration: const InputDecoration(labelText: "ชื่อโต๊ะ / สถานะ")),
          const SizedBox(height: 10),
          TextField(controller: totalController, decoration: const InputDecoration(labelText: "ยอดเงินรวม"), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
          ElevatedButton(onPressed: () async {
            if (tableController.text.isNotEmpty && totalController.text.isNotEmpty) {
              await DatabaseHelper.instance.updateSale(sale['id'], tableController.text, double.parse(totalController.text));
              Navigator.pop(ctx); _loadDashboardData();
            }
          }, child: const Text("บันทึก")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0), 
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("สรุปยอดขายรายวัน", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text("ประจำวันที่: ${DateFormat('dd MMMM yyyy').format(selectedDate)}", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ]),
          ElevatedButton.icon(onPressed: () async {
            DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2025), lastDate: DateTime.now());
            if (picked != null) { setState(() => selectedDate = picked); _loadDashboardData(); }
          }, icon: const Icon(Icons.calendar_month), label: const Text("เลือกวันที่ดูย้อนหลัง"))
        ]),
        const SizedBox(height: 25),
        Row(children: [
          _buildStatCard("ยอดขายรวม", "${dailyTotal.toInt()} ฿", Icons.monetization_on, Colors.green),
          const SizedBox(width: 15),
          _buildStatCard("จำนวนบิล", "${salesList.length} รายการ", Icons.receipt_long, Colors.orange),
          const SizedBox(width: 15),
          _buildStatCard("เมนูยอดฮิต", topItemsList.isNotEmpty ? topItemsList[0]['name'] : "-", Icons.star, Colors.purple),
        ]),
        const SizedBox(height: 25),
        Expanded(child: Row(children: [
          Expanded(flex: 1, child: _buildDashboardBox("🏆 5 อันดับสินค้าขายดี", topItemsList.isEmpty ? const Center(child: Text("ไม่มีข้อมูลการขาย")) : ListView.builder(itemCount: topItemsList.length, itemBuilder: (ctx, i) => ListTile(leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: Text("${i+1}")), title: Text(topItemsList[i]['name'], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Text("${topItemsList[i]['total_qty']} จาน", style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)))))),
          const SizedBox(width: 20),
          Expanded(flex: 1, child: _buildDashboardBox("🧾 ประวัติการขาย (ล่าสุด)", salesList.isEmpty ? const Center(child: Text("ยังไม่มีการออกบิล")) : ListView.separated(itemCount: salesList.length, separatorBuilder: (ctx, i) => const Divider(height: 1), itemBuilder: (ctx, i) {
            final sale = salesList[i];
            return ListTile(title: Text("บิล #${sale['id']} - ${sale['tableName']}", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("ยอดรวม: ${sale['total'].toInt()} ฿"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _editSaleRecord(sale)), IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteSaleRecord(sale['id']))]));
          })))
        ]))
      ]),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]), child: Column(children: [Icon(icon, color: color, size: 40), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])));
  }

  Widget _buildDashboardBox(String title, Widget content) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)), const Divider(height: 30), Expanded(child: content)]));
  }
}

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});
  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  final nameCtrl = TextEditingController(); 
  final priceCtrl = TextEditingController(); 
  List<Map<String, dynamic>> prods = [];

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() { prods = data; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView.builder(padding: const EdgeInsets.all(10), itemCount: prods.length, itemBuilder: (ctx, i) => Card(child: ListTile(title: Text(prods[i]['name'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${prods[i]['price']} ฿"), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await DatabaseHelper.instance.deleteProduct(prods[i]['id']); _refresh(); })))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAdd, label: const Text("เพิ่มเมนู"), icon: const Icon(Icons.add)),
    );
  }

  void _showAdd() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("เพิ่มเมนูใหม่"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "ชื่อเมนู")),
        TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "ราคา"), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
        ElevatedButton(onPressed: () async {
          if(nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {

            await DatabaseHelper.instance.addProduct(nameCtrl.text, double.parse(priceCtrl.text));
            nameCtrl.clear(); priceCtrl.clear();
            Navigator.pop(context); _refresh();
          }
        }, child: const Text("บันทึก"))
      ],
    ));
  }
}