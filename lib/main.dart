import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  runApp(const DateFixerApp());
}

class DateFixerApp extends StatelessWidget {
  const DateFixerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EXIF Date Fixer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const ImageListPage(),
    );
  }
}

class ImageRecord {
  ImageRecord({
    required this.asset,
    required this.name,
    required this.exifDate,
    required this.nameDate,
    required this.selected,
  });

  final AssetEntity asset;
  final String name;
  final DateTime? exifDate;
  final DateTime? nameDate;
  bool selected;

  bool get isMatch {
    if (exifDate == null || nameDate == null) {
      return false;
    }
    return exifDate!.year == nameDate!.year &&
        exifDate!.month == nameDate!.month &&
        exifDate!.day == nameDate!.day &&
        exifDate!.hour == nameDate!.hour &&
        exifDate!.minute == nameDate!.minute &&
        exifDate!.second == nameDate!.second;
  }
}

class DateFilePattern {
  DateFilePattern({required this.regex, required this.parser});

  final RegExp regex;
  final DateTime Function(RegExpMatch match) parser;
}

class ImageListPage extends StatefulWidget {
  const ImageListPage({super.key});

  @override
  State<ImageListPage> createState() => _ImageListPageState();
}

class _ImageListPageState extends State<ImageListPage> {
  final DateFormat _exifFormat = DateFormat('yyyy:MM:dd HH:mm:ss');
  final DateFormat _displayFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  final List<DateFilePattern> _patterns = [
    DateFilePattern(
      regex: RegExp(r'IMG_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})', caseSensitive: false),
      parser: (match) => DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      ),
    ),
    DateFilePattern(
      regex: RegExp(r'(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})'),
      parser: (match) => DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      ),
    ),
    DateFilePattern(
      regex: RegExp(r'(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})'),
      parser: (match) => DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      ),
    ),
    DateFilePattern(
      regex: RegExp(
        r'(\d{4})[-_](\d{2})[-_](\d{2})[ _-](\d{2})[.:\-](\d{2})[.:\-](\d{2})',
      ),
      parser: (match) => DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      ),
    ),
    DateFilePattern(
      regex: RegExp(
        r'WhatsApp Image (\d{4})-(\d{2})-(\d{2}) at (\d{2})\.(\d{2})\.(\d{2})',
        caseSensitive: false,
      ),
      parser: (match) => DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      ),
    ),
  ];

  final List<ImageRecord> _images = [];

  bool _loading = true;
  bool _fixing = false;
  bool _permissionDenied = false;
  bool _cancelScanRequested = false;
  int _scanProcessed = 0;
  int _scanTotal = 0;
  String _scanAlbum = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
      _cancelScanRequested = false;
      _scanProcessed = 0;
      _scanTotal = 0;
      _scanAlbum = '';
      _error = null;
      _images.clear();
    });

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        setState(() {
          _loading = false;
          _permissionDenied = true;
          _error = 'Permission denied. Please allow photo access.';
        });
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      final pathInfos = <({AssetPathEntity path, int count})>[];
      var totalAssets = 0;
      for (final path in paths) {
        final count = await path.assetCountAsync;
        pathInfos.add((path: path, count: count));
        totalAssets += count;
      }

      if (mounted) {
        setState(() {
          _scanTotal = totalAssets;
        });
      }

      final records = <ImageRecord>[];
      var processed = 0;
      var wasCancelled = false;

      for (final info in pathInfos) {
        if (_cancelScanRequested) {
          wasCancelled = true;
          break;
        }

        final path = info.path;
        final count = info.count;
        if (mounted) {
          setState(() {
            _scanAlbum = path.name;
          });
        }

        const pageSize = 200;
        final pages = (count / pageSize).ceil();

        for (var page = 0; page < pages; page++) {
          if (_cancelScanRequested) {
            wasCancelled = true;
            break;
          }

          final assets = await path.getAssetListPaged(page: page, size: pageSize);
          for (final asset in assets) {
            if (_cancelScanRequested) {
              wasCancelled = true;
              break;
            }

            processed++;
            if (mounted && (processed % 25 == 0 || processed == totalAssets)) {
              setState(() {
                _scanProcessed = processed;
              });
            }

            final file = await asset.file;
            if (file == null) {
              continue;
            }

            final name = asset.title ?? file.uri.pathSegments.last;
            final exifDate = await _readExifDate(file);
            final nameDate = _parseDateFromFileName(name);

            final record = ImageRecord(
              asset: asset,
              name: name,
              exifDate: exifDate,
              nameDate: nameDate,
              selected: true,
            );
            record.selected = !record.isMatch;
            records.add(record);
          }

          if (wasCancelled) {
            break;
          }
        }

        if (wasCancelled) {
          break;
        }
      }

      setState(() {
        _images
          ..clear()
          ..addAll(records);
        _scanProcessed = processed;
        _loading = false;
      });

      if (wasCancelled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search canceled. ${records.length} image(s) found.')),
        );
      }
    } catch (error) {
      setState(() {
        _loading = false;
        _permissionDenied = false;
        _error = 'Failed to load images: $error';
      });
    }
  }

  Future<void> _resolvePermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (permission.hasAccess) {
      await _loadImages();
      return;
    }
    await PhotoManager.openSetting();
  }

  void _cancelSearch() {
    if (!_loading || _cancelScanRequested) {
      return;
    }
    setState(() {
      _cancelScanRequested = true;
    });
  }

  DateTime? _parseDateFromFileName(String name) {
    final baseName = name.replaceAll(RegExp(r'\\.[^.]+$'), '');
    for (final pattern in _patterns) {
      final match = pattern.regex.firstMatch(baseName);
      if (match == null) {
        continue;
      }
      try {
        return pattern.parser(match);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<DateTime?> _readExifDate(File file) async {
    Exif? exif;
    try {
      exif = await Exif.fromPath(file.path);
      final dateValue = await exif.getAttribute('DateTimeOriginal') ??
          await exif.getAttribute('DateTimeDigitized') ??
          await exif.getAttribute('DateTime');
      if (dateValue == null || dateValue.trim().isEmpty) {
        return null;
      }
      return _exifFormat.parseStrict(dateValue.trim());
    } catch (_) {
      return null;
    } finally {
      await exif?.close();
    }
  }

  Future<void> _fixSelected() async {
    setState(() {
      _fixing = true;
    });

    var fixed = 0;
    var skipped = 0;

    try {
      for (final record in _images.where((item) => item.selected)) {
        if (record.nameDate == null) {
          skipped++;
          continue;
        }

        final file = await record.asset.file;
        if (file == null) {
          skipped++;
          continue;
        }

        Exif? exif;
        try {
          exif = await Exif.fromPath(file.path);
          final value = _exifFormat.format(record.nameDate!);
          await exif.writeAttribute('DateTimeOriginal', value);
          await exif.writeAttribute('DateTimeDigitized', value);
          await exif.writeAttribute('DateTime', value);
          fixed++;
        } catch (_) {
          skipped++;
        } finally {
          await exif?.close();
        }
      }

      await _loadImages();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fixed: $fixed | Skipped: $skipped')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _fixing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _images.where((item) => item.selected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EXIF Date Fixer'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadImages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _fixing || selectedCount == 0 ? null : _fixSelected,
            icon: _fixing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.build),
            label: Text('Fix selected images ($selectedCount)'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      final progress = _scanTotal > 0 ? _scanProcessed / _scanTotal : null;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              const Text('Searching images...'),
              if (_scanTotal > 0) ...[
                const SizedBox(height: 8),
                Text('$_scanProcessed / $_scanTotal processed'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
              ],
              if (_scanAlbum.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Album: $_scanAlbum', textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cancelScanRequested ? null : _cancelSearch,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(_cancelScanRequested ? 'Cancelling...' : 'Cancel search'),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadImages,
                child: const Text('Try again'),
              ),
              if (_permissionDenied) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _resolvePermission,
                  child: const Text('Grant permission'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(child: Text('No images found on device.'));
    }

    final mismatchCount = _images.where((item) => !item.isMatch).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Images: ${_images.length} | Mismatch: $mismatchCount | Selected: ${_images.where((item) => item.selected).length}',
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _images.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _images[index];
              final subtitle =
                  'EXIF: ${_formatDate(item.exifDate)}  |  Name: ${_formatDate(item.nameDate)}';

              return CheckboxListTile(
                value: item.selected,
                onChanged: (value) {
                  setState(() {
                    item.selected = value ?? false;
                  });
                },
                title: Text(item.name),
                subtitle: Text(
                  '$subtitle\nStatus: ${item.isMatch ? 'match' : 'mismatch'}',
                ),
                isThreeLine: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'not found';
    }
    return _displayFormat.format(date);
  }
}
