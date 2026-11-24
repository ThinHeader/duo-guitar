# 双琴

两部手机拼成一把吉他。琴颈只上传按弦，琴身负责扫弦和发声。

## 运行

```powershell
$env:Path = "C:\Users\Administrator\sdks\flutter\bin;" + $env:Path
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
dart run tool/gen_samples.dart
flutter run -d windows
```

手机上安装同一个包。一台选「琴身」，记下房间码和 IP。另一台选「琴颈」，输入房间码。发现失败时，把琴身 IP 填进「琴身 IP」。两台手机需要在同一个 Wi-Fi。

调试时首页有「分屏调试」，在一个窗口里同时按品和扫弦，不走网络。

## 开源协议

本项目采用 [CC BY-NC-SA 4.0](LICENSE)（署名-非商业性使用-相同方式共享 4.0 国际）协议公开发布。

- 可以署名分享、修改、二次开发，但**禁止任何商业使用**。
- 衍生作品必须沿用相同协议。
- 注意：CC BY-NC-SA 不是 OSI 认证的开源许可证，属于「公开源码 + 非商用」授权。
