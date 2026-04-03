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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
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
  
  // เปลี่ยนจาก NavigationRail เป็นการคุมหน้าผ่านตัวแปรธรรมดา
  final List<Widget> _pages = [const POSScreen(), const ManageMenuScreen()];
  final List<String> _titles = ['หน้าขาย (POS)', 'ตั้งค่าเมนูอาหาร'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- ใช้ AppBar พร้อมปุ่มเมนูเพื่อเปิด Drawer ---
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(), // เปิดเมนูข้าง
          ),
        ),
      ),
      
      // --- ส่วนของเมนูที่จะซ่อนไว้ (Drawer) ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, color: Colors.white, size: 50),
                  SizedBox(height: 10),
                  Text("KITTIPHON POS", style: TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('หน้าขาย'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context); // ปิด Drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('จัดการเมนู'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context); // ปิด Drawer
              },
            ),
          ],
        ),
      ),
      
      body: _pages[_selectedIndex],
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
  }

  void _loadProducts() async {
    final data = await DatabaseHelper.instance.getAllProducts();
    setState(() => products = data);
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      int index = cart.indexWhere((item) => item['id'] == product['id']);
      if (index != -1) {
        cart[index]['qty']++;
      } else {
        cart.add({...product, 'qty': 1});
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (cart[index]['qty'] > 1) {
        cart[index]['qty']--;
      } else {
        cart.removeAt(index);
      }
    });
  }

  double get totalPrice => cart.fold(0, (sum, item) => sum + (item['price'] * item['qty']));

  void _showReceiptPreview() {
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text("ตรวจสอบออเดอร์")),
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("KITTIPHON POS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("วันที่: $formattedDate"),
                Text("ตำแหน่ง: ${selectedTable == "กลับบ้าน" ? "สั่งกลับบ้าน" : "โต๊ะ $selectedTable"}"),
                const Divider(),
                ...cart.map((item) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text("${item['name']} x${item['qty']}")),
                    Text("${(item['price'] * item['qty']).toInt()}"),
                  ],
                )).toList(),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("รวมเงิน", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("${totalPrice.toInt()} ฿", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("แก้ไข")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => cart = []);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกสำเร็จ!")));
            },
            child: const Text("ยืนยัน / ปิดบิล"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. เลือกโต๊ะ (ซ้าย) - กว้างเท่าเดิม
        Container(
          width: 130,
          color: Colors.grey[50],
          child: Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  itemCount: 12,
                  itemBuilder: (context, i) {
                    String tableNum = "${i + 1}";
                    bool isSelected = selectedTable == tableNum;
                    return InkWell(
                      onTap: () => setState(() => selectedTable = tableNum),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                        ),
                        child: Center(
                          child: Text(tableNum, style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ChoiceChip(
                  label: const Text("กลับบ้าน"),
                  selected: selectedTable == "กลับบ้าน",
                  onSelected: (val) => setState(() => selectedTable = "กลับบ้าน"),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // 2. เมนูกลาง (ขยายเต็มพื้นที่ที่เหลือ)
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: products.isEmpty 
                  ? const Center(child: Text("ยังไม่มีเมนู"))
                  : GridView.builder(
                      padding: const EdgeInsets.all(15),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2),
                      itemCount: products.length,
                      itemBuilder: (context, i) => Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _addToCart(products[i]),
                          child: Center(child: Text(products[i]['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),

        // 3. พรีวิวขวา (กว้างคงที่)
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey[200]!)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                color: Colors.indigo[600],
                child: Text(
                  selectedTable == "กลับบ้าน" ? "สั่งกลับบ้าน" : "โต๊ะ $selectedTable",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: cart.isEmpty 
                  ? const Center(child: Text("ตะกร้าว่างเปล่า"))
                  : ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: cart.length,
                      separatorBuilder: (context, i) => const Divider(height: 1),
                      itemBuilder: (context, i) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(cart[i]['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Row(
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle, size: 22, color: Colors.red), onPressed: () => _removeFromCart(i)),
                            Text("${cart[i]['qty']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.add_circle, size: 22, color: Colors.green), onPressed: () => _addToCart(cart[i])),
                          ],
                        ),
                        trailing: Text("${(cart[i]['price'] * cart[i]['qty']).toInt()} ฿"),
                      ),
                    ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey[50],
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("รวม:", style: TextStyle(fontSize: 18)),
                        Text("${totalPrice.toInt()} ฿", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: cart.isEmpty ? null : _showReceiptPreview,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text("ยืนยันออเดอร์", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}

// --- หน้าจัดการเมนู (คงเดิม) ---
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
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: products.length,
        itemBuilder: (context, i) => Card(
          child: ListTile(
            title: Text(products[i]['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${products[i]['price']} บาท"),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
              await DatabaseHelper.instance.deleteProduct(products[i]['id']);
              _refresh();
            }),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
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
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อเมนู', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'ราคา', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
          ElevatedButton(onPressed: () async {
            if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
              await DatabaseHelper.instance.addProduct(nameCtrl.text, double.parse(priceCtrl.text));
              nameCtrl.clear(); priceCtrl.clear();
              _refresh(); Navigator.pop(context);
            }
          }, child: const Text('บันทึก'))
        ],
      ),
    );
  }
}