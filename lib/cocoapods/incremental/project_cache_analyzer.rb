
module Pod
  class Installer
    class ProjectCacheAnalyzer

      require 'cocoapods/incremental/project_cache_analyzer_result'

      def initialize(project_cache, all_pod_targets, all_aggregate_targets)
        @project_cache = project_cache
        @all_pod_targets = all_pod_targets
        @all_aggregate_targets = all_aggregate_targets
      end

      def analyze!
        changed_pod_targets = []
        pod_cache = @project_cache['POD_TARGETS']
        aggregate_cache = @project_cache['AGGREGATE_TARGETS']
        @all_pod_targets.each do |pod_target|
          cached_pod_descriptor = pod_cache[pod_target.label]
          if cached_pod_descriptor
            current_state = pod_target_descriptor(pod_target)
            if current_state[:checksum] != cached_pod_descriptor[:checksum] ||
                current_state[:file_list].sort != cached_pod_descriptor[:file_list].sort
              changed_pod_targets += [pod_target]
            end
          else
            changed_pod_targets += [pod_target]
          end
        end

        changed_aggregate_targets = []
        @all_aggregate_targets.each do |aggregate_target|
          changed = false
          cached_aggregated_descriptor =aggregate_cache[aggregate_target.label]
          if cached_aggregated_descriptor
            current_state = aggregate_target_descriptor(aggregate_target)
            if current_state[:pod_targets].sort != cached_aggregated_descriptor[:pod_targets]
              changed = true
              break
            end
          else
            changed = true
            break
          end
          if changed
            changed_aggregate_targets = @all_aggregate_targets
          end
        end

        ProjectCacheAnalyzerResult.new(changed_pod_targets, changed_aggregate_targets)
      end

      def pod_target_descriptor(pod_target)
        checksum = pod_target.root_spec.checksum
        file_list = pod_target.file_accessors.map { |f| f.all_files }.flatten
        { :checksum => checksum, :file_list => file_list }
      end

      def aggregate_target_descriptor(aggregate_target)
        { :pod_targets => aggregate_target.pod_targets.map { |t| t.label } }
      end


    end
  end
end
