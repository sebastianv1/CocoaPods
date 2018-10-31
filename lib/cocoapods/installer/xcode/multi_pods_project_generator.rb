module Pod
  class Installer
    class Xcode
      class MultiPodsProjectGenerator < PodsProjectGenerator
        def initialize(sandbox, aggregate_targets, pod_targets, analysis_result, installation_options, config)
          super(sandbox, aggregate_targets, pod_targets, analysis_result, installation_options, config)
        end

        def generate!
          project_object_version = self.class.project_object_version(aggregate_targets)
          build_configurations = analysis_result.all_user_build_configurations
          platforms = aggregate_targets.map(&:platform)
          project_generator = ProjectGenerator.new(sandbox,
                                                   sandbox.project_path,
                                                   [],
                                                   build_configurations,
                                                   platforms,
                                                   false,
                                                   project_object_version,
                                                   config.podfile_path)
          container_project = project_generator.generate!
          @sandbox.project = container_project

          pod_target_project_hash = {}
          pod_targets.each do |pod_target|

            if File.exists?(sandbox.target_project_path(pod_target)) && (pod_target.name != 'Cleanse')
              container_project.add_subproject_reference(sandbox.target_project_path(pod_target), container_project.main_group, [pod_target])
            else
              puts "GENERATING #{pod_target}"
              target_project_generator = ProjectGenerator.new(sandbox,
                                                              sandbox.target_project_path(pod_target),
                                                              [pod_target],
                                                              build_configurations,
                                                              platforms,
                                                              true,
                                                              project_object_version)
              target_proj = target_project_generator.generate!
              target_proj.save
              container_project.add_subproject_reference(target_proj.path, container_project.main_group, [pod_target])
              pod_target_project_hash[pod_target] = target_proj
            end
          end

          pod_target_installation_results_hash = {}
          pod_targets.each do |pod_target|
            project = pod_target_project_hash[pod_target]
            if project
              install_pod_target_file_references(project, [pod_target])
              pod_target_installation_results_hash[project] = install_pod_targets(project, [pod_target]).results
            end
          end

          aggregate_target_installation_results = install_aggregate_pod_targets(container_project, aggregate_targets).results
          all_pod_target_installation_results = pod_target_installation_results_hash.values.inject(:merge) || {}
          target_installation_results = InstallationResults.new(all_pod_target_installation_results, aggregate_target_installation_results)

          integrate_targets(target_installation_results.pod_target_installation_results)
          wire_target_dependencies(target_installation_results, pod_target_project_hash)

          PodsProjectGeneratorResult.new(container_project, pod_target_installation_results_hash, target_installation_results)
        end
      end
    end
  end
end
