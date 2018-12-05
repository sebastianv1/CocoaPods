module Pod
  class Installer
    class Xcode

      class AggregateTargetDependencyInstaller
        require 'cocoapods/native_target_ext.rb'

        attr_reader :pod_target_installation_results
        attr_reader :aggregate_target_installation_results

        def initialize(aggregate_target_installation_results, pod_target_installation_results)
          @aggregate_target_installation_results = aggregate_target_installation_results
          @pod_target_installation_results = pod_target_installation_results
        end

        def install!
          aggregate_target_installation_results.values.each do |aggregate_target_installation_result|
            aggregate_target = aggregate_target_installation_result.target
            aggregate_native_target = aggregate_target_installation_result.native_target
            project = aggregate_native_target.project
            is_app_extension = !(aggregate_target.user_targets.map(&:symbol_type) &
                [:app_extension, :watch_extension, :watch2_extension, :tv_extension, :messages_extension]).empty?
            is_app_extension ||= aggregate_target.user_targets.any? { |ut| ut.common_resolved_build_setting('APPLICATION_EXTENSION_API_ONLY') == 'YES' }
            configure_app_extension_api_only_to_native_target(aggregate_native_target) if is_app_extension
            # Wire up dependencies that are part of inherit search paths for this aggregate target.
            aggregate_target.search_paths_aggregate_targets.each do |search_paths_target|
              aggregate_native_target.add_dependency(aggregate_target_installation_results[search_paths_target.name].native_target)
            end
            # Wire up all pod target dependencies to aggregate target.
            aggregate_target.pod_targets.each do |pod_target|
              if pod_target_installation_result = pod_target_installation_results[pod_target.name]
                pod_target_native_target = pod_target_installation_result.native_target
                aggregate_native_target.add_dependency(pod_target_native_target)
                configure_app_extension_api_only_to_native_target(pod_target_native_target) if is_app_extension
              else
                # Hit the cache
                cached_dependency = metadata_cache.target_label_by_metadata[pod_target.label]
                project.add_cached_subproject_reference(cached_dependency, project.dependencies_group)
                aggregate_native_target.add_cached_dependency(cached_dependency)
              end
            end
          end
        end

        private

        # Sets the APPLICATION_EXTENSION_API_ONLY build setting to YES for all
        # configurations of the given native target.
        #
        def configure_app_extension_api_only_to_native_target(native_target)
          native_target.build_configurations.each do |config|
            config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
          end
        end

      end
    end
  end
end
