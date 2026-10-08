import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../core/app_theme.dart';
import '../localization/language_scope.dart';

/// Widget build failures become one route-level surface, not a page per child.
/// Transport failures remain controller states and never enter this boundary.
class AppRouteErrorBoundary extends StatefulWidget {
  const AppRouteErrorBoundary({super.key, required this.child});
  final Widget child;
  @override
  State<AppRouteErrorBoundary> createState() => _AppRouteErrorBoundaryState();
}

class _AppRouteErrorBoundaryState extends State<AppRouteErrorBoundary> {
  bool _failed = false, _scheduled = false;
  void reportFailure() {
    if (_failed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _scheduled = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => _RouteFailureScope(
    boundary: this,
    child: _failed
        ? Material(
            color: AppColors.background,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('page_load_failed'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('page_load_failed_description'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton(
                                  onPressed: () =>
                                      setState(() => _failed = false),
                                  child: Text(context.tr('retry')),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        AppRoutes.landing,
                                        (_) => false,
                                      ),
                                  child: Text(context.tr('go_home')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : widget.child,
  );
}

class _RouteFailureScope extends InheritedWidget {
  const _RouteFailureScope({required this.boundary, required super.child});
  final _AppRouteErrorBoundaryState boundary;
  @override
  bool updateShouldNotify(_RouteFailureScope oldWidget) =>
      boundary != oldWidget.boundary;
}

class AppBuildFailure extends StatelessWidget {
  const AppBuildFailure({super.key, required this.details});
  final FlutterErrorDetails details;
  @override
  Widget build(BuildContext context) {
    final boundary = context
        .getInheritedWidgetOfExactType<_RouteFailureScope>();
    if (boundary == null) {
      return ErrorWidget.withDetails(message: 'Unable to display this view');
    }
    boundary.boundary.reportFailure();
    // The route boundary replaces the whole route on the next frame. Flutter
    // still reports the original exception; it is not swallowed by this view.
    return const SizedBox.shrink();
  }
}
