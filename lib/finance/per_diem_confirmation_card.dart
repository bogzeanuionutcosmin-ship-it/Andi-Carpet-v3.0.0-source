
import 'package:flutter/material.dart';
import 'per_diem_firestore_repository.dart';

/// Reusable beneficiary control. Must be mounted by the Decont screen.
class PerDiemConfirmationCard extends StatefulWidget {
  final String settlementId;
  final String beneficiaryId;
  final String currentUserId;
  final int declaredBani;
  final PerDiemFirestoreRepository repository;
  final VoidCallback? onSaved;

  const PerDiemConfirmationCard({
    super.key,
    required this.settlementId,
    required this.beneficiaryId,
    required this.currentUserId,
    required this.declaredBani,
    required this.repository,
    this.onSaved,
  });

  @override
  State<PerDiemConfirmationCard> createState() =>
      _PerDiemConfirmationCardState();
}

class _PerDiemConfirmationCardState
    extends State<PerDiemConfirmationCard> {
  bool saving = false;

  String money(int bani) => '${(bani / 100).toStringAsFixed(2)} lei';

  Future<void> confirm() async {
    if (saving || widget.currentUserId != widget.beneficiaryId) {
      return;
    }

    final input = TextEditingController(
      text: (widget.declaredBani / 100).toStringAsFixed(2),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmare diurnă'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Declarat: ${money(widget.declaredBani)}'),
            TextField(
              controller: input,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Sumă primită (lei)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () {
              final normalized =
                  input.text.trim().replaceAll(',', '.');

              if (!RegExp(r'^\d+(\.\d{1,2})?$')
                  .hasMatch(normalized)) {
                return;
              }

              final parts = normalized.split('.');
              final lei = int.tryParse(parts[0]);
              final cents = parts.length == 2
                  ? int.tryParse(parts[1].padRight(2, '0'))
                  : 0;

              if (lei == null || cents == null) {
                return;
              }

              Navigator.pop(context, lei * 100 + cents);
            },
            child: const Text('Confirmă'),
          ),
        ],
      ),
    );

    input.dispose();

    if (result == null || !mounted) {
      return;
    }

    if (result != widget.declaredBani) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Diferență de sumă'),
          content: Text(
            'Declarat: ${money(widget.declaredBani)}\n'
            'Primit: ${money(result)}\n'
            'Diferența va fi evidențiată separat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Corectează'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmă diferența'),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) {
        return;
      }
    }

    setState(() => saving = true);

    try {
      await widget.repository.acknowledge(
        id: widget.settlementId,
        actorId: widget.currentUserId,
        receivedBani: result,
      );

      widget.onSaved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirmarea nu a fost salvată: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diurnă declarată: ${money(widget.declaredBani)}',
              ),
              if (widget.currentUserId == widget.beneficiaryId)
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: saving ? null : confirm,
                      child: const Text('Confirmă primirea'),
                    ),
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setState(() => saving = true);

                              try {
                                await widget.repository.acknowledge(
                                  id: widget.settlementId,
                                  actorId: widget.currentUserId,
                                  receivedBani: 0,
                                );

                                widget.onSaved?.call();
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text('$e'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => saving = false);
                                }
                              }
                            },
                      child: const Text('Nu am primit'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
}
