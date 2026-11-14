# 本地验证与 XCFramework 制作

## 插件测试

在本目录使用 Bundler，Gemfile 的 `gemspec` 引用当前源码，避免误测已发布版本：

```sh
bundle install
bundle exec rake specs
bundle exec pod bin --help
```

当前验证组合：Ruby 3.3、CocoaPods 1.17、Xcode 27.2、Apple Silicon。
`mocha-on-bacon` 不兼容 Mocha 3 的 `mocha_verify` API，开发依赖锁定 Mocha 2。
完整 iOS 验证需要完整 Xcode；可设置进程级 `DEVELOPER_DIR`，不必修改全局 xcode-select。

## 可选 XCFramework 路径

旧归档路径构建 armv7 并合并设备与模拟器库，无法用于当前 Xcode 的完整 arm64 验证。
新增显式参数，保留原路径默认行为：

```sh
# 在源码组件的 podspec 所在目录执行
bundle exec pod bin auto TinyMath.podspec.json --xcframework --no-clean
```

该命令分别构建 iphoneos 和 iphonesimulator 静态库，由 `xcodebuild -create-xcframework`
生成两个平台切片，打包 ZIP，上传文件并发布二进制 podspec。
下载地址仍由 `bin_dev.yml` 等环境配置指定；制作前须配置自己可写的 spec 仓库与上传服务。
`auto` 有实际上传/推送行为；仅制作可使用 `pod bin archive ... --xcframework`。

支持 iOS Objective-C 和 Swift 静态 Framework，以及普通 Pod 依赖、`resources`、`resource_bundles`。
Swift 模块和 `.swiftinterface` 保留；XCFramework 使用模块名命名，ZIP 和下载地址仍使用 Pod 名称。
资源保留原始路径和本地化目录，由消费工程按实际 SDK 编译资产目录等资源。
`exclude_files` 在收集资源时应用；包内文件实体化，越界或循环软链直接报错。

```sh
# 同时制作并发布根组件及其传递依赖（按依赖顺序）
bundle exec pod bin auto FeatureKit.podspec.json --xcframework --all-make --no-clean
```

不传 `--all-make` 时仅输出根组件；依赖可继续使用源码或事先制作的二进制。
生成二进制 spec 固定实际参与编译的直接依赖版本（包括 iOS 专属依赖），避免消费端选用不同版本。
制作时强制使用源码来源，已有同版本二进制不会成为重复制作的输入。
每个 Pod 单独打包，不将依赖符号合并进根组件。

制作时开启 Swift library evolution。输出 spec 带 `IMY_BINARY_LIBRARY_EVOLUTION=YES` 标记；
消费安装的 post_install hook 会为该二进制的传递源码 Swift 依赖统一设置
`BUILD_LIBRARY_FOR_DISTRIBUTION=YES` 并保存 Pods 项目，保证混合模式的 ABI 一致。
仅匹配标记，不改普通源码工程或未标记的第三方二进制；该行为需要消费端也加载此插件。
自定义 post_install/后续手工修改不得再将这些依赖改回 NO。
同一源码依赖若同时服务于未知 ABI 的第三方二进制，需要额外确认配置兼容，本次未覆盖。

仍明确拒绝仅资源而无可编译代码的 Pod、subspec、非 iOS 平台、vendored 输入、按需资源（on-demand resources）、自定义 module map 和构建脚本。
`--xcframework` 不支持与 `--framework-output`、`--no-zip` 同时使用。
生成项目仅在本次制作上下文使用静态 Framework，不改变普通消费工程的链接配置。
新路径不使用旧增量缓存，因为旧缓存键不区分产物格式和工具链。

接入保持原有 Podfile 配置：

```ruby
plugin 'cocoapods-imy-bin'
use_binaries!
```

验收必须检查实际 ZIP 下载、平台切片、二进制命中报告、Pods 中无组件实现源码，
并分别执行模拟器功能测试和真机 SDK 构建。仅有 `auto` 成功提示或 `pod install` 成功不足以证明接入成功。

上传逻辑现在校验 curl/HTTP 失败，失败时不发布 spec；`auto` 的上传或发布失败会返回非零。
真机 SDK 无签名构建不代表已完成真机安装、签名或运行验证。
