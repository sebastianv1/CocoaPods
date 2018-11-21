module Pod
  class Installer
    class ProjectInstallationCache
      require 'cocoapods/installer/project_cache/target_cache_key.rb'
      attr_reader :target_by_cache_key
      attr_reader :build_configurations
      attr_reader :project_object_version

      def initialize(target_by_cache_key = {}, build_configurations = nil, project_object_version = nil)
        @target_by_cache_key = target_by_cache_key
        @build_configurations = build_configurations
        @project_object_version = project_object_version
      end

      def target_by_cache_key=(target_name_by_cache_key)
        @target_by_cache_key = target_name_by_cache_key
      end

      def build_configurations=(build_configurations)
        @build_configurations = build_configurations
      end

      def project_object_version=(project_object_version)
        @project_object_version = project_object_version
      end

      def save_as(path)
        Pathname(path).dirname.mkpath
        cache_key_contents = Hash[target_by_cache_key.map do |name, key|
          [name, key.to_cache_hash]
        end]
        contents = { 'CACHE_KEYS' => cache_key_contents }
        contents['BUILD_CONFIGURATIONS'] = build_configurations if build_configurations
        contents['OBJECT_VERSION'] = project_object_version if project_object_version
        path.open('w') { |f| f.puts YAMLHelper.convert_hash(contents, nil) }
      end

      def self.from_file(path)
        return ProjectInstallationCache.new() if !File.exist?(path)
        contents = YAMLHelper.load_file(path)
        target_by_cache_key = Hash[contents['CACHE_KEYS'].map do |name, key_hash|
          [name, TargetCacheKey.from_cache_hash(key_hash)]
        end]
        project_object_version = contents['OBJECT_VERSION']
        build_configurations = contents['BUILD_CONFIGURATIONS']
        ProjectInstallationCache.new(target_by_cache_key, build_configurations, project_object_version)
      end
    end
  end
end
