import 'ads_service.dart';
import 'form_transaksi.dart';
import 'menu_screens.dart';
import 'privacy_policy_screen.dart';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'database/database_helper.dart'; // Memanggil file database yang baru dibuat

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NotaBBM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF23B2EE)),
        primaryColor: const Color(0xFF23B2EE),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Variabel untuk menyimpan data dari database
  List<Map<String, dynamic>> bbmList = [];
  bool isLoading = true; // Indikator loading
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _muatDataBBM(); // Memanggil fungsi ambil data saat aplikasi pertama kali dibuka
  }

  // Fungsi untuk mengambil data BBM dari SQLite
  Future<void> _muatDataBBM() async {
    final data = await DatabaseHelper.instance.getSemuaBBM();
    final urut = List<Map<String, dynamic>>.from(data);
    final iGreen = urut.indexWhere(
      (b) => b['nama_bbm'].toString().toUpperCase() == 'PERTAMAX GREEN',
    );
    if (iGreen != -1) {
      final green = urut.removeAt(iGreen);
      final iTurbo = urut.indexWhere(
        (b) => b['nama_bbm'].toString().toUpperCase() == 'PERTAMAX TURBO',
      );
      urut.insert(iTurbo == -1 ? urut.length : iTurbo + 1, green);
    }
    setState(() {
      bbmList = urut;
      isLoading = false; // Matikan loading setelah data didapat
    });
  }

  Widget _menuItem(IconData icon, String title, Widget Function() page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () async {
        // Drawer dibiarkan terbuka agar tombol kembali mengembalikan ke Preferensi Nota
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page()),
        );
        _muatDataBBM(); // harga mungkin berubah
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF23B2EE),
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.local_gas_station, color: Colors.black),
            SizedBox(width: 8),
            Text(
              'Pilih BBM',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: const [
          SizedBox(width: 48), // Penyeimbang posisi tengah
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF23B2EE)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Preferensi Nota',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfoFuture,
                    builder: (context, snapshot) {
                      final packageInfo = snapshot.data;
                      final versionText = snapshot.hasError
                          ? 'Versi aplikasi tidak tersedia'
                          : packageInfo == null
                          ? 'Memuat versi aplikasi...'
                          : 'Versi ${packageInfo.version}+${packageInfo.buildNumber}';
                      return Text(
                        versionText,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            _menuItem(
              Icons.local_gas_station,
              'Harga BBM',
              () => const HargaBbmScreen(),
            ),
            _menuItem(
              Icons.person,
              'Nama Operator',
              () => const OperatorScreen(),
            ),
            _menuItem(Icons.store, 'Data SPBU', () => const DataSpbuScreen()),
            _menuItem(
              Icons.receipt_long,
              'Footer Nota',
              () => const FooterNotaScreen(),
            ),
            _menuItem(
              Icons.privacy_tip_outlined,
              'Kebijakan Privasi',
              () => const PrivacyPolicyScreen(),
            ),
          ],
        ),
      ),
      // Tampilkan animasi muter (loading) jika data belum siap
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF23B2EE)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Ukuran kartu menyesuaikan tinggi layar agar semua BBM muat
                  const spacing = 16.0;
                  final rows = (bbmList.length / 2).ceil().clamp(1, 100);
                  final cellWidth = (constraints.maxWidth - spacing) / 2;
                  final cellHeight =
                      (constraints.maxHeight - spacing * (rows - 1)) / rows;
                  return GridView.builder(
                    physics: const ClampingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: cellWidth / cellHeight,
                    ),
                    itemCount: bbmList.length,
                    itemBuilder: (context, index) {
                      final bbm = bbmList[index];
                      // Mengubah teks warna (contoh: '0xFF1ABC9C') dari database menjadi warna asli (Color)
                      Color warnaCard = Color(int.parse(bbm['warna_hex']));

                      return _buildBbmCard(
                        context,
                        bbm['nama_bbm'],
                        bbm['harga_per_liter'],
                        warnaCard,
                      );
                    },
                  );
                },
              ),
            ),
      bottomNavigationBar: kShowAds
          ? const Align(
              heightFactor: 1,
              alignment: Alignment.center,
              child: BannerAdWidget(),
            )
          : null,
    );
  }

  // Desain tombol BBM
  Widget _buildBbmCard(
    BuildContext context,
    String nama,
    int harga,
    Color warna,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FormTransaksiScreen(
              namaBbm: nama,
              hargaPerLiter: harga,
              warnaBbm: warna,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: warna,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_gas_station,
                  size: 50,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  nama,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Rp $harga/L',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
