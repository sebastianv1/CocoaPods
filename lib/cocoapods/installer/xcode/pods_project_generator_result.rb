module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # A simple container produced after a pod project generation is completed.
        #
        class PodsProjectGeneratorResult
          # @return [Project] the container project
          #
          attr_reader :project

          # @return [Hash<Project, Array<PodTarget>] the projects by pod targets that were generated
          #
          attr_reader :project_by_pod_targets

          # @return [InstallationResults] target installation results
          #
          attr_reader :target_installation_results

          # Initialize a new instance
          #
          # @param [Project] project @see #project
          # @param [Hash<Project, Array<PodTarget>] @see #project_by_pod_targets
          # @param [InstallationResults] target_installation_results @see #target_installation_results
          #
          def initialize(project, project_by_pod_targets, target_installation_results)
            @project = project
            @project_by_pod_targets = project_by_pod_targets
            @target_installation_results = target_installation_results
          end
        end
      end
    end
  end
end
