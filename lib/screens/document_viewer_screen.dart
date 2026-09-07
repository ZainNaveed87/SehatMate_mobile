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
    final fileType = widget.file.isPdf
        ? 'PDF'
        : widget.file.isImage
        ? 'Image'
        : 'Document';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F7),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Icon(
                widget.file.isPdf
                    ? Icons.picture_as_pdf_outlined
                    : widget.file.isImage
                    ? Icons.image_outlined
                    : Icons.description_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.file.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$fileType · ${_formattedFileSize(widget.file.bytes.length)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121A1B),
                    borderRadius: BorderRadius.circular(AppRadii.xxl),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: .12),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x160F172A),
                        blurRadius: 24,
                        spreadRadius: -10,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        top: -80,
                        end: -60,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x120D9488),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: -100,
                        start: -70,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x0D14B8A6),
                          ),
                        ),
                      ),
                      Positioned.fill(child: _buildViewer(context)),
                      PositionedDirectional(
                        top: 12,
                        end: 12,
                        child: _viewerStatusChip(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildToolbar(context),
          ],
        ),
      ),
    );
  }

  String _formattedFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil().clamp(1, 999999)} KB';
  }

  Widget _viewerStatusChip() {
    final label = widget.file.isPdf
        ? (_pdfPageCount > 0 ? '$_pdfPage / $_pdfPageCount' : 'PDF')
        : '${(_imageScale * 100).round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD91F2930),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.file.isPdf
                ? Icons.menu_book_outlined
                : Icons.zoom_in_map_outlined,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 20,
            spreadRadius: -10,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    final enabled = onPressed != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: label,
        child: Material(
          color: enabled ? const Color(0xFFF0F7F6) : const Color(0xFFF5F7F8),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: 20,
                color: enabled ? AppColors.primary : AppColors.subtle,
              ),
            ),
          ),
        ),
      ),
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
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(AppRadii.xxl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(icon, size: 25, color: AppColors.primary),
              ),
              const SizedBox(height: 13),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
