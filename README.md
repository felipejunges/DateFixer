# Date Fixer Three

Aplicativo Android em Flutter para corrigir datas EXIF de imagens no celular após uma formatação.

## O que este app faz

- Lista as imagens encontradas no dispositivo.
- Mostra o nome do arquivo e a data EXIF atual.
- Verifica, por expressões regulares (Regex), se a data no nome do arquivo combina com a data EXIF.
- Seleciona automaticamente as imagens com descasamento.
- Permite corrigir em lote as imagens selecionadas.

## O que é EXIF

EXIF (Exchangeable Image File Format) é um conjunto de metadados gravados em fotos e vídeos.
Nele ficam informações como:

- Data e hora de captura (`DateTimeOriginal`)
- Modelo do aparelho/câmera
- Configurações da captura (ISO, exposição, etc.)
- Em alguns casos, localização GPS

Esses metadados são usados pela galeria e por apps para organizar mídia por data, criar linhas do tempo e manter ordem cronológica.

## Por que ocorre descasamento de data

Após formatação, backup/restauração, migração entre dispositivos ou download por mensageiros/nuvem, é comum acontecer:

- O nome do arquivo manter a data original (ex.: `IMG_20260226_155630.jpg`)
- O EXIF ser perdido, alterado ou sobrescrito com outra data

Quando isso acontece, as fotos aparecem fora de ordem na galeria e em backups, mesmo que o nome do arquivo ainda tenha a data correta.

## Motivação do projeto

Criei este projeto com ajuda de I.A. porque considero absurdo isso não vir resolvido nativamente no celular e, muitas vezes, a pessoa precisar pagar para fazer esse ajuste de forma segura em seus próprios arquivos.
