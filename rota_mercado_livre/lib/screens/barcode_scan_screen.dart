import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/database_helper.dart';
import '../theme/sb2.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: [BarcodeFormat.all],
  );
  final _db = DatabaseHelper();
  String _last = '';
  int _ok = 0;
  int _naoEncontrado = 0;
  bool _paused = false;
  final Set<String> _scanned = <String>{};

  Future<void> _process(String raw) async {
    // Heurística: prioriza 11 dígitos (ex.: 46509912627). Se vier maior, usa os 11 últimos.
    String id = '';
    final m11 = RegExp(r'\d{11}').firstMatch(raw);
    if (m11 != null) {
      id = m11.group(0)!;
    } else {
      final m10p = RegExp(r'\d{10,}').firstMatch(raw);
      if (m10p != null) {
        final s = m10p.group(0)!;
        id = s.length > 11 ? s.substring(s.length - 11) : s;
      } else {
        final md = RegExp(r'\d{6,}').firstMatch(raw);
        if (md != null) id = md.group(0)!;
      }
    }
    setState(() => _last = id.isEmpty ? raw : id);
    if (id.isEmpty) return;
    if (_scanned.contains(id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ID repetido: $id')));
      }
      return;
    }
    final updated = await _db.conferirSeNaoConferidoPorIdPacote(id);
    if (updated > 0) {
      _scanned.add(id);
      setState(() => _ok += 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conferido $id')));
      }
    } else {
      final item = await _db.getRomaneioByIdPacote(id);
      if (item != null && (item['status'] == 'conferido')) {
        _scanned.add(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Já conferido: $id')));
        }
      } else {
        setState(() => _naoEncontrado += 1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ID não encontrado: $id')));
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxWidth = size.width * 0.82;
    final boxHeight = size.height * 0.34;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner de Código de Barras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: boxWidth,
                          height: boxHeight,
                          child: MobileScanner(
                            controller: _controller,
                            onDetect: (capture) {
                              if (_paused) return;
                              for (final b in capture.barcodes) {
                                final raw = b.rawValue ?? '';
                                if (raw.isEmpty) continue;
                                _paused = true;
                                _process(raw).whenComplete(() {
                                  Future.delayed(const Duration(milliseconds: 600), () {
                                    _paused = false;
                                  });
                                });
                                break;
                              }
                            },
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _ScanFramePainter(),
                          size: Size(boxWidth, boxHeight),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  color: Colors.black54,
                  padding: const EdgeInsets.all(12),
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.white),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Último: ${_last.isEmpty ? '—' : _last}'),
                        const SizedBox(height: 4),
                        Text('Conferidos: $_ok • Não encontrados: $_naoEncontrado'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: SB2.surface,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Fechar'),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final edge = 24.0;
    // corners
    // top-left
    canvas.drawLine(Offset(0, 0), Offset(edge, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, edge), paint);
    // top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - edge, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, edge), paint);
    // bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(edge, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - edge), paint);
    // bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - edge, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - edge), paint);
    // middle guide line
    canvas.drawLine(Offset(12, size.height / 2), Offset(size.width - 12, size.height / 2), paint..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
