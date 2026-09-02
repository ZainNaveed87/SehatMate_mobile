import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';
import '../localization/localized_errors.dart';
import '../services/auth_service.dart';
import '../services/care_plan_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/care_setup_progress.dart';
import '../widgets/page_header.dart';
import '../widgets/ui.dart';

class UploadDocumentItem {
  const UploadDocumentItem(
    this.id,
    this.name,
    this.type,
    this.size, {
    this.uploading = false,
    this.serverId,
    this.error,
  });
  final String id;
  final String name;
  final String type;
  final String size;
  final bool uploading;
  final String? serverId;
  final String? error;
}

class CarePlanUploadScreen extends StatefulWidget {
  const CarePlanUploadScreen({this.draft, super.key});

  final CarePlanUploadArgs? draft;

  @override
  State<CarePlanUploadScreen> createState() => _CarePlanUploadScreenState();
}

class _CarePlanUploadScreenState extends State<CarePlanUploadScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late final List<UploadDocumentItem> files;
  bool processing = false;
  int step = 0;
  Timer? timer;
  static const stepKeys = [
    'upload_step_uploading_documents',
    'upload_step_reading_instructions',
    'upload_step_extracting_instructions',
    'upload_step_organizing_verified_plan',
  ];

  @override
  void initState() {
    super.initState();
    files = AuthSession.instance.isGuest
        ? <UploadDocumentItem>[
            const UploadDocumentItem('f1', 'prescription-17-aug.pdf', 'PDF', '412 KB'),
            const UploadDocumentItem('f2', 'discharge-summary.pdf', 'PDF', '1.2 MB'),
          ]
        : <UploadDocumentItem>[];
    if (!AuthSession.instance.isGuest && widget.draft != null) {
      _loadExistingDocuments();
    }
  }

  Future<void> _loadExistingDocuments() async {
    try {
      final detail = await CarePlanService.instance.fetchPlanDetail(widget.draft!.planId);
      if (!mounted || files.isNotEmpty) return;
      setState(() {
        files.addAll(
          detail.documents.map(
            (document) => UploadDocumentItem(
              'server-${document.id}',
              document.name,
              document.type,
              context.tr('existing_document'),
              serverId: document.id,
            ),
          ),
        );
      });
    } on CarePlanException {
      // The upload screen still works even when an older draft cannot load its document list.
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _addFile(String name, String type, String size) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() => files.add(UploadDocumentItem(id, name, type, size, uploading: true)));
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final index = files.indexWhere((item) => item.id == id);
      if (index < 0) return;
      setState(() => files[index] = UploadDocumentItem(id, name, type, size));
    });
  }

  Future<void> _pickFiles() async {
    final pickedFiles = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (pickedFiles.isEmpty) return;

    for (var index = 0; index < pickedFiles.length; index++) {
      final file = pickedFiles[index];
      final dot = file.name.lastIndexOf('.');
      final extension = dot > 0 && dot < file.name.length - 1
          ? file.name.substring(dot + 1).toUpperCase()
          : 'FILE';
      final byteLength = await file.length();

      if (byteLength > 20 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('file_exceeds_20_mb_limit', values: {'file': file.name}))),
        );
        continue;
      }

      if (AuthSession.instance.isGuest || widget.draft == null) {
        _addFile(file.name, extension, _formatSize(byteLength));
        continue;
      }

      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() {
        files.add(
          UploadDocumentItem(
            localId,
            file.name,
            extension,
            _formatSize(byteLength),
            uploading: true,
          ),
        );
      });

      try {
        final bytes = await file.readAsBytes();
        final selectedTypes = widget.draft!.documentTypes;
        final documentType = selectedTypes.isEmpty
            ? 'other'
            : selectedTypes[index.clamp(0, selectedTypes.length - 1).toInt()];
        final serverId = await CarePlanService.instance.uploadDocument(
          planId: widget.draft!.planId,
          documentType: documentType,
          originalName: file.name,
          mimeType: _mimeType(extension),
          bytes: bytes,
        );
        if (!mounted) return;
        final itemIndex = files.indexWhere((item) => item.id == localId);
        if (itemIndex < 0) continue;
        setState(() {
          files[itemIndex] = UploadDocumentItem(
            localId,
            file.name,
            extension,
            _formatSize(byteLength),
            serverId: serverId,
          );
        });
      } on CarePlanException catch (error) {
        if (!mounted) return;
        final itemIndex = files.indexWhere((item) => item.id == localId);
        if (itemIndex >= 0) {
          setState(() {
            files[itemIndex] = UploadDocumentItem(
              localId,
              file.name,
              extension,
              _formatSize(byteLength),
              error: localizedCarePlanExceptionMessage(error, context.appLanguage),
            );
          });
        }
      } catch (_) {
        if (!mounted) return;
        final itemIndex = files.indexWhere((item) => item.id == localId);
        if (itemIndex >= 0) {
          setState(() {
            files[itemIndex] = UploadDocumentItem(
              localId,
              file.name,
              extension,
              _formatSize(byteLength),
              error: context.tr('error_upload_failed_try_again'),
            );
          });
        }
      }
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 3000,
      );

      if (photo == null || !mounted) return;

      final byteLength = await photo.length();
      if (byteLength > 20 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('captured_photo_exceeds_20_mb_limit'))),
        );
        return;
      }

      final fileName = 'care-document-${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (AuthSession.instance.isGuest || widget.draft == null) {
        _addFile(fileName, 'JPG', _formatSize(byteLength));
        return;
      }

      final localId = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() {
        files.add(
          UploadDocumentItem(
            localId,
            fileName,
            'JPG',
            _formatSize(byteLength),
            uploading: true,
          ),
        );
      });

      try {
        final bytes = await photo.readAsBytes();
        final selectedTypes = widget.draft!.documentTypes;
        final documentType = selectedTypes.isEmpty ? 'other' : selectedTypes.first;
        final serverId = await CarePlanService.instance.uploadDocument(
          planId: widget.draft!.planId,
          documentType: documentType,
          originalName: fileName,
          mimeType: 'image/jpeg',
          bytes: bytes,
        );

        if (!mounted) return;
        final itemIndex = files.indexWhere((item) => item.id == localId);
        if (itemIndex < 0) return;
        setState(() {
          files[itemIndex] = UploadDocumentItem(
            localId,
            fileName,
            'JPG',
            _formatSize(byteLength),
            serverId: serverId,
          );
        });
      } on CarePlanException catch (error) {
        if (!mounted) return;
        _markCameraUploadFailed(
          localId,
          fileName,
          byteLength,
          localizedCarePlanExceptionMessage(error, context.appLanguage),
        );
      } catch (_) {
        if (!mounted) return;
        _markCameraUploadFailed(
          localId,
          fileName,
          byteLength,
          context.tr('error_upload_failed_try_again'),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('camera_open_failed')),
        ),
      );
    }
  }

  void _markCameraUploadFailed(
    String localId,
    String fileName,
    int byteLength,
    String message,
  ) {
    final itemIndex = files.indexWhere((item) => item.id == localId);
    if (itemIndex < 0) return;
    setState(() {
      files[itemIndex] = UploadDocumentItem(
        localId,
        fileName,
        'JPG',
        _formatSize(byteLength),
        error: message,
      );
    });
  }

  String _mimeType(String extension) => switch (extension) {
        'PDF' => 'application/pdf',
        'PNG' => 'image/png',
        _ => 'image/jpeg',
      };

  Future<void> _removeFile(UploadDocumentItem file) async {
    if (file.serverId != null && !AuthSession.instance.isGuest) {
      try {
        await CarePlanService.instance.deleteDocument(file.serverId!);
      } on CarePlanException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedCarePlanExceptionMessage(error, context.appLanguage))),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() => files.removeWhere((item) => item.id == file.id));
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).ceil().clamp(1, 999999)} KB';
  }

  Future<void> _startProcessing() async {
    setState(() {
      processing = true;
      step = 0;
    });

    if (AuthSession.instance.isGuest || widget.draft == null) {
      timer = Timer.periodic(const Duration(milliseconds: 900), (value) {
        if (!mounted) return;
        if (step >= stepKeys.length - 1) {
          value.cancel();
          Navigator.pushReplacementNamed(context, AppRoutes.carePlanReview);
        } else {
          setState(() => step++);
        }
      });
      return;
    }

    timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && step < 2) setState(() => step++);
    });
    try {
      await CarePlanService.instance.extractInstructions(widget.draft!.planId);
      timer?.cancel();
      if (!mounted) return;
      setState(() => step = stepKeys.length - 1);
      await CarePlanService.instance.updateSetupStep(
        widget.draft!.planId,
        CareSetupStep.review,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.carePlanReview,
        arguments: CarePlanReviewArgs(
          planId: widget.draft!.planId,
          guidedSetup: widget.draft!.guidedSetup,
          returnToPrevious: widget.draft!.returnToPrevious,
        ),
      );
    } on CarePlanException catch (error) {
      timer?.cancel();
        if (!mounted) return;
        setState(() => processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedCarePlanExceptionMessage(error, context.appLanguage))),
        );
      } catch (_) {
      timer?.cancel();
      if (!mounted) return;
        setState(() => processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('document_extraction_failed_retry'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (processing) return _processing();
    return AppShell(
      currentRoute: AppRoutes.carePlanUpload,
      title: context.tr('upload_documents'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  if (widget.draft?.returnToPrevious == true && Navigator.canPop(context)) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pushReplacementNamed(
                    context,
                    widget.draft == null
                        ? AppRoutes.carePlanNew
                        : AppRoutes.carePlans,
                  );
                },
              icon: const Icon(Icons.arrow_back, size: 17),
              label: Text(context.tr('back')),
            ),
          ),
          PageHeader(title: context.tr('upload_your_documents'), subtitle: context.tr('upload_documents_subtitle')),
          if (widget.draft?.guidedSetup == true) ...[
            GuidedCareSetupProgress(
              currentStep: 1,
              planId: widget.draft!.planId,
              saveState: processing ? 'Saving…' : 'Saved',
            ),
            const SizedBox(height: 16),
          ],
          DashedBorder(
            radius: AppRadii.xxl,
            strokeWidth: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.xxl)),
              child: Column(
              children: [
                const CircleAvatar(radius: 24, backgroundColor: AppColors.primaryLight, child: Icon(Icons.upload_outlined, size: 21, color: AppColors.primary)),
                const SizedBox(height: 14),
                Text(context.tr('drag_drop_documents_here'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(context.tr('document_file_limits'), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(onPressed: _pickFiles, child: Text(context.tr('choose_files'))),
                    OutlinedButton.icon(
                      onPressed: _capturePhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 17),
                      label: Text(context.tr('use_camera')),
                    ),
                  ],
                ),
              ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...files.map(
            (file) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(16),
                radius: 12,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(AppRadii.xl)),
                      child: const Icon(Icons.description_outlined, size: 18, color: AppColors.muted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          Text(
                            '${file.type} · ${file.size} · ${file.error ?? (file.uploading ? context.tr('uploading') : context.tr('uploaded'))}',
                            style: TextStyle(
                              fontSize: 13,
                              color: file.error == null ? AppColors.muted : AppColors.critical,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (file.uploading) ...[
                      const SizedBox(width: 12),
                      const SizedBox(width: 88, child: LinearProgressIndicator(value: .6, minHeight: 7)),
                    ],
                    IconButton(
                      onPressed: file.uploading ? null : () => _removeFile(file),
                      icon: const Icon(Icons.delete_outline, size: 19),
                      tooltip: context.tr('remove_file', values: {'file': file.name}),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SafetyNote(text: context.tr('upload_documents_safety_note')),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: files.isEmpty || files.any((file) => file.uploading || file.error != null)
                  ? null
                  : _startProcessing,
              child: Text(context.tr('continue')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _processing() => AppShell(
        currentRoute: AppRoutes.carePlanUpload,
        title: context.tr('processing_documents'),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: AppCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const CircleAvatar(radius: 28, backgroundColor: AppColors.primaryLight, child: Icon(Icons.description_outlined, size: 24, color: AppColors.primary)),
                    const SizedBox(height: 20),
                    Text(context.tr(stepKeys[step]), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(context.tr('processing_documents_description'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(value: (step + 1) / stepKeys.length, minHeight: 8, color: AppColors.primary, backgroundColor: AppColors.secondary),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(stepKeys.length, (index) {
                      final complete = index <= step;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 17, color: complete ? AppColors.success : AppColors.border),
                            const SizedBox(width: 8),
                            Expanded(child: Text(context.tr(stepKeys[index]), style: TextStyle(fontSize: 14, color: complete ? AppColors.foreground : AppColors.subtle))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
