<div align="center">
  <img src="assets/logo.png" alt="RTSP Hub" width="96">
  <h1>RTSP Hub</h1>
  <p>Visualizador local de câmeras IP e fluxos RTSP para desktop e dispositivos móveis.</p>

  <p>
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"></a>
    <a href="https://www.linux.org"><img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux"></a>
    <a href="https://www.android.com"><img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android"></a>
    <a href="https://www.microsoft.com/windows"><img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows"></a>
    <a href="https://mpv.io"><img src="https://img.shields.io/badge/libmpv-Decodificação_Nativa-7B1FA2?style=for-the-badge&logo=vlc&logoColor=white" alt="libmpv"></a>
  </p>
</div>

---

O **RTSP Hub** é um aplicativo multiplataforma criado para monitorar fluxos de câmeras de segurança diretamente na rede local, sem depender de internet, nuvem ou servidores externos. 

A reprodução usa decodificação acelerada por hardware via `libmpv`, renderizando o vídeo em texturas nativas do sistema com baixo uso de CPU e memória.

---

## Telas do aplicativo

### Desktop (Linux e Windows)

Monitoramento em tela cheia com barras e botões recolhidos durante a reprodução:

<table>
  <thead>
    <tr>
      <th align="center">Tema escuro</th>
      <th align="center">Tema claro</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center">
        <img src="assets/screenshots/desktop-dark.png" alt="RTSP Hub no desktop tema escuro" width="460">
      </td>
      <td align="center">
        <img src="assets/screenshots/desktop-light.png" alt="RTSP Hub no desktop tema claro" width="460">
      </td>
    </tr>
  </tbody>
</table>

### Dispositivos móveis (Android)

Interface adaptada para smartphones, com paginação automática para manter baixo consumo de bateria:

<table>
  <thead>
    <tr>
      <th align="center">Tema escuro</th>
      <th align="center">Tema claro</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center">
        <img src="assets/screenshots/android-dark.png" alt="RTSP Hub no celular tema escuro" width="240">
      </td>
      <td align="center">
        <img src="assets/screenshots/android-light.png" alt="RTSP Hub no celular tema claro" width="240">
      </td>
    </tr>
  </tbody>
</table>

---

## Funcionalidades principais

- **Grades flexíveis:** layouts simétricos (1x1, 2x2, 3x3, 4x4) e composições com uma câmera principal em destaque.
- **Modo foco com alívio de hardware:** ao ampliar uma câmera (duplo clique ou toque), os demais fluxos pausam em segundo plano para poupar processador, placa de vídeo e rede.
- **Canal principal e subfluxo:** suporta alta resolução para tela cheia e subfluxo leve para exibição simultânea na grade.
- **Descoberta de rede e ONVIF:** varredura de sub-rede para identificar portas RTSP abertas (554) e rotas de vídeo compatíveis com cancelamento instantâneo.
- **Teste prévio (Probe):** valida a decodificação da imagem e credenciais antes de salvar, gerando miniaturas com data e hora real da captura.
- **Cofre seguro:** senhas ficam protegidas nos cofres nativos de cada sistema (Secret Service no Linux, Credential Manager no Windows e Keystore no Android).
- **Reconexão automática:** monitora a saúde das transmissões e reconecta fluxos interrompidos de forma progressiva.
- **Instância única:** controle que impede a abertura de janelas duplicadas na mesma sessão no desktop.

---

## Como executar

### No Linux (Ubuntu / Debian)

Instale as bibliotecas necessárias para compilar:

```sh
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev libepoxy-dev libsecret-1-dev
```

Execute o projeto:

```sh
flutter pub get
flutter run -d linux
```

### No Android

Conecte o smartphone ou inicie um emulador e execute:

```sh
flutter run -d android
```

---

## Pacotes e Releases

Os instaladores finais são gerados pela automação do repositório a cada nova tag de versão:

- **Linux:** pacote `.deb` com bibliotecas de vídeo integradas (não requer instalar `libmpv` à parte).
- **Android:** aplicativo em formato `.apk` pronto para instalação.
- **Windows:** instalador `.exe` x64 com runtimes de vídeo e Visual C++ embutidos.

