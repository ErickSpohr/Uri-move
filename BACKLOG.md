# Backlog — URI Move

Atualizado em 5 de outubro de 2026. Este documento organiza o trabalho pendente; não estabelece prazos nem autoriza a implementação de todas as propostas.

## Objetivo

Permitir que estudantes e demais integrantes da comunidade URI encontrem caronas, gerenciem veículos e conversem com motorista e passageiros confirmados, com acesso confiável pelo aplicativo web.

## Prioridades e estados

- **P0:** acesso, segurança da autenticação e impedimentos no fluxo principal.
- **P1:** confiabilidade e experiência dos fluxos principais.
- **P2:** evolução do produto e operação.
- **A fazer:** implementação ou revisão ainda pendente.
- **Validar:** implementação existente que precisa de confirmação funcional em produção.

A existência de uma rota ou tela não significa que seu fluxo completo tenha sido validado. Os itens abaixo distinguem melhoria proposta de validação pendente.

## Itens priorizados

| ID | Prioridade | Item | Estado | Critérios de aceite | Dependências |
| --- | --- | --- | --- | --- | --- |
| UM-01 | P0 | Validar recuperação da conta institucional | Validar | Usuário recebe o código no e-mail, redefine a senha e entra no site; senha antiga e reutilização do código são recusadas. Registrar o resultado sem expor senha ou código. | — |
| UM-02 | P0 | Completar a jornada de e-mail não verificado | A fazer | Após login com senha válida de uma conta não verificada, abrir a tela de verificação; permitir reenviar o código; autenticar após validação; mostrar falha de envio sem anunciar sucesso. | — |
| UM-03 | P0 | Limitar tentativas no login e na verificação de e-mail | A fazer | Login, validação de código e reenvio têm limites definidos e testados; excesso retorna erro compreensível; códigos expirados ou utilizados não autenticam. Recuperação de senha mantém os limites já existentes. | — |
| UM-04 | P1 | Criar ambiente de QA com contas controladas | A fazer | Ambiente separado de produção, sem dados reais; contas de motorista e passageiro disponíveis; instruções de uso e limpeza documentadas; seeder demo continua bloqueado em produção. | — |
| UM-05 | P1 | Tratar falhas e demora da API | A fazer | Requisições têm prazo máximo; interface informa demora ou falha e permite tentar novamente; botões deixam de carregar ao finalizar ou falhar; novas tentativas não duplicam ações. | — |
| UM-06 | P1 | Validar veículos e publicação de caronas | Validar | Motorista cadastra veículo e publica carona; campos obrigatórios e quantidade de vagas são validados; usuário não altera veículos de terceiros; erros aparecem na tela. | UM-04 |
| UM-07 | P1 | Validar solicitações e consistência das vagas | Validar | Passageiro solicita carona; motorista aceita ou recusa; vagas refletem a resposta e o cancelamento; duas aceitações simultâneas não ultrapassam a capacidade; solicitação duplicada é tratada. | UM-04, UM-06 |
| UM-08 | P1 | Validar o grupo de chat por carona | Validar | Motorista e passageiros confirmados enviam e recebem mensagens sem recarregar a tela; usuários externos não acessam o grupo; mensagens não se repetem; desconexão e retorno são tratados. | UM-07 |
| UM-09 | P1 | Validar início, conclusão e cancelamento de caronas | Validar | Cada transição permitida funciona e é refletida para os participantes; transições inválidas são recusadas; passageiros recebem informação sobre cancelamento. | UM-07 |
| UM-10 | P1 | Melhorar busca e filtros de caronas | A fazer | Revisar filtros existentes de origem e destino; permitir filtrar data e campus conforme os dados disponíveis; limpar filtros restaura resultados; lista vazia mostra orientação. | UM-06 |
| UM-11 | P1 | Revisar uso em celular e acessibilidade | A fazer | Login, recuperação, cadastro, caronas e chat funcionam em tela pequena e com teclado aberto; campos e botões têm rótulos; navegação por teclado e controle de visibilidade das senhas funcionam. | UM-01, UM-08 |
| UM-12 | P1 | Automatizar validação do Flutter no GitHub | A fazer | Pull requests e pushes executam análise estática e testes do Flutter na pasta `front`; falhas ficam visíveis no GitHub; manter testes Laravel com PostgreSQL. | — |
| UM-13 | P2 | Validar notificações e indicação de mensagens novas | A fazer | Revisar notificações existentes; aceite, recusa e cancelamento aparecem na interface; definir e implementar indicação de mensagens não lidas no grupo; marcar como lida atualiza o contador. | UM-08, UM-09 |
| UM-14 | P2 | Validar avaliações, denúncias e bloqueios | Validar | Revisar regras existentes; testar avaliação após carona, denúncia e bloqueio; somente administradores alteram o estado de denúncias; interface explica o resultado das ações. | UM-09 |
| UM-15 | P2 | Documentar recuperação e operação dos serviços | A fazer | Documentar verificação de saúde, falhas de e-mail, variáveis secretas e procedimento de restauração do banco; testar restauração em ambiente isolado; definir procedimento de retorno à versão anterior. | UM-04 |
| UM-16 | P2 | Avaliar alternativa ao polling do chat | A fazer | Medir atraso e volume de requisições do chat atual; comparar opções compatíveis com a hospedagem e o orçamento escolhido; registrar a decisão e os testes necessários antes de migrar. | UM-08 |

## Próxima sequência de trabalho

1. Confirmar UM-01 com recebimento do e-mail e login reais.
2. Implementar UM-02 e UM-03 para fechar os fluxos de autenticação.
3. Preparar UM-04 e UM-12 para repetir o QA com segurança.
4. Validar UM-06 a UM-09 com motorista e passageiro, incluindo falhas e concorrência.
5. Priorizar UM-05 e UM-11 conforme os resultados do QA; depois selecionar as evoluções P2.

## Entregas já implementadas

| Entrega | Evidência disponível | Limite da validação |
| --- | --- | --- |
| API Laravel, PostgreSQL e aplicativo Flutter web publicados | Site na Vercel e API no Render responderam durante as verificações de publicação. | Disponibilidade precisa ser acompanhada; não garante todos os fluxos de negócio. |
| Cadastro de veículo pelo perfil | Botão e formulário implementados. | Jornada em produção ainda deve ser registrada no UM-06. |
| Sessão web por aba | Token armazenado por aba, em vez de compartilhado entre abas. | Confirmar a experiência com duas contas no QA. |
| Grupo de chat por carona | API e tela implementadas; teste de envio e recebimento no Flutter. | Atualmente utiliza consultas periódicas, sem WebSockets. |
| Integração de e-mail com Brevo | Transporte separado da geração dos códigos; envio de verificação observado anteriormente. | Recebimento e recuperação da conta atual ainda dependem do UM-01. |
| Mostrar e ocultar senha | Botão de olho no login, cadastro e recuperação. | Revisar acessibilidade e apresentação no UM-11. |
| Recuperação de senha e link abaixo de Criar conta | Rotas e tela publicadas; testes de expiração, uso único, isolamento entre contas e revogação de sessões. | Recebimento do código e novo login reais ainda não confirmados pelo usuário. |
| Preparação do código para GitHub | Documentação, exclusão de credenciais locais, bloqueio de contas demo em produção e atualização de segurança. | Não equivale a uma auditoria completa de segurança. |

## Conclusão de um item

Um item pode ser marcado como concluído quando seus critérios de aceite forem atendidos, os testes aplicáveis passarem, a documentação necessária estiver atualizada e, quando houver deploy, a versão publicada tiver sido conferida. Registre o commit ou a evidência de QA correspondente. Não incluir credenciais, códigos de recuperação nem dados pessoais na evidência.
