# Decisões de TC3-09

- GitHub Actions é mantido como mecanismo de CI/CD.
- Push valida; PR opened/synchronize/reopened planeja; PR closed com merged
  verdadeiro planeja novamente e aplica. PR fechado sem merge não implanta.
- Só PRs internos acessam AWS. Forks recebem validação sem credenciais.
- Um job Terraform mantém plan e apply no mesmo runner: o apply consome o
  plano binário salvo, sem transportar state/plano entre jobs.
- PR merged usa explicitamente merge_commit_sha no checkout.
- GitHub Environments homologacao/producao isolam variáveis e secrets.
- Configurações versionadas em environment.tfvars.json; credenciais e contas
  permanecem nas configurações do GitHub, e nunca nos arquivos de ambiente.
- Backend S3 parcial recebe bucket/região/conta no init; cada ambiente tem
  chave própria, encrypt=true e use_lockfile=true. Terraform mínimo 1.10.
- Concurrency sem cancelamento de execução ativa e lock S3 protegem o state.
- OIDC preferencial; alternativa com AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
  e AWS_SESSION_TOKEN atende contas temporárias de laboratório.
- Produção usa Multi-AZ e 14 dias de backup; homologação Single-AZ e 7 dias.
- Não criar IAM/bucket em pipeline: devem existir antes do primeiro init.
