module Pod
  class Installer
    class Xcode
      class SinglePodsProjectGenerator < PodsProjectGenerator
        def generate!
          project_path = sandbox.project_path
          build_configurations = analysis_result.all_user_build_configurations
          platforms = aggregate_targets.map(&:platform)
          object_version = aggregate_targets.map(&:user_project).compact.map { |p| p.object_version.to_i }.min
          project_generator = ProjectGenerator.new(sandbox, project_path, pod_targets, build_configurations,
                                                   platforms, object_version, config.podfile_path)
          project = project_generator.generate!
          sandbox.project = project

          install_file_references(project, pod_targets)
          pod_target_installation_results = install_pod_targets(project, pod_targets)
          aggregate_target_installation_results = install_aggregate_targets(project, aggregate_targets)
          target_installation_results = InstallationResults.new(pod_target_installation_results, aggregate_target_installation_results)
          integrate_targets(target_installation_results.pod_target_installation_results)
          wire_target_dependencies(target_installation_results, false)
          PodsProjectGeneratorResult.new(project, {}, target_installation_results)
        end
      end
    end
  end
end
