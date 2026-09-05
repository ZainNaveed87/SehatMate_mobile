import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../services/document_service.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.file});

  final DocumentFile file;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  static const double _minImageScale = 1;
  static const double _maxImageScale = 5;

  final TransformationController _imageController = TransformationController();
  final PdfViewerController _pdfController = PdfViewerController();

  int _rotationTurns = 0;
  double _imageScale = 1;
  int _pdfPage = 1;
  int _pdfPageCount = 0;

  @override
  void initState() {
    super.initState();
    _pdfController.addListener(_syncPdfState);
  }

  @override
  void dispose() {
    _pdfController.removeListener(_syncPdfState);
    _imageController.dispose();
    super.dispose();
  }

  void _syncPdfState() {
    if (!mounted || !_pdfController.isReady) return;

    final page = _pdfController.pageNumber ?? 1;
    final count = _pdfController.pageCount;

    if (page == _pdfPage && count == _pdfPageCount) return;

    setState(() {
      _pdfPage = page;
      _pdfPageCount = count;
    });
  }

  void _rotateLeft() {
    setState(() {
      _rotationTurns = (_rotationTurns + 3) % 4;
    });
  }

  void _rotateRight() {
    setState(() {
      _rotationTurns = (_rotationTurns + 1) % 4;
    });
  }

  void _setImageScale(double nextScale) {
    final target = nextScale.clamp(_minImageScale, _maxImageScale).toDouble();
    final matrix = _imageController.value.clone();

    matrix.setEntry(0, 0, target);
    matrix.setEntry(1, 1, target);

    _imageController.value = matrix;
    setState(() => _imageScale = target);
  }

  void _zoomImageIn() => _setImageScale(_imageScale + 0.5);

  void _zoomImageOut() => _setImageScale(_imageScale - 0.5);

  void _resetImage() {
    final matrix = _imageController.value.clone()..setIdentity();
    _imageController.value = matrix;

    setState(() {
      _imageScale = 1;
      _rotationTurns = 0;
    });
  }

  Future<void> _zoomPdfIn() async {
    if (!_pdfController.isReady) return;
    await _pdfController.zoomUp();
  }

  Future<void> _zoomPdfOut() async {
    if (!_pdfController.isReady) return;
    await _pdfController.zoomDown();
  }

  Future<void> _previousPdfPage() async {
    if (!_pdfController.isReady) return;
    final current = _pdfController.pageNumber ?? _pdfPage;
    if (current <= 1) return;

    await _pdfController.goToPage(
      pageNumber: current - 1,
      anchor: PdfPageAnchor.top,
    );
  }

  Future<void> _nextPdfPage() async {
    if (!_pdfController.isReady) return;

    final current = _pdfController.pageNumber ?? _pdfPage;
    final count = _pdfController.pageCount;

    if (current >= count) return;

    await _pdfController.goToPage(
      pageNumber: current + 1,
      anchor: PdfPageAnchor.top,
    );
  }

  Future<void> _resetPdf() async {
    final page = _pdfController.isReady
        ? (_pdfController.pageNumber ?? _pdfPage)
        : _pdfPage;

    setState(() => _rotationTurns = 0);

    if (!_pdfController.isReady) return;

    await _pdfController.goToPage(pageNumber: page, anchor: PdfPageAnchor.all);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          widget.file.originalName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: AppColors.card,
                child: _buildViewer(context),
              ),
            ),
            _buildToolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(BuildContext context) {
    if (widget.file.isImage) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ClipRect(
            child: RotatedBox(
              quarterTurns: _rotationTurns,
              child: InteractiveViewer(
                key: const Key('document_image_viewer'),
                transformationController: _imageController,
                minScale: _minImageScale,
                maxScale: _maxImageScale,
                boundaryMargin: const EdgeInsets.all(120),
                onInteractionEnd: (_) {
                  if (!mounted) return;
                  final scale = _imageController.value
                      .getMaxScaleOnAxis()
                      .clamp(_minImageScale, _maxImageScale)
                      .toDouble();
                  if ((_imageScale - scale).abs() < 0.01) return;
                  setState(() => _imageScale = scale);
                },
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Center(
                    child: Image.memory(
                      widget.file.bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _ViewerMessage(
                            icon: Icons.broken_image_outlined,
                            text: context.tr('document_open_failed'),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.file.isPdf) {
      return RotatedBox(
        quarterTurns: _rotationTurns,
        child: PdfViewer.data(
          widget.file.bytes,
          sourceName: widget.file.originalName,
          controller: _pdfController,
        ),
      );
    }

    return _ViewerMessage(
      icon: Icons.description_outlined,
      text: context.tr('document_viewer_unsupported'),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final children = widget.file.isPdf
        ? _pdfToolbarButtons(context)
        : _imageToolbarButtons(context);

    return Material(
      color: AppColors.background,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _imageToolbarButtons(BuildContext context) {
    return [
      _ToolbarButton(
        key: const Key('document_viewer_zoom_out'),
        icon: Icons.zoom_out,
        label: context.tr('document_viewer_zoom_out'),
        onPressed: _imageScale <= _minImageScale ? null : _zoomImageOut,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_zoom_in'),
        icon: Icons.zoom_in,
        label: context.tr('document_viewer_zoom_in'),
        onPressed: _imageScale >= _maxImageScale ? null : _zoomImageIn,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_rotate_left'),
        icon: Icons.rotate_left,
        label: context.tr('document_viewer_rotate_left'),
        onPressed: _rotateLeft,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_rotate_right'),
        icon: Icons.rotate_right,
        label: context.tr('document_viewer_rotate_right'),
        onPressed: _rotateRight,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_reset'),
        icon: Icons.restart_alt,
        label: context.tr('document_viewer_reset'),
        onPressed: _resetImage,
      ),
    ];
  }

  List<Widget> _pdfToolbarButtons(BuildContext context) {
    final ready = _pdfController.isReady;
    final count = ready ? _pdfController.pageCount : _pdfPageCount;
    final page = ready ? (_pdfController.pageNumber ?? _pdfPage) : _pdfPage;

    return [
      _ToolbarButton(
        key: const Key('document_viewer_previous_page'),
        icon: Icons.chevron_left,
        label: context.tr('document_viewer_previous_page'),
        onPressed: ready && page > 1 ? _previousPdfPage : null,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          context.tr(
            'document_viewer_page_of',
            values: {'current': page, 'total': count > 0 ? count : '-'},
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      ),
      _ToolbarButton(
        key: const Key('document_viewer_next_page'),
        icon: Icons.chevron_right,
        label: context.tr('document_viewer_next_page'),
        onPressed: ready && count > 0 && page < count ? _nextPdfPage : null,
      ),
      const SizedBox(width: 8),
      _ToolbarButton(
        key: const Key('document_viewer_zoom_out'),
        icon: Icons.zoom_out,
        label: context.tr('document_viewer_zoom_out'),
        onPressed: ready ? _zoomPdfOut : null,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_zoom_in'),
        icon: Icons.zoom_in,
        label: context.tr('document_viewer_zoom_in'),
        onPressed: ready ? _zoomPdfIn : null,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_rotate_left'),
        icon: Icons.rotate_left,
        label: context.tr('document_viewer_rotate_left'),
        onPressed: _rotateLeft,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_rotate_right'),
        icon: Icons.rotate_right,
        label: context.tr('document_viewer_rotate_right'),
        onPressed: _rotateRight,
      ),
      _ToolbarButton(
        key: const Key('document_viewer_reset'),
        icon: Icons.restart_alt,
        label: context.tr('document_viewer_reset'),
        onPressed: _resetPdf,
      ),
    ];
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon)),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
