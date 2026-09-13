# Tarefas de TC3-09

- [x] T1 — Backend e ambientes (CICD-04/05)
  - Arquivos: backend.tf, versions.tf, environments/{homologacao,producao}/
    {backend.hcl,environment.tfvars.json}, tests/environments/environment.tftest.hcl.
  - Aceite: fmt/init sem backend/validate; testes atuais e testes de cada
    configuração real com provider simulado.
  - Commit: feat(infra): isolate staging and production state and configuration
- [x] T2 — Pipeline (CICD-01/02/03/05/06), depende de T1
  - Arquivo: .github/workflows/terraform.yml.
  - Aceite: actionlint; fmt/validate/test; revisão dos eventos, origem do PR,
    autenticação, conta esperada e uso do plano salvo no apply.
  - Verificado: actionlint 1.7.12 e dez cenários dos scripts reais de
    preflight/apply com comandos simulados; credenciais ausentes, falta do
    token, revisão desatualizada e falha da consulta impedem o apply.
  - Commit: ci(terraform): plan pull requests and apply merged environments
- [ ] T3 — Documentação (CICD-07), depende de T1/T2
  - Arquivos: README.md, docs/cicd.md, .specs/project/{STATE,ROADMAP}.md.
  - Aceite: guia de configuração contém todos os nomes usados na pipeline,
    comandos de bucket/IAM, branches e dependências externas reais.
  - Commit: docs(cicd): document environment setup and deployment flow
