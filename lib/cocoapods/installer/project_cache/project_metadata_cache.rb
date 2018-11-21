module Pod
  class Installer
    class ProjectMetadataCache
      require 'cocoapods/installer/project_cache/target_metadata.rb'
      attr_reader :target_label_by_metadata

      def initialize(target_label_by_metadata = {})
        @target_label_by_metadata = target_label_by_metadata
      end

      def to_hash
        Hash[target_label_by_metadata.map do |target_label, metdata|
          [target_label, metdata.to_hash]
        end]
      end

      def save_as(path)
        path.open('w') { |f| f.puts YAMLHelper.convert_hash(to_hash, nil)}
      end

      def update_metadata!(pod_target_installation_results, aggregate_target_installation_results)
        installation_results = (pod_target_installation_results.values || []) + (aggregate_target_installation_results.values || [])
        installation_results.each do |installation_result|
          native_target = installation_result.native_target
          target_label_by_metadata[native_target.name] = TargetMetadata.cache_metadata_from_native_target(native_target)
        end
      end

      def self.from_file(path)
        return ProjectMetadataCache.new if !File.exist?(path)
        contents = YAMLHelper.load_file(path)
        target_by_label_metadata = {}
        contents.each do |pod_target_label, hash|
          target_by_label_metadata[pod_target_label] = TargetMetadata.cache_metadata_from_hash(hash)
        end
        ProjectMetadataCache.new(target_by_label_metadata)
      end
    end
  end
end
