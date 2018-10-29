module Pod
  class Installer
    class Xcode
      class SinglePodsProjectGenerator < PodsProjectGenerator
        def initialize(sandbox, aggregate_targets, pod_targets, analysis_result, installation_options, config)
          super(sandbox, aggregate_targets, pod_targets, analysis_result, installation_options, config)
        end

        def generate!
          project_object_version = self.class.project_object_version(aggregate_targets)
          build_configurations = analysis_result.all_user_build_configurations
          platforms = aggregate_targets.map(&:platform)
          project_generator = ProjectGenerator.new(sandbox,
                                                   sandbox.project_path,
                                                   pod_targets,
                                                   build_configurations,
                                                   platforms,
                                                   false,
                                                   project_object_version,
                                                   config.podfile_path)
          project = project_generator.generate!
          @sandbox.project = project

          install_pod_target_file_references(project, pod_targets)

          pod_target_installation_results = install_pod_targets(project, pod_targets).results
          aggregate_target_installation_results = install_aggregate_pod_targets(project, aggregate_targets).results
          target_installation_results = InstallationResults.new(pod_target_installation_results, aggregate_target_installation_results)

          integrate_targets(target_installation_results.pod_target_installation_results)
          wire_target_dependencies(target_installation_results, nil)
          PodsProjectGeneratorResult.new(project, {}, target_installation_results)
        end
      end
    end
  end
end
