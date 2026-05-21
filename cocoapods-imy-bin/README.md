# cocoapods-imy-bin

## `--imt`

`--imt` 用于忽略 CocoaPods 在集成用户工程时的 target 名称不匹配错误。

当 Podfile 中的 target 名称与 `.xcodeproj` 里的真实 target 名称不一致时，例如：

```text
[!] Unable to find a target named `Seeyou Today` in project `Seeyou.xcodeproj`, did find `Seeyou`.
```

开启 `--imt` 后，插件会将这类错误降级为 warning，并跳过这个不存在的 target 以及它对应的 pod 处理流程。

### install

```bash
pod bin install --imt
```

### update

```bash
pod bin update --imt
```

注意：`--imt` 只忽略这类 target 名称不匹配错误，并跳过对应 target 的 pod 处理，不会屏蔽其他 CocoaPods 校验错误。

