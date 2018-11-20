module Pod
  class Installer
    class ProjectCacheAnalysisResult
      attr_reader :changed_pod_targets
      attr_reader :changed_aggregate_targets

      attr_reader :removed_pod_targets
      attr_reader :removed_aggregate_targets

      attr_reader :added_pod_targets
      attr_reader :added_aggregate_targets

      def initialize(changed_pod_targets, changed_aggregate_targets,
                     removed_pod_targets, removed_aggregate_targets,
                     added_pod_targets, added_aggregate_targets)
        @changed_pod_targets = changed_pod_targets
        @changed_aggregate_targets = changed_aggregate_targets

        @removed_pod_targets = removed_pod_targets
        @removed_aggregate_targets = removed_aggregate_targets

        @added_pod_targets = added_pod_targets
        @added_aggregate_targets = added_aggregate_targets
      end

    end
  end
end
