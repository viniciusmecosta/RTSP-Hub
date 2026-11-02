# Android TV e Google TV

O RTSP Hub mantém uma única aplicação para Android, tablets, desktop Linux e Windows. O mesmo APK Android também declara suporte a Android TV e Google TV. A identificação da televisão usa o modo do sistema e a presença da funcionalidade Leanback; não depende do fabricante nem do nome do aparelho. Uma tela grande, sozinha, não ativa a experiência de televisão.

## Instalação e primeira configuração

1. Instale o APK Android da release no dispositivo, autorizando a instalação pela ferramenta de transferência usada na TV. O aplicativo ainda não é distribuído pela Play Store.
2. Abra **RTSP Hub** no menu de aplicativos da televisão.
3. Mantenha a televisão e as câmeras na mesma rede, ou em redes que tenham acesso entre si.
4. Configure a conexão global ou os dados individuais das câmeras, teste o vídeo e associe as câmeras a um layout.
5. Em **Ajustes → Ao abrir o aplicativo**, escolha **Monitor** ou **Automático** para abrir a grade nas próximas execuções. Isso não inicia o aplicativo automaticamente quando o Android liga.

As bibliotecas de reprodução são incluídas no APK. Não é necessário instalar VLC ou MPV separadamente. Um mouse ou teclado externo continua sendo opcional para agilizar o cadastro; o monitor e os controles também aceitam o direcional.

## Controle e teclado

- **Setas:** navegar entre as câmeras, botões, campos e opções.
- **OK, Enter ou botão A:** ativar o controle selecionado; na imagem da câmera, ampliar ou retornar à grade.
- **Voltar ou Esc:** retornar da câmera ampliada, fechar os diagnósticos ou sair do monitor. Nas páginas de configuração, Voltar retorna ao início.
- **Página anterior e Próxima página:** trocar as câmeras em exibição. Os mesmos controles estão no menu do monitor em telas compactas.
- **Page Up / Page Down:** trocar páginas pelo teclado.
- **Teclado e controle remoto**, no menu do monitor: consultar os atalhos existentes.

O foco da câmera tem um contorno visível. Os controles reaparecem com a interação e não são recolhidos enquanto um botão do monitor está selecionado ou um menu está aberto. O uso por toque, mouse e clique duplo permanece disponível nos outros dispositivos.

## Câmeras por página

**Ajustes → Reprodução e desempenho → Câmeras por página** está disponível em todas as plataformas:

| Opção | Comportamento |
| --- | --- |
| Automático | Mostra até quatro posições em televisões e mantém a grade inteira nos outros dispositivos. |
| 1, 2, 4, 6, 9 ou 16 | Divide a grade em páginas com a quantidade escolhida. |
| Todas da grade | Exibe simultaneamente todas as posições do layout, inclusive na televisão. |

A escolha não apaga câmeras, canais, layouts ou perfis. A preferência acompanha o backup completo. Somente as câmeras da página visível mantêm sessões de reprodução; a página anterior é fechada antes de abrir a próxima. Ao ampliar uma câmera, as outras sessões da página permanecem conectadas para permitir o retorno à grade sem recarga. As superfícies ocultas não são desenhadas nem recebem foco e suas animações ficam suspensas. O decoder recebe uma solicitação para descartar quadros que não são referência enquanto a câmera está oculta, com restauração ao retornar à grade; a economia varia com o codec e o hardware.

No Android TV, as aberturas e reconexões são coordenadas com uma conexão em preparação por vez. Isso não limita quantas câmeras já conectadas podem continuar reproduzindo.

## Desempenho

- Comece pelo perfil **Leve** e pelo subfluxo das câmeras quando houver vários vídeos simultâneos.
- A ampliação preserva o fluxo atual em todas as plataformas, inclusive o subfluxo automático nos perfis Leve e Equilibrado. A opção manual de fluxo principal e o perfil Qualidade continuam disponíveis.
- Se o aparelho apresentar lentidão, escolha duas câmeras por página. As demais continuam cadastradas e acessíveis nas próximas páginas.
- A resolução do vídeo não é reduzida por um fator fixo de escala na interface. A redução de consumo depende principalmente do fluxo escolhido, das sessões em exibição e da aceleração de vídeo suportada pelo aparelho.
- Quantidade de decodificadores, codec, resolução, FPS, taxa de dados e qualidade da rede afetam o resultado. Ter saída 1080p ou 4K não garante decodificar vários vídeos simultâneos nessa resolução.

Não há regras exclusivas para Mi Stick, bloqueios por modelo ou promessa de quatro fluxos principais em alta resolução. O Mi TV Stick Full HD possui 1 GB de RAM; quatro subfluxos precisam ser verificados no aparelho com as câmeras reais. A partir dessa medição, pode ser necessário reduzir a resolução/FPS na própria câmera ou a quantidade por página.

## Validação

Os testes automatizados cobrem ativação sem toque, navegação por setas, Voltar, temas claro/escuro, dimensões de televisão, política de páginas, preservação do backup e descarte de sessões. O APK deve ser validado também em uma televisão real para confirmar reprodução, limites do decodificador e comportamento do controle remoto do fabricante.

Referências: [preparar uma aplicação Android TV](https://developer.android.com/training/tv/get-started/create), [controles de TV](https://developer.android.com/training/tv/get-started/controllers) e [especificações Mi TV Stick](https://www.mi.com/global/product/mi-tv-stick/specs/).
