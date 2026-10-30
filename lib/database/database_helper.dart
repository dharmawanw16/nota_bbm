import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Membuat instance tunggal (singleton) agar koneksi database efisien
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('minipom.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Buka database, jika belum ada maka buat baru (onCreate)
    return await openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE pengaturan ADD COLUMN id_spbu TEXT');
          await db.update('pengaturan', {'id_spbu': '3414210'});
        }
        if (oldVersion < 3) {
          await _createSpbuTable(db);
          final lama = await db.query('pengaturan', where: 'id = 1');
          if (lama.isNotEmpty) {
            await db.insert('spbu', {
              'id_spbu': lama.first['id_spbu'] ?? '',
              'nama_spbu': lama.first['nama_spbu'] ?? '',
              'alamat_spbu': lama.first['alamat_spbu'] ?? '',
            });
          }
        }
        if (oldVersion < 4) {
          await _createFooterTable(db);
        }
        if (oldVersion < 5) {
          await _isiFooterSubsidi(db);
        }
        if (oldVersion < 6) {
          await _ensurePertaminaDex(db);
        }
        if (oldVersion < 7) {
          await _ensurePertamaxGreen(db);
        }
        if (oldVersion < 8) {
          await db.delete('spbu', where: 'id_spbu = ?', whereArgs: ['3414210']);
          if ((await db.query('spbu', limit: 1)).isEmpty) {
            await db.insert('spbu', _spbuDefault);
          }
          await db.update('pengaturan', {
            'id_spbu': _spbuDefault['id_spbu'],
            'nama_spbu': _spbuDefault['nama_spbu'],
            'alamat_spbu': _spbuDefault['alamat_spbu'],
          });
        }
        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS transaksi (
              id_transaksi TEXT PRIMARY KEY,
              nama_bbm TEXT NOT NULL,
              jumlah_liter REAL NOT NULL,
              total_bayar INTEGER NOT NULL,
              plat_nomor TEXT,
              waktu_transaksi TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  static const Map<String, Object?> _spbuDefault = {
    'id_spbu': '348888',
    'nama_spbu': 'SPBU MASA DEPAN',
    'alamat_spbu': 'JL. KEBAHAGIAAN NO. 1',
  };

  Future<void> _ensurePertamaxGreen(Database db) async {
    final bbm = await db.query(
      'bbm',
      where: 'nama_bbm = ? COLLATE NOCASE',
      whereArgs: ['Pertamax Green'],
    );
    if (bbm.isEmpty) {
      await db.insert('bbm', {
        'nama_bbm': 'Pertamax Green',
        'harga_per_liter': 19150,
        'warna_hex': '0xFFC905AD',
      });
    }

    final footer = await db.query(
      'footer_bbm',
      where: 'nama_bbm = ? COLLATE NOCASE',
      whereArgs: ['Pertamax Green'],
    );
    if (footer.isEmpty) {
      final pengaturan = await db.query('pengaturan', where: 'id = 1');
      await db.insert('footer_bbm', {
        'nama_bbm': 'Pertamax Green',
        'teks_footer': pengaturan.isEmpty
            ? ''
            : (pengaturan.first['teks_footer'] ?? '').toString(),
      });
    }
  }

  static const footerSubsidi =
      'Anda mendapat subsidi dari\n'
      'Pemerintah sebesar Rp {subsidi}\n'
      '(Perhitungan Subsidi Unaudited\n'
      'atau Estimasi). Gunakan BBM\n'
      'Subsidi secara bijak.';

  // Footer Pertalite berisi paragraf subsidi; {subsidi} = total subsidi
  Future<void> _isiFooterSubsidi(Database db) async {
    await db.update(
      'footer_bbm',
      {'teks_footer': footerSubsidi},
      where: 'nama_bbm = ? COLLATE NOCASE',
      whereArgs: ['Pertalite'],
    );
  }

  // Footer per jenis BBM; diisi awal dengan footer umum yang lama
  Future<void> _createFooterTable(Database db) async {
    await db.execute('''
      CREATE TABLE footer_bbm (
        nama_bbm TEXT PRIMARY KEY,
        teks_footer TEXT
      )
    ''');
    final lama = await db.query('pengaturan', where: 'id = 1');
    final teks = lama.isEmpty ? '' : (lama.first['teks_footer'] ?? '');
    for (final b in await db.query('bbm')) {
      await db.insert('footer_bbm', {
        'nama_bbm': b['nama_bbm'],
        'teks_footer': teks,
      });
    }
  }

  Future<void> _createSpbuTable(Database db) async {
    await db.execute('''
      CREATE TABLE spbu (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_spbu TEXT NOT NULL,
        nama_spbu TEXT NOT NULL,
        alamat_spbu TEXT
      )
    ''');
  }

  Future<void> _ensurePertaminaDex(Database db) async {
    final bbm = await db.query(
      'bbm',
      where: 'nama_bbm = ? COLLATE NOCASE',
      whereArgs: ['Pertamina Dex'],
    );
    if (bbm.isEmpty) {
      await db.insert('bbm', {
        'nama_bbm': 'Pertamina Dex',
        'harga_per_liter': 16000,
        'warna_hex': '0xFF16A085',
      });
    }

    final footer = await db.query(
      'footer_bbm',
      where: 'nama_bbm = ? COLLATE NOCASE',
      whereArgs: ['Pertamina Dex'],
    );
    if (footer.isEmpty) {
      final pengaturan = await db.query('pengaturan', where: 'id = 1');
      await db.insert('footer_bbm', {
        'nama_bbm': 'Pertamina Dex',
        'teks_footer': pengaturan.isEmpty
            ? ''
            : (pengaturan.first['teks_footer'] ?? '').toString(),
      });
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. Membuat Tabel BBM
    await db.execute('''
      CREATE TABLE bbm (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_bbm TEXT NOT NULL,
        harga_per_liter INTEGER NOT NULL,
        warna_hex TEXT NOT NULL
      )
    ''');

    // Mengisi data awal (default) BBM beserta harganya saat aplikasi pertama kali diinstal
    await db.insert('bbm', {
      'nama_bbm': 'Pertalite',
      'harga_per_liter': 10000,
      'warna_hex': '0xFF1ABC9C',
    });
    await db.insert('bbm', {
      'nama_bbm': 'Pertamax',
      'harga_per_liter': 15950,
      'warna_hex': '0xFF3498DB',
    });
    await db.insert('bbm', {
      'nama_bbm': 'Pertamax Turbo',
      'harga_per_liter': 19600,
      'warna_hex': '0xFFE74C3C',
    });
    await db.insert('bbm', {
      'nama_bbm': 'Bio Solar',
      'harga_per_liter': 6800,
      'warna_hex': '0xFFF39C12',
    });
    await db.insert('bbm', {
      'nama_bbm': 'Dexlite',
      'harga_per_liter': 23700,
      'warna_hex': '0xFF2980B9',
    });
    await db.insert('bbm', {
      'nama_bbm': 'Pertamina Dex',
      'harga_per_liter': 25200,
      'warna_hex': '0xFF16A085',
    });
    await db.insert('bbm', {
      'nama_bbm': 'Pertamax Green',
      'harga_per_liter': 19150,
      'warna_hex': '0xFFC905AD',
    });

    // 2. Membuat Tabel Transaksi untuk menyimpan struk/nota
    await db.execute('''
      CREATE TABLE transaksi (
        id_transaksi TEXT PRIMARY KEY,
        nama_bbm TEXT NOT NULL,
        jumlah_liter REAL NOT NULL,
        total_bayar INTEGER NOT NULL,
        plat_nomor TEXT,
        waktu_transaksi TEXT NOT NULL
      )
    ''');

    // 3. Membuat Tabel Operator (Kasir)
    await db.execute('''
      CREATE TABLE operator (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_operator TEXT NOT NULL
      )
    ''');

    // 4. Membuat Tabel Pengaturan SPBU (Hanya boleh ada 1 baris data)
    await db.execute('''
      CREATE TABLE pengaturan (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        id_spbu TEXT,
        nama_spbu TEXT,
        alamat_spbu TEXT,
        teks_footer TEXT
      )
    ''');

    // Insert data pengaturan default
    await db.insert('pengaturan', {
      'id': 1,
      ..._spbuDefault,
      'teks_footer': 'Terima kasih telah mengisi BBM',
    });

    await _createSpbuTable(db);
    await db.insert('spbu', _spbuDefault);
    await _createFooterTable(db);
    await _isiFooterSubsidi(db);
  }

  // ==========================================
  // FUNGSI UNTUK MENGAMBIL DATA (READ)
  // ==========================================

  // Fungsi untuk mengambil semua daftar BBM dari tabel database
  Future<List<Map<String, dynamic>>> getSemuaBBM() async {
    final db = await instance.database;
    return await db.query('bbm');
  }

  Future<void> updateHargaBBM(int id, int harga) async {
    final db = await instance.database;
    await db.update(
      'bbm',
      {'harga_per_liter': harga},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getOperator() async {
    final db = await instance.database;
    return await db.query('operator', orderBy: 'nama_operator');
  }

  Future<void> tambahOperator(String nama) async {
    final db = await instance.database;
    await db.insert('operator', {'nama_operator': nama});
  }

  Future<void> ubahOperator(int id, String nama) async {
    final db = await instance.database;
    await db.update(
      'operator',
      {'nama_operator': nama},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hapusOperator(int id) async {
    final db = await instance.database;
    await db.delete('operator', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getSpbu() async {
    final db = await instance.database;
    return await db.query('spbu', orderBy: 'nama_spbu');
  }

  Future<void> tambahSpbu(Map<String, Object?> values) async {
    final db = await instance.database;
    await db.insert('spbu', values);
  }

  Future<void> ubahSpbu(int id, Map<String, Object?> values) async {
    final db = await instance.database;
    await db.update('spbu', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> hapusSpbu(int id) async {
    final db = await instance.database;
    await db.delete('spbu', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getFooterBbm(String namaBbm) async {
    final db = await instance.database;
    final rows = await db.query(
      'footer_bbm',
      where: 'nama_bbm = ? COLLATE NOCASE',
      whereArgs: [namaBbm],
    );
    return rows.isEmpty ? '' : (rows.first['teks_footer'] ?? '').toString();
  }

  Future<void> simpanFooterBbm(String namaBbm, String teks) async {
    final db = await instance.database;
    await db.insert('footer_bbm', {
      'nama_bbm': namaBbm,
      'teks_footer': teks,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>> getPengaturan() async {
    final db = await instance.database;
    final rows = await db.query('pengaturan', where: 'id = 1');
    return rows.isNotEmpty ? rows.first : {};
  }

  Future<void> simpanPengaturan(Map<String, Object?> values) async {
    final db = await instance.database;
    await db.update('pengaturan', values, where: 'id = 1');
  }

  // ==========================================
  // RIWAYAT TRANSAKSI
  // ==========================================
  Future<void> tambahTransaksi({
    required String idTransaksi,
    required String namaBbm,
    required double jumlahLiter,
    required int totalBayar,
    String? platNomor,
    required String waktuTransaksi,
  }) async {
    final db = await instance.database;
    await db.insert(
      'transaksi',
      {
        'id_transaksi': idTransaksi,
        'nama_bbm': namaBbm,
        'jumlah_liter': jumlahLiter,
        'total_bayar': totalBayar,
        'plat_nomor': platNomor,
        'waktu_transaksi': waktuTransaksi,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRiwayatTransaksi() async {
    final db = await instance.database;
    return await db.query('transaksi', orderBy: 'rowid DESC');
  }

  Future<void> hapusTransaksi(String idTransaksi) async {
    final db = await instance.database;
    await db.delete('transaksi', where: 'id_transaksi = ?', whereArgs: [idTransaksi]);
  }

  Future<void> hapusSemuaTransaksi() async {
    final db = await instance.database;
    await db.delete('transaksi');
  }

  // ==========================================
  // BACKUP & RESTORE LOKAL
  // ==========================================
  Future<Map<String, dynamic>> exportData() async {
    final db = await instance.database;
    final operator = await db.query('operator');
    final spbu = await db.query('spbu');
    final footerBbm = await db.query('footer_bbm');
    final pengaturan = await db.query('pengaturan');
    final bbm = await db.query('bbm');
    final transaksi = await db.query('transaksi');

    return {
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'operator': operator,
      'spbu': spbu,
      'footer_bbm': footerBbm,
      'pengaturan': pengaturan,
      'bbm': bbm,
      'transaksi': transaksi,
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('operator');
      await txn.delete('spbu');
      await txn.delete('footer_bbm');
      await txn.delete('pengaturan');
      await txn.delete('bbm');
      await txn.delete('transaksi');

      if (data['operator'] is List) {
        for (final item in data['operator']) {
          await txn.insert('operator', Map<String, Object?>.from(item));
        }
      }

      if (data['spbu'] is List) {
        for (final item in data['spbu']) {
          await txn.insert('spbu', Map<String, Object?>.from(item));
        }
      }

      if (data['footer_bbm'] is List) {
        for (final item in data['footer_bbm']) {
          await txn.insert('footer_bbm', Map<String, Object?>.from(item));
        }
      }

      if (data['pengaturan'] is List) {
        for (final item in data['pengaturan']) {
          await txn.insert('pengaturan', Map<String, Object?>.from(item));
        }
      }

      if (data['bbm'] is List) {
        for (final item in data['bbm']) {
          await txn.insert('bbm', Map<String, Object?>.from(item));
        }
      }

      if (data['transaksi'] is List) {
        for (final item in data['transaksi']) {
          await txn.insert('transaksi', Map<String, Object?>.from(item));
        }
      }
    });
  }
}
