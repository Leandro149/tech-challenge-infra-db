# Especificação TC3-05

| ID | Requisito | Critério de aceitação |
| --- | --- | --- |
| R1 | Provisionar Amazon RDS PostgreSQL | Instância postgres, gp3 criptografado, endpoint privado, senha gerenciada pelo RDS. |
| R2 | VPC/subnets necessárias | VPC com DNS, duas subnets de banco e duas de aplicação em duas AZs; opção de VPC existente validada. |
| R3 | Security Groups | Porta 5432 somente de SGs autorizados; SGs novos com saída específica para banco e secret. |
| R4 | Backup e parâmetros | Retenção configurável de 1–35 dias, janela UTC, snapshot final, TLS obrigatório e logs. |
| R5 | Acesso Lambda e EKS | Outputs de rede, SGs de clientes, endpoint de secrets e policy IAM restrita; instruções para ENIs/nodes/pods. |

Verificação local: fmt, init sem backend, validate e terraform test com mocks.
Verificação AWS: aluno executa plan/apply e teste de conexão nas aplicações.

