import 'package:flutter/material.dart';
import 'per_diem_money.dart';
import 'per_diem_reconciliation.dart';
/// PATCH 26: read-only balance UI; no writes are triggered by rendering.
class PerDiemBalanceCard extends StatelessWidget {
  final Reconciliation balance;
  final String distributorName;
  final String beneficiaryName;
  const PerDiemBalanceCard({super.key, required this.balance,
    required this.distributorName, required this.beneficiaryName});
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$distributorName → $beneficiaryName',
          style: Theme.of(context).textTheme.titleMedium),
      Text('Diurne cuvenite: ${formatBani(balance.dueBani)}'),
      Text('Primit confirmat: ${formatBani(balance.paidBani)}'),
      Text('Distribuiri neconfirmate: ${formatBani(balance.pendingBani)}'),
      if (balance.outstandingBani > 0)
        Text('Restanță: ${formatBani(balance.outstandingBani)}'),
      if (balance.advanceBani > 0)
        Text('Avans: ${formatBani(balance.advanceBani)}'),
    ])));
}
