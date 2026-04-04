import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_fix_final.db'); // ชื่อใหม่เพื่อล้างบั๊ก
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE products (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, price REAL)');
    await db.execute('CREATE TABLE sales (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, total REAL, tableName TEXT)');
    await db.execute('CREATE TABLE sale_items (id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER, name TEXT, price REAL, qty INTEGER)');
  }

  // สินค้า
  Future<int> addProduct(String name, double price) async => (await database).insert('products', {'name': name, 'price': price});
  Future<List<Map<String, dynamic>>> getAllProducts() async => (await database).query('products');
  Future<int> deleteProduct(int id) async => (await database).delete('products', where: 'id = ?', whereArgs: [id]);

  // ยอดขาย
  Future<void> saveSale(String tableName, double total, List<Map<String, dynamic>> items) async {
    final db = await database;
    String date = DateTime.now().toString().split(' ')[0];
    int id = await db.insert('sales', {'date': date, 'total': total, 'tableName': tableName});
    for (var item in items) {
      await db.insert('sale_items', {'sale_id': id, 'name': item['name'], 'price': item['price'], 'qty': item['qty']});
    }
  }

  Future<List<Map<String, dynamic>>> getSalesByDate(String date) async => (await database).query('sales', where: 'date = ?', whereArgs: [date]);
  Future<List<Map<String, dynamic>>> getTopItems(String date) async => (await database).rawQuery(
    'SELECT name, SUM(qty) as total_qty FROM sale_items WHERE sale_id IN (SELECT id FROM sales WHERE date = ?) GROUP BY name ORDER BY total_qty DESC LIMIT 5', [date]
  );
}