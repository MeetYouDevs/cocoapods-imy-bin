

require 'cocoapods-imy-bin/native/sources_manager'

module Pod
  class Specification
    VALID_EXTNAME = %w[.binary.podspec.json .binary.podspec .podspec.json .podspec].freeze
    DEFAULT_TEMPLATE_EXTNAME = %w[.binary-template.podspec .binary-template.podspec.json].freeze

    # TODO
    # 可以在这里根据组件依赖二进制或源码调整 sources 的先后顺序
    # 如果是源码，则调整 code_source 到最前面
    # 如果是二进制，则调整 binary_source 到最前面
    # 这样 CocoaPods 分析时，就会优先获取到对应源的 podspec
    #
    # 先要把 Podfile 里面的配置数据保存到单例中，再在这里判断，就不需要 resolver 了
    # 但是现在这个插件依旧可用，重构需要时间 = = ，没什么动力去重构了呀。。。
    #
    # class Set
    #   old_initialize = instance_method(:initialize)
    #   define_method(:initialize) do |name, sources|
    #     if name == 'TDFAdaptationKit'
    #       sources_manager = Pod::Config.instance.sources_manager
    #       # sources = [sources_manager.binary_source, *sources].uniq
    #       sources = [sources_manager.code_source, *sources].uniq
    #     end
    #     old_initialize.bind(self).call(name, sources)
    #   end
    # end
  end
end
