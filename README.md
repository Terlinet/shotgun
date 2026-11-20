# TerlineT Bubble Gun

Aplicativo Flutter com fundo de vídeo, arma controlada pela posição horizontal da
mão e um alvo animado. Ao apontar e puxar o dedo, a arma dispara; acertar o alvo
aciona uma animação de explosão e faz o alvo reaparecer em outra posição.

## Executar

```shell
flutter pub get
flutter run -d chrome
```

## GitHub Pages

O deploy é feito automaticamente pelo GitHub Actions ao enviar alterações para
`main`. O site fica disponível em:

https://terlinet.github.io/shotgun/

Na primeira publicação, confirme em **Settings > Pages** que a origem está
configurada como **GitHub Actions**.

Para usar o reconhecimento de gestos, execute a versão Web em `localhost` ou
HTTPS, clique em **Ativar gesto** e permita o acesso à câmera. O rastreamento
MediaPipe é carregado do jsDelivr e requer conexão com a internet. O controle por
câmera está disponível na versão Web; no Android, o app exibe os elementos da
tela, mas o rastreamento por câmera ainda não está integrado.

## Assets

- `assets/videos/BubblesChain.mp4`: vídeo de fundo.
- `assets/videos/gun-shoot.gif`: GIF decorativo no canto inferior esquerdo.
- `assets/videos/pepe.gif`: alvo animado.
- `assets/tirosemfundo.png`: imagem da arma e mão com fundo transparente.
