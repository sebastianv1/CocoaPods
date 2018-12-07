module Pod
  class Installer
    require 'cocoapods/installer/project_cache/project_cache_analysis_result'

    class ProjectCacheAnalyzer
      attr_reader :pod_targets
      attr_reader :aggregate_targets
      attr_reader :cache
      attr_reader :sandbox
      attr_reader :build_configurations
      attr_reader :project_object_version
      attr_reader :clean_install


      def initialize(sandbox, cache, build_configurations, project_object_version, pod_targets, aggregate_targets,
                     clean_install: false)
        @sandbox = sandbox
        @cache = cache
        @build_configurations = build_configurations
        @pod_targets = pod_targets
        @aggregate_targets = aggregate_targets
        @project_object_version = project_object_version
        @clean_install = clean_install
      end

      def analyze
        target_by_label = Hash[(pod_targets + aggregate_targets).map { |target| [target.label, target] }]
        cache_key_by_target_label = Hash[target_by_label.map do |label, target|
          if target.is_a?(PodTarget)
            local = sandbox.local?(target.pod_name)
            checkout_options = sandbox.checkout_sources[target.pod_name]
            [label, TargetCacheKey.from_pod_target(target, is_local_pod: local, checkout_options: checkout_options)]
          elsif target.is_a?(AggregateTarget)
            [label, TargetCacheKey.from_aggregate_target(target)]
          else
            raise '[BUG] Unknown target type'
          end
        end]

        # Bail out early since these properties affect all targets and their associate projects.
        if cache.build_configurations != build_configurations || cache.project_object_version != project_object_version || clean_install
          return ProjectCacheAnalysisResult.new(pod_targets, aggregate_targets, cache_key_by_target_label,
                                                build_configurations, project_object_version)
        end

        added_targets = (cache_key_by_target_label.keys - cache.cache_key_by_target_label.keys).map do |label|
          target_by_label[label]
        end
        added_pod_targets = added_targets.select { |target| target.is_a?(PodTarget) }
        added_aggregate_targets = added_targets.select { |target| target.is_a?(AggregateTarget) }

        changed_targets = []
        cache_key_by_target_label.each do |label, cache_key|
          next unless cache.cache_key_by_target_label[label]
          if cache_key.key_difference(cache.cache_key_by_target_label[label]) == :project
            changed_targets << target_by_label[label]
          end
        end

        changed_pod_targets = changed_targets.select { |target| target.is_a?(PodTarget) }
        changed_aggregate_targets = changed_targets.select { |target| target.is_a?(AggregateTarget) }

        pod_targets_to_generate = changed_pod_targets + added_pod_targets
        # NOTE: We do this because all aggregate targets go into Pods.xcodeproj.
        #
        aggregate_target_to_generate =
            if !(changed_aggregate_targets + added_aggregate_targets).empty?
              aggregate_targets
            else
              []
            end

        ProjectCacheAnalysisResult.new(pod_targets_to_generate, aggregate_target_to_generate, cache_key_by_target_label,
                                       build_configurations, project_object_version)
      end
    end
  end
end
