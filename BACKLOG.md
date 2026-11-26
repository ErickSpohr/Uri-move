# Backlog — URI Move

Atualizado em 26 de novembro de 2026. Este documento organiza o trabalho pendente; não estabelece prazos nem autoriza a implementação de todas as propostas.

## Objetivo

Permitir que estudantes e demais integrantes da comunidade URI encontrem caronas, gerenciem veículos e conversem com motorista e passageiros confirmados, com acesso confiável pelo aplicativo web.

## Prioridades e estados

- **P0:** acesso, segurança da autenticação e impedimentos no fluxo principal.
- **P1:** confiabilidade e experiência dos fluxos principais.
- **P2:** evolução do produto e operação.
- **A fazer:** implementação ou revisão ainda pendente.
- **Implementado — validar:** código e testes automatizados prontos; falta conferir o fluxo real em produção.
- **Validar:** implementação existente que precisa de confirmação funcional em produção.
- **Concluído:** critérios de aceite atendidos e versão publicada conferida.

A existência de uma rota ou tela não significa que seu fluxo completo tenha sido validado. O teste `FullRideFlowTest` percorre pela API a jornada completa (cadastro → verificação → carona → solicitação → chat → aceite → início → rastreamento → conclusão → avaliação), mas não substitui o QA manual no aplicativo.

## Itens priorizados

| ID | Prioridade | Item | Estado | Critérios de aceite | Dependências |
| --- | --- | --- | --- | --- | --- |
| UM-01 | P0 | Validar recuperação da conta institucional | Validar | Usuário recebe o código no e-mail, redefine a senha e entra no site; senha antiga e reutilização do código são recusadas. Registrar o resultado sem expor senha ou código. | — |
| UM-02 | P0 | Completar a jornada de e-mail não verificado | Implementado — validar | Login de conta não verificada abre a verificação e só reenvia código se não houver um válido dos últimos 2 min; falha no envio do código desfaz o cadastro (permite tentar de novo). | — |
| UM-03 | P0 | Limitar tentativas no login e na verificação de e-mail | Concluído | Limites por e-mail e por IP em login (5/min), verificação (5/10 min) e envio de código (3/10 min); mensagens 429 em português; IP real atrás do proxy (`trustProxies`). `AuthRateLimitTest`. | — |
| UM-04 | P1 | Criar ambiente de QA com contas controladas | A fazer | Ambiente separado de produção, sem dados reais; contas de motorista e passageiro disponíveis; instruções de uso e limpeza documentadas; seeder demo continua bloqueado em produção. Localmente: `setup.cmd`/`start.cmd`. | — |
| UM-05 | P1 | Tratar falhas e demora da API | Implementado — validar | Timeout de 75 s, nova tentativa automática em GET, faixa "Conectando ao servidor…" após 5 s, erros de rede em português; "Tentar novamente" no cadastro. `api_client_test.dart`. | — |
| UM-06 | P1 | Validar veículos e publicação de caronas | Implementado — validar | Coberto por `FullRideFlowTest`; falta o QA manual no app. | UM-04 |
| UM-07 | P1 | Validar solicitações e consistência das vagas | Implementado — validar | `lockForUpdate` no aceite; solicitação respondida não é aceita de novo; vaga confirmada não pode ser liberada após a partida; passageiro pode cancelar solicitação/liberar vaga pelo app. | UM-04, UM-06 |
| UM-08 | P1 | Validar o grupo de chat por carona | Validar | Motorista e passageiros confirmados enviam e recebem mensagens sem recarregar a tela; usuários externos não acessam o grupo; mensagens não se repetem; desconexão e retorno são tratados. | UM-07 |
| UM-09 | P1 | Validar início, conclusão e cancelamento de caronas | Implementado — validar | Cancelar carona encerra solicitações e participações e notifica os passageiros (`ride_cancelled`); o app mostra "cancelada pelo motorista". | UM-07 |
| UM-10 | P1 | Melhorar busca e filtros de caronas | A fazer | API já valida data, horário e preço; falta no app: campus, horário, preço, limpar filtros e orientação para lista vazia. | UM-06 |
| UM-11 | P1 | Revisar uso em celular e acessibilidade | A fazer | Login, recuperação, cadastro, caronas e chat funcionam em tela pequena e com teclado aberto; campos e botões têm rótulos; navegação por teclado e controle de visibilidade das senhas funcionam. | UM-01, UM-08 |
| UM-12 | P1 | Automatizar validação do Flutter no GitHub | Concluído | `flutter analyze`, `flutter test`, testes em Chrome e `flutter build web` a cada mudança em `front/`; Pint e testes Laravel com PostgreSQL no backend. | — |
| UM-13 | P2 | Validar notificações e indicação de mensagens novas | Implementado — validar | `GET /chats/unread`; selo na aba Conversas e por conversa (consulta a cada 30 s); abrir o chat marca como lido. | UM-08, UM-09 |
| UM-14 | P2 | Validar avaliações, denúncias e bloqueios | Implementado — validar | Tela de avaliação após conclusão; denunciar/bloquear no card do motorista, no chat privado e na avaliação; lista de bloqueados no perfil; bloqueio oculta caronas e impede solicitar vaga. | UM-09 |
| UM-15 | P2 | Documentar recuperação e operação dos serviços | A fazer | Documentar Render, Vercel, Supabase, Brevo e cron-job.org; verificação de saúde, variáveis secretas, restauração do banco e retorno à versão anterior. | UM-04 |
| UM-16 | P2 | Avaliar alternativa ao polling do chat | A fazer | Medir atraso e volume de requisições do chat atual; comparar opções compatíveis com a hospedagem e o orçamento escolhido; registrar a decisão e os testes necessários antes de migrar. | UM-08 |
| UM-17 | P1 | Painel de administração de denúncias | A fazer | Administrador lista denúncias e altera o estado pelo app (API `admin/reports` já existe); denunciante recebe atualização. Sem isso, denúncias não têm efeito prático. | UM-14 |
| UM-18 | P2 | Tela de rotas favoritas | A fazer | API existe; criar tela para salvar e reutilizar origem/destino na busca. | UM-10 |
| UM-19 | P2 | Servidor e banco na mesma região | A fazer | Render (Oregon) e Supabase (São Paulo) têm ~180 ms por ida e volta; avaliar migrar um dos dois. Hoje: ~0,4 s por requisição simples após otimizações. | — |
| UM-20 | P2 | Domínio próprio para e-mails | A fazer | Remetente Gmail tende a cair no spam; configurar domínio autenticado (SPF/DKIM) na Brevo. | UM-01 |
| UM-21 | P2 | Decidir exibição do RA para outros usuários | A fazer | E-mail, telefone e gênero já são privados; o RA ainda aparece no card do motorista. Decidir se deve ser ocultado. | — |

## Próxima sequência de trabalho

1. QA manual com duas contas (navegador normal + janela anônima) cobrindo UM-01, UM-02, UM-05 a UM-09, UM-13 e UM-14.
2. UM-17 (painel de denúncias).
3. UM-10 e UM-11 conforme os resultados do QA.
4. UM-15 antes da apresentação final; demais P2 conforme necessidade.

## Entregas já implementadas

| Entrega | Evidência disponível | Limite da validação |
| --- | --- | --- |
| API Laravel no Render, banco no Supabase, app Flutter web na Vercel | Deploys automáticos a partir do `main`; `/up` e rotas públicas conferidas. | Plano gratuito: cron-job.org mantém a API ativa a cada 10 min. |
| Login persistente no navegador | Token em `localStorage`, com migração do formato antigo por aba; testes em Chrome no CI. | Duas contas ao mesmo tempo exigem janela anônima ou outro navegador. |
| Desempenho da API | Conexão persistente com o banco, consultas sem prepare duplo, opcache; listagens com número fixo de consultas (12 caronas: 28 → 10). | Primeira requisição de cada processo ainda abre conexão (~1,5 s). |
| Privacidade de dados pessoais | E-mail, telefone e gênero visíveis só ao próprio usuário e a administradores (inclusive na rota pública `/users/{id}`). | RA ainda visível (UM-21). |
| Mensagens da API em português | Locale `pt_BR` com traduções das regras de validação usadas. | Regras novas precisam ser adicionadas a `lang/pt_BR/validation.php`. |
| Logo e identidade | Logo URI Move nas telas de login/abertura, favicon e ícones PWA. | Uso da marca URI fora da disciplina deve ser confirmado com a universidade. |
| Integração de e-mail com Brevo | Envio de códigos de verificação; cadastro desfeito se o envio falhar. | Recebimento real e recuperação de senha dependem do UM-01. |
| Testes automatizados | 64 testes Laravel (incluindo jornada completa) e testes Flutter (unitários, widgets e navegador). | Não substituem QA manual nem auditoria de segurança. |

## Conclusão de um item

Um item pode ser marcado como concluído quando seus critérios de aceite forem atendidos, os testes aplicáveis passarem, a documentação necessária estiver atualizada e, quando houver deploy, a versão publicada tiver sido conferida. Registre o commit ou a evidência de QA correspondente. Não incluir credenciais, códigos de recuperação nem dados pessoais na evidência.
