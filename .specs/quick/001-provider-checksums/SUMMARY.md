# Quick Task 001: Resultado

O workflow de validação falhava antes de executar os testes porque o lock
gerado no Windows não continha o checksum h1 do provider AWS para Linux.
O init com lock somente leitura validava o pacote ZIP pelos hashes zh, mas
não persistia o h1 necessário para validar o provider extraído.

O comando oficial providers lock verificou as assinaturas HashiCorp para
windows_amd64 e linux_amd64, acrescentando somente o h1 do Linux. AWS permanece
na versão 6.64.0. O README documenta o comando para futuras atualizações.

## Verificação

- Falha original reproduzida no Linux com Terraform 1.16.2.
- Windows e Linux: fmt, init com lock somente leitura e validate aprovados.
- Windows e Linux: terraform test, nove aprovados e nenhuma falha.
- SHA256 do lock inalterado após as verificações em ambas as plataformas.
- Nenhum recurso AWS provisionado; os testes usam mock_provider.

## Commit

`fix(terraform): lock AWS provider for Windows and Linux`

Correção local. O envio ao GitHub e a nova execução da CI estão pendentes.
