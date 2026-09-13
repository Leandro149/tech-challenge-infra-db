# TC3-09 — CI/CD da infraestrutura

## Problema e objetivo

A CI atual apenas formata, valida e executa mocks. A atividade exige plano
Terraform nos PRs e aplicação após merge, separando homologação e produção.

## Requisitos e aceite

| ID | Quando / então | Verificação |
| --- | --- | --- |
| CICD-01 | Em push ou PR aberto/atualizado, executar fmt, init sem backend, validate e testes simulados. | Terraform e análise do workflow |
| CICD-02 | Em PR interno para develop/main, executar plan no ambiente correspondente; nunca executar apply enquanto aberto. | Condições de eventos e actionlint |
| CICD-03 | Quando PR interno for merged, gerar novo plano do commit de merge e aplicar esse arquivo somente após validação bem-sucedida. | Evento closed + merged; plano salvo |
| CICD-04 | develop usa homologacao/staging e main usa producao/prod, com configurações, CIDRs, nomes e chaves de state distintos. | Testes dos arquivos de ambiente |
| CICD-05 | Usar backend S3 criptografado, com lock nativo, e serializar operações por ambiente. | Configuração HCL e workflow |
| CICD-06 | Autenticar por OIDC ou secrets por ambiente; conferir conta e exigir token para chaves temporárias. | Preflight e ação AWS |
| CICD-07 | Documentar bucket, IAM, environments, variáveis/secrets, branches e execução local. | Guia reproduzível |

## Limites

Implementar a pipeline e seus arquivos. Não executar deploy real nesta sessão:
o token AWS ainda não foi informado e os recursos de backend não existem
confirmadamente. Não alterar os projetos Lambda/EKS.

## Estado

Implementação e verificações locais em andamento. Plan/apply reais dependem
da configuração do GitHub e do backend AWS.
