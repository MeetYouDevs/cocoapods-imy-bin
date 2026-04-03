require 'json'
require 'time'

module CBin
  class ResolutionReport
    attr_reader :events

    def initialize
      @events = []
      @start_time = Time.now
    end

    # Record a resolution event
    # event_type: :binary_hit, :missing_binary_version, :missing_source,
    #             :whitelist_filtered, :selector_filtered, :source_fallback
    def record(pod_name, version, event_type, detail = nil)
      @events << {
        pod: pod_name,
        version: version.to_s,
        event: event_type.to_s,
        detail: detail
      }
    end

    def summary
      grouped = @events.group_by { |e| e[:event] }
      {
        binary_hit: count_unique(grouped['binary_hit']),
        missing_binary_version: count_unique(grouped['missing_binary_version']),
        missing_source: count_unique(grouped['missing_source']),
        whitelist_filtered: count_unique(grouped['whitelist_filtered']),
        selector_filtered: count_unique(grouped['selector_filtered']),
        total: @events.map { |e| e[:pod] }.uniq.length
      }
    end

    def to_json_hash
      {
        'version' => CBin::VERSION,
        'timestamp' => Time.now.iso8601,
        'duration_seconds' => (Time.now - @start_time).round(2),
        'summary' => summary.transform_keys(&:to_s),
        'events' => @events
      }
    end

    def save(path)
      File.open(path, 'w') { |f| f.write(JSON.pretty_generate(to_json_hash)) }
    end

    def print_summary
      s = summary
      return if s[:total] == 0

      Pod::UI.puts "\n【二进制切换摘要】"
      Pod::UI.puts "  命中二进制: #{s[:binary_hit]}" if s[:binary_hit] > 0
      Pod::UI.puts "  缺失二进制: #{s[:missing_binary_version]}" if s[:missing_binary_version] > 0
      Pod::UI.puts "  未配置源:   #{s[:missing_source]}" if s[:missing_source] > 0
      Pod::UI.puts "  白名单过滤: #{s[:whitelist_filtered]}" if s[:whitelist_filtered] > 0
      Pod::UI.puts "  selector 过滤: #{s[:selector_filtered]}" if s[:selector_filtered] > 0
      Pod::UI.puts "  共涉及 #{s[:total]} 个组件"

      sandbox_root = Pod::Config.instance.sandbox_root rescue nil
      if sandbox_root
        report_path = File.join(sandbox_root.to_s, 'bin-report.json')
        Pod::UI.puts "  详细报告: #{report_path}"
      end
      Pod::UI.puts ''
    end

    private

    def count_unique(arr)
      return 0 unless arr
      arr.map { |e| e[:pod] }.uniq.length
    end
  end

  # Global accessor
  def self.resolution_report
    @resolution_report
  end

  def self.reset_resolution_report!
    @resolution_report = ResolutionReport.new
  end
end
