import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';

import 'ads_service.dart';
import 'folder_image_picker.dart';
import 'preview_struk.dart';
import 'database/database_helper.dart';

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final digitsBeforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final formatted = _formatThousands(digits);
    var cursorOffset = 0;
    var countedDigits = 0;
    while (cursorOffset < formatted.length &&
        countedDigits < digitsBeforeCursor) {
      if (formatted[cursorOffset] != '.') countedDigits++;
      cursorOffset++;
    }
    if (digitsBeforeCursor == digits.length) {
      cursorOffset = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

String _formatThousands(String digits) {
  final formatted = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      formatted.write('.');
    }
    formatted.write(digits[index]);
  }
  return formatted.toString();
}

class FormTransaksiScreen extends StatefulWidget {
  final String namaBbm;
  final int hargaPerLiter;
  final Color warnaBbm;

  const FormTransaksiScreen({
    super.key,
    required this.namaBbm,
    required this.hargaPerLiter,
    required this.warnaBbm,
  });

  @override
  State<FormTransaksiScreen> createState() => _FormTransaksiScreenState();
}

class _FormTransaksiScreenState extends State<FormTransaksiScreen> {
  static const _inputTextColor = Colors.black;

  final TextEditingController _jumlahRpController = TextEditingController();
  final TextEditingController _platNomorController = TextEditingController();
  final TextEditingController _hargaNonSubsidiController =
      TextEditingController();
  final TextEditingController _subsidiController = TextEditingController();
  final TextEditingController _idTransaksiController = TextEditingController();
  final TextEditingController _jamController = TextEditingController();
  final TextEditingController _menitController = TextEditingController();
  final TextEditingController _detikController = TextEditingController();

  double _estimasiLiter = 0.0;
  int? _selectedNominal;
  late DateTime _tanggalTransaksi;

  // Pengaturan Logo
  double _ukuranLogo = 70.0;
  String? _customLogoPath; // Menyimpan gambar logo

  // Variabel Data
  List<String> _listSpbu = ['SPBU MASA DEPAN (348888)'];
  String _selectedSpbu = 'SPBU MASA DEPAN (348888)';
  List<Map<String, dynamic>> _spbuData = [];
  String _footerText = '';
  final List<int> _listShift = [1, 2, 3];
  int _selectedShift = 2;
  final List<int> _listPompa = List.generate(30, (index) => index + 1);
  int _selectedPompa = 14;
  List<String> _listOperator = ['AWANDA', 'ENDANG', 'GADIS'];
  String? _selectedOperator = 'AWANDA';

  // BBM non-subsidi tidak memiliki harga non subsidi dan subsidi pemerintah
  bool get _isPertaminaDex => const {
    'PERTAMINA DEX',
    'PERTAMAX GREEN',
  }.contains(widget.namaBbm.trim().toUpperCase());

  bool get _adaSubsidi => !const {
    'PERTAMAX',
    'PERTAMAX TURBO',
    'PERTAMAX GREEN',
    'DEXLITE',
    'PERTAMINA DEX',
  }.contains(widget.namaBbm.trim().toUpperCase());

  String _labelSpbu(Map<String, dynamic> s) =>
      '${s['nama_spbu']} (${s['id_spbu']})';

  Map<String, dynamic>? get _spbuTerpilih {
    for (final s in _spbuData) {
      if (_labelSpbu(s) == _selectedSpbu) return s;
    }
    return null;
  }

  Future<void> _muatPengaturan() async {
    final db = DatabaseHelper.instance;
    final List<Map<String, dynamic>> ops;
    final List<Map<String, dynamic>> spbu;
    final String footer;
    try {
      ops = await db.getOperator();
      spbu = await db.getSpbu();
      footer = await db.getFooterBbm(widget.namaBbm);
    } catch (_) {
      return; // database tidak tersedia, pakai nilai bawaan
    }
    if (!mounted) return;
    setState(() {
      _spbuData = spbu;
      _listSpbu = spbu.map(_labelSpbu).toList();
      _selectedSpbu = _listSpbu.isEmpty ? '' : _listSpbu.first;
      _footerText = footer;
      _listOperator = ops.map((o) => o['nama_operator'] as String).toList();
      _selectedOperator = _listOperator.isEmpty ? null : _listOperator.first;
    });
  }

  @override
  void initState() {
    super.initState();
    _muatPengaturan();
    _tanggalTransaksi = DateTime.now();
    _jamController.text = _tanggalTransaksi.hour.toString().padLeft(2, '0');
    _menitController.text = _tanggalTransaksi.minute.toString().padLeft(2, '0');
    _detikController.text = _tanggalTransaksi.second.toString().padLeft(2, '0');
  }

  @override
  void dispose() {
    _jamController.dispose();
    _menitController.dispose();
    _detikController.dispose();
    super.dispose();
  }

  // Pengguna memilih sumber logo. Akses folder diberikan lewat dialog sistem
  // (Storage Access Framework), sehingga tidak butuh izin penyimpanan luas.
  Future<void> _pickLogo() async {
    final sumber = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, 'galeri'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Telusuri Folder'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            if (_customLogoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Hapus Logo'),
                onTap: () => Navigator.pop(context, 'hapus'),
              ),
          ],
        ),
      ),
    );
    if (sumber == null || !mounted) return;

    try {
      String? path;
      if (sumber == 'galeri') {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        path = image?.path;
      } else if (sumber == 'file') {
        path = await FolderImagePickerScreen.pick(context);
      } else {
        setState(() => _customLogoPath = null);
        return;
      }
      if (path != null && mounted) setState(() => _customLogoPath = path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo tidak dapat dibuka: $error')),
      );
    }
  }

  Future<void> _pilihTanggal() async {
    final tanggal = await showDatePicker(
      context: context,
      initialDate: _tanggalTransaksi,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (tanggal != null) {
      setState(() => _tanggalTransaksi = tanggal);
    }
  }

  String _formatTanggal(DateTime tanggal) =>
      '${tanggal.day.toString().padLeft(2, '0')}/'
      '${tanggal.month.toString().padLeft(2, '0')}/'
      '${tanggal.year}';

  String? _waktuTransaksi() {
    final jam = int.tryParse(_jamController.text);
    final menit = int.tryParse(_menitController.text);
    final detik = int.tryParse(_detikController.text);
    if (jam == null ||
        jam < 0 ||
        jam > 23 ||
        menit == null ||
        menit < 0 ||
        menit > 59 ||
        detik == null ||
        detik < 0 ||
        detik > 59) {
      return null;
    }
    return '${_formatTanggal(_tanggalTransaksi)} '
        '${jam.toString().padLeft(2, '0')}:'
        '${menit.toString().padLeft(2, '0')}:'
        '${detik.toString().padLeft(2, '0')}';
  }

  Widget _buildTimeField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _inputTextColor),
      keyboardType: TextInputType.number,
      maxLength: 2,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _hitungLiter(String value) {
    _selectedNominal = null;
    if (value.isNotEmpty) {
      int jumlahRp = int.parse(value.replaceAll(RegExp(r'[^0-9]'), ''));
      setState(() => _estimasiLiter = jumlahRp / widget.hargaPerLiter);
    } else {
      setState(() => _estimasiLiter = 0.0);
    }
  }

  void _setNominal(int nominal) {
    final formatted = _formatThousands(nominal.toString());
    _jumlahRpController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {
      _selectedNominal = nominal;
      _estimasiLiter = nominal / widget.hargaPerLiter;
    });
  }

  void _openPreview() {
    if (_jumlahRpController.text.isEmpty || _estimasiLiter <= 0) return;
    final waktu = _waktuTransaksi();
    if (waktu == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Masukkan waktu yang valid (jam 0-23, menit dan detik 0-59).',
          ),
        ),
      );
      return;
    }
    final totalUang = int.parse(
      _jumlahRpController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewStrukScreen(
          namaBbm: widget.namaBbm,
          hargaPerLiter: widget.hargaPerLiter,
          totalBayar: totalUang,
          estimasiLiter: _estimasiLiter,
          platNomor: _platNomorController.text,
          namaSpbu: _spbuTerpilih?['nama_spbu'] ?? _selectedSpbu.split(' (')[0],
          kodeSpbu: _spbuTerpilih?['id_spbu'] ?? '348888',
          alamatSpbu: _spbuTerpilih?['alamat_spbu'] ?? '',
          footerText: _footerText,
          shift: _selectedShift,
          pompa: _selectedPompa,
          tanggalWaktu: waktu,
          namaOperator: _selectedOperator ?? '-',
          hargaNonSubsidi: _adaSubsidi
              ? int.tryParse(
                  _hargaNonSubsidiController.text.replaceAll(
                    RegExp(r'[^0-9]'),
                    '',
                  ),
                )
              : null,
          subsidiPemerintah: _adaSubsidi
              ? int.tryParse(
                  _subsidiController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                )
              : null,
          showSubsidi: _adaSubsidi,
          idTransaksi: _idTransaksiController.text,
          customLogoPath: _customLogoPath,
          showHeader: true,
          logoSizePercent: _ukuranLogo,
        ),
      ),
    );
  }

  Widget _buildHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF23B2EE), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF23B2EE),
        title: Text(
          widget.namaBbm,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: Theme.of(context).inputDecorationTheme
                .copyWith(
                  labelStyle: TextStyle(
                    color: _inputTextColor.withValues(alpha: 0.5),
                  ),
                ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Pengaturan Logo
                _buildHeader(Icons.image, 'Pengaturan Logo'),
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _customLogoPath != null
                            ? Image.file(
                                File(_customLogoPath!),
                                fit: BoxFit.contain,
                              )
                            : const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.grey,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Logo Custom',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF23B2EE),
                            ),
                            onPressed: _pickLogo,
                            icon: const Icon(
                              Icons.image,
                              color: Colors.black,
                              size: 18,
                            ),
                            label: const Text(
                              'Pilih Logo',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Ukuran Logo di Header',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _ukuranLogo,
                        min: 50,
                        max: 200,
                        activeColor: const Color(0xFF23B2EE),
                        onChanged: (val) => setState(() => _ukuranLogo = val),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${_ukuranLogo.round()}%',
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 8),
                // 2. Data SPBU
                _buildHeader(Icons.location_on, 'Data SPBU'),
                DropdownButtonFormField<String>(
                  style: const TextStyle(color: _inputTextColor),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  initialValue: _selectedSpbu.isEmpty ? null : _selectedSpbu,
                  items: _listSpbu
                      .map(
                        (spbu) =>
                            DropdownMenuItem(value: spbu, child: Text(spbu)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSpbu = val!),
                ),

                // 3. Shift and transaction ID
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_gas_station,
                              color: Color(0xFF23B2EE),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Shift',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number,
                              color: Color(0xFF23B2EE),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ID Transaksi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        style: const TextStyle(color: _inputTextColor),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        initialValue: _selectedShift,
                        items: _listShift
                            .map(
                              (shift) => DropdownMenuItem(
                                value: shift,
                                child: Text(shift.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedShift = value!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _idTransaksiController,
                        style: const TextStyle(color: _inputTextColor),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.numbers),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // 4. Waktu Transaksi
                _buildHeader(Icons.access_time, 'Waktu'),
                InkWell(
                  onTap: _pilihTanggal,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tanggal',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _formatTanggal(_tanggalTransaksi),
                      style: const TextStyle(color: _inputTextColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTimeField('Jam', _jamController)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimeField('Menit', _menitController)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTimeField('Detik', _detikController)),
                  ],
                ),

                // 6. Data Transaksi
                _buildHeader(Icons.receipt_long, 'Data Transaksi'),
                DropdownButtonFormField<int>(
                  style: const TextStyle(color: _inputTextColor),
                  decoration: InputDecoration(
                    labelText: 'Pompa',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  initialValue: _selectedPompa,
                  items: _listPompa
                      .map(
                        (pump) => DropdownMenuItem(
                          value: pump,
                          child: Text(pump.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedPompa = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  style: const TextStyle(color: _inputTextColor),
                  decoration: InputDecoration(
                    labelText: 'Operator',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  initialValue: _selectedOperator,
                  items: _listOperator
                      .map((op) => DropdownMenuItem(value: op, child: Text(op)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedOperator = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _jumlahRpController,
                  style: const TextStyle(color: _inputTextColor),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandsSeparatorInputFormatter()],
                  onChanged: _hitungLiter,
                  decoration: InputDecoration(
                    labelText: 'Jumlah (Rp)',
                    prefixIcon: const Icon(
                      Icons.money,
                      color: Color(0xFF23B2EE),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [50000, 100000, 200000, 300000].map((val) {
                    final selected = _selectedNominal == val;
                    return ChoiceChip(
                      label: Text(
                        '${val ~/ 1000}k',
                        style: TextStyle(color: Colors.black),
                      ),
                      selected: selected,
                      selectedColor: const Color(0xFF23B2EE),
                      onSelected: (value) {
                        if (value) _setNominal(val);
                      },
                    );
                  }).toList(),
                ),
                if (!_isPertaminaDex) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _platNomorController,
                    style: const TextStyle(color: _inputTextColor),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Nomor Kendaraan',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],

                if (_adaSubsidi) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hargaNonSubsidiController,
                    style: const TextStyle(color: _inputTextColor),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Harga Non Subsidi (Rp/Liter)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _subsidiController,
                    style: const TextStyle(color: _inputTextColor),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Subsidi Pemerintah (Rp/Liter)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: _buildPreviewButton(),
          ),
          if (kShowAds)
            const ColoredBox(
              color: Colors.white,
              child: Align(
                heightFactor: 1,
                alignment: Alignment.center,
                child: BannerAdWidget(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewButton() {
    return Material(
      key: const ValueKey('preview-column'),
      color: const Color(0xFF23B2EE),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openPreview,
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: const SizedBox(
          width: double.infinity,
          height: 56,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.print, color: Colors.black),
                SizedBox(width: 8),
                Text(
                  'Preview',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
