
module Pod
  class Installer
    class ProjectCache
      require 'cocoapods-core/yaml_helper'

      CACHE_FILENAME = ".cocoapods_cache/project".freeze

      def initialize(internal_cache = { 'POD_TARGETS' => {}, 'AGGREGATE_TARGETS' => {}})
        @internal_cache = internal_cache
      end

      def self.open_or_create
        if File.exists? CACHE_FILENAME
          cache = YAMLHelper.load_file(CACHE_FILENAME)
          ProjectCache.new(cache)
        else
          Dir.mkdir '.cocoapods_cache'
          File.new(CACHE_FILENAME, "w")
          ProjectCache.new
        end
      end

      def project_cache
        @internal_cache
      end

      def update_cache(pod_targets, aggregate_targets)
        pod_target_cache = @internal_cache['POD_TARGETS']
        pod_targets.each do |pod_target|
          pod_target_by_descriptor = {}
          checksum = pod_target.root_spec.checksum
          file_list = pod_target.file_accessors.map { |f| f.all_files }.flatten
          pod_target_cache[pod_target.label] = { :checksum => checksum, :file_list => file_list }
        end

        aggregate_target_cache = @internal_cache['AGGREGATE_TARGETS']
        aggregate_targets.each do |aggregate_target|
          aggregate_target_by_descriptor = {}
          pod_targets = aggregate_target.pod_targets
          aggregate_target_cache[aggregate_target.label] = { :pod_targets => pod_targets.map { |t| t.label } }
        end

        Pathname.new(CACHE_FILENAME).open('w') { |f| f.write(to_yaml) }
      end

      def to_yaml
        YAMLHelper.convert_hash(@internal_cache, nil, "\n")
      end

    end
  end
end
