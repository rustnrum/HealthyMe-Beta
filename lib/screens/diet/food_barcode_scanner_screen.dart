import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';

/// On-device ML Kit scanning. Raw barcodes are looked up only after the user
/// explicitly scans; camera frames are never sent to the food database.
class FoodBarcodeScannerScreen extends StatefulWidget {
  const FoodBarcodeScannerScreen({super.key});

  @override
  State<FoodBarcodeScannerScreen> createState() => _FoodBarcodeScannerScreenState();
}

class _FoodBarcodeScannerScreenState extends State<FoodBarcodeScannerScreen> {
  bool _scanned = false;
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8,
      BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.itf14],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    if (_scanned || !mounted) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue?.trim() ?? '';
      // Packaged food UPC-A, EAN-8, EAN-13 and GTIN-14. No arbitrary QR URLs.
      if (!RegExp(r'^\d{8,14}$').hasMatch(code)) continue;
      _scanned = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Scan food barcode'),
      backgroundColor: Colors.black,
    ),
    body: SafeArea(child: Column(children: [
      Expanded(child: Stack(fit: StackFit.expand, children: [
        MobileScanner(controller: _controller, onDetect: _detected),
        IgnorePointer(child: Center(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 34),
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.mint, width: 3),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Center(child: Icon(Icons.qr_code_scanner_rounded,
              color: AppTheme.mint, size: 42)),
        ))),
      ])),
      const Padding(
        padding: EdgeInsets.fromLTRB(20, 17, 20, 26),
        child: Text('Point the camera at the UPC or EAN code on the package. '
            'Salus will look up the food automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
      ),
    ])),
  );
}
