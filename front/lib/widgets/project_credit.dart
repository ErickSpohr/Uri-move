import 'package:flutter/material.dart';

/// Crédito institucional do projeto (exibido em login, perfil e "Como funciona").
class ProjectCredit extends StatelessWidget {
  const ProjectCredit({super.key});

  static const text =
      'Desenvolvido por estudantes de Ciência da Computação da URI Santo Ângelo '
      'como projeto de extensão (Projeto Integrador II).';

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.35, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
