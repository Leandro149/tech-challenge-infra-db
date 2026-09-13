# Quick Task 001: Checksums do provider na CI

**Date:** 2026-09-13
**Status:** Done

## Description

Corrigir o lock do provider AWS 6.64.0 para que a validação com lock somente
leitura funcione no Linux da CI e no Windows de desenvolvimento.

## Files Changed

- `.terraform.lock.hcl`: checksums oficiais para Windows e Linux.
- `README.md`: comando de manutenção do lock para ambas as plataformas.
- `.specs/project/STATE.md`: resultado da correção e das verificações.

## Verification

- [x] Reproduzir em Linux a falha com o lock original.
- [x] Confirmar que o lock corrigido mantém AWS 6.64.0 e os hashes existentes.
- [x] Executar fmt, init com lock somente leitura, validate e os nove testes
  com AWS simulada em Linux.
- [x] Executar init com lock somente leitura, validate e testes em Windows.

## Commit

`fix(terraform): lock AWS provider for Windows and Linux`
