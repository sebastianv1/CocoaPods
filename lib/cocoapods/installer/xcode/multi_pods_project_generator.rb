module Pod
  class Installer
    class Xcode
      # The {MultiPodsProjectGenerator} handles generation of the 'Pods/Pods.xcodeproj' and Xcode projects
      # for every {PodTarget}. All Pod Target projects are nested under the 'Pods.xcodeproj'.
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

          project_paths_by_pod_targets = pod_targets.group_by do |pod_target|
            sandbox.pod_target_project_path(pod_target)
          end

          # Generate and install projects per pod target.
          project_by_pod_targets = Hash[project_paths_by_pod_targets.map do |project_path, pod_targets|
            project_generator = ProjectGenerator.new(sandbox, project_path, pod_targets, build_configurations,
                                                     platforms, object_version, nil, true)
            target_project = project_generator.generate!
            target_project.save # TODO: optimize?
            container_project.add_subproject(target_project, container_project.dependencies).name = target_project.path.basename('.*').to_s
            install_file_references(target_project, pod_targets)
            [target_project, pod_targets]
          end]

          pod_target_installation_results = project_by_pod_targets.each_with_object({}) do |(project, pod_targets), hash|
            hash.merge!(install_pod_targets(project, pod_targets))
          end

          aggregate_target_installation_results = install_aggregate_targets(container_project, aggregate_targets)
          target_installation_results = InstallationResults.new(pod_target_installation_results, aggregate_target_installation_results)

          integrate_targets(target_installation_results.pod_target_installation_results)
          wire_target_dependencies(target_installation_results)
          PodsProjectGeneratorResult.new(container_project, project_by_pod_targets, target_installation_results)
        end
      end
    end
  end
end
