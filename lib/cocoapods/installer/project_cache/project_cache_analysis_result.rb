module Pod
  class Installer
    class ProjectCacheAnalysisResult
      attr_reader :pod_targets_to_generate
      attr_reader :aggregate_targets_to_generate
      attr_reader :cache_key_by_target_label
      attr_reader :build_configurations
      attr_reader :project_object_version


      def initialize(pod_targets_to_generate, aggregate_targets_to_generate, cache_key_by_target_label,
                     build_configurations, project_object_version)
        @pod_targets_to_generate = pod_targets_to_generate
        @aggregate_targets_to_generate = aggregate_targets_to_generate
        @cache_key_by_target_label = cache_key_by_target_label
        @build_configurations = build_configurations
        @project_object_version = project_object_version
      end
    end
  end
end
