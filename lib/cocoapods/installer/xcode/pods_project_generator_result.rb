module Pod
  class Installer
    class Xcode
      class PodsProjectGenerator
        # A simple container produced after a pod project generation is completed.
        #
        class PodsProjectGeneratorResult
          # @return [Project] project
          #
          attr_reader :project_target_hash

          attr_reader :project

          # @return [InstallationResults] target installation results
          #
          attr_reader :target_installation_results

          # Initialize a new instance
          #
          # @param [Project] project @see #project
          # @param [InstallationResults] target_installation_results @see #target_installation_results
          #
          def initialize(project, project_target_hash, target_installation_results)
            @project = project
            @project_target_hash = project_target_hash
            @target_installation_results = target_installation_results
          end
        end
      end
    end
  end
end
