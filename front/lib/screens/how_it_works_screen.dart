import 'package:flutter/material.dart';

import '../widgets/project_credit.dart';

/// Ajuda do app (heurística 10 de Nielsen): passo a passo de cada parte.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const _sections = <(IconData, String, List<String>)>[
    (Icons.search, 'Encontrar uma carona', [
      'Na aba Explorar, informe origem, destino e data. Digite "uri" para ver os câmpus.',
      'Use os filtros Manhã, Tarde, Noite e Preço para refinar.',
      'Toque numa carona para ver o trajeto no mapa, o motorista e o valor.',
      'Nada encontrado? Toque em "Me avise quando aparecer" e receba uma notificação quando alguém publicar uma carona parecida.',
    ]),
    (Icons.person_add_alt_1, 'Pedir uma vaga', [
      'Em "Solicitar vaga", marque no mapa onde você vai embarcar.',
      'Antes de enviar, você vê o valor estimado.',
      'O motorista recebe o pedido e responde. Você é avisado na hora.',
      'Enquanto espera, pode conversar com o motorista pelo chat.',
    ]),
    (Icons.add_circle_outline, 'Oferecer uma carona', [
      'Cadastre seu veículo no Perfil, com o consumo médio (km/L).',
      'Na aba Publicar, escolha origem, destino, data, horário e vagas.',
      'Ative "Repetir toda semana" para publicar vários dias de uma vez.',
      'Enquanto ninguém foi aceito, você pode editar a carona.',
    ]),
    (Icons.local_gas_station_outlined, 'Como o preço é calculado', [
      'Com "Dividir custos", o valor reparte o combustível da viagem entre todos no carro, incluindo o motorista.',
      'Cada passageiro paga também o desvio que o motorista faz para buscá-lo.',
      'O motorista pode dar desconto ao aceitar, mas nunca cobrar acima do sugerido.',
      'Com "Gratuita", ninguém paga.',
    ]),
    (Icons.directions_car_outlined, 'No dia da viagem', [
      'O motorista toca em "Iniciar carona". A localização dele passa a ser enviada automaticamente.',
      'Em "Acompanhar carro", o passageiro vê o carro, a rota e o tempo até o embarque.',
      'Você recebe um aviso quando o motorista está a cerca de 5 minutos e quando chega.',
      'Mantenha o app aberto durante o trajeto, se você for o motorista.',
    ]),
    (Icons.pix, 'Pagamento', [
      'O pagamento é combinado direto entre as pessoas, por Pix.',
      'Depois do aceite, a chave Pix do motorista aparece na carona com um botão de copiar.',
    ]),
    (Icons.star_outline, 'Depois da carona', [
      'O motorista conclui a carona e todos podem se avaliar.',
      'As avaliações aparecem no perfil e ajudam outros usuários a decidir.',
    ]),
    (Icons.shield_outlined, 'Segurança', [
      'Só entra quem tem e-mail institucional da URI.',
      'Veja o perfil e as avaliações antes de aceitar ou pedir vaga.',
      'Mulheres podem oferecer e buscar caronas só para mulheres.',
      'Você pode bloquear e denunciar usuários pelo menu (⋮) no perfil ou na carona.',
    ]),
    (Icons.notifications_outlined, 'Notificações', [
      'No celular Android, os avisos chegam mesmo com o app fechado.',
      'No navegador, ative em Notificações → "Avisar com o app fechado".',
      'Na tela de Notificações há um botão para testar.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Como funciona')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [

          for (final (icon, title, steps) in _sections)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: Icon(icon, color: scheme.primary),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 10, top: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(steps[i], style: const TextStyle(height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const ProjectCredit(),
        ],
      ),
    );
  }
}
