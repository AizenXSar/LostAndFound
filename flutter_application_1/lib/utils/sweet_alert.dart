import 'package:flutter/material.dart';

class SweetAlert {
  static Future<void> fire({
    required BuildContext context,
    required String title,
    String? message,
    SweetAlertType icon = SweetAlertType.success,
    bool draggable = true,
    VoidCallback? onConfirm,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: _SweetAlertDialog(
              title: title,
              message: message,
              icon: icon,
              draggable: draggable,
              onConfirm: onConfirm ?? () => Navigator.pop(context),
            ),
          ),
        );
      },
    );
  }

  static Future<void> success({
    required BuildContext context,
    required String title,
    String? message,
    bool draggable = true,
    VoidCallback? onConfirm,
  }) {
    return fire(
      context: context,
      title: title,
      message: message,
      icon: SweetAlertType.success,
      draggable: draggable,
      onConfirm: onConfirm,
    );
  }

  static Future<void> error({
    required BuildContext context,
    required String title,
    String? message,
    bool draggable = true,
    VoidCallback? onConfirm,
  }) {
    return fire(
      context: context,
      title: title,
      message: message,
      icon: SweetAlertType.error,
      draggable: draggable,
      onConfirm: onConfirm,
    );
  }

  static Future<void> warning({
    required BuildContext context,
    required String title,
    String? message,
    bool draggable = true,
    VoidCallback? onConfirm,
  }) {
    return fire(
      context: context,
      title: title,
      message: message,
      icon: SweetAlertType.warning,
      draggable: draggable,
      onConfirm: onConfirm,
    );
  }

  static Future<void> info({
    required BuildContext context,
    required String title,
    String? message,
    bool draggable = true,
    VoidCallback? onConfirm,
  }) {
    return fire(
      context: context,
      title: title,
      message: message,
      icon: SweetAlertType.info,
      draggable: draggable,
      onConfirm: onConfirm,
    );
  }
}

enum SweetAlertType {
  success,
  error,
  warning,
  info,
}

class _SweetAlertDialog extends StatefulWidget {
  final String title;
  final String? message;
  final SweetAlertType icon;
  final bool draggable;
  final VoidCallback onConfirm;

  const _SweetAlertDialog({
    required this.title,
    this.message,
    required this.icon,
    required this.draggable,
    required this.onConfirm,
  });

  @override
  State<_SweetAlertDialog> createState() => _SweetAlertDialogState();
}

class _SweetAlertDialogState extends State<_SweetAlertDialog> {
  Offset _offset = Offset.zero;
  Offset _initialOffset = Offset.zero;

  Color _getIconColor() {
    switch (widget.icon) {
      case SweetAlertType.success:
        return Colors.green;
      case SweetAlertType.error:
        return Colors.red;
      case SweetAlertType.warning:
        return Colors.orange;
      case SweetAlertType.info:
        return Colors.blue;
    }
  }

  IconData _getIconData() {
    switch (widget.icon) {
      case SweetAlertType.success:
        return Icons.check_circle;
      case SweetAlertType.error:
        return Icons.error;
      case SweetAlertType.warning:
        return Icons.warning;
      case SweetAlertType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap from closing
              onPanUpdate: widget.draggable
                  ? (details) {
                      setState(() {
                        _offset = _initialOffset + details.delta;
                      });
                    }
                  : null,
              onPanStart: widget.draggable
                  ? (details) {
                      _initialOffset = _offset;
                    }
                  : null,
              child: Transform.translate(
                offset: _offset,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.draggable)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Icon(
                            Icons.drag_handle,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.4),
                            size: 24,
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(24, widget.draggable ? 0 : 24, 24, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _getIconColor().withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconData(),
                                color: _getIconColor(),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            if (widget.message != null && widget.message!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                widget.message!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color
                                          ?.withOpacity(0.8),
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: FilledButton(
                          onPressed: widget.onConfirm,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('OK'),
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

