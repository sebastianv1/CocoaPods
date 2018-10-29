module Pod
  class Installer
    class Xcode
      class PodsProjectWriter
        def initialize(sandbox, project, pod_target_installation_results, installation_options)
          @sandbox = sandbox
          @project = project
          @pod_target_installation_results = pod_target_installation_results
          @installation_options = installation_options
        end

        def write!
          UI.message "- Writing Xcode project file to #{UI.path @sandbox.project_path}" do
            @project.pods.remove_from_project if @project.pods.empty?
            @project.support_files_group.remove_from_project if @project.support_files_group.empty?
            @project.development_pods.remove_from_project if @project.development_pods.empty?
            @project.dependencies.remove_from_project if @project.dependencies.empty?
            @project.sort(:groups_position => :below)
            if @installation_options.deterministic_uuids?
              UI.message('- Generating deterministic UUIDs') { @project.predictabilize_uuids }
            end
            library_product_types = [:framework, :dynamic_library, :static_library]

            results_by_native_target = Hash[@pod_target_installation_results.map do |_, result|
              [result.native_target, result]
            end]
            @project.recreate_user_schemes(false) do |scheme, target|
              next unless target.respond_to?(:symbol_type)
              next unless library_product_types.include? target.symbol_type
              installation_result = results_by_native_target[target]
              next unless installation_result
              installation_result.test_native_targets.each do |test_native_target|
                scheme.add_test_target(test_native_target)
              end
            end
            @project.save
          end
        end
      end
    end
  end
end
