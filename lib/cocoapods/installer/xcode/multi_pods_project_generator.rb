module Pod
  class Installer
    class Xcode
      # The {MultiPodsProjectGenerator} handles generation of the 'Pods/Pods.xcodeproj' and Xcode projects
      # for every Pod Target. All Pod Target projects are nested under the 'Pods.xcodeproj'.
      #
      class MultiPodsProjectGenerator < PodsProjectGenerator
        # Generates `Pods/Pods.xcodeproj` and all pod target subprojects.
        #
        # @return [PodsProjectGeneratorResult]
        #
        def generate!
          container_project_path = sandbox.project_path
          build_configurations = analysis_result.all_user_build_configurations
          platforms = aggregate_targets.map(&:platform)
          object_version = aggregate_targets.map(&:user_project).compact.map { |p| p.object_version.to_i }.min
          # Generate container Pods.xcodeproj.
          container_project_generator = ProjectGenerator.new(sandbox, container_project_path, [],
                                                             build_configurations, platforms, object_version,
                                                             config.podfile_path)

          container_project = container_project_generator.generate!
          sandbox.project = container_project

          # Generate and install projects per pod target.
          pod_target_by_installation_map = {}
          pod_targets_by_project_map = Hash[pod_targets.map do |pod_target|
            project_generator = ProjectGenerator.new(sandbox, sandbox.pod_target_project_path(pod_target),
                                                     [pod_target], build_configurations, platforms,
                                                     object_version, false, true)
            target_project = project_generator.generate!
            target_project.save
            container_project.add_subproject(target_project, container_project.main_group)

            install_file_references(target_project, [pod_target])
            pod_target_by_installation_map[pod_target] = install_pod_targets(target_project, [pod_target])
            [pod_target, target_project]
          end]

          aggregate_target_installation_results = install_aggregate_targets(container_project, aggregate_targets)
          pod_target_installation_results = pod_target_by_installation_map.values.inject(:merge)
          target_installation_results = InstallationResults.new(pod_target_installation_results, aggregate_target_installation_results)

          integrate_targets(target_installation_results.pod_target_installation_results)
          wire_target_dependencies(target_installation_results, pod_targets_by_project_map)
          PodsProjectGeneratorResult.new(container_project, pod_targets_by_project_map, target_installation_results)
        end
      end
    end
  end
end
