import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:internet_file/internet_file.dart';

class PdfViewer extends StatefulWidget {
  final String url;
  final String title;

  const PdfViewer({super.key, required this.url, required this.title});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late PdfControllerPinch pdfController;

  @override
  void initState() {
    super.initState();
    pdfController = PdfControllerPinch(
      document: PdfDocument.openData(InternetFile.get(widget.url)),
    );
  }

  @override
  void dispose() {
    pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PdfViewPinch(
        controller: pdfController,
      ),
    );
  }
}
