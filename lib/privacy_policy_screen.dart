import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: 'Data yang disimpan aplikasi',
      body:
          'NotaBBM tidak mewajibkan akun. Data transaksi dan pengaturan '
          'seperti jenis dan jumlah BBM, total pembayaran, nomor polisi jika '
          'diisi, waktu transaksi, data SPBU, nama operator, serta preferensi '
          'nota disimpan di database lokal pada perangkat. NotaBBM tidak '
          'mengirim isi data tersebut ke server milik pengembang.',
    ),
    (
      title: 'Iklan',
      body:
          'Aplikasi menggunakan Google Mobile Ads (AdMob). Google dapat '
          'memproses informasi perangkat atau pengenal iklan, interaksi '
          'dengan iklan, dan data diagnostik untuk menayangkan serta '
          'mengukur iklan dan mencegah penyalahgunaan, sesuai pengaturan '
          'perangkat dan kebijakan Google. Informasi lebih lanjut tersedia '
          'di policies.google.com/privacy.',
    ),
    (
      title: 'Berbagi file dan pencetakan',
      body:
          'Jika Anda memilih membagikan nota, aplikasi membuat file PDF atau '
          'JPG dan menyerahkannya ke aplikasi tujuan yang Anda pilih. '
          'Aplikasi tujuan kemudian menangani file tersebut sesuai '
          'kebijakannya. Jika Anda mencetak, data nota dikirim melalui '
          'Bluetooth ke printer yang Anda pilih.',
    ),
    (
      title: 'Penyimpanan dan penghapusan',
      body:
          'Data lokal tersimpan sampai Anda menghapus data aplikasi melalui '
          'pengaturan Android atau menghapus aplikasi. File yang sudah '
          'dibagikan atau disimpan di luar NotaBBM perlu dihapus dari lokasi '
          'atau aplikasi tujuan secara terpisah. Data iklan yang diproses '
          'Google tunduk pada pengaturan dan kebijakan Google.',
    ),
    (
      title: 'Keamanan dan anak-anak',
      body:
          'Data lokal berada di penyimpanan privat aplikasi pada perangkat. '
          'Aplikasi ini tidak ditujukan untuk anak di bawah 13 tahun.',
    ),
    (
      title: 'Perubahan kebijakan',
      body:
          'Kebijakan ini dapat diperbarui jika fitur atau praktik '
          'pemrosesan data berubah. Versi terbaru akan tersedia di halaman '
          'kebijakan privasi publik.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Terakhir diperbarui: 27 Oktober 2026'),
          const SizedBox(height: 12),
          const Text(
            'Kebijakan ini menjelaskan bagaimana Karya Tunggal Apps '
            'menangani informasi saat Anda menggunakan NotaBBM.',
          ),
          for (final section in _sections) ...[
            const SizedBox(height: 20),
            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(section.body),
          ],
          const SizedBox(height: 20),
          Text('Kontak', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const SelectableText('085158778607'),
        ],
      ),
    );
  }
}
