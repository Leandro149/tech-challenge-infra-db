# Quick Task 002: Configuração preparada

Credenciais salvas no profile default dos arquivos AWS locais, que não
existiam antes desta configuração. Região us-east-1 definida no config e
no terraform.tfvars ignorado pelo Git.

aws_account_id permite restringir o provider à conta informada. Seu default
null mantém compatibilidade para quem não configurar uma conta permitida.

fmt, validate e os nove testes com AWS simulada passaram.

A autenticação real depende do AWS_SESSION_TOKEN da mesma sessão das chaves
temporárias. Nenhuma chamada autenticada, plan ou apply foi executada.

## Commit

`feat(aws): support restricting the configured account`
