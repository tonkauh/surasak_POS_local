import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_database_v7.db'); // ปรับเป็น v7 เพื่อสร้างตารางใหม่
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, price REAL, sort_order INTEGER DEFAULT 0, color INTEGER)');
    await db.execute('CREATE TABLE sales (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, total REAL, tableName TEXT)');
    await db.execute('CREATE TABLE sale_items (id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER, name TEXT, price REAL, qty INTEGER)');
    
    // ตารางสำหรับพักบิล (Pending Orders)
    await db.execute('''
      CREATE TABLE pending_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tableName TEXT,
        productId INTEGER,
        name TEXT,
        price REAL,
        qty INTEGER
      )
    ''');
  }

  // ระบบอัปเกรดฐานข้อมูลให้รองรับการจัดเรียง (ข้อมูลเก่าไม่หาย)
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN sort_order INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE products ADD COLUMN color INTEGER');
    }
  }

  // --- ระบบจัดการสินค้า ---
  Future<int> addProduct(String name, double price, int color) async => (await database).insert('products', {'name': name, 'price': price, 'color': color});
  // ดึงข้อมูลโดยเรียงตาม sort_order ก่อน
  Future<List<Map<String, dynamic>>> getAllProducts() async => (await database).query('products', orderBy: 'sort_order ASC, id ASC');
  Future<int> deleteProduct(int id) async => (await database).delete('products', where: 'id = ?', whereArgs: [id]);
  Future<int> updateProduct(int id, String name, double price, int color) async => (await database).update('products', {'name': name, 'price': price, 'color': color}, where: 'id = ?', whereArgs: [id]);

  // --- ระบบจัดเรียงลำดับสินค้า ---
  Future<void> updateProductOrder(List<Map<String, dynamic>> orderedProducts) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedProducts.length; i++) {
        await txn.update('products', {'sort_order': i}, where: 'id = ?', whereArgs: [orderedProducts[i]['id']]);
      }
    });
  }

  // --- ระบบจัดการยอดขาย ---
  Future<void> saveSale(String tableName, double total, List<Map<String, dynamic>> items) async {
    final db = await database;
    String nowDate = DateTime.now().toString().split(' ')[0];
    await db.transaction((txn) async {
      int saleId = await txn.insert('sales', {'date': nowDate, 'total': total, 'tableName': tableName});
      for (var item in items) {
        await txn.insert('sale_items', {'sale_id': saleId, 'name': item['name'], 'price': item['price'], 'qty': item['qty']});
      }
      // เมื่อขายเสร็จ ให้ลบข้อมูลที่พักไว้ของโต๊ะนี้ออก
      await txn.delete('pending_orders', where: 'tableName = ?', whereArgs: [tableName]);
    });
  }

  // --- ระบบพักบิล (Pending Orders) ---
  Future<void> savePendingOrder(String tableName, List<Map<String, dynamic>> cart) async {
    final db = await database;
    await db.delete('pending_orders', where: 'tableName = ?', whereArgs: [tableName]);
    for (var item in cart) {
      await db.insert('pending_orders', {
        'tableName': tableName,
        'productId': item['id'],
        'name': item['name'],
        'price': item['price'],
        'qty': item['qty']
      });
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOrder(String tableName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('pending_orders', where: 'tableName = ?', whereArgs: [tableName]);
    return maps.map((item) => {
      'id': item['productId'],
      'name': item['name'],
      'price': item['price'],
      'qty': item['qty']
    }).toList();
  }

  // --- ระบบ Dashboard ---
  Future<List<Map<String, dynamic>>> getSalesByDate(String date) async => (await database).query('sales', where: 'date = ?', whereArgs: [date], orderBy: 'id DESC');
  Future<List<Map<String, dynamic>>> getTopItems(String date) async => (await database).rawQuery('SELECT name, SUM(qty) as total_qty FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE date = ?) GROUP BY name ORDER BY total_qty DESC LIMIT 5', [date]);
  Future<void> deleteSale(int id) async {
    final db = await database;
    await db.delete('sale_items', where: 'sale_id = ?', whereArgs: [id]);
    await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }
  Future<void> updateSale(int id, String tableName, double total) async => (await database).update('sales', {'tableName': tableName, 'total': total}, where: 'id = ?', whereArgs: [id]);
}