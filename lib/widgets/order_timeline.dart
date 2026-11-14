import 'package:flutter/material.dart';

class OrderTimeline extends StatelessWidget {
  final int status; // -1, 0, 1, 2, 3

  const OrderTimeline({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == -1) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.red[700]),
          const SizedBox(width: 8),
          Text('Commande annulée', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final steps = [
      const _Step('Brouillon', Icons.edit_outlined, 0),
      const _Step('Validée', Icons.check_circle_outline, 1),
      const _Step('Expédiée', Icons.local_shipping_outlined, 2),
      const _Step('Livrée', Icons.home_outlined, 3),
    ];

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final done = status > step.statusValue;
        final active = status == step.statusValue;
        final color = done || active
            ? (done ? Colors.green : const Color(0xFF1565C0))
            : Colors.grey[300]!;
        final textColor = done || active ? color : Colors.grey[400]!;

        return Expanded(
          child: Row(children: [
            Expanded(
              child: Column(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done || active ? color : Colors.grey[200],
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    done ? Icons.check : step.icon,
                    size: 16,
                    color: done || active ? Colors.white : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(step.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: textColor, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
              ]),
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 20),
                  color: status > steps[i].statusValue ? Colors.green : Colors.grey[300],
                ),
              ),
          ]),
        );
      }).toList(),
    );
  }
}

class _Step {
  final String label;
  final IconData icon;
  final int statusValue;
  const _Step(this.label, this.icon, this.statusValue);
}
