import 'package:flutter/material.dart';

class LectorPersonalizeInvitation extends StatelessWidget {
  const LectorPersonalizeInvitation({
    required this.onConnect,
    required this.onExplore,
    super.key,
  });
  final VoidCallback onConnect, onExplore;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personnalisez votre Lector',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Choisissez les lectures et les marchés qui vous intéressent pour retrouver les rencontres qui correspondent à votre façon d’analyser le sport.',
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onConnect, child: const Text('Se connecter')),
        TextButton.icon(
          onPressed: onExplore,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          iconAlignment: IconAlignment.end,
          label: const Text('Découvrir tous les matchs'),
        ),
      ],
    ),
  );
}
