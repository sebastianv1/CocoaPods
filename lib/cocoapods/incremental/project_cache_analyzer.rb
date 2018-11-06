
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

        ProjectCacheAnalyzerResult.new(changed_pod_targets, [])
      end

      def pod_target_descriptor(pod_target)
        checksum = pod_target.root_spec.checksum
        file_list = pod_target.file_accessors.map { |f| f.all_files }.flatten
        { :checksum => checksum, :file_list => file_list }
      end


    end
  end
end
