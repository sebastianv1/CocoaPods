

module Pod
  class Installer
    class ProjectCacheAnalyzerResult

      attr_reader :pod_targets

      attr_reader :aggregate_targets

      def initialize(pod_targets, aggregate_targets)
        @pod_targets = pod_targets
        @aggregate_targets = aggregate_targets
      end
    end
  end
end
