# Quick Task 002: Configuração preparada

Credenciais salvas no profile default dos arquivos AWS locais, que não
existiam antes desta configuração. Região us-east-1 definida no config e
no terraform.tfvars ignorado pelo Git.

aws_account_id permite restringir o provider à conta informada. Seu default
null mantém compatibilidade para quem não configurar uma conta permitida.

fmt, validate e os nove testes com AWS simulada passaram.

Token recebido posteriormente e salvo no profile default local.
sts get-caller-identity confirmou acesso à conta 213284176265 com a sessão
voc labs. Configuração e autenticação local concluídas.

A preparação posterior de backend e plan de homologação está registrada
na feature TC3-09; nenhum apply foi executado.

## Commit

`feat(aws): support restricting the configured account`
