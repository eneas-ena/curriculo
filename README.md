# Rede de Crianças

Gerador de material e trilha de formação bíblica do Departamento Infantil da Igreja Vidas.

**Abrir o app:** https://eneas-ena.github.io/curriculo/

## Como funciona

- App feito em página web; abre direto no navegador.
- Os dados ficam salvos no Supabase, por isso aparecem iguais em todos os aparelhos.
- Os serviços externos, como a inteligência artificial, passam pelo Worker `curriculo-criancas` no Cloudflare; as chaves secretas ficam guardadas lá, nunca neste código.

## Observações

- `previa-impressao.html` é a página de prévia para impressão das lições.

## Como publicar uma nova versão

1. Nesta página do repositório, clique em **Add file → Upload files**.
2. Arraste os arquivos novos, com os mesmos nomes dos antigos.
3. Clique em **Commit changes**.

Em um ou dois minutos a nova versão está no ar no mesmo endereço.

---
Desenvolvido por Bispo Enéas Araújo.
