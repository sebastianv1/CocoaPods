module Pod
  class Installer
    class Xcode
      class PodTargetDependencyInstaller
        require 'cocoapods/native_target_ext.rb'

        attr_reader :pod_target_installation_results
        attr_reader :metadata_cache

        def initialize(pod_target_installation_results, metadata_cache)
          @pod_target_installation_results = pod_target_installation_results
          @metadata_cache = metadata_cache
        end

        def install!
          # Wire up pod targets
          pod_target_installation_results.values.each do |pod_target_installation_result|
            pod_target = pod_target_installation_result.target
            native_target = pod_target_installation_result.native_target
            project = native_target.project
            frameworks_group = project.frameworks_group

            # First, wire up all resource bundles.
            wire_resource_bundle_targets(pod_target_installation_result.resource_bundle_targets,
                                         native_target, pod_target)
            # Wire up all dependencies to this pod target, if any.
            wire_target_dependencies(pod_target, native_target, project, pod_target_installation_results,
                                     metadata_cache, frameworks_group)


            # Wire up test native targets.
            unless pod_target_installation_result.test_native_targets.empty?
              wire_test_native_targets(pod_target_installation_result.test_specs_by_native_target, pod_target, project,
                                       pod_target_installation_results, metadata_cache, frameworks_group)
            end

            # Wire up app native targets.
            unless pod_target_installation_result.app_native_targets.empty?
              wire_app_native_targets(pod_target_installation_result.app_specs_by_native_target, pod_target,
                                      native_target, pod_target_installation_results, project, metadata_cache, frameworks_group)

            end
          end
        end

        def wire_resource_bundle_targets(resource_bundle_targets, native_target, pod_target)
          resource_bundle_targets.each do |resource_bundle_target|
            native_target.add_dependency(resource_bundle_target)
            if pod_target.build_as_dynamic_framework? && pod_target.should_build?
              native_target.add_resources([resource_bundle_target.product_reference])
            end
          end
        end

        def wire_target_dependencies(pod_target, native_target, project,
                                     pod_target_installation_results, metadata_cache, frameworks_group)
          dependent_targets = pod_target.dependent_targets
          dependent_targets.each do |dependent_target|
            if installation_result = pod_target_installation_results[dependent_target.name]
              dependent_project = installation_result.native_target.project
              if dependent_project != project
                project.add_subproject_reference(dependent_project, project.dependencies_group)
              end
              native_target.add_dependency(installation_result.native_target)
              add_framework_file_reference_to_native_target(native_target, pod_target, dependent_target, frameworks_group)
            else
              # Hit the cache
              cached_dependency = metadata_cache.target_label_by_metadata[dependent_target.label]
              project.add_cached_subproject_reference(cached_dependency, project.dependencies_group)
              native_target.add_cached_dependency(cached_dependency)
            end
          end
        end

        def wire_test_native_targets(test_specs_by_native_target, pod_target, project, pod_target_installation_results,
                                     metadata_cache, frameworks_group)
          test_specs_by_native_target.each do |test_native_target, test_specs|
            test_dependent_targets = test_specs.flat_map { |s| pod_target.test_dependent_targets_by_spec_name[s.name] }.compact.unshift(pod_target).uniq
            test_dependent_targets.each do |test_dependent_target|
              if dependency_installation_result = pod_target_installation_results[test_dependent_target.name]
                resource_bundle_native_targets = dependency_installation_result.test_resource_bundle_targets[test_specs.first.name]
                unless resource_bundle_native_targets.nil?
                  resource_bundle_native_targets.each do |test_resource_bundle_target|
                    test_native_target.add_dependency(test_resource_bundle_target)
                  end
                end
                dependent_test_project = dependency_installation_result.native_target.project
                if dependent_test_project != project
                  project.add_subproject_reference(dependent_test_project, project.dependencies_group)
                end
                test_native_target.add_dependency(dependency_installation_result.native_target)
                add_framework_file_reference_to_native_target(test_native_target, pod_target, test_dependent_target, frameworks_group)
              else
                # Hit the cache
                cached_dependency = metadata_cache.target_label_by_metadata[test_dependent_target.label]
                project.add_cached_subproject_reference(cached_dependency, project.dependencies_group)
                test_native_target.add_cached_dependency(cached_dependency)
              end
            end
          end
        end

        def wire_app_native_targets(app_specs_by_native_target, pod_target, native_target, pod_target_installation_results,
                                    project, metadata_cache, frameworks_group)
          app_specs_by_native_target.each do |app_native_target, app_specs|
            app_dependent_targets = app_specs.flat_map { |s| pod_target.app_dependent_targets_by_spec_name[s.name] }.compact.unshift(pod_target).uniq
            app_dependent_targets.each do |app_dependent_target|
              if dependency_installation_result = pod_target_installation_results[app_dependent_target.name]
                resource_bundle_native_targets = dependency_installation_result.app_resource_bundle_targets[app_specs.first.name]
                unless resource_bundle_native_targets.nil?
                  resource_bundle_native_targets.each do |app_resource_bundle_target|
                    app_native_target.add_dependency(app_resource_bundle_target)
                  end
                end
                dependency_project = dependency_installation_result.native_target.project
                if dependency_project != project
                  project.add_subproject_reference(dependency_project, project.dependencies_group)
                end
                app_native_target.add_dependency(dependency_installation_result.native_target)
                add_framework_file_reference_to_native_target(app_native_target, pod_target, app_dependent_target, frameworks_group)
              else
                # Hit the cache
                cached_dependency = metadata_cache.target_label_by_metadata[app_dependent_target.label]
                project.add_cached_subproject_reference(cached_dependency, project.dependencies_group)
                native_target.add_cached_dependency(cached_dependency)
              end
            end
          end
        end

        private

        def add_framework_file_reference_to_native_target(native_target, pod_target, dependent_target, frameworks_group)
          if pod_target.should_build? && pod_target.build_as_dynamic? && dependent_target.should_build?
            product_ref = frameworks_group.files.find { |f| f.path == dependent_target.product_name } ||
                frameworks_group.new_product_ref_for_target(dependent_target.product_basename, dependent_target.product_type)
            native_target.frameworks_build_phase.add_file_reference(product_ref, true)
          end
        end

      end
    end
  end
end
