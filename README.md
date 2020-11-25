

### 更新
- 2020-11-02

  v0.3.0.11 支持纯Swift、纯Object-C、Swift-OC混编
 
# Cocoapods-imy-bin

关于 插件具体的架构部署实践和更详细的资源，可以参考

> [iOS编译速度如何稳定提高10倍以上](https://juejin.im/post/5eccceb9f265da76f30e4e13)
>
> [iOS美团同款"ZSource"二进制调试实现](https://juejin.im/post/5f066cfa5188252e893a136e)
>
> [iOS教你如何像RN一样实时编译](https://juejin.im/post/6850037272415813645)
>
> [Swift编译慢？请看这里，全套开源](https://juejin.im/post/6890419459639476237)
>
> [OC-Demo](https://github.com/su350380433/cocoapods-imy-bin-demo)
>
> [Swift-OC-Demo](https://github.com/su350380433/Swift-OC-Demo)





### 特色：

 1. **无入侵、无感知、不影响现有业务，不影响现有代码框架、完全绿色产品~**
 2. **轻量级，只要项目能编译通过就能使用，无视组件化、无视耦合**
 3. **完全自动化，一键使用、无需手动操作**
 4. **一步步教你使用，新手也能欢乐玩转**
 5. **提供几个特色服务**
 6. **支持 使用与不使用 use_frameworks!**
 7. **少数支持swift项目二进制化编译的开源项目之一**

## 一、概要

 
cocoapods-imy-bin功能点：

 1. 组件二进制化，`无入侵式`支持组件二进制化，完全自动化，无需手动操作。致力于解决Ci打包速度慢、研发编译慢等编译问题。
 2. 本地配置文件 - `Podfile_local`
 3. 二进制源码调试`pod bin code`，类似[美团 iOS 工程 zsource 命令背后的那些事儿](https://juejin.im/post/6847897745987125262)的效果。
 4. 命令快捷键`pod bin imy`，如游戏快捷键，根据配置会在特定目录执行特定命令（如任意终端目录下，执行某个特定目录的pod update --no-repo-update命令），减少其他繁琐操作。支持任意个快捷键。

cocoapods-imy-bin插件所关联的组件二进制化策略：

预先将打包成 `.a`  的组件保存到静态服务器上，并在 `install` 时，去下载组件对应的二进制版本，以减少组件编译时间，达到加快 App 打包、组件发布等操作的目的。



## 二、准备工作



### 1、安装插件

```shell
sudo gem install cocoapods-imy-bin
```



## 三、使用二进制组件


### 1、环境搭建

<br/>

[环境搭建详细教程](https://github.com/su350380433/cocoapods-imy-bin-demo)

使用二进制时，本插件需要提供以下资源：

- 静态资源服务器（ [binary-server](https://github.com/su350380433/binary-server)，附详细使用教程）
- 二进制私有源仓库（保存组件二进制版本 podspec）



### 2、初始化插件

``` shell
xx:Demo slj$ pod bin init

======  dev 环境 ========

开始设置二进制化初始信息.
所有的信息都会保存在 /Users/slj/.cocoapods/bin_dev.yml 文件中.
%w[bin_dev.yml bin_debug_iphoneos.yml bin_release_iphoneos.yml] 
你可以在对应目录下手动添加编辑该文件. 文件包含的配置信息样式如下：

---
configuration_env: dev
code_repo_url: git@github.com:su350380433/example_spec_source.git
binary_repo_url: git@github.com:su350380433/example_spec_bin_dev.git
binary_download_url: http://localhost:8080/frameworks/%s/%s/zip
download_file_type: zip


编译环境
可选值：[ dev / debug_iphoneos / release_iphoneos ]
旧值：dev
```

按提示输入`所属环境`、源码私有源、二进制私有源、二进制下载地址、下载文件类型后，插件就配置完成了。其中 `binary_download_url` 需要预留组件名称与组件版本占位符，插件内部会依次替换 `%s` 为相应组件的值。

`cococapods-imy-bin` 也支持从 url 下载配置文件，方便对多台机器进行配置：

```shell
➜  ~ pod bin init --bin-url=https://github.com/su350380433/cocoapods-imy-bin-configs/raw/master/bin_dev.yml
```

配置文件模版内容如下，根据不同团队的需求定制即可：

```shell
---
configuration_env: dev
code_repo_url: git@github.com:su350380433/example_spec_source.git
binary_repo_url: git@github.com:su350380433/example_spec_bin_dev.git
binary_download_url: http://localhost:8080/frameworks/%s/%s/zip
download_file_type: zip

```

配置时，不需要手动添加源码和二进制私有源的 repo，插件在找不到对应 repo 时会主动 clone。

记得启动 `sudo mongod`服务，静态资源服务。


<br/>

## 四、制作二进制组件

<br/>

[视频演示](https://github.com/MeetYouDevs/cocoapods-imy-bin/tree/master/%E6%BC%94%E7%A4%BA%E8%A7%86%E9%A2%91)

### 1、制作命令

可以直接使用插件的 `pod bin auto`命令，在插件初始化配置完成后，目录下只要有包含podspec文件，根据podspec文件的version版本号会自动化执行build、组装二进制组件、制作二进制podspec、上传二进制文件、上传二进制podspec到私有源仓库。

```shell
pod bin auto
```

带上`—all-make`参数会把当前组件所依赖的组件都自动化制作成二进制组件。

```shell
pod bin local
```

pod bin local 是配合其他三方编译产物的命令，需要配置编译产物的目录。

`BinArchive.json`是制作二进制的一些配置项，放在项目跟目录下：

``` json
{
    "//": "archive-white-pod-list 不制作二进制白名单，",
    "archive-white-pod-list" : [
        "YYTargetDemo",
        "YYModel"
    ],
    "//": "ignore-git-list 不制作二进制 所属git白名单，",
    "ignore-git-list": [
        "git@gitlab.xxx.com:Github-iOS"
    ],
     "//": "ignore-http-list 不制作二进制 所属https白名单，",
    "ignore-http-list": [
        "https://gitlab.xxx.com/Github-iOS"
    ],
    "//": "xcode_build_path 设置编译缓存完整路径, 默认地址如下",
    "xcode_build_path" : "xcode-build/Build/Intermediates.noindex/ArchiveIntermediates/#{target_name}/IntermediateBuildFilesPath/UninstalledProducts/iphoneos/",
}
```


<br/>

### 2. 二进制Podspec 

通过`pod bin auto`和`pod bin local`二进制Podspec 会自动生成、上传，无需关心。


<br/>

### 3、查看结果

二进制存储服务：[http://localhost:8080/frameworks/](http://localhost:8080/frameworks/)（默认本地8080端口）

二进制私有源参考：[https://github.com/su350380433/example_spec_bin_dev](https://github.com/su350380433/example_spec_bin_dev)（自定义）


<br/>

### 4、使用二进制

<br/>

[视频演示](https://github.com/MeetYouDevs/cocoapods-imy-bin/tree/master/%E6%BC%94%E7%A4%BA%E8%A7%86%E9%A2%91)

在Podfile文件中，加入这两行代码，对已经制作二进制的就会生效，自动转换二进制组件依赖。

``` ruby
plugin 'cocoapods-imy-bin'
use_binaries!
```


<br/>

## 五、扩展功能

<br/>

### 1、本地配置文件 - Podfile_local

本地组件配置文件 Podfile_local，目前已支持Podfile下的大部分功能，可以把一些本地配置的语句放到Podfile_local。

<img src="https://raw.githubusercontent.com/MeetYouDevs/cocoapods-imy-bin/master/img/Podfile_local.png" style="zoom:50%;" />

场景: 

1. 不希望把本地采用的源码/二进制配置、本地库传到远程仓库。
2. 避免直接修改Podfile文件，引起更新代码时冲突、或者误提交。

如Podfile本地库的写法：
```ruby
pod YYModel :path => '../' #提交的时候往往要修改回来才提交，操作繁琐
```
用法：

在与Podfile同级目录下，新增一个`Podfile_local`文件

```ruby
#target 'Seeyou' do 不同的项目注意修改下Seeyou的值
#:path => '../IMYYQHome',根据实际情况自行修改，与之前在podfile写法一致


 plugin 'cocoapods-imy-bin'
#是否启用二进制插件，想开启把下面注释去掉
# use_binaries! 

#设置使用【源码】版本的组件。
#set_use_source_pods ['YYKit','SDWebImaage']

#需要替换Podfile里面的组件才写到这里
#在这里面的所写的组件库依赖，默认切换为【源码】依赖
target 'Seeyou' do
  #本地库引用
	#pod 'YYModel', :path => '../YYModel'

  #覆盖、自定义组件
  	#pod 'YYCache', :podspec => 'http://覆盖、自定义/'
end
```

```ruby
以前的 pod update --no-repo-update 命令加个前缀 `bin` 变成
```

```shell
pod bin update --no-repo-update 
```
or
```shell
pod bin install
```

支持 pod install/update 命令参数

并将其加入 .gitignore ，再也不用担心我误提交或者冲突了，Podfile_local 中的配置选项优先级比 Podfile 高，支持和 Podfile 相同的配置语句，同时支持**pre_install** or **post_install**。


如果您不习惯Podfile_local的使用方式，可以把命令写在Podfile里面，pod时不需要加bin，依旧是 pod update/install。


<br/>

### 2、二进制源码调试

<br/>

[视频演示](https://github.com/MeetYouDevs/cocoapods-imy-bin/tree/master/%E6%BC%94%E7%A4%BA%E8%A7%86%E9%A2%91)

在项目根目录下，输入命令:

```ruby
pod bin code YYModel
```

`YYModel`为需要源码调试的组件库名称。成功之后像平时一样单步调试，控制台打印变量。让我们同时拥有使用二进制的便利和源码调试的能力。

``` shell
 $ pod bin code --help                                                                   [11:37:50]
Usage:

    $ pod bin code [NAME]

      通过将二进制对应源码放置在临时目录中，让二进制出现断点时可以跳到对应的源码，方便调试。 在不删除二进制的情况下为某个组件添加源码调试能力，多个组件名称用空格分隔

Options:

    --all-clean   删除所有已经下载的源码
    --clean       删除所有指定下载的源码
    --list        展示所有一级下载的源码以及其大小
    --source      源码路径，本地路径,会去自动链接本地源码
```

效果与演示参考[链接1](https://juejin.im/post/5eccceb9f265da76f30e4e13#heading-48)、[视频](https://github.com/MeetYouDevs/cocoapods-imy-bin/tree/master/%E6%BC%94%E7%A4%BA%E8%A7%86%E9%A2%91)


<br/>

### 3、快捷键命令

<br/>

在任意的终端执行命令，都能执行特定目录下特定命令

使用命令：

```shell
pod bin imy
```

or

``` shell
pod bin imy 2    #2 是自定义的快捷键
```

使用场景:

 	1. 在任意目录下，执行项目A的pod update --no-repo-update命令

命令快捷键配置

```shell
 $ pod bin inithk                                                                        [11:37:58]

开始设置快捷键 pod bin imy.
所有的信息都会保存在 /Users/ci/.cocoapods/hot_key_1.yml 文件中.
%w[hot_key.yaml] 
你可以在对应目录下手动添加编辑该文件. 文件包含的配置信息样式如下：

---
hot_key_index: '1'
hot_key_dir: '/User/ci/自定义目录'
hot_key_cmd: pod bin update --no-repo-update


快捷键
可选值：[ 1 / 2 / 3... ]
旧值：1 
```


<br/>

## 六、 DSL参数解释



首先，开发者需要在 Podfile 中需要使用 `plugin 'cocoapods-imy-bin'` 语句引入插件 

```ruby
plugin 'cocoapods-imy-bin'
```

顺带可以删除 Podfile 中的 source ，因为插件内部会自动帮你添加两个私有源。

`cocoapods-bin `插件提供二进制相关的配置语句有 `use_binaries!`、`use_binaries_with_spec_selector!` 以及 `set_use_source_pods`，下面会分别介绍。

##### use_binaries!

全部组件使用二进制版本。

支持传入布尔值控制是否使用二进制版本，比如 DEBUG 包使用二进制版本，正式包使用源码版本，Podfile 关联语句可以这样写：

```ruby
use_binaries! (ENV['DEBUG'].nil? || ENV['DEBUG'] == 'true')
```

##### set_use_source_pods

设置使用源码版本的组件。

实际开发中，可能需要查看 YYModel 组件的源码，这时候可以这么设置：

```ruby
set_use_source_pods ['YYModel']
```

如果 CocoaPods 版本为 1.5.3 ，终端会输出以下内容，表示 YYModel 的参照源从二进制私有源切换到了源码私有源：

```ruby
Analyzing dependencies
Fetching podspec for `A` from `../`
Downloading dependencies
Using A (0.1.0)
Installing YYModel 1.0.4.2 (source changed to `git@git.xxxxxx.net:ios/cocoapods-spec.git` from `git@git.xxxxxx.net:ios/cocoapods-spec-binary.git`)
Generating Pods project
Integrating client project
Sending stats
Pod installation complete! There is 1 dependency from the Podfile and 2 total pods installed.
```

##### use_binaries_with_spec_selector!

过滤出需要使用二进制版本组件。

假如开发者只需要 `YYModel` 的二进制版本，那么他可以在 Podfile 中添加以下代码：

```ruby
use_binaries_with_spec_selector! do |spec|
  spec.name == 'YYModel'
end
```

**需要注意的是，如果组件有 subspec ，使用组件名作为判断条件应如下**：

```ruby
use_binaries_with_spec_selector! do |spec|
  spec.name.start_with? == '组件名'
end
```

如果像上个代码块一样，**直接对比组件名，则插件会忽略此组件的所有 subspec，导致资源拉取错误**，这种场景下，最好通过 `set_use_source_pods` 语句配置依赖。

一个实际应用是，三方组件采用二进制版本，团队编写的组件依旧采用源码版本。如果三方组件都在 `cocoapods-repo` 组下，就可以使用以下代码过滤出三方组件：

```ruby
use_binaries_with_spec_selector! do |spec|
 git = spec.source && spec.source['git']
 git && git.include?('cocoapods-repo')
end
```

##### 切换Dev/Debug_iPhoneos/Release_iPhoneos环境初始化设置


```shell
#dev 初始化插件配置 默认dev环境
pod bin init --bin-url=https://gitlab.xxx.com/cocoapods-imy-bin-config/raw/master/bin_dev.yml

#Debug_iPhoneos 初始化插件配置
pod bin init --bin-url=https://gitlab.xxx.com/cocoapods-imy-bin-config/raw/master/bin_debug_iphoneos.yml


#release_iPhoneos 初始化插件配置
pod bin init --bin-url=https://gitlab.xxx.com/cocoapods-imy-bin-config/raw/master/bin_release_iphoneos.yml
```

使用时在podfile 或者 podfile_local指定设置

```shell
#在podfile 或者 podfile_local 文件下加这句话
set_configuration_env('debug_iphoneos')	
```

##### 其他设置

插件默认开启多线程下载组件资源，如果要禁用这个功能，Podfile 添加以下代码即可：

```ruby
install! 'cocoapods', { install_with_multi_threads: false }
```


<br/>

## 七、感谢



**[cocoapods-bin](https://github.com/tripleCC/cocoapods-bin)**

[美团 iOS 工程 zsource 命令背后的那些事儿](https://tech.meituan.com/2019/08/08/the-things-behind-the-ios-project-zsource-command.html)

#### 您有什么更好的想法，可以提出来，我们一起来实现，共创一个强大的工具平台，同时也欢迎给我们提PR。 

加技术讨论群，微信号：su1231235 （备注 cocoapods-imy-bin加群）
