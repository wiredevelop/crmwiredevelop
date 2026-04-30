# Checklist de Paridade Web Laravel vs Flutter

Data da análise: 2026-04-30

## Legenda

- [x] Paridade funcional aceitável
- [~] Paridade parcial
- [ ] Sem paridade

## Dashboard

- [x] Web: dashboard com indicadores principais
- [x] Flutter: dashboard com indicadores principais
- [~] Web: mais detalhe administrativo em tabelas e breakdowns
- [~] Flutter: visão mais resumida

Notas:
- A base funcional existe nas duas plataformas.
- A web continua mais rica para exploração analítica.

## Clientes

- [x] Web: listar clientes
- [x] Flutter: listar clientes
- [x] Web: criar cliente
- [x] Flutter: criar cliente
- [x] Web: editar cliente
- [x] Flutter: editar cliente
- [x] Web: apagar cliente
- [x] Flutter: apagar cliente
- [x] Web: notas internas
- [x] Flutter: notas internas
- [x] Web: criar acesso portal
- [x] Flutter: criar acesso portal
- [x] Web: regenerar senha temporária
- [x] Flutter: regenerar senha temporária
- [ ] Web: duplicar cliente
- [ ] Flutter: duplicar cliente
- [x] Web: criar objeto
- [x] Flutter: criar objeto
- [x] Web: criar credencial
- [x] Flutter: criar credencial
- [x] Web: transferir objeto
- [x] Flutter: transferir objeto
- [x] Web: promover objeto para cliente
- [x] Flutter: promover objeto para cliente
- [x] Web: mostrar/ocultar senha
- [x] Flutter: mostrar/ocultar senha
- [x] Web: copiar senha
- [x] Flutter: copiar senha
- [x] Web: abrir URL da credencial
- [x] Flutter: ver URL da credencial
- [x] Web: exportar objeto
- [ ] Flutter: exportar objeto
- [x] Web: apagar objeto
- [ ] Flutter: apagar objeto
- [x] Web: apagar credencial
- [ ] Flutter: apagar credencial
- [x] Web: atalho novo projeto a partir do cliente
- [ ] Flutter: atalho novo projeto a partir do cliente

Estado do módulo:
- [~] Paridade parcial

## Objetos do cliente autenticado

- [x] Web: listar objetos do cliente autenticado
- [x] Flutter: listar objetos do cliente autenticado
- [x] Web: ver projeto associado
- [x] Flutter: ver projeto associado
- [x] Web: mostrar/ocultar senha
- [x] Flutter: mostrar/ocultar senha
- [x] Web: copiar senha
- [x] Flutter: copiar senha
- [x] Web: exportar objeto
- [ ] Flutter: exportar objeto

Estado do módulo:
- [~] Paridade parcial

## Projetos

- [x] Web: listar projetos
- [x] Flutter: listar projetos
- [x] Web: criar projeto
- [x] Flutter: criar projeto
- [x] Web: editar projeto
- [x] Flutter: editar projeto
- [x] Web: apagar projeto
- [x] Flutter: apagar projeto
- [x] Web: detalhe do projeto
- [x] Flutter: detalhe do projeto
- [x] Web: timeline/mensagens do projeto
- [x] Flutter: timeline/mensagens do projeto
- [x] Web: estado do projeto
- [x] Flutter: estado do projeto
- [x] Web: PDF do orçamento associado
- [x] Flutter: PDF do orçamento associado
- [x] Web: incluir produtos/packs no projeto/orçamento
- [x] Flutter: incluir produtos/packs no projeto/orçamento
- [x] Web: credenciais do projeto
- [ ] Flutter: credenciais do projeto
- [x] Web: apagar credenciais do projeto
- [ ] Flutter: apagar credenciais do projeto

Estado do módulo:
- [~] Paridade parcial

## Orçamentos

- [x] Web: listar orçamentos
- [x] Flutter: listar orçamentos
- [x] Web: ver detalhe
- [x] Flutter: ver detalhe
- [x] Web: exportar PDF
- [x] Flutter: exportar PDF
- [x] Web: exportar DOCX
- [ ] Flutter: exportar DOCX
- [x] Web: exportar DOCX parceiro
- [ ] Flutter: exportar DOCX parceiro
- [x] Web: partilha pública
- [ ] Flutter: partilha pública
- [x] Web: atualizar adjudicação
- [ ] Flutter: atualizar adjudicação
- [x] Web: visão de pipeline e recebidos
- [x] Flutter: visão resumida de pipeline

Estado do módulo:
- [~] Paridade parcial

## Produtos / Packs

- [x] Web: listar produtos/packs
- [x] Flutter: listar produtos/packs
- [x] Web: exportar PDF
- [x] Flutter: exportar PDF
- [x] Web: criar produto/pack
- [ ] Flutter: criar produto/pack
- [x] Web: editar produto/pack
- [ ] Flutter: editar produto/pack
- [x] Web: apagar produto/pack
- [ ] Flutter: apagar produto/pack
- [x] Web: alternar visibilidade de métodos de pagamento no PDF
- [ ] Flutter: alternar visibilidade de métodos de pagamento no PDF
- [x] Web: filtro por tipo produto/pack
- [ ] Flutter: filtro equivalente

Estado do módulo:
- [~] Paridade parcial

## Documentos / Faturas

- [x] Web: listar documentos
- [x] Flutter: listar documentos
- [x] Web: ver detalhe
- [x] Flutter: ver detalhe
- [x] Web: exportar PDF
- [x] Flutter: exportar PDF
- [x] Web: marcar pago
- [x] Flutter: marcar pago
- [x] Web: marcar pendente
- [x] Flutter: marcar pendente
- [x] Web: desfaturar
- [x] Flutter: desfaturar
- [x] Web: editar linhas do documento
- [ ] Flutter: editar linhas do documento
- [x] Web: editar método de pagamento
- [ ] Flutter: editar método de pagamento
- [x] Web: editar conta de pagamento
- [ ] Flutter: editar conta de pagamento

Estado do módulo:
- [~] Paridade parcial

## Financeiro

- [x] Web: resumo financeiro
- [x] Flutter: resumo financeiro
- [x] Web: movimentos recentes
- [x] Flutter: movimentos recentes
- [x] Web: gerir parcelas
- [ ] Flutter: gerir parcelas
- [x] Web: faturar item individual
- [ ] Flutter: faturar item individual
- [x] Web: desfaturar em lote
- [ ] Flutter: desfaturar em lote
- [x] Web: faturar em lote
- [ ] Flutter: faturar em lote
- [x] Web: marcar item para faturação
- [ ] Flutter: marcar item para faturação
- [x] Web: navegação operacional de backoffice
- [~] Flutter: leitura quase toda, poucas ações

Estado do módulo:
- [~] Paridade parcial

## Intervenções

- [x] Web: listar intervenções
- [x] Flutter: listar intervenções
- [x] Web: iniciar intervenção
- [x] Flutter: iniciar intervenção
- [x] Web: pausar
- [x] Flutter: pausar
- [x] Web: retomar
- [x] Flutter: retomar
- [x] Web: concluir
- [x] Flutter: concluir
- [x] Web: separação pack / sem pack
- [x] Flutter: separação pack / sem pack
- [x] Web: compra manual de pack a partir do módulo
- [x] Flutter: compra manual de pack a partir do módulo

Estado do módulo:
- [x] Paridade funcional aceitável

## Carteiras

- [x] Web: listar carteira por cliente
- [x] Flutter: listar carteira por cliente
- [x] Web: ver saldo em horas e valor
- [x] Flutter: ver saldo em horas e valor
- [x] Web: registar compra manual de pack
- [x] Flutter: registar compra manual de pack
- [x] Web: checkout Stripe para packs
- [x] Flutter: checkout Stripe para packs
- [x] Web: listar transações
- [x] Flutter: listar transações
- [x] Web: apagar transação
- [ ] Flutter: apagar transação

Estado do módulo:
- [~] Paridade parcial

## Carteira do cliente autenticado

- [x] Web: ver carteira
- [x] Flutter: ver carteira
- [x] Web: checkout Stripe
- [x] Flutter: checkout Stripe
- [x] Web: ver compras e transações
- [x] Flutter: ver compras e transações
- [x] Web: abrir PDF do pack
- [x] Flutter: abrir PDF do pack
- [x] Web: pagamento manual configurável
- [x] Flutter: pagamento manual visível quando configurado

Estado do módulo:
- [x] Paridade funcional aceitável

## Empresa

- [x] Web: editar dados da empresa
- [x] Flutter: editar dados da empresa
- [x] Web: IBAN / banco / SWIFT
- [x] Flutter: IBAN / banco / SWIFT
- [x] Web: método de checkout em destaque
- [ ] Flutter: método de checkout em destaque
- [x] Web: notas de pagamento
- [ ] Flutter: notas de pagamento
- [x] Web: métodos de pagamento adicionais
- [ ] Flutter: métodos de pagamento adicionais

Estado do módulo:
- [~] Paridade parcial

## Definições

- [x] Web: meta anual
- [x] Flutter: meta anual
- [x] Web: sobretaxa terminal (%)
- [x] Flutter: sobretaxa terminal (%)
- [x] Web: sobretaxa terminal fixa (€)
- [x] Flutter: sobretaxa terminal fixa (€)
- [x] Web: toggle IDE
- [x] Flutter: toggle IDE

Estado do módulo:
- [x] Paridade funcional aceitável

## Segurança / Autenticação

- [x] Web: login
- [x] Flutter: login
- [x] Web: mudança forçada de password
- [x] Flutter: mudança forçada de password
- [x] Web: passkeys / WebAuthn
- [x] Flutter: biometria local
- [x] Web: logout
- [x] Flutter: logout
- [x] Web: perfil
- [ ] Flutter: perfil equivalente
- [x] Web: forgot password
- [ ] Flutter: forgot password
- [x] Web: reset password
- [ ] Flutter: reset password
- [x] Web: verify email
- [ ] Flutter: verify email
- [~] Web: segurança existe mas não em experiência 1:1 com a app
- [~] Flutter: login rápido biométrico sem equivalente direto na web

Estado do módulo:
- [~] Paridade parcial

## Terminal Stripe

- [ ] Web: interface operacional de terminal
- [x] Flutter: Tap to Pay completo
- [x] Web: backend/API Stripe Terminal
- [x] Flutter: cliente operacional
- [x] Flutter: ligação ao leitor local
- [x] Flutter: cobrança presencial
- [x] Flutter: diagnóstico de dispositivo
- [x] Flutter: cálculo e visualização de sobretaxa

Estado do módulo:
- [ ] Sem paridade

## Resumo Executivo

### Módulos com melhor paridade

- Intervenções
- Carteira do cliente autenticado
- Definições
- Base de clientes/projetos no CRUD principal

### Módulos com maior desvio

- Terminal Stripe
- Financeiro
- Produtos / Packs
- Orçamentos
- Documentos
- Credenciais de projeto

### Prioridade recomendada para atingir 1:1

1. Produtos / Packs
2. Orçamentos
3. Documentos
4. Financeiro
5. Clientes: export/apagar objetos e credenciais, duplicar cliente
6. Credenciais de projeto
7. Carteiras: apagar transações
8. Empresa: métodos e notas de pagamento
9. Segurança: perfil e recuperação de conta
10. Web: interface de terminal, se quiseres paridade também do lado Laravel
