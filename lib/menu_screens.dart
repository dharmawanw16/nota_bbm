import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'database/database_helper.dart';
import 'preview_struk.dart';

const _biru = Color(0xFF23B2EE);

AppBar _appBar(String title) => AppBar(
  backgroundColor: _biru,
  title: Text(title, style: const TextStyle(color: Colors.black)),
  iconTheme: const IconThemeData(color: Colors.black),
);

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// ---------------- Harga BBM ----------------
class HargaBbmScreen extends StatefulWidget {
  const HargaBbmScreen({super.key});

  @override
  State<HargaBbmScreen> createState() => _HargaBbmScreenState();
}

class _HargaBbmScreenState extends State<HargaBbmScreen> {
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final d = await DatabaseHelper.instance.getSemuaBBM();
    if (mounted) setState(() => _data = d);
  }

  Future<void> _ubah(Map<String, dynamic> bbm) async {
    final c = TextEditingController(text: '${bbm['harga_per_liter']}');
    final hasil = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Harga ${bbm['nama_bbm']}'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            suffixText: '/L',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(c.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (hasil == null) return;
    await DatabaseHelper.instance.updateHargaBBM(bbm['id'] as int, hasil);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Harga BBM'),
      body: ListView.separated(
        itemCount: _data.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final b = _data[i];
          return ListTile(
            leading: Icon(
              Icons.local_gas_station,
              color: Color(int.parse(b['warna_hex'])),
            ),
            title: Text(b['nama_bbm']),
            subtitle: Text('Rp ${b['harga_per_liter']}/L'),
            trailing: const Icon(Icons.edit),
            onTap: () => _ubah(b),
          );
        },
      ),
    );
  }
}

// ---------------- Nama Operator ----------------
class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final d = await DatabaseHelper.instance.getOperator();
    if (mounted) setState(() => _data = d);
  }

  Future<void> _form([Map<String, dynamic>? op]) async {
    final c = TextEditingController(text: op?['nama_operator'] ?? '');
    final nama = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(op == null ? 'Tambah Operator' : 'Ubah Operator'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama operator'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final v = c.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (nama == null) return;
    if (op == null) {
      await DatabaseHelper.instance.tambahOperator(nama);
    } else {
      await DatabaseHelper.instance.ubahOperator(op['id'] as int, nama);
    }
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Nama Operator'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _biru,
        onPressed: _form,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _data.isEmpty
          ? const Center(child: Text('Belum ada operator'))
          : ListView.separated(
              itemCount: _data.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final o = _data[i];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(o['nama_operator']),
                  onTap: () => _form(o),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await DatabaseHelper.instance.hapusOperator(
                        o['id'] as int,
                      );
                      await _muat();
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ---------------- Data SPBU & Footer Nota ----------------
class _PengaturanForm extends StatefulWidget {
  final String title;
  final List<({String key, String label, int lines})> fields;

  const _PengaturanForm({required this.title, required this.fields});

  @override
  State<_PengaturanForm> createState() => _PengaturanFormState();
}

class _PengaturanFormState extends State<_PengaturanForm> {
  late final Map<String, TextEditingController> _c = {
    for (final f in widget.fields) f.key: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    DatabaseHelper.instance.getPengaturan().then((p) {
      if (!mounted) return;
      for (final f in widget.fields) {
        _c[f.key]!.text = (p[f.key] ?? '').toString();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    await DatabaseHelper.instance.simpanPengaturan({
      for (final f in widget.fields) f.key: _c[f.key]!.text.trim(),
    });
    if (!mounted) return;
    _snack(context, 'Tersimpan');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(widget.title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _c[f.key],
                minLines: 1,
                maxLines: f.lines,
                decoration: InputDecoration(
                  labelText: f.label,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _biru,
              foregroundColor: Colors.black,
            ),
            onPressed: _simpan,
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class DataSpbuScreen extends StatefulWidget {
  const DataSpbuScreen({super.key});

  @override
  State<DataSpbuScreen> createState() => _DataSpbuScreenState();
}

class _DataSpbuScreenState extends State<DataSpbuScreen> {
  static const _borderWidth = 5.0;

  InputDecoration _spbuDecoration(String hint) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: _borderWidth),
    );
    return InputDecoration(
      hintText: hint,
      border: border(Colors.grey),
      enabledBorder: border(Colors.grey),
      focusedBorder: border(_biru),
    );
  }

  List<Map<String, dynamic>> _data = [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final d = await DatabaseHelper.instance.getSpbu();
    if (mounted) setState(() => _data = d);
  }

  Future<void> _form([Map<String, dynamic>? spbu]) async {
    final idC = TextEditingController(text: spbu?['id_spbu'] ?? '');
    final namaC = TextEditingController(text: spbu?['nama_spbu'] ?? '');
    final alamatC = TextEditingController(text: spbu?['alamat_spbu'] ?? '');
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: Text(spbu == null ? 'Tambah SPBU' : 'Ubah SPBU'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idC,
                  autofocus: true,
                  decoration: _spbuDecoration('ID SPBU'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: namaC,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _spbuDecoration('Nama SPBU'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: alamatC,
                  minLines: 1,
                  maxLines: 3,
                  decoration: _spbuDecoration('Alamat SPBU'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              if (idC.text.trim().isEmpty || namaC.text.trim().isEmpty) return;
              Navigator.pop(ctx, {
                'id_spbu': idC.text.trim(),
                'nama_spbu': namaC.text.trim(),
                'alamat_spbu': alamatC.text.trim(),
              });
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (values == null) return;
    if (spbu == null) {
      await DatabaseHelper.instance.tambahSpbu(values);
    } else {
      await DatabaseHelper.instance.ubahSpbu(spbu['id'] as int, values);
    }
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Data SPBU'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _biru,
        onPressed: _form,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: _data.isEmpty
          ? const Center(child: Text('Belum ada data SPBU'))
          : ListView.separated(
              itemCount: _data.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _data[i];
                return ListTile(
                  leading: const Icon(Icons.store),
                  title: Text('${s['nama_spbu']} (${s['id_spbu']})'),
                  subtitle: Text('${s['alamat_spbu'] ?? ''}'),
                  onTap: () => _form(s),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await DatabaseHelper.instance.hapusSpbu(s['id'] as int);
                      await _muat();
                    },
                  ),
                );
              },
            ),
    );
  }
}

class FooterNotaScreen extends StatefulWidget {
  const FooterNotaScreen({super.key});

  @override
  State<FooterNotaScreen> createState() => _FooterNotaScreenState();
}

class _FooterNotaScreenState extends State<FooterNotaScreen> {
  List<Map<String, dynamic>> _bbm = [];
  final Map<String, String> _footer = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final db = DatabaseHelper.instance;
    final bbm = await db.getSemuaBBM();
    final footer = <String, String>{};
    for (final b in bbm) {
      final nama = b['nama_bbm'] as String;
      footer[nama] = await db.getFooterBbm(nama);
    }
    if (!mounted) return;
    setState(() {
      _bbm = bbm;
      _footer
        ..clear()
        ..addAll(footer);
    });
  }

  Future<void> _ubah(String nama) async {
    final c = TextEditingController(text: _footer[nama] ?? '');
    final teks = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        title: Text('Footer $nama'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: c,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Teks footer nota. Tulis {subsidi} untuk total subsidi',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (teks == null) return;
    await DatabaseHelper.instance.simpanFooterBbm(nama, teks);
    await _muat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Footer Nota'),
      body: ListView.separated(
        itemCount: _bbm.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final nama = _bbm[i]['nama_bbm'] as String;
          final teks = _footer[nama] ?? '';
          return ListTile(
            leading: Icon(
              Icons.local_gas_station,
              color: Color(int.parse(_bbm[i]['warna_hex'])),
            ),
            title: Text(nama),
            subtitle: Text(
              teks.isEmpty ? 'Belum ada footer' : teks,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _ubah(nama),
          );
        },
      ),
    );
  }
}

// ---------------- Pengaturan Printer ----------------
class PengaturanPrinterScreen extends StatefulWidget {
  const PengaturanPrinterScreen({super.key});

  @override
  State<PengaturanPrinterScreen> createState() =>
      _PengaturanPrinterScreenState();
}

class _PengaturanPrinterScreenState extends State<PengaturanPrinterScreen> {
  List<BluetoothInfo> _printers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
        _error = 'Izin Bluetooth belum diberikan.';
      } else if (!await PrintBluetoothThermal.bluetoothEnabled) {
        _error = 'Aktifkan Bluetooth pada HP.';
      } else {
        _printers = await PrintBluetoothThermal.pairedBluetooths;
        if (_printers.isEmpty) {
          _error =
              'Belum ada printer yang dipasangkan di pengaturan Bluetooth HP.';
        }
      }
    } catch (e) {
      _error = 'Gagal membaca printer: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _tes(BluetoothInfo p) async {
    final ok = await PrintBluetoothThermal.connect(
      macPrinterAddress: p.macAdress,
    );
    if (!mounted) return;
    _snack(
      context,
      ok ? 'Terhubung ke ${p.name}' : 'Gagal terhubung ke ${p.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Pengaturan Printer'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  for (final p in _printers)
                    ListTile(
                      leading: const Icon(Icons.print),
                      title: Text(p.name),
                      subtitle: Text(p.macAdress),
                      trailing: const Text('Tes koneksi'),
                      onTap: () => _tes(p),
                    ),
                ],
              ),
            ),
    );
  }
}

// ---------------- History Cetak Struk ----------------
class RiwayatStrukScreen extends StatefulWidget {
  const RiwayatStrukScreen({super.key});

  @override
  State<RiwayatStrukScreen> createState() => _RiwayatStrukScreenState();
}

class _RiwayatStrukScreenState extends State<RiwayatStrukScreen> {
  List<Map<String, dynamic>> _riwayat = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getRiwayatTransaksi();
    if (mounted) {
      setState(() {
        _riwayat = data;
        _loading = false;
      });
    }
  }

  Future<void> _lihatStruk(Map<String, dynamic> item) async {
    final pengaturan = await DatabaseHelper.instance.getPengaturan();
    final footer = await DatabaseHelper.instance.getFooterBbm(
      item['nama_bbm'] as String,
    );
    final bbmList = await DatabaseHelper.instance.getSemuaBBM();
    if (!mounted) return;
    final bbm = bbmList.firstWhere(
      (b) =>
          b['nama_bbm'].toString().toLowerCase() ==
          (item['nama_bbm'] as String).toLowerCase(),
      orElse: () => {'harga_per_liter': 10000},
    );
    final hargaPerLiter = (bbm['harga_per_liter'] as num?)?.toInt() ?? 10000;
    final totalBayar = (item['total_bayar'] as num?)?.toInt() ?? 0;
    final estimasiLiter =
        (item['jumlah_liter'] as num?)?.toDouble() ??
        (totalBayar / hargaPerLiter);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewStrukScreen(
          namaBbm: item['nama_bbm'] ?? 'BBM',
          hargaPerLiter: hargaPerLiter,
          totalBayar: totalBayar,
          estimasiLiter: estimasiLiter,
          platNomor: item['plat_nomor'] ?? '',
          namaSpbu: pengaturan['nama_spbu'] ?? 'SPBU MASA DEPAN',
          kodeSpbu: pengaturan['id_spbu'] ?? '348888',
          alamatSpbu: pengaturan['alamat_spbu'] ?? '',
          footerText: footer,
          shift: 1,
          pompa: 1,
          tanggalWaktu: item['waktu_transaksi'] ?? '',
          namaOperator: '-',
          idTransaksi: item['id_transaksi'] ?? '',
          showSubsidi:
              (item['nama_bbm'] as String).toLowerCase() == 'pertalite',
          subsidiPemerintah:
              (item['nama_bbm'] as String).toLowerCase() == 'pertalite'
                  ? (totalBayar * 0.2).round()
                  : null,
          hargaNonSubsidi:
              (item['nama_bbm'] as String).toLowerCase() == 'pertalite'
                  ? hargaPerLiter + 2000
                  : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('History Cetak Struk'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _riwayat.isEmpty
          ? const Center(child: Text('Belum ada history cetak struk'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete_sweep,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Hapus Semua',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Semua History'),
                              content: const Text(
                                'Yakin ingin menghapus seluruh history cetak struk?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Hapus',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await DatabaseHelper.instance
                                .hapusSemuaTransaksi();
                            _muat();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _riwayat.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _riwayat[i];
                      return ListTile(
                        leading: const Icon(
                          Icons.receipt,
                          color: Color(0xFF23B2EE),
                        ),
                        title: Text(
                          '${item['nama_bbm']} - Rp ${item['total_bayar']}',
                        ),
                        subtitle: Text(
                          'ID: ${item['id_transaksi']} | ${item['jumlah_liter']} L\nPlat: ${item['plat_nomor'] ?? '-'}\nWaktu: ${item['waktu_transaksi']}',
                        ),
                        isThreeLine: true,
                        onTap: () => _lihatStruk(item),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await DatabaseHelper.instance.hapusTransaksi(
                              item['id_transaksi'] as String,
                            );
                            _muat();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------- Backup & Pemulihan Data ----------------
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _processing = false;

  Future<void> _backupData() async {
    setState(() => _processing = true);
    try {
      final data = await DatabaseHelper.instance.exportData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final result = await FilePicker.saveFile(
        dialogTitle: 'Simpan Backup Data NotaBBM',
        fileName:
            'notabbm_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: utf8.encode(jsonString),
      );

      if (result != null) {
        if (mounted) _snack(context, 'Backup berhasil disimpan ke file.');
      } else {
        await Share.share(jsonString, subject: 'Backup Data NotaBBM');
      }
    } catch (e) {
      if (mounted) _snack(context, 'Gagal backup data: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _restoreData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Data (Restore)'),
        content: const Text(
          'Memulihkan data akan mengganti data Nama Operator, Data SPBU, Footer Nota, dan data aplikasi saat ini dengan data dari file backup. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Pulihkan',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isNotEmpty && result.single.path != null) {
        final file = File(result.single.path!);
        final jsonString = await file.readAsString();
        final data = jsonDecode(jsonString) as Map<String, dynamic>;

        await DatabaseHelper.instance.importData(data);
        if (mounted) {
          _snack(context, 'Data berhasil dipulihkan!');
        }
      }
    } catch (e) {
      if (mounted) _snack(context, 'Gagal memulihkan data: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar('Backup & Pemulihan Data'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _processing
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Cadangkan atau Pulihkan Data secara Lokal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Fitur ini mencadangkan data penting Anda secara lokal ke perangkat:\n'
                    '• Nama Operator\n'
                    '• Data SPBU\n'
                    '• Footer Nota\n'
                    '• Harga BBM & History Transaksi',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _biru,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.backup),
                    label: const Text(
                      'Backup Data (Simpan ke File JSON)',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: _backupData,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.restore),
                    label: const Text(
                      'Pulihkan Data (Restore dari File)',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: _restoreData,
                  ),
                ],
              ),
      ),
    );
  }
}

