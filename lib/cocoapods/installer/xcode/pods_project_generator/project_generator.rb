module Pod
  class Installer
    class Xcode
      class ProjectGenerator
        def initialize(sandbox, path, pod_targets, build_configurations, platforms, pod_target_subproject, object_version=nil, podfile_path=nil)
          @sandbox = sandbox
          @path = path
          @pod_targets = pod_targets
          @build_configurations = build_configurations
          @platforms = platforms
          @object_version = object_version
          @podfile_path = podfile_path
          @pod_target_subproject = pod_target_subproject
        end

        def generate!
          project = create_project(@path, @object_version, @pod_target_subproject)
          prepare(@sandbox, project, @pod_targets, @build_configurations, @platforms, @podfile_path)
          project
        end

        def create_project(path, object_version, pod_target_subproject = false)
          if object_version
            Pod::Project.new(path, pod_target_subproject, false, object_version)
          else
            Pod::Project.new(path, pod_target_subproject)
          end
        end

        def prepare(sandbox, project, pod_targets, build_configurations, platforms, podfile_path)
          UI.message '- Creating Pods project' do
            build_configurations.each do |name, type|
              project.add_build_configuration(name, type)
            end
            # Reset symroot just in case the user has added a new build configuration other than 'Debug' or 'Release'.
            project.symroot = Pod::Project::LEGACY_BUILD_ROOT

            pod_names = pod_targets.map(&:pod_name).uniq
            pod_names.each do |pod_name|
              local = sandbox.local?(pod_name)
              path = sandbox.pod_dir(pod_name)
              was_absolute = sandbox.local_path_was_absolute?(pod_name)
              project.add_pod_group(pod_name, path, local, was_absolute)
            end

            if podfile_path
              project.add_podfile(podfile_path)
            end

            osx_deployment_target = platforms.select { |p| p.name == :osx }.map(&:deployment_target).min
            ios_deployment_target = platforms.select { |p| p.name == :ios }.map(&:deployment_target).min
            watchos_deployment_target = platforms.select { |p| p.name == :watchos }.map(&:deployment_target).min
            tvos_deployment_target = platforms.select { |p| p.name == :tvos }.map(&:deployment_target).min
            project.build_configurations.each do |build_configuration|
              build_configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = osx_deployment_target.to_s if osx_deployment_target
              build_configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = ios_deployment_target.to_s if ios_deployment_target
              build_configuration.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = watchos_deployment_target.to_s if watchos_deployment_target
              build_configuration.build_settings['TVOS_DEPLOYMENT_TARGET'] = tvos_deployment_target.to_s if tvos_deployment_target
              build_configuration.build_settings['STRIP_INSTALLED_PRODUCT'] = 'NO'
              build_configuration.build_settings['CLANG_ENABLE_OBJC_ARC'] = 'YES'
            end
          end
        end
      end
    end
  end
end
