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
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
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
  final List<Widget> _pages = [const POSScreen(), const ManageMenuScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shopping_basket), label: 'หน้าขาย'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'จัดการเมนู'),
        ],
      ),
    );
  }
}

// --- หน้าขาย (POS Screen) ---
class POSScreen extends StatefulWidget {
  const POSScreen({super.key});
  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  String selectedTable = "โต๊ะ 1";
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];

  void _loadProducts() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() => products = data);
  }

  @override
  void initState() { super.initState(); _loadProducts(); }

  double get totalPrice => cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));

  // ฟังก์ชันแสดงใบเสร็จจำลอง (Virtual Receipt)
  void _showVirtualReceipt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Center(child: Text("ใบเสร็จรับเงิน")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("รายการสำหรับ: $selectedTable"),
            const Divider(),
            ...cart.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${item['name']} x${item['qty']}"),
                  Text("${(item['price'] * item['qty']).toStringAsFixed(2)} บ."),
                ],
              ),
            )).toList(),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("ยอดรวมทั้งสิ้น", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${totalPrice.toStringAsFixed(2)} บาท", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
              ],
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() => cart = []); // เคลียร์ตะกร้า
                Navigator.pop(context);
              },
              child: const Text("ตกลง / รับออเดอร์ใหม่"),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เครื่องคิดเงิน POS')),
      body: Column(
        children: [
          // ส่วนเลือกโต๊ะ
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: ["โต๊ะ 1", "โต๊ะ 2", "โต๊ะ 3", "กลับบ้าน"].map((t) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(t), selected: selectedTable == t, onSelected: (s) => setState(() => selectedTable = t)),
              )).toList()),
            ),
          ),
          // แสดงเมนูสินค้า
          Expanded(
            child: products.isEmpty 
              ? const Center(child: Text('ยังไม่มีสินค้า กรุณาเพิ่มที่หน้า "จัดการเมนู"'))
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1),
                  itemCount: products.length,
                  itemBuilder: (context, i) => Card(
                    elevation: 2,
                    child: InkWell(
                      onTap: () => setState(() => cart.add({...products[i], 'qty': 1})),
                      child: Center(child: Text(products[i]['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500))),
                    ),
                  ),
                ),
          ),
          // แถบสรุปยอดด้านล่าง
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("รายการในตะกร้า: ${cart.length}"),
                  Text("${totalPrice.toStringAsFixed(2)} บาท", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: cart.isEmpty ? null : _showVirtualReceipt,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: const Text('ออกใบเสร็จ (จำลอง)', style: TextStyle(fontSize: 16)),
                ),
              )
            ]),
          )
        ],
      ),
    );
  }
}

// --- หน้าจัดการเมนู (Manage Menu Screen) ---
class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});
  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  List<Map<String, dynamic>> products = [];
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  void _refresh() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() => products = data);
  }

  @override
  void initState() { super.initState(); _refresh(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คลังสินค้า')),
      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.fastfood, color: Colors.orange),
          title: Text(products[i]['name']),
          subtitle: Text('${products[i]['price']} บาท'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              await DatabaseHelper.instance.deleteProduct(products[i]['id']);
              _refresh();
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มเมนูใหม่'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อเมนู')),
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'ราคา'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                await DatabaseHelper.instance.addProduct(nameCtrl.text, double.parse(priceCtrl.text));
                nameCtrl.clear(); priceCtrl.clear();
                _refresh(); 
                Navigator.pop(context);
              }
            }, 
            child: const Text('บันทึก')
          )
        ],
      ),
    );
  }
}