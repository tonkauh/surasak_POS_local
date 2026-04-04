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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      drawer: Drawer(
        child: Column(children: [
          const UserAccountsDrawerHeader(decoration: BoxDecoration(color: Colors.indigo), accountName: Text("KITTIPHON POS"), accountEmail: Text("ระบบจัดการร้านค้า")),
          ListTile(leading: const Icon(Icons.shopping_cart), title: const Text("หน้าขาย"), onTap: () { setState(() => _selectedIndex = 0); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.bar_chart), title: const Text("Dashboard"), onTap: () { setState(() => _selectedIndex = 1); Navigator.pop(context); }),
          ListTile(leading: const Icon(Icons.settings), title: const Text("จัดการเมนู"), onTap: () { setState(() => _selectedIndex = 2); Navigator.pop(context); }),
        ]),
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
    );
  }
}

// --- หน้าขาย POS ---
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
  void initState() { super.initState(); _load(); }

  // แก้ไขฟังก์ชันโหลดข้อมูลให้ถูกต้อง
  void _load() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() { products = data; });
  }

  double get total => cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));

  void _showPreview() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Center(child: Text("ใบเสร็จ")),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("เป๋าตุง บ่อนไก่...", style: TextStyle(fontWeight: FontWeight.bold)),
          const Text("โทร: 095-532-5638"),
          const Divider(),
          ...cart.map((e) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text("${e['name']} x${e['qty']}")), Text("${(e['price']*e['qty']).toInt()} ฿")])).toList(),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("รวมเงิน"), Text("${total.toInt()} ฿", style: const TextStyle(fontWeight: FontWeight.bold))]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("แก้ไข")),
        ElevatedButton(onPressed: () async {
          await DatabaseHelper.instance.saveSale(selectedTable, total, cart);
          setState(() => cart = []); Navigator.pop(ctx);
          _load(); // รีโหลดเผื่อมีการเปลี่ยนแปลง
        }, child: const Text("ยืนยัน")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(children: [
        // ซ้าย: โต๊ะ
        Container(width: 120, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)), child: Column(children: [
          Expanded(child: GridView.builder(padding: const EdgeInsets.all(5), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 5, crossAxisSpacing: 5), itemCount: 12, itemBuilder: (ctx, i) => InkWell(onTap: () => setState(() => selectedTable = "${i+1}"), child: Container(decoration: BoxDecoration(color: selectedTable == "${i+1}" ? Colors.indigo : Colors.white, borderRadius: BorderRadius.circular(8)), child: Center(child: Text("${i+1}", style: TextStyle(color: selectedTable == "${i+1}" ? Colors.white : Colors.black))))))),
          Padding(padding: const EdgeInsets.all(8), child: ChoiceChip(label: const Text("กลับบ้าน"), selected: selectedTable == "กลับบ้าน", onSelected: (v) => setState(() => selectedTable = "กลับบ้าน"))),
        ])),
        const SizedBox(width: 10),
        // กลาง: เมนู
        Expanded(flex: 3, child: products.isEmpty ? const Center(child: Text("ไปเพิ่มเมนูที่หน้าจัดการก่อนครับ")) : GridView.builder(gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1), itemCount: products.length, itemBuilder: (ctx, i) => Card(child: InkWell(onTap: () => setState(() {
          int idx = cart.indexWhere((it) => it['id'] == products[i]['id']);
          if(idx != -1) cart[idx]['qty']++; else cart.add({...products[i], 'qty': 1});
        }), child: Center(child: Text(products[i]['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))))))),
        const SizedBox(width: 10),
        // ขวา: ตะกร้า
        Container(width: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]), child: Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.vertical(top: Radius.circular(15))), child: Text(selectedTable == "กลับบ้าน" ? "สั่งกลับบ้าน" : "โต๊ะ $selectedTable", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(child: ListView.builder(itemCount: cart.length, itemBuilder: (ctx, i) => ListTile(title: Text(cart[i]['name'], maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Row(children: [IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => setState(() => cart[i]['qty'] > 1 ? cart[i]['qty']-- : cart.removeAt(i))), Text("${cart[i]['qty']}"), IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), onPressed: () => setState(() => cart[i]['qty']++))]), trailing: Text("${(cart[i]['price']*cart[i]['qty']).toInt()}")))),
          Padding(padding: const EdgeInsets.all(15), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("รวม:"), Text("${total.toInt()} ฿", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo))]), const SizedBox(height: 10), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: cart.isEmpty ? null : _showPreview, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: const Text("ยืนยันออเดอร์")))]))
        ])),
      ]),
    );
  }
}

// --- หน้า Dashboard (สถิติ) ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime date = DateTime.now(); double total = 0; List<Map<String, dynamic>> sales = []; List<Map<String, dynamic>> tops = [];
  @override
  void initState() { super.initState(); _load(); }
  void _load() async {
    String d = date.toString().split(' ')[0];
    var s = await DatabaseHelper.instance.getSalesByDate(d);
    var t = await DatabaseHelper.instance.getTopItems(d);
    double sum = 0; for(var x in s) sum += x['total'];
    setState(() { sales = s; tops = t; total = sum; });
  }
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("สถิติวันที่: ${DateFormat('dd/MM/yyyy').format(date)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), ElevatedButton(onPressed: () async { DateTime? p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2025), lastDate: DateTime.now()); if(p != null) { setState(() => date = p); _load(); } }, child: const Text("เปลี่ยนวัน"))]),
      const SizedBox(height: 15),
      Row(children: [_card("ยอดรวม", "${total.toInt()} ฿", Colors.green), _card("จำนวนบิล", "${sales.length}", Colors.orange)]),
      const SizedBox(height: 15),
      Expanded(child: Row(children: [
        Expanded(child: _box("สินค้าขายดี", ListView.builder(itemCount: tops.length, itemBuilder: (ctx, i) => ListTile(title: Text(tops[i]['name']), trailing: Text("${tops[i]['total_qty']}"))))),
        const SizedBox(width: 15),
        Expanded(child: _box("รายการบิล", ListView.builder(itemCount: sales.length, itemBuilder: (ctx, i) => ListTile(title: Text("บิล #${sales[i]['id']}"), trailing: Text("${sales[i]['total'].toInt()}"))))),
      ])),
    ]));
  }
  Widget _card(String t, String v, Color c) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [Text(t), Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c))]))));
  Widget _box(String t, Widget c) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), const Divider(), Expanded(child: c)]));
}

// --- หน้าจัดการเมนู (แก้ไขจุดบันทึกแล้วไม่โชว์) ---
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

  // แก้ไขฟังก์ชัน Refresh ให้ถูกต้อง
  void _refresh() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      prods = data;
    });
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
            // 1. บันทึกลงฐานข้อมูล
            await DatabaseHelper.instance.addProduct(nameCtrl.text, double.parse(priceCtrl.text));
            nameCtrl.clear(); priceCtrl.clear();
            // 2. ปิด Dialog
            Navigator.pop(context);
            // 3. รีเฟรชหน้าจอทันที
            _refresh();
          }
        }, child: const Text("บันทึก"))
      ],
    ));
  }
}