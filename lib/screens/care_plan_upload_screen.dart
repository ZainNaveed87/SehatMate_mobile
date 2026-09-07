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
            const UploadDocumentItem(
              'f1',
              'prescription-17-aug.pdf',
              'PDF',
              '412 KB',
            ),
            const UploadDocumentItem(
              'f2',
              'discharge-summary.pdf',
              'PDF',
              '1.2 MB',
            ),
          ]
        : <UploadDocumentItem>[];
    if (!AuthSession.instance.isGuest && widget.draft != null) {
      _loadExistingDocuments();
    }
  }

  Future<void> _loadExistingDocuments() async {
    try {
      final detail = await CarePlanService.instance.fetchPlanDetail(
        widget.draft!.planId,
      );
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
    setState(
      () =>
          files.add(UploadDocumentItem(id, name, type, size, uploading: true)),
    );
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
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
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'file_exceeds_20_mb_limit',
                values: {'file': file.name},
              ),
            ),
          ),
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
        final documentType = widget.draft!.documentTypeForUpload(index);
        final serverId = await CarePlanService.instance.uploadDocument(
          planId: widget.draft!.planId,
          documentType: documentType,
          originalName: file.name,
          mimeType: _mimeType(extension),
          bytes: bytes,
        );
        if (!mounted) {
          return;
        }
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
        if (!mounted) {
          return;
        }
        final itemIndex = files.indexWhere((item) => item.id == localId);
        if (itemIndex >= 0) {
          setState(() {
            files[itemIndex] = UploadDocumentItem(
              localId,
              file.name,
              extension,
              _formatSize(byteLength),
              error: localizedCarePlanExceptionMessage(
                error,
                context.appLanguage,
              ),
            );
          });
        }
      } catch (_) {
        if (!mounted) {
          return;
        }
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
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('captured_photo_exceeds_20_mb_limit')),
          ),
        );
        return;
      }

      final fileName =
          'care-document-${DateTime.now().millisecondsSinceEpoch}.jpg';

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
        final documentType = widget.draft!.documentTypeForUpload(0);
        final serverId = await CarePlanService.instance.uploadDocument(
          planId: widget.draft!.planId,
          documentType: documentType,
          originalName: fileName,
          mimeType: 'image/jpeg',
          bytes: bytes,
        );

        if (!mounted) {
          return;
        }
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
        if (!mounted) {
          return;
        }
        _markCameraUploadFailed(
          localId,
          fileName,
          byteLength,
          localizedCarePlanExceptionMessage(error, context.appLanguage),
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        _markCameraUploadFailed(
          localId,
          fileName,
          byteLength,
          context.tr('error_upload_failed_try_again'),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('camera_open_failed'))));
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
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedCarePlanExceptionMessage(error, context.appLanguage),
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => files.removeWhere((item) => item.id == file.id));
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / 1024).ceil().clamp(1, 999999)} KB';
  }

  Future<void> _startProcessing() async {
    setState(() {
      processing = true;
      step = 0;
    });

    if (AuthSession.instance.isGuest || widget.draft == null) {
      timer = Timer.periodic(const Duration(milliseconds: 900), (value) {
        if (!mounted) {
          return;
        }
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
      if (mounted && step < 2) {
        setState(() => step++);
      }
    });
    try {
      await CarePlanService.instance.extractInstructions(widget.draft!.planId);
      timer?.cancel();
      if (!mounted) {
        return;
      }
      setState(() => step = stepKeys.length - 1);
      await CarePlanService.instance.updateSetupStep(
        widget.draft!.planId,
        CareSetupStep.review,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      setState(() => processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedCarePlanExceptionMessage(error, context.appLanguage),
          ),
        ),
      );
    } catch (_) {
      timer?.cancel();
      if (!mounted) {
        return;
      }
      setState(() => processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('document_extraction_failed_retry'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (processing) return _processing();

    final uploadingCount = files.where((file) => file.uploading).length;
    final errorCount = files.where((file) => file.error != null).length;
    final readyCount = files
        .where((file) => !file.uploading && file.error == null)
        .length;
    final canContinue =
        files.isNotEmpty &&
        files.every((file) => !file.uploading && file.error == null);

    return AppShell(
      currentRoute: AppRoutes.carePlanUpload,
      title: context.tr('upload_documents'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                if (widget.draft?.returnToPrevious == true &&
                    Navigator.canPop(context)) {
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
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: Text(context.tr('back')),
            ),
          ),
          const SizedBox(height: 6),

          FadeSlideIn(
            child: _uploadHero(
              readyCount: readyCount,
              uploadingCount: uploadingCount,
              errorCount: errorCount,
            ),
          ),

          if (widget.draft?.guidedSetup == true) ...[
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              child: GuidedCareSetupProgress(
                currentStep: 1,
                planId: widget.draft!.planId,
                saveState: processing ? 'Saving…' : 'Saved',
              ),
            ),
          ],

          const SizedBox(height: 18),

          FadeSlideIn(
            delay: const Duration(milliseconds: 70),
            child: _uploadPanel(),
          ),

          if (files.isNotEmpty) ...[
            const SizedBox(height: 22),
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _filesHeader(
                readyCount: readyCount,
                uploadingCount: uploadingCount,
                errorCount: errorCount,
              ),
            ),
            const SizedBox(height: 12),
            ...files.asMap().entries.map(
              (entry) => FadeSlideIn(
                delay: Duration(milliseconds: 30 * entry.key.clamp(0, 5)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _fileCard(entry.value),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          FadeSlideIn(
            delay: const Duration(milliseconds: 110),
            child: SafetyNote(text: context.tr('upload_documents_safety_note')),
          ),

          const SizedBox(height: 18),

          FadeSlideIn(
            delay: const Duration(milliseconds: 130),
            child: _continueCard(canContinue),
          ),
        ],
      ),
    );
  }

  Widget _uploadHero({
    required int readyCount,
    required int uploadingCount,
    required int errorCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;

        return Container(
          padding: EdgeInsets.all(compact ? 20 : 26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xxxl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F766E),
                blurRadius: 32,
                spreadRadius: -12,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -72,
                end: -54,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x16FFFFFF),
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: -92,
                start: -62,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x0FFFFFFF),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x20FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x30FFFFFF)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 15,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Verified care intake',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.tr('upload_your_documents'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 27 : 30,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.45,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          context.tr('upload_documents_subtitle'),
                          style: const TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        if (files.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _heroStatusChip(
                                icon: Icons.description_outlined,
                                label:
                                    '${files.length} file${files.length == 1 ? '' : 's'}',
                              ),
                              if (readyCount > 0)
                                _heroStatusChip(
                                  icon: Icons.check_circle_outline_rounded,
                                  label: '$readyCount ready',
                                ),
                              if (uploadingCount > 0)
                                _heroStatusChip(
                                  icon: Icons.cloud_upload_outlined,
                                  label: '$uploadingCount uploading',
                                ),
                              if (errorCount > 0)
                                _heroStatusChip(
                                  icon: Icons.error_outline_rounded,
                                  label: '$errorCount need attention',
                                  warning: true,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 20),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0x1FFFFFFF),
                        borderRadius: BorderRadius.circular(AppRadii.xxxl),
                        border: Border.all(color: const Color(0x2FFFFFFF)),
                      ),
                      child: const Icon(
                        Icons.upload_file_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroStatusChip({
    required IconData icon,
    required String label,
    bool warning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: warning ? const Color(0x33FFF7ED) : const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: warning ? const Color(0x50FED7AA) : const Color(0x26FFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadPanel() {
    return HoverLift(
      child: DashedBorder(
        radius: AppRadii.xxxl,
        strokeWidth: 1.6,
        color: const Color(0xFF99D8D1),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0FDFA), Color(0xFFFAFCFD)],
            ),
            borderRadius: BorderRadius.circular(AppRadii.xxxl),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;

              final icon = Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFCCFBF1), Color(0xFFE6FFFA)],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xxl),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 29,
                  color: AppColors.primary,
                ),
              );

              final copy = Column(
                crossAxisAlignment: compact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('drag_drop_documents_here'),
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr('document_file_limits'),
                    textAlign: compact ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: compact
                        ? WrapAlignment.center
                        : WrapAlignment.start,
                    children: const [
                      _UploadFormatChip(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'PDF',
                      ),
                      _UploadFormatChip(
                        icon: Icons.image_outlined,
                        label: 'JPG',
                      ),
                      _UploadFormatChip(
                        icon: Icons.image_outlined,
                        label: 'PNG',
                      ),
                      _UploadFormatChip(
                        icon: Icons.storage_outlined,
                        label: '≤ 20 MB',
                      ),
                    ],
                  ),
                ],
              );

              final actions = Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: compact ? WrapAlignment.center : WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: Text(context.tr('choose_files')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 17),
                    label: Text(context.tr('use_camera')),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  children: [
                    icon,
                    const SizedBox(height: 14),
                    copy,
                    const SizedBox(height: 18),
                    actions,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 16),
                  Expanded(child: copy),
                  const SizedBox(width: 18),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _filesHeader({
    required int readyCount,
    required int uploadingCount,
    required int errorCount,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: const Icon(
            Icons.folder_copy_outlined,
            size: 19,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected documents',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 2),
              Text(
                'Review upload status before continuing',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: errorCount > 0
                ? AppColors.warningSoft
                : uploadingCount > 0
                ? AppColors.primaryLight
                : AppColors.successSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            errorCount > 0
                ? '$errorCount issue${errorCount == 1 ? '' : 's'}'
                : uploadingCount > 0
                ? '$uploadingCount uploading'
                : '$readyCount ready',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: errorCount > 0
                  ? AppColors.warningForeground
                  : uploadingCount > 0
                  ? AppColors.primary
                  : AppColors.successForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fileCard(UploadDocumentItem file) {
    final hasError = file.error != null;
    final accent = hasError
        ? AppColors.critical
        : file.uploading
        ? AppColors.primary
        : AppColors.success;

    final soft = hasError
        ? AppColors.criticalSoft
        : file.uploading
        ? AppColors.primaryLight
        : AppColors.successSoft;

    return HoverLift(
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: accent.withValues(alpha: .18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 3, color: accent),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                    ),
                    child: Icon(_fileIcon(file.type), size: 21, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _fileMetaChip(file.type),
                            _fileMetaChip(file.size),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: soft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (file.uploading)
                                    const SizedBox(
                                      width: 11,
                                      height: 11,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.7,
                                      ),
                                    )
                                  else
                                    Icon(
                                      hasError
                                          ? Icons.error_outline_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 13,
                                      color: accent,
                                    ),
                                  const SizedBox(width: 5),
                                  Text(
                                    hasError
                                        ? 'Needs attention'
                                        : file.uploading
                                        ? context.tr('uploading')
                                        : context.tr('uploaded'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasError) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.criticalSoft,
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 15,
                                  color: AppColors.critical,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    file.error!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.35,
                                      color: AppColors.critical,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (file.uploading) ...[
                          const SizedBox(height: 9),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: const LinearProgressIndicator(minHeight: 5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: file.uploading ? null : () => _removeFile(file),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    tooltip: context.tr(
                      'remove_file',
                      values: {'file': file.name},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileMetaChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData _fileIcon(String type) {
    return switch (type.toUpperCase()) {
      'PDF' => Icons.picture_as_pdf_outlined,
      'PNG' => Icons.image_outlined,
      'JPG' || 'JPEG' => Icons.photo_outlined,
      _ => Icons.description_outlined,
    };
  }

  Widget _continueCard(bool canContinue) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: canContinue ? const Color(0xFFF0FDFA) : const Color(0xFFFAFCFD),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(
          color: canContinue ? const Color(0xFF99F6E4) : AppColors.border,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          final copy = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: canContinue
                      ? AppColors.successSoft
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  canContinue
                      ? Icons.verified_outlined
                      : Icons.upload_file_outlined,
                  color: canContinue
                      ? AppColors.successForeground
                      : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canContinue
                          ? 'Documents ready'
                          : files.isEmpty
                          ? 'Add your care documents'
                          : 'Finish uploads first',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      canContinue
                          ? 'SehatMate can now read and organize the uploaded instructions.'
                          : 'Continue becomes available when every selected file is uploaded successfully.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: canContinue ? _startProcessing : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(context.tr('continue')),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 14), button],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 18),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _processing() {
    final progress = (step + 1) / stepKeys.length;

    return AppShell(
      currentRoute: AppRoutes.carePlanUpload,
      title: context.tr('processing_documents'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: FadeSlideIn(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.xxxl),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1C0F766E),
                      blurRadius: 30,
                      spreadRadius: -12,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  radius: AppRadii.xxxl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0F766E),
                              Color(0xFF0D9488),
                              Color(0xFF14B8A6),
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppRadii.xxxl),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: const Color(0x20FFFFFF),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.xxl,
                                ),
                                border: Border.all(
                                  color: const Color(0x30FFFFFF),
                                ),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_outlined,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                context.tr(stepKeys[step]),
                                key: ValueKey(step),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              context.tr('processing_documents_description'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xDEFFFFFF),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                color: Colors.white,
                                backgroundColor: const Color(0x30FFFFFF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  color: Color(0xE6FFFFFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: List.generate(stepKeys.length, (index) {
                            final complete = index < step;
                            final active = index == step;

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == stepKeys.length - 1 ? 0 : 10,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.primaryLight
                                      : complete
                                      ? AppColors.successSoft
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.xl,
                                  ),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.primary.withValues(
                                            alpha: .16,
                                          )
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: complete
                                            ? AppColors.successSoft
                                            : active
                                            ? Colors.white
                                            : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: active
                                          ? const SizedBox(
                                              width: 15,
                                              height: 15,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              complete
                                                  ? Icons.check_rounded
                                                  : Icons.circle_outlined,
                                              size: 17,
                                              color: complete
                                                  ? AppColors.successForeground
                                                  : AppColors.subtle,
                                            ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Text(
                                        context.tr(stepKeys[index]),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: active || complete
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: active || complete
                                              ? AppColors.foreground
                                              : AppColors.subtle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadFormatChip extends StatelessWidget {
  const _UploadFormatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
