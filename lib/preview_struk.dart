import 'dart:io';
import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:file_picker/file_picker.dart';

import 'ads_service.dart';

enum _ReceiptFileFormat { pdf, jpg }

class _WatermarkPainter extends CustomPainter {
  const _WatermarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'NotaBBM',
        style: TextStyle(
          color: Color(0x40000000),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final stepX = painter.width + 36;
    final stepY = painter.height + 44;
    final diagonal = size.width + size.height;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-25 * 3.141592653589793 / 180);
    var row = 0;
    for (var y = -diagonal; y < diagonal; y += stepY, row++) {
      final shift = row.isEven ? 0.0 : stepX / 2;
      for (var x = -diagonal + shift; x < diagonal; x += stepX) {
        painter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PreviewStrukScreen extends StatefulWidget {
  final String namaBbm;
  final int hargaPerLiter;
  final int totalBayar;
  final double estimasiLiter;
  final String platNomor;

  final String namaSpbu;
  final int shift;
  final int pompa;
  final String tanggalWaktu;
  final String namaOperator;
  final int? hargaNonSubsidi;
  final int? subsidiPemerintah;
  final String idTransaksi;
  final String? customLogoPath;
  final bool showHeader;
  final double logoSizePercent;
  final bool showSubsidi;
  final String kodeSpbu;
  final String alamatSpbu;
  final String footerText;

  const PreviewStrukScreen({
    super.key,
    required this.namaBbm,
    required this.hargaPerLiter,
    required this.totalBayar,
    required this.estimasiLiter,
    required this.platNomor,
    required this.namaSpbu,
    required this.shift,
    required this.pompa,
    required this.tanggalWaktu,
    required this.namaOperator,
    this.hargaNonSubsidi,
    this.subsidiPemerintah,
    required this.idTransaksi,
    this.customLogoPath,
    this.showHeader = true,
    this.logoSizePercent = 70,
    this.showSubsidi = true,
    this.kodeSpbu = '3414210',
    this.alamatSpbu = 'JL. SENTRA BISNIS ARTHA GADING',
    this.footerText = '',
  });

  @override
  State<PreviewStrukScreen> createState() => _PreviewStrukScreenState();
}

class _PreviewStrukScreenState extends State<PreviewStrukScreen> {
  static const _teal = Color(0xFF23B2EE);
  static const _receiptWidth = 32;
  static const _printableWidth = 384;
  static const _exportWidth = 1152;
  static const _jpgPaperMm = 66;
  static const _printZoom = 1.07;
  static const _printTrimChars = 0.0;
  // Geser isi struk ke kiri (poin) khusus cetak Bluetooth
  static const _printLeftTrim = 0.0;
  // Geser seluruh isi struk ke kanan (piksel printer) khusus cetak Bluetooth
  static const _printShiftRightPx = 1;
  double _previewFontSize = 12;
  final _receiptBoundaryKey = GlobalKey();
  static const _fontBoost = 1.0;
  // Lebar tambahan agar margin tetap sama setelah font diperbesar _fontBoost
  static const _fontBoostExtraWidth = _receiptWidth * 0.602 * _fontBoost;
  static const _receiptPaperWidth =
      60 * 96 / 25.4 * 1.1 * 1.3 + _fontBoostExtraWidth;
  bool _isPrinting = false;
  bool _isExporting = false;
  bool _showWatermark = true;

  // Iklan reward wajib ditonton; watermark hanya hilang jika iklan selesai.
  // Mengembalikan false jika aksi dibatalkan. Watermark dipulihkan di akhir aksi.
  Future<bool> _prepareReceipt() async {
    final result = await AdsService.showRewarded();
    if (!mounted) return false;
    if (result == AdResult.dismissed) {
      _showMessage('Tonton iklan sampai selesai untuk melanjutkan.');
      return false;
    }
    if (result == AdResult.unavailable) {
      _showMessage('Iklan belum tersedia, struk dibuat dengan watermark.');
    }
    setState(() => _showWatermark = result != AdResult.rewarded);
    await WidgetsBinding.instance.endOfFrame;
    return true;
  }

  void _restoreWatermark() {
    if (mounted) setState(() => _showWatermark = true);
  }

  // {subsidi} pada footer diganti dengan total subsidi pemerintah
  String get _footerResolved => widget.footerText.replaceAll(
    '{subsidi}',
    _totalSubsidi == null ? '-' : _formatRibuan(_totalSubsidi!),
  );

  int? get _totalTanpaSubsidi => widget.hargaNonSubsidi == null
      ? null
      : (widget.estimasiLiter * widget.hargaNonSubsidi!).round();

  int? get _totalSubsidi => widget.subsidiPemerintah == null
      ? null
      : (widget.estimasiLiter * widget.subsidiPemerintah!).round();

  String _formatRibuan(int value) {
    final digits = value.abs().toString();
    final result = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        result.write(',');
      }
      result.write(digits[index]);
    }
    return value < 0 ? '-$result' : result.toString();
  }

  String _alignCenter(String text) {
    if (text.length >= _receiptWidth) return text;
    return '${' ' * ((_receiptWidth - text.length) ~/ 2)}$text';
  }

  String _alignRight(String text) {
    final spaces = _receiptWidth - text.length;
    if (spaces <= 0) return text;
    return '${' ' * spaces}$text';
  }

  List<String> _wrap(String text, {int width = _receiptWidth}) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var line = '';
    for (final word in words) {
      if (word.length > width) {
        if (line.isNotEmpty) {
          lines.add(line);
          line = '';
        }
        for (var start = 0; start < word.length; start += width) {
          lines.add(
            word.substring(
              start,
              start + width < word.length ? start + width : word.length,
            ),
          );
        }
      } else if (line.isEmpty) {
        line = word;
      } else if (line.length + word.length + 1 <= width) {
        line = '$line $word';
      } else {
        lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  List<String> _detailLines(
    String label,
    String value, {
    bool uppercase = true,
    int labelWidth = 12,
  }) {
    final valueWidth = _receiptWidth - labelWidth - 2;
    final valueLines = _wrap(
      uppercase ? value.toUpperCase() : value,
      width: valueWidth,
    );
    return [
      '${label.padRight(labelWidth)}: ${valueLines.first}',
      ...valueLines.skip(1).map((line) => '${' ' * (labelWidth + 2)}$line'),
    ];
  }

  List<String> _indentLines(Iterable<String> lines) =>
      lines.map((line) => line).toList();

  String _priceLine(
    String label,
    int? value, {
    int spacesAfterColon = 1,
    int? alignToDigits,
    int? alignToFormattedLength,
  }) {
    const colonColumn = 19;
    final prefix = '${label.padRight(colonColumn - 1)} :';
    if (value == null) return '$prefix${' ' * spacesAfterColon}-';
    final digitPadding = alignToDigits == null
        ? 0
        : (alignToDigits - value.abs().toString().length).clamp(
            0,
            alignToDigits,
          );
    final formattedValue = _formatRibuan(value);
    final formattedPadding = alignToFormattedLength == null
        ? 0
        : (alignToFormattedLength - formattedValue.length).clamp(
            0,
            alignToFormattedLength,
          );
    return '$prefix${' ' * (spacesAfterColon + digitPadding + formattedPadding)}$formattedValue';
  }

  List<String> _receiptLines() {
    final separator = ' ${_alignCenter('-' * (_receiptWidth - 2))}';
    final isPertaminaDex = const {
      'PERTAMINA DEX',
      'PERTAMAX GREEN',
    }.contains(widget.namaBbm.trim().toUpperCase());
    final totalAlignmentLength =
        [
          _totalTanpaSubsidi,
          _totalSubsidi,
          widget.totalBayar,
        ].whereType<int>().fold<int>(
          0,
          (largest, value) => _formatRibuan(value).length > largest
              ? _formatRibuan(value).length
              : largest,
        );
    final lines = <String>[
      if (widget.kodeSpbu.isNotEmpty) _alignCenter(widget.kodeSpbu),
      ..._wrap(widget.namaSpbu.toUpperCase()).map(_alignCenter),
      if (widget.alamatSpbu.trim().isNotEmpty)
        ..._wrap(widget.alamatSpbu.toUpperCase()).map(_alignCenter),
      'Shift: ${widget.shift}     No. Trans: ${widget.idTransaksi}',
      ..._indentLines(_wrap('Waktu: ${widget.tanggalWaktu}')),
      separator,
      if (isPertaminaDex) ...[
        ..._indentLines(
          _detailLines('Pulau/Pompa', widget.pompa.toString(), labelWidth: 11),
        ),
        ..._indentLines(
          _detailLines(
            'Nama Produk',
            widget.namaBbm.trim().toUpperCase() == 'PERTAMAX GREEN'
                ? 'PERTAMAX_GREEN'
                : 'PERTAMINA_DEX',
            labelWidth: 11,
          ),
        ),
        ..._indentLines(
          _detailLines(
            'Harga/Liter',
            'Rp. ${_formatRibuan(widget.hargaPerLiter)}',
            uppercase: false,
            labelWidth: 11,
          ),
        ),
        ..._indentLines(
          _detailLines(
            'Volume',
            '(L) ${widget.estimasiLiter.toStringAsFixed(2)}',
            uppercase: false,
            labelWidth: 11,
          ),
        ),
        ..._indentLines(
          _detailLines(
            'Total Harga',
            'Rp. ${_formatRibuan(widget.totalBayar)}',
            uppercase: false,
            labelWidth: 11,
          ),
        ),
        ..._indentLines(
          _detailLines('Operator', widget.namaOperator, labelWidth: 11),
        ),
        separator,
        'CASH',
        '   ${_alignRight(_formatRibuan(widget.totalBayar))}',
        separator,
      ] else ...[
        ..._indentLines(_detailLines('Pulau/Pompa', widget.pompa.toString())),
        ..._indentLines(_detailLines('Operator', widget.namaOperator)),
        ..._indentLines(_detailLines('Jenis BBM', widget.namaBbm)),
        ..._indentLines(
          _detailLines(
            'Volume',
            '${widget.estimasiLiter.toStringAsFixed(2)} liter',
            uppercase: false,
          ),
        ),
        separator,
        ..._indentLines(_wrap('Informasi Harga BBM (Rp/Liter)')),
        if (widget.showSubsidi) ...[
          _priceLine('Harga Non Subsidi', widget.hargaNonSubsidi),
          _priceLine(
            'Subsidi Pemerintah',
            widget.subsidiPemerintah,
            alignToDigits: 5,
          ),
        ],
        _priceLine('Harga Jual', widget.hargaPerLiter),
        separator,
        'Total Penjualan (Rp)',
        if (widget.showSubsidi) ...[
          _priceLine(
            'Tanpa Subsidi',
            _totalTanpaSubsidi,
            alignToFormattedLength: totalAlignmentLength,
          ),
          _priceLine(
            'Subsidi Pemerintah',
            _totalSubsidi,
            alignToFormattedLength: totalAlignmentLength,
          ),
          _priceLine(
            'Dibayar Konsumen',
            widget.totalBayar,
            alignToFormattedLength: totalAlignmentLength,
          ),
        ] else ...[
          _priceLine('Dibayar Konsumen', widget.totalBayar),
        ],
        separator,
        'CASH',
        '   ${_alignRight(_formatRibuan(widget.totalBayar))}',
        separator,
        'No. Plat  : ${widget.platNomor.isEmpty ? '-' : widget.platNomor.toUpperCase()}',
        separator,
      ],
      if (_footerResolved.trim().isNotEmpty)
        for (final baris in _footerResolved.trim().split('\n'))
          ..._wrap(baris.isEmpty ? ' ' : baris).map(_alignCenter),
    ];
    return lines;
  }

  Widget _buildReceiptLogo(double availableWidth) {
    final logoPath = widget.customLogoPath;
    if (!widget.showHeader || logoPath == null) return const SizedBox.shrink();

    final image = Image.file(
      File(logoPath),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Text(
        'Logo tidak dapat dimuat',
        style: TextStyle(fontSize: 10, color: Colors.red),
      ),
    );

    final logoWidth = (availableWidth * (widget.logoSizePercent / 200) * 1.2676)
        .clamp(0.0, availableWidth);
    return SizedBox(
      key: const ValueKey('receipt-logo'),
      width: logoWidth,
      height: logoWidth * 0.28,
      child: image,
    );
  }

  // Struk diambil langsung dari widget preview agar hasilnya identik.
  // trimChars memotong margin kiri-kanan sebanyak N karakter per sisi.
  Future<img.Image> _renderCombinedReceiptImage({
    int width = _printableWidth,
    double zoom = 1,
    double trimChars = 0,
    double leftTrim = 0,
    int shiftRightPx = 0,
  }) async {
    final boundary =
        _receiptBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      throw const FormatException('Struk tidak dapat disiapkan.');
    }
    final fullWidth = boundary.size.width;
    final charPainter = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontFamily: 'Droid Sans Mono',
          fontSize: _previewFontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final trimPerSide =
        (fullWidth - fullWidth / zoom) / 2 + trimChars * charPainter.width;
    charPainter.dispose();
    final visibleWidth = fullWidth - 2 * trimPerSide;
    final pixelRatio = width / visibleWidth;

    final captured = await boundary.toImage(pixelRatio: pixelRatio);
    final png = await captured.toByteData(format: ui.ImageByteFormat.png);
    captured.dispose();
    final decoded = png == null
        ? null
        : img.decodePng(png.buffer.asUint8List());
    if (decoded == null) {
      throw const FormatException('Struk tidak dapat disiapkan.');
    }
    final rgb = decoded.convert(numChannels: 3);
    if (trimPerSide <= 0 && leftTrim <= 0) return rgb;
    // Lebar hasil harus tepat sama dengan width (kelipatan 8) untuk printer.
    final cropX =
        (((trimPerSide + leftTrim) * pixelRatio).round() - shiftRightPx).clamp(
          0,
          (rgb.width - width).clamp(0, rgb.width),
        );
    return img.copyCrop(
      rgb,
      x: cropX,
      y: 0,
      width: width.clamp(1, rgb.width - cropX),
      height: rgb.height,
    );
  }

  Future<Uint8List> _buildReceiptJpg() async {
    final image = await _renderCombinedReceiptImage(width: _exportWidth);
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  // Struk 58 mm diletakkan di tengah kertas putih selebar 66 mm
  Uint8List _widenReceiptJpg(Uint8List jpgBytes) {
    final receipt = img.decodeJpg(jpgBytes);
    if (receipt == null) {
      throw const FormatException('Struk tidak dapat disiapkan untuk JPG.');
    }
    final paperWidth = (receipt.width * _jpgPaperMm / 58).round();
    final canvas = img.Image(
      width: paperWidth,
      height: receipt.height,
      numChannels: 3,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(
      canvas,
      receipt,
      dstX: (paperWidth - receipt.width) ~/ 2,
    );
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
  }

  Future<Uint8List> _buildReceiptPdf(Uint8List jpgBytes) async {
    final image = img.decodeImage(jpgBytes);
    if (image == null) {
      throw const FormatException('Struk tidak dapat disiapkan untuk PDF.');
    }
    final pageWidth = 60 * PdfPageFormat.mm;
    final pageHeight = pageWidth * image.height / image.width;
    final document = pw.Document();
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(
          pw.MemoryImage(jpgBytes),
          width: pageWidth,
          height: pageHeight,
          fit: pw.BoxFit.fill,
        ),
      ),
    );
    return document.save();
  }

  String get _receiptFileBaseName {
    final safeId = widget.idTransaksi.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return safeId.isEmpty ? 'struk' : 'struk_$safeId';
  }

  Future<_ReceiptFileFormat?> _chooseReceiptFileFormat() {
    return showModalBottomSheet<_ReceiptFileFormat>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Simpan Struk sebagai',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: _teal),
              title: const Text('File PDF'),
              onTap: () => Navigator.pop(context, _ReceiptFileFormat.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: _teal),
              title: const Text('File JPG'),
              onTap: () => Navigator.pop(context, _ReceiptFileFormat.jpg),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bagikanStruk() async {
    if (_isPrinting || _isExporting) return;
    final format = await _chooseReceiptFileFormat();
    if (format == null || !mounted) return;

    setState(() => _isExporting = true);
    try {
      if (!await _prepareReceipt()) return;
      final jpgBytes = await _buildReceiptJpg();
      final extension = format == _ReceiptFileFormat.pdf ? 'pdf' : 'jpg';
      final fileBytes = format == _ReceiptFileFormat.pdf
          ? await _buildReceiptPdf(jpgBytes)
          : _widenReceiptJpg(jpgBytes);
      final fileName = '$_receiptFileBaseName.$extension';
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Simpan struk $extension',
        fileName: fileName,
        bytes: fileBytes,
        type: FileType.custom,
        allowedExtensions: [extension],
      );
      if (savedPath != null) _showMessage('Struk disimpan sebagai $fileName');
    } on PlatformException catch (error) {
      _showMessage(
        error.message ?? 'File struk gagal disimpan.',
        isError: true,
      );
    } on FileSystemException catch (error) {
      _showMessage(
        'File logo tidak dapat dibuka: ${error.message}',
        isError: true,
      );
    } on FormatException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      _restoreWatermark();
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : _teal,
        ),
      );
  }

  Future<BluetoothInfo?> _choosePrinter(List<BluetoothInfo> printers) {
    return showDialog<BluetoothInfo>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Printer Bluetooth'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: printers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final printer = printers[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print, color: _teal),
                title: Text(printer.name),
                subtitle: Text(printer.macAdress),
                onTap: () => Navigator.pop(context, printer),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Future<void> _cetakStruk() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final hasPermission =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!hasPermission) {
        _showMessage(
          'Izin Bluetooth belum diberikan. Izinkan akses Bluetooth untuk mencetak.',
          isError: true,
        );
        return;
      }

      final isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!isBluetoothEnabled) {
        _showMessage(
          'Aktifkan Bluetooth pada HP untuk mencetak struk.',
          isError: true,
        );
        return;
      }

      final printers = await PrintBluetoothThermal.pairedBluetooths;
      if (printers.isEmpty) {
        _showMessage(
          'Printer belum ditemukan. Pasangkan printer melalui pengaturan Bluetooth HP terlebih dahulu.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      final printer = await _choosePrinter(printers);
      if (printer == null) return;

      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.macAdress,
      );
      if (!connected) {
        _showMessage(
          'Tidak dapat terhubung ke ${printer.name}.',
          isError: true,
        );
        return;
      }

      final profile = await CapabilityProfile.load();
      if (!await _prepareReceipt()) return;
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = <int>[...generator.reset()];
      bytes.addAll(
        generator.imageRaster(
          await _renderCombinedReceiptImage(
            zoom: _printZoom,
            trimChars: _printTrimChars,
            leftTrim: _printLeftTrim,
            shiftRightPx: _printShiftRightPx,
          ),
        ),
      );
      bytes.addAll(generator.feed(3));

      final printed = await PrintBluetoothThermal.writeBytes(bytes);
      if (!printed) {
        _showMessage(
          'Struk gagal dikirim ke printer. Periksa koneksi printer.',
          isError: true,
        );
        return;
      }
      _showMessage('Struk berhasil dikirim ke ${printer.name}.');
    } on PlatformException catch (error) {
      _showMessage(
        error.message ?? 'Terjadi kesalahan saat mengakses printer Bluetooth.',
        isError: true,
      );
    } on FileSystemException catch (error) {
      _showMessage('Logo tidak dapat dibuka: ${error.message}', isError: true);
    } on FormatException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      _restoreWatermark();
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: _teal,
        elevation: 0,
        leadingWidth: 54,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: CircleAvatar(
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.receipt_long, color: Colors.black, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview Struk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.namaBbm,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tutup',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 30),
            child: Center(
              child: Container(
                key: const ValueKey('receipt-preview'),
                width: _receiptPaperWidth,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  key: _receiptBoundaryKey,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(
                          8,
                          14 + 5 * _receiptPaperWidth / 60,
                          8,
                          19 + 5 * _receiptPaperWidth / 60,
                        ),
                        child: LayoutBuilder(
                          builder: (context, receiptConstraints) {
                            final textPainter = TextPainter(
                              text: TextSpan(
                                text: '0' * _receiptWidth,
                                style: const TextStyle(
                                  fontFamily: 'Droid Sans Mono',
                                  fontSize: 1,
                                ),
                              ),
                              textDirection: TextDirection.ltr,
                            )..layout();
                            final previewFontSize =
                                ((receiptConstraints.maxWidth -
                                                    _fontBoostExtraWidth) /
                                                textPainter.width *
                                                0.9 -
                                            3)
                                        .clamp(1.0, double.infinity) *
                                    1.2324 +
                                _fontBoost;
                            textPainter.dispose();
                            _previewFontSize = previewFontSize;

                            final centeredLines = {
                              widget.kodeSpbu,
                              ..._wrap(widget.namaSpbu.toUpperCase()),
                              ..._wrap(widget.alamatSpbu.toUpperCase()),
                              for (final baris in _footerResolved.trim().split(
                                '\n',
                              ))
                                ..._wrap(baris),
                            };
                            final receiptLines = _receiptLines();

                            return Column(
                              children: [
                                _buildReceiptLogo(receiptConstraints.maxWidth),
                                SizedBox(
                                  height: (previewFontSize - 4).clamp(
                                    0.0,
                                    double.infinity,
                                  ),
                                ),
                                ...receiptLines.map((line) {
                                  final content = line.trim();
                                  final isSeparator =
                                      content.isNotEmpty &&
                                      content
                                          .split('')
                                          .every(
                                            (character) => character == '-',
                                          );
                                  final isCentered =
                                      centeredLines.contains(content) ||
                                      isSeparator;
                                  final isBold =
                                      widget.kodeSpbu.isNotEmpty &&
                                      content == widget.kodeSpbu;
                                  return SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      isCentered ? content : line,
                                      textAlign: isCentered
                                          ? TextAlign.center
                                          : TextAlign.left,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontFamily: 'Droid Sans Mono',
                                        fontSize: previewFontSize,
                                        fontWeight: isBold
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: const Color(0xFF222222),
                                        height: 1.28,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                      if (_showWatermark)
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(painter: _WatermarkPainter()),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _teal,
                    side: const BorderSide(color: _teal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isPrinting || _isExporting ? null : _bagikanStruk,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _teal,
                          ),
                        )
                      : const Icon(Icons.save_alt, size: 17),
                  label: Text(
                    _isExporting
                        ? 'Menyiapkan file...'
                        : 'Simpan Sebagai File PDF / JPG',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.grey.shade600,
                        side: const BorderSide(color: Color(0xFFD1D5D9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isPrinting || _isExporting
                          ? null
                          : _cetakStruk,
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.print, size: 17),
                      label: Text(
                        _isPrinting ? 'Memproses...' : 'Cetak Struk',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
