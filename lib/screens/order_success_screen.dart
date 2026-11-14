import 'package:flutter/material.dart';

class OrderSuccessScreen extends StatelessWidget {
  final int orderId;
  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text('Commande envoyée !', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Commande #$orderId créée dans Dolibarr', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Nouvelle commande'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
