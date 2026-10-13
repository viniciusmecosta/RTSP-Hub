# RTSP View

Aplicativo Flutter para cadastrar câmeras RTSP, localizar canais e monitorar vários fluxos em Android, Windows e Linux.

## Executar no Linux

O plugin de vídeo usa libmpv para reproduzir RTSP. Em Ubuntu ou Debian, instale as dependências de compilação uma vez:

```sh
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev libepoxy-dev libsecret-1-dev
```

Depois execute:

```sh
flutter pub get
flutter run -d linux
```

`libmpv-dev` contém cabeçalhos e metadados necessários para compilar o aplicativo. Não é VLC. O pacote Linux de distribuição inclui o runtime libmpv junto com o aplicativo.

## Validar

```sh
flutter analyze
flutter test
```

## Releases

Enviar uma tag no formato `v1.2.3` inicia a pipeline do GitHub Actions. Ela cria um instalador para Windows, um pacote `.deb` para Ubuntu e um APK Android, e anexa os três arquivos à release correspondente.

O instalador Windows x64 gerado pela pipeline inclui as bibliotecas de vídeo e o runtime Visual C++ junto ao aplicativo. Para usar essa versão do instalador, não é preciso instalar Flutter, VLC, MPV ou o Visual C++ Redistributable separadamente.
