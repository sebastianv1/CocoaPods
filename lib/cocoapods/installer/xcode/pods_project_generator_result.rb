module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # A simple container produced after a pod project generation is completed.
        #
        class PodsProjectGeneratorResult
          # @return [Project] project
          #
          attr_reader :project

          # @return [Hash<PodTarget, Project>] pod target by project map
          #
          attr_reader :pod_target_by_project_map

          # @return [InstallationResults] target installation results
          #
          attr_reader :target_installation_results

          # Initialize a new instance
          #
          # @param [Project] project @see #project
          # @param [InstallationResults] target_installation_results @see #target_installation_results
          #
          def initialize(project, pod_target_by_project_map, target_installation_results)
            @project = project
            @pod_target_by_project_map = pod_target_by_project_map
            @target_installation_results = target_installation_results
          end
        end
      end
    end
  end
end
