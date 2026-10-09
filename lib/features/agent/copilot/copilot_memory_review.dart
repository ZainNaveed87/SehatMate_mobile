import 'copilot_strings.dart';
import 'package:flutter/material.dart';
import 'copilot_service.dart';
import 'copilot.dart';

/// Clears account-scoped content and removes only this owned modal route when
/// its account is invalidated; unrelated Navigator routes are left intact.
class CopilotAccountSurface extends StatefulWidget {
  const CopilotAccountSurface({
    super.key,
    required this.registry,
    required this.child,
  });
  final CopilotRegistry registry;
  final Widget child;
  @override
  State<CopilotAccountSurface> createState() => _CopilotAccountSurfaceState();
}

class _CopilotAccountSurfaceState extends State<CopilotAccountSurface> {
  @override
  void initState() {
    super.initState();
    widget.registry.addListener(_changed);
  }

  void _changed() {
    if (widget.registry.valid || !mounted) return;
    setState(() {});
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route?.navigator;
      if (navigator != null && route!.isActive) navigator.removeRoute(route);
    });
  }

  @override
  void dispose() {
    widget.registry.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.registry.valid ? widget.child : const SizedBox.shrink();
}

String _memoryLabel(Map<String, dynamic> item) {
  final value = item['value'];
  if (value is Map) {
    return value.entries
        .map((e) => '${e.key.toString().replaceAll('_', ' ')}: ${e.value}')
        .join('\n');
  }
  return value?.toString() ?? '';
}

Future<void> confirmCopilotMemory(
  BuildContext context,
  CopilotService service,
  Map<String, dynamic> proposal,
  String sessionId,
) async {
  final label = _memoryLabel(proposal);
  if (!service.registry.valid || label.isEmpty || label.length > 1200) return;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => CopilotAccountSurface(
      registry: service.registry,
      child: AlertDialog(
        title: Text(copilotText(context, 'remember_question')),
        content: Text(label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(copilotText(context, 'not_now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(copilotText(context, 'remember')),
          ),
        ],
      ),
    ),
  );
  if (accepted != true || !context.mounted || !service.registry.valid) return;
  try {
    await service.request(
      'memory',
      body: {
        'sessionId': sessionId,
        'item': {...proposal, 'confirmedByUser': true},
      },
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(copilotText(context, 'memory_failed'))),
      );
    }
  }
}

final _memoryReviews=Expando<Future<void>>();
Future<void> showCopilotMemoryReview(BuildContext context,CopilotService service) async {
  if(!service.registry.valid)return;
  final pending=_memoryReviews[service];
  if(pending!=null){await pending;return;}
  final presentation=CopilotScope.maybeOf(context)?.presentation;
  presentation?.minimizeChat();
  presentation?.setMemoryReviewBusy(true);
  final future=showModalBottomSheet<void>(context:context,isScrollControlled:true,
    builder:(_)=>CopilotAccountSurface(registry:service.registry,child:_MemoryReview(service:service)));
  _memoryReviews[service]=future;
  try{await future;}finally{
    _memoryReviews[service]=null;
    if(service.registry.valid)presentation?.setMemoryReviewBusy(false);
  }
}

class _MemoryReview extends StatefulWidget {
  const _MemoryReview({required this.service});
  final CopilotService service;
  @override
  State<_MemoryReview> createState() => _MemoryReviewState();
}

class _MemoryReviewState extends State<_MemoryReview> {
  List<Map<String, dynamic>>? items;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.service.request('memory', method: 'GET');
      final raw = data['data'] ?? data['items'] ?? data['memory'] ?? [];
      if (mounted) {
        setState(() {
          items = raw is List
              ? raw.whereType<Map<String, dynamic>>().toList()
              : [];
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'memory_unavailable');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          ListTile(
            title: Text(copilotText(context, 'memory')),
            subtitle: Text(copilotText(context, 'memory_help')),
            trailing: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: error != null
                ? Center(child: Text(copilotText(context, error!)))
                : items == null
                ? const Center(child: CircularProgressIndicator())
                : items!.isEmpty
                ? Center(child: Text(copilotText(context, 'memory_empty')))
                : ListView(
                    children: items!
                        .map(
                          (item) => ListTile(
                            title: Text(_memoryLabel(item)),
                            subtitle: Text(
                              copilotText(
                                context,
                                item['kind'] == 'INFERRED_PATTERN'
                                    ? 'inferred'
                                    : 'confirmed_memory',
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: copilotText(context, 'forget'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final id = item['id']?.toString();
                                if (id == null ||
                                    !RegExp(
                                      r'^[A-Za-z0-9_-]{1,80}$',
                                    ).hasMatch(id)) {
                                  return;
                                }
                                try {
                                  await widget.service.request(
                                    'memory/$id',
                                    method: 'DELETE',
                                  );
                                  await _load();
                                } catch (_) {
                                  if (mounted) {
                                    setState(() => error = 'forget_failed');
                                  }
                                }
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    ),
  );
}
