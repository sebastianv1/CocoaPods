module Pod
  class Installer
    class ProjectCacheAnalysisResult
      attr_reader :pod_targets_to_generate
      attr_reader :aggregate_targets_to_generate
      attr_reader :target_by_cache_key


      def initialize(pod_targets_to_generate, aggregate_targets_to_generate, target_by_cache_key)
        @pod_targets_to_generate = pod_targets_to_generate
        @aggregate_targets_to_generate = aggregate_targets_to_generate
        @target_by_cache_key = target_by_cache_key
      end

    end
  end
end
