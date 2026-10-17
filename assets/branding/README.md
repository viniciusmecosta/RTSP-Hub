# Identidade do RTSP Hub

A marca Mosaico representa quatro áreas de vídeo, com um canal em destaque. O azul oficial é `#1764ED`. As quatro áreas são um símbolo de monitoramento simultâneo e não limitam o número de câmeras do aplicativo.

## Fonte e recursos

`assets/logo.svg` é a fonte vetorial aprovada. `assets/logo.png` é a versão de 1024 pixels usada pelo componente Flutter `AppLogo`, que limita a decodificação ao tamanho e à densidade da tela. Os símbolos transparentes estão em `mark.svg` e `mark-white.svg`.

Os ícones nativos são gerados diretamente do SVG:

- Android: ícones nas cinco densidades, camadas adaptáveis e versão temática monocromática. A marca é mantida dentro da área segura do [ícone adaptável](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).
- iOS e iPadOS: tamanhos declarados no catálogo de recursos, com fundo opaco e sem arredondamento prévio.
- macOS: tamanhos do catálogo, com margem transparente para o Dock.
- Windows: um único ICO com nove resoluções de 16 a 256 pixels, usado pelo executável e pelo instalador.
- Linux: PNGs de 16 a 512 pixels, versão escalável em SVG e fallback de 256 pixels.
- Recursos web existentes: favicon, ícones e versões com área segura para máscaras.

As telas de abertura de Android e iOS usam a mesma marca, com fundos claro e escuro. A abertura é estática, sem espera adicional. No Linux, o bundle também contém uma cópia do ícone para abrir fora do instalador. O pacote Debian registra o lançador com o identificador GTK existente e preserva um atalho de compatibilidade oculto, para manter o nome e a imagem corretos sem duplicar a entrada no menu.

## Regenerar

Em um ambiente de desenvolvimento Linux com Python 3, Cairo e librsvg:

```sh
sudo apt install python3-cairo python3-gi gir1.2-rsvg-2.0
python3 tool/generate_brand_assets.py
```

Essas ferramentas são usadas apenas para gerar recursos durante o desenvolvimento. Não são dependências para instalar ou executar o aplicativo.

Os arquivos gerados já estão no repositório; os builds e a pipeline não precisam executar a geração. O gerador também mantém os recursos XML de abertura do Android. Para conferir se todos correspondem ao SVG, usando apenas a biblioteca padrão do Python:

```sh
python3 tool/generate_brand_assets.py --check
python3 -m unittest discover -s tool/tests
```

Depois de alterar o SVG, regenere e versione os recursos junto com `resources.json`. Esse manifesto não contém datas de geração, para permitir conferir alterações sem modificar arquivos a cada build.

Use `AppLogo` nos locais que identificam o aplicativo. Os ícones funcionais de câmera, layout e navegação mantêm seus significados próprios. A tela de monitoramento prioriza os vídeos e não recebe uma marca sobre as imagens das câmeras.
