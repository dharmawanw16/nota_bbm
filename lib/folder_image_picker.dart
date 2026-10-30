import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';
import 'package:saf_util/saf_util_platform_interface.dart';

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'};

/// Penelusur folder berbasis Storage Access Framework. Pengguna memilih satu
/// folder (izin diberikan lewat dialog sistem), lalu dapat membuka subfolder
/// dan memilih gambar, termasuk yang tidak muncul di galeri.
/// Mengembalikan path salinan gambar di penyimpanan privat aplikasi.
class FolderImagePickerScreen extends StatefulWidget {
  const FolderImagePickerScreen({super.key, required this.root});

  final SafDocumentFile root;

  /// Meminta pengguna memilih folder, lalu membuka penelusur.
  static Future<String?> pick(BuildContext context) async {
    final folder = await SafUtil().pickDirectory();
    if (folder == null || !context.mounted) return null;
    return Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => FolderImagePickerScreen(root: folder)),
    );
  }

  @override
  State<FolderImagePickerScreen> createState() =>
      _FolderImagePickerScreenState();
}

class _FolderImagePickerScreenState extends State<FolderImagePickerScreen> {
  final _saf = SafUtil();
  final _stack = <SafDocumentFile>[];
  List<SafDocumentFile> _items = [];
  bool _loading = true;
  String? _error;

  SafDocumentFile get _current => _stack.last;

  @override
  void initState() {
    super.initState();
    _stack.add(widget.root);
    _load();
  }

  bool _isImage(SafDocumentFile f) =>
      !f.isDir && _imageExtensions.contains(p.extension(f.name).toLowerCase());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _saf.list(_current.uri);
      final shown = all.where((f) => f.isDir || _isImage(f)).toList()
        ..sort((a, b) {
          if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      if (!mounted) return;
      setState(() {
        _items = shown;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Folder tidak dapat dibuka: $error';
        _loading = false;
      });
    }
  }

  Future<void> _open(SafDocumentFile item) async {
    if (item.isDir) {
      _stack.add(item);
      await _load();
      return;
    }
    try {
      final dir = await getApplicationSupportDirectory();
      final logoDir = Directory(p.join(dir.path, 'logo'))
        ..createSync(recursive: true);
      final ext = p.extension(item.name).toLowerCase();
      final dest = p.join(
        logoDir.path,
        'logo_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await SafStream().copyToLocalFile(item.uri, dest);
      if (mounted) Navigator.pop(context, dest);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gambar tidak dapat dibuka: $error')),
      );
    }
  }

  Future<bool> _goUp() async {
    if (_stack.length <= 1) return true;
    _stack.removeLast();
    await _load();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stack.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF23B2EE),
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(
            _current.name,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items.isEmpty) {
      return const Center(child: Text('Tidak ada gambar atau subfolder'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return InkWell(
          onTap: () => _open(item),
          child: item.isDir
              ? _FolderTile(name: item.name)
              : _ImageTile(item: item, saf: _saf),
        );
      },
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.folder, size: 56, color: Color(0xFF23B2EE)),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _ImageTile extends StatefulWidget {
  const _ImageTile({required this.item, required this.saf});

  final SafDocumentFile item;
  final SafUtil saf;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  late final Future<String?> _thumb = _makeThumb();

  Future<String?> _makeThumb() async {
    final cache = await getTemporaryDirectory();
    final dest = p.join(
      cache.path,
      'thumb_${widget.item.uri.hashCode}_${widget.item.lastModified}.jpg',
    );
    if (File(dest).existsSync()) return dest;
    final ok = await widget.saf.saveThumbnailToFile(
      uri: widget.item.uri,
      width: 200,
      height: 200,
      destPath: dest,
    );
    return ok ? dest : null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder<String?>(
          future: _thumb,
          builder: (context, snapshot) {
            final path = snapshot.data;
            if (path == null) {
              return const ColoredBox(
                color: Color(0xFFE0E0E0),
                child: Icon(Icons.image_outlined, color: Colors.grey),
              );
            }
            return Image.file(File(path), fit: BoxFit.cover);
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(2),
            child: Text(
              widget.item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}
