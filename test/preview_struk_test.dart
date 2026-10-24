import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_pom/form_transaksi.dart';
import 'package:mini_pom/preview_struk.dart';

void main() {
  testWidgets('logo size slider shows its current percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    expect(find.text('70%'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    expect(
      find.ancestor(of: find.text('70%'), matching: find.byType(Row)),
      findsWidgets,
    );
    slider.onChanged!(175);
    await tester.pump();

    expect(find.text('175%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo header stays enabled and logo controls are aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    expect(find.text('Cetak Header Struk'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    final customLogo = find.text('Logo Custom');
    final chooseLogo = find.text('Pilih Logo');
    final logoOptionsRow = find
        .ancestor(of: customLogo, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: logoOptionsRow, matching: chooseLogo),
      findsOneWidget,
    );

    final sizeLabel = tester.widget<Text>(find.text('Ukuran Logo di Header'));
    expect(sizeLabel.textAlign, TextAlign.center);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick amount choices use the same chip style and update total', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    for (final amount in ['50k', '100k', '200k', '300k']) {
      expect(find.byType(ChoiceChip).evaluate(), isNotEmpty);
      expect(find.text(amount), findsOneWidget);
    }

    final fiftyThousandChip = find.widgetWithText(ChoiceChip, '50k');
    await tester.ensureVisible(fiftyThousandChip);
    await tester.pumpAndSettle();
    await tester.tap(fiftyThousandChip);
    await tester.pump();

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '50k'))
          .selected,
      isTrue,
    );
    expect(find.text('Total: 5.00 L'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction ID can be entered manually', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    final idField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.prefixIcon is Icon &&
          (widget.decoration!.prefixIcon! as Icon).icon == Icons.numbers,
    );
    expect(tester.widget<TextField>(idField).enabled, isNot(false));

    final shiftField = find.byType(DropdownButtonFormField<int>).first;
    final rowWithShiftAndId = find
        .ancestor(of: shiftField, matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: rowWithShiftAndId, matching: idField),
      findsOneWidget,
    );

    await tester.enterText(idField, '1234567');

    expect(find.text('1234567'), findsOneWidget);
    expect(find.text('Generate'), findsNothing);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.byIcon(Icons.print), findsOneWidget);
    expect(find.byKey(const ValueKey('total-liter-column')), findsNothing);
    expect(find.byKey(const ValueKey('preview-column')), findsOneWidget);
    final amountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Jumlah (Rp)',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('preview-column'))).width,
      closeTo(tester.getSize(amountField).width, 1),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('preview-column')),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview column responds to touch and opens receipt preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    final amountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Jumlah (Rp)',
    );
    await tester.enterText(amountField, '20000');
    expect(find.text('20.000'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preview-column')));
    await tester.pumpAndSettle();

    expect(find.text('Preview Struk'), findsOneWidget);
    expect(find.textContaining('Dibayar Konsumen'), findsOneWidget);
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.style?.fontFamily == 'Droid Sans Mono')
          .any(
            (text) =>
                text.data?.contains('Dibayar Konsumen   : 20,000') ?? false,
          ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('amount input adds dot separators for thousands', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    final amountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Jumlah (Rp)',
    );
    await tester.enterText(amountField, '123456789');
    expect(find.text('123.456.789'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'subsidy price inputs format thousands and retain numeric values',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FormTransaksiScreen(
            namaBbm: 'PERTALITE',
            hargaPerLiter: 10000,
            warnaBbm: Colors.green,
          ),
        ),
      );

      Finder priceField(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      final nonSubsidizedPrice = priceField('Harga Non Subsidi (Rp/Liter)');
      final governmentSubsidy = priceField('Subsidi Pemerintah (Rp/Liter)');
      await tester.enterText(nonSubsidizedPrice, '18101');
      await tester.enterText(governmentSubsidy, '8101');
      expect(find.text('18.101'), findsOneWidget);
      expect(find.text('8.101'), findsOneWidget);

      final amountField = priceField('Jumlah (Rp)');
      await tester.enterText(amountField, '20000');
      await tester.tap(find.byKey(const ValueKey('preview-column')));
      await tester.pumpAndSettle();

      final receiptText = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) => text.style?.fontFamily == 'Droid Sans Mono')
          .map((text) => text.data ?? '')
          .join('\n');
      expect(receiptText, contains('Harga Non Subsidi  : 18,101'));
      expect(receiptText, contains('Subsidi Pemerintah :  8,101'));
      expect(receiptText, contains('Tanpa Subsidi      : 36,202'));
      expect(receiptText, contains('Subsidi Pemerintah : 16,202'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transaction date and time can be entered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    expect(find.text('Waktu'), findsOneWidget);
    expect(find.text('Tanggal'), findsOneWidget);

    for (final label in ['Jam', 'Menit', 'Detik']) {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, label == 'Jam' ? '23' : '59');
    }

    expect(find.text('23'), findsOneWidget);
    expect(find.text('59'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('price labels stay inside empty fields like vehicle field', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FormTransaksiScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          warnaBbm: Colors.green,
        ),
      ),
    );

    for (final label in [
      'Nomor Kendaraan',
      'Harga Non Subsidi (Rp/Liter)',
      'Subsidi Pemerintah (Rp/Liter)',
    ]) {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(
        tester.widget<TextField>(field).decoration!.floatingLabelBehavior,
        isNot(FloatingLabelBehavior.always),
      );
    }

    for (final label in [
      'Harga Non Subsidi (Rp/Liter)',
      'Subsidi Pemerintah (Rp/Liter)',
    ]) {
      final field = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == label,
        ),
      );
      expect(field.decoration!.hintText, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pertamina Dex uses the Pertalite receipt layout without subsidy',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FormTransaksiScreen(
            namaBbm: 'Pertamina Dex',
            hargaPerLiter: 16000,
            warnaBbm: Colors.teal,
          ),
        ),
      );

      expect(find.text('Pertamina Dex'), findsOneWidget);
      expect(find.text('Nomor Kendaraan'), findsNothing);
      expect(find.text('Harga Non Subsidi (Rp/Liter)'), findsNothing);
      expect(find.text('Subsidi Pemerintah (Rp/Liter)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inside-field text is 50% black and labels follow the app theme',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FormTransaksiScreen(
            namaBbm: 'PERTALITE',
            hargaPerLiter: 10000,
            warnaBbm: Colors.green,
          ),
        ),
      );

      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.style?.color, Colors.black);
      }
      final inputTheme = Theme.of(tester.element(find.byType(TextField).first))
          .inputDecorationTheme;
      expect(inputTheme.labelStyle?.color, Colors.black.withValues(alpha: 0.5));
      expect(inputTheme.floatingLabelStyle, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pertamina Dex receipt uses its product-focused layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PreviewStrukScreen(
          namaBbm: 'Pertamina Dex',
          hargaPerLiter: 16000,
          totalBayar: 32000,
          estimasiLiter: 2,
          platNomor: 'B1024DKG',
          namaSpbu: 'SPBU SENTRA BISNIS ARTHA',
          shift: 2,
          pompa: 14,
          tanggalWaktu: '16/10/2026 07:19:55',
          namaOperator: 'AWANDA',
          idTransaksi: '2633953',
          showSubsidi: false,
          footerText: 'Catatan khusus Pertamina Dex',
        ),
      ),
    );

    final receiptLines = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.style?.fontFamily == 'Droid Sans Mono')
        .map((text) => text.data ?? '')
        .toList();
    final receiptText = receiptLines.join('\n');
    final orderedRows = [
      'Pulau/Pompa: 14',
      'Nama Produk: PERTAMINA_DEX',
      'Harga/Liter: Rp. 16,000',
      'Volume     : (L) 2.00',
      'Total Harga: Rp. 32,000',
      'Operator   : AWANDA',
      'CASH',
      'Catatan khusus Pertamina Dex',
    ];
    final rowIndexes = orderedRows
        .map((row) => receiptLines.indexWhere((line) => line.contains(row)))
        .toList();
    expect(rowIndexes.every((index) => index >= 0), isTrue);
    expect(rowIndexes, orderedEquals([...rowIndexes]..sort()));
    final cashIndex = receiptLines.indexOf('CASH');
    final cashAmountIndex = receiptLines.indexWhere(
      (line) => line.trim() == '32,000',
    );
    final footnoteIndex = receiptLines.indexWhere(
      (line) => line.contains('Catatan khusus Pertamina Dex'),
    );
    expect(cashAmountIndex, cashIndex + 1);
    expect(receiptLines[cashIndex + 2], matches(r'^-+$'));
    expect(receiptText, isNot(contains('Harga Non Subsidi')));
    expect(receiptText, isNot(contains('Dibayar Konsumen')));
    expect(receiptText, isNot(contains('No. Plat')));
    expect(
      receiptLines.indexWhere((line) => line.contains('Operator')),
      lessThan(cashIndex),
    );
    expect(receiptLines[footnoteIndex - 1], matches(r'^-+$'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('teen-thousand total subsidy has no extra space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PreviewStrukScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          totalBayar: 15000,
          estimasiLiter: 1,
          platNomor: '',
          namaSpbu: 'SPBU SENTRA BISNIS ARTHA',
          shift: 2,
          pompa: 14,
          tanggalWaktu: '16/10/2026 07:19:55',
          namaOperator: 'AWANDA',
          hargaNonSubsidi: 18101,
          subsidiPemerintah: 15000,
          idTransaksi: '2633953',
        ),
      ),
    );

    expect(find.text('Subsidi Pemerintah : 15,000'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('receipt totals align their last digit without extra spaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PreviewStrukScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          totalBayar: 25000,
          estimasiLiter: 1,
          platNomor: '',
          namaSpbu: 'SPBU SENTRA BISNIS ARTHA',
          shift: 2,
          pompa: 14,
          tanggalWaktu: '16/10/2026 07:19:55',
          namaOperator: 'AWANDA',
          hargaNonSubsidi: 18101,
          subsidiPemerintah: 25000,
          idTransaksi: '2633953',
        ),
      ),
    );

    expect(find.text('Subsidi Pemerintah : 25,000'), findsNWidgets(2));
    expect(find.text('Subsidi Pemerintah :  25,000'), findsNothing);
    final totalLines = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.style?.fontFamily == 'Droid Sans Mono')
        .map((text) => text.data ?? '')
        .where(
          (line) =>
              line.contains('Tanpa Subsidi') ||
              line.contains('Subsidi Pemerintah') ||
              line.contains('Dibayar Konsumen'),
        )
        .toList();
    final finalDigitPositions = totalLines
        .map((line) => line.lastIndexOf(line.split(':').last.trim()))
        .toSet();
    expect(finalDigitPositions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('receipt totals with millions keep their last digits aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PreviewStrukScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          totalBayar: 1000000,
          estimasiLiter: 100,
          platNomor: '',
          namaSpbu: 'SPBU SENTRA BISNIS ARTHA',
          shift: 2,
          pompa: 14,
          tanggalWaktu: '16/10/2026 07:19:55',
          namaOperator: 'AWANDA',
          hargaNonSubsidi: 18101,
          subsidiPemerintah: 8101,
          idTransaksi: '2633953',
        ),
      ),
    );

    final totalLines = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.style?.fontFamily == 'Droid Sans Mono')
        .map((text) => text.data ?? '')
        .where(
          (line) =>
              line.contains('Tanpa Subsidi') ||
              line.contains('Subsidi Pemerintah') ||
              line.contains('Dibayar Konsumen'),
        )
        .toList();
    final expectedTotals = [
      'Tanpa Subsidi      : 1,810,100',
      'Subsidi Pemerintah :   810,100',
      'Dibayar Konsumen   : 1,000,000',
    ];
    for (final expected in expectedTotals) {
      expect(totalLines, contains(expected));
    }

    final finalDigitPositions = totalLines
        .where((line) => expectedTotals.any((expected) => line == expected))
        .map((line) {
          final value = line.split(':').last.trim();
          return line.lastIndexOf(value) + value.length - 1;
        })
        .toSet();
    expect(finalDigitPositions, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview shows 58 mm receipt and print actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PreviewStrukScreen(
          namaBbm: 'PERTALITE',
          hargaPerLiter: 10000,
          totalBayar: 300000,
          estimasiLiter: 30,
          platNomor: 'B1024DKG',
          namaSpbu: 'SPBU SENTRA BISNIS ARTHA',
          shift: 2,
          pompa: 14,
          tanggalWaktu: '16/10/2026 07:19:55',
          namaOperator: 'AWANDA',
          hargaNonSubsidi: 18101,
          subsidiPemerintah: 8101,
          idTransaksi: '2633953',
          footerText:
              'Anda mendapat subsidi dari\n'
              'Pemerintah sebesar Rp {subsidi}\n'
              '(Perhitungan Subsidi Unaudited\n'
              'atau Estimasi). Gunakan BBM\n'
              'Subsidi secara bijak.',
        ),
      ),
    );

    expect(find.text('Preview Struk'), findsOneWidget);
    expect(find.text('Pilih Template'), findsNothing);
    expect(find.text('Template 7 (Subsidi)'), findsNothing);
    final logo = tester.widget<Image>(find.byType(Image).first);
    expect(logo.image, isA<AssetImage>());
    expect((logo.image as AssetImage).assetName, defaultReceiptLogoAsset);
    expect(
      tester.getSize(find.byKey(const ValueKey('receipt-logo'))).width,
      closeTo(
        (tester.getSize(find.byKey(const ValueKey('receipt-preview'))).width -
                16) *
            0.4437,
        1,
      ),
    );
    expect(find.textContaining('SPBU SENTRA BISNIS ARTHA'), findsOneWidget);
    expect(find.textContaining('Dibayar Konsumen'), findsOneWidget);
    expect(find.text('Cetak Struk'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('receipt-preview'))).dx,
      closeTo(180, 1),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('receipt-preview'))).width,
      closeTo(328, 1), // dibatasi lebar layar uji (360 - 2 * 16)
    );
    final receiptLines = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.style?.fontFamily == 'Droid Sans Mono')
        .toList();
    final receiptText = receiptLines.map((text) => text.data ?? '').join('\n');
    expect(receiptLines.first.style!.fontSize!, greaterThan(1));
    expect(receiptLines.first.style!.fontSize!, lessThan(13));
    expect(receiptText, contains('Pulau/Pompa : 14'));
    expect(receiptText, contains('Volume      : 30.00 liter'));
    expect(receiptText, contains('Operator    : AWANDA'));
    expect(receiptText, contains('Harga Non Subsidi  : 18,101'));
    expect(receiptText, contains('Subsidi Pemerintah :  8,101'));
    expect(receiptText, contains('Harga Jual         : 10,000'));
    expect(receiptText, contains('Tanpa Subsidi      : 543,030'));
    expect(receiptText, contains('Subsidi Pemerintah : 243,030'));
    expect(receiptText, contains('Dibayar Konsumen   : 300,000'));
    expect(receiptText, contains('${' ' * 28}300,000'));
    expect(receiptText, contains('No. Plat  : B1024DKG'));
    expect(receiptText, contains('No. Trans: 2633953'));
    expect(receiptText, contains('CASH'));
    expect(receiptText, contains('No. Plat  : B1024DKG'));
    expect(receiptText, contains('Pemerintah sebesar Rp 243,030'));
    expect(receiptText, contains('(Perhitungan Subsidi Unaudited'));
    expect(receiptText, isNot(contains('FootNote')));
    for (final centeredLine in [
      '3414210',
      'SPBU SENTRA BISNIS ARTHA',
      'JL. SENTRA BISNIS ARTHA GADING',
      'Anda mendapat subsidi dari',
      'Subsidi secara bijak.',
    ]) {
      final text = receiptLines.firstWhere((text) => text.data == centeredLine);
      expect(text.textAlign, TextAlign.center, reason: centeredLine);
    }
    expect(
      receiptLines
          .firstWhere((text) => text.data == '3414210')
          .style
          ?.fontWeight,
      FontWeight.bold,
    );
    expect(
      receiptLines
          .firstWhere((text) => text.data?.trim() == 'No. Plat  : B1024DKG')
          .textAlign,
      TextAlign.left,
    );
    expect(
      receiptLines.any(
        (text) =>
            text.textAlign == TextAlign.center &&
            (text.data ?? '').trim().split('').every((char) => char == '-'),
      ),
      isTrue,
    );
    await tester.tap(find.text('Simpan Sebagai File PDF / JPG'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan Struk sebagai'), findsOneWidget);
    expect(find.text('File PDF'), findsOneWidget);
    expect(find.text('File JPG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
