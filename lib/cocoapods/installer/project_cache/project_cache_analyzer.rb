module Pod
  class Installer
    class ProjectCacheAnalyzer
      attr_reader :pod_targets
      attr_reader :aggregate_targets
      attr_reader :cache
      attr_reader :sandbox
      attr_reader :build_configurations
      attr_reader :project_object_version

      require 'cocoapods/installer/project_cache/project_cache_analysis_result.rb'

      def initialize(sandbox, cache, build_configurations, project_object_version, pod_targets, aggregate_targets)
        @sandbox = sandbox
        @cache = cache
        @build_configurations = build_configurations
        @pod_targets = pod_targets
        @aggregate_targets = aggregate_targets
        @project_object_version = project_object_version
      end

      def analyze
        label_by_pod_target = Hash[pod_targets.map { |pod_target| [pod_target.label, pod_target] }]
        label_by_aggregate_target = Hash[aggregate_targets.map { |aggregate_target| [aggregate_target.label, aggregate_target] }]
        pod_target_by_cache_key = Hash[label_by_pod_target.map do |label, pod_target|
          local = sandbox.local?(pod_target.pod_name)
          checkout_options = sandbox.checkout_sources[pod_target.pod_name]
          [label, TargetCacheKey.from_pod_target(pod_target, is_local_pod: local, checkout_options: checkout_options)]
        end]
        aggregate_target_by_cache_key = Hash[label_by_aggregate_target.map do |label, aggregate_target|
          [label, TargetCacheKey.from_aggregate_target(aggregate_target)]
        end]
        target_by_cache_key = pod_target_by_cache_key.merge(aggregate_target_by_cache_key)

        # Bail out early since these affect integrating ALL targets.
        if cache.build_configurations != build_configurations || cache.project_object_version != project_object_version
          return ProjectCacheAnalysisResult.new(pod_targets, aggregate_targets, target_by_cache_key, build_configurations, project_object_version)
        end

        added_pod_targets_labels = pod_target_by_cache_key.keys - cache.target_by_cache_key.keys
        added_aggregate_targets_labels = aggregate_target_by_cache_key.keys - cache.target_by_cache_key.keys

        changed_pod_targets_labels = []
        changed_aggregate_targets_labels = []
        target_by_cache_key.each do |name, cache_key|
          next unless cache.target_by_cache_key[name]
          if cache_key.key_difference(cache.target_by_cache_key[name]) == :project
            if cache_key.type == :pod_target
              changed_pod_targets_labels << name
            else
              changed_aggregate_targets_labels << name
            end
          end
        end

        changed_pod_targets = label_by_pod_target.select { |label, _| changed_pod_targets_labels.include?(label) }.values
        changed_aggregate_targets = label_by_aggregate_target.select { |label, _| changed_aggregate_targets_labels.include?(label) }.values

        added_pod_targets = label_by_pod_target.select { |label, _| added_pod_targets_labels.include?(label) }.values
        added_aggregate_targets = label_by_aggregate_target.select { |label, _| added_aggregate_targets_labels.include?(label) }.values

        pod_targets_to_generate = changed_pod_targets + added_pod_targets
        aggregate_target_to_generate = changed_aggregate_targets + added_aggregate_targets

        ProjectCacheAnalysisResult.new(pod_targets_to_generate, aggregate_target_to_generate, target_by_cache_key,
                                       build_configurations, project_object_version)
      end

    end
  end
end
