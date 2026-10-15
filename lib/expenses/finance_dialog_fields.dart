import 'package:flutter/material.dart';

/// Owns text fields until the dialog subtree actually unmounts, including its
/// reverse transition. The Future returned by showDialog completes earlier.
class FinanceDialogFields extends StatefulWidget {
  const FinanceDialogFields({super.key, required this.initialTexts, required this.builder});
  final List<String> initialTexts;
  final Widget Function(BuildContext, List<TextEditingController>, StateSetter) builder;

  /// A second tap during the reverse transition must not pop the parent route.
  static void close<T>(BuildContext context, [T? result]) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pop<T>(result);
  }

  @override
  State<FinanceDialogFields> createState() => _FinanceDialogFieldsState();
}

class _FinanceDialogFieldsState extends State<FinanceDialogFields> {
  late final List<TextEditingController> _controllers = [
    for (final text in widget.initialTexts) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers, setState);
}
