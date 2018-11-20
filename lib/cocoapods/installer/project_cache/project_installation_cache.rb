module Pod
  class Installer
    class ProjectInstallationCache
      require 'cocoapods/installer/project_cache/target_cache_key.rb'
      attr_reader :target_by_cache_key
      attr_reader :build_configurations

      def initialize(target_by_cache_key = {}, build_configurations = nil)
        @target_by_cache_key = target_by_cache_key
        @build_configurations = build_configurations
      end

      def target_by_cache_key=(target_name_by_cache_key)
        @target_by_cache_key = target_name_by_cache_key
      end

      def save_as(path)
        Pathname(path).dirname.mkpath
        cache_key_contents = Hash[target_by_cache_key.map do |name, key|
          [name, key.to_cache_hash]
        end]
        contents = { 'CACHE_KEYS' => cache_key_contents }
        path.open('w') { |f| f.puts YAMLHelper.convert_hash(contents, nil) }
      end

      def self.from_file(path)
        return ProjectInstallationCache.new() if !File.exist?(path)
        contents = YAMLHelper.load_file(path)
        target_by_cache_key = Hash[contents['CACHE_KEYS'].map do |name, key_hash|
          [name, TargetCacheKey.from_cache_hash(key_hash)]
        end]
        ProjectInstallationCache.new(target_by_cache_key)
      end
    end
  end
end
