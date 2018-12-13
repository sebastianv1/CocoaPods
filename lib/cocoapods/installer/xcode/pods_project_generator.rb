module Pod
  class Installer
    class Xcode
      # The {PodsProjectGenerator} handles generation of CocoaPods Xcode projects.
      #
      class PodsProjectGenerator
        require 'cocoapods/installer/xcode/pods_project_generator/target_installer_helper'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_integrator'
        require 'cocoapods/installer/xcode/pods_project_generator/target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/target_installation_result'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/file_references_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/aggregate_target_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/project_generator'
        require 'cocoapods/installer/xcode/pods_project_generator_result'
        require 'cocoapods/installer/xcode/pods_project_generator/aggregate_target_dependency_installer'
        require 'cocoapods/installer/xcode/pods_project_generator/pod_target_dependency_installer'
        require 'cocoapods/native_target_ext.rb'

        # @return [Sandbox] The sandbox where the Pods should be installed.
        #
        attr_reader :sandbox

        # @return [Array<AggregateTarget>] The model representations of an
        #         aggregation of pod targets generated for a target definition
        #         in the Podfile.
        #
        attr_reader :aggregate_targets

        # @return [Array<PodTarget>] The model representations of pod targets.
        #
        attr_reader :pod_targets

        # @return [Analyzer] the analyzer which provides the information about what
        #         needs to be installed.
        #
        attr_reader :build_configurations

        # @return [InstallationOptions] the installation options from the Podfile.
        #
        attr_reader :installation_options

        # @return [Config] the global CocoaPods configuration.
        #
        attr_reader :config

        attr_reader :metadata_cache

        attr_reader :project_object_version

        # Initialize a new instance
        #
        # @param  [Sandbox]                sandbox               @see #sandbox
        # @param  [Array<AggregateTarget>] aggregate_targets     @see #aggregate_targets
        # @param  [Array<PodTarget>]       pod_targets           @see #pod_targets
        # @param  [Analyzer]               analysis_result       @see #analysis_result
        # @param  [InstallationOptions]    installation_options  @see #installation_options
        # @param  [Config]                 config                @see #config
        #
        def initialize(sandbox, aggregate_targets, pod_targets, build_configurations, installation_options, config, project_object_version, metadata_cache = nil)
          @sandbox = sandbox
          @aggregate_targets = aggregate_targets
          @pod_targets = pod_targets
          @build_configurations = build_configurations
          @installation_options = installation_options
          @config = config
          @project_object_version = project_object_version
          @metadata_cache = metadata_cache
        end

        # Shares schemes of development Pods.
        #
        # @return [void]
        #
        def share_development_pod_schemes(project, development_pod_targets = [])
          targets = development_pod_targets.select do |target|
            target.should_build? && share_scheme_for_development_pod?(target.pod_name)
          end
          targets.each do |pod_target|
            Xcodeproj::XCScheme.share_scheme(project.path, pod_target.label)
            pod_target.test_specs.each do |test_spec|
              Xcodeproj::XCScheme.share_scheme(project.path, pod_target.test_target_label(test_spec))
            end

            pod_target.app_specs.each do |app_spec|
              Xcodeproj::XCScheme.share_scheme(project.path, pod_target.app_target_label(app_spec))
            end
          end
        end
        # @!attribute [Hash{String => TargetInstallationResult}] pod_target_installation_results
        # @!attribute [Hash{String => TargetInstallationResult}] aggregate_target_installation_results
        InstallationResults = Struct.new(:pod_target_installation_results, :aggregate_target_installation_results)

        private

        def install_file_references(project, pod_targets)
          UI.message "- Installing files into #{project.project_name} project" do
            installer = FileReferencesInstaller.new(sandbox, pod_targets, project, installation_options.preserve_pod_file_structure)
            installer.install!
          end
        end

        def install_pod_targets(project, pod_targets)
          umbrella_headers_by_dir = pod_targets.map do |pod_target|
            next unless pod_target.should_build? && pod_target.defines_module?
            pod_target.umbrella_header_path
          end.compact.group_by(&:dirname)

          pod_target_installation_results = Hash[pod_targets.sort_by(&:name).map do |pod_target|
            umbrella_headers_in_header_dir = umbrella_headers_by_dir[pod_target.module_map_path.dirname]
            target_installer = PodTargetInstaller.new(sandbox, project, pod_target, umbrella_headers_in_header_dir)
            [pod_target.name, target_installer.install!]
          end]

          # Hook up system framework dependencies for the pod targets that were just installed.
          pod_target_installation_result_values = pod_target_installation_results.values.compact
          unless pod_target_installation_result_values.empty?
            add_system_framework_dependencies(pod_target_installation_result_values)
          end

          pod_target_installation_results
        end

        def install_aggregate_targets(project, aggregate_targets)
          UI.message '- Installing Aggregate Targets' do
            aggregate_target_installation_results = Hash[aggregate_targets.sort_by(&:name).map do |target|
              target_installer = AggregateTargetInstaller.new(sandbox, project, target)
              [target.name, target_installer.install!]
            end]

            aggregate_target_installation_results
          end
        end

        # @param [Hash{String => InstallationResult}] pod_target_installation_results
        #        the installations to integrate
        #
        # @return [void]
        #
        def integrate_targets(pod_target_installation_results)
          pod_installations_to_integrate = pod_target_installation_results.values.select do |pod_target_installation_result|
            pod_target = pod_target_installation_result.target
            !pod_target_installation_result.test_native_targets.empty? ||
                !pod_target_installation_result.app_native_targets.empty? ||
                pod_target.contains_script_phases?
          end
          return if pod_installations_to_integrate.empty?

          UI.message '- Integrating targets' do
            use_input_output_paths = !installation_options.disable_input_output_paths
            pod_installations_to_integrate.each do |pod_target_installation_result|
              PodTargetIntegrator.new(pod_target_installation_result, :use_input_output_paths => use_input_output_paths).integrate!
            end
          end
        end

        def add_system_framework_dependencies(pod_target_installation_results)
          sorted_installation_results = pod_target_installation_results.sort_by do |pod_target_installation_result|
            pod_target_installation_result.target.name
          end
          sorted_installation_results.each do |target_installation_result|
            pod_target = target_installation_result.target
            next unless pod_target.should_build?
            next if pod_target.build_as_static?
            pod_target.file_accessors.each do |file_accessor|
              native_target = target_installation_result.native_target_for_spec(file_accessor.spec)
              add_system_frameworks_to_native_target(native_target, file_accessor)
            end
          end
        end

        # Adds a target dependency for each pod spec to each aggregate target and
        # links the pod targets among each other.
        #
        # @param  [Array[Hash{String=>TargetInstallationResult}]] target_installation_results
        #         the installation results that were produced when all targets were installed. This includes
        #         pod target installation results and aggregate target installation results.
        #
        # @return [void]
        #
        def wire_target_dependencies(target_installation_results)
          pod_target_installation_results_hash = target_installation_results.pod_target_installation_results || {}
          aggregate_target_installation_results_hash = target_installation_results.aggregate_target_installation_results || {}

          AggregateTargetDependencyInstaller.new(aggregate_target_installation_results_hash,
                                                 pod_target_installation_results_hash, metadata_cache).install!

          PodTargetDependencyInstaller.new(pod_target_installation_results_hash, metadata_cache).install!
        end

        # @param  [String] pod The root name of the development pod.
        #
        # @return [Bool] whether the scheme for the given development pod should be
        #         shared.
        #
        def share_scheme_for_development_pod?(pod)
          case dev_pods_to_share = installation_options.share_schemes_for_development_pods
          when TrueClass, FalseClass, NilClass
            dev_pods_to_share
          when Array
            dev_pods_to_share.any? { |dev_pod| dev_pod === pod } # rubocop:disable Style/CaseEquality
          else
            raise Informative, 'Unable to handle share_schemes_for_development_pods ' \
              "being set to #{dev_pods_to_share.inspect} -- please set it to true, " \
              'false, or an array of pods to share schemes for.'
          end
        end

        #------------------------------------------------------------------------#

        # @! group Private Helpers

        def add_system_frameworks_to_native_target(native_target, file_accessor)
          file_accessor.spec_consumer.frameworks.each do |framework|
            native_target.add_system_framework(framework)
          end
        end
      end
    end
  end
end
