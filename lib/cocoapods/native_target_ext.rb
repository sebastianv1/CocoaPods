module Xcodeproj
  class Project
    module Object
      class AbstractTarget
        def add_cached_dependency(metadata)
          #unless dependency_for_target(target)
            container_proxy = project.new(Xcodeproj::Project::PBXContainerItemProxy)

            subproject_reference = project.reference_for_path(metadata.container_project_path)
            raise ArgumentError, "add_dependency received target (#{target}) that belongs to a project that is not this project (#{self}) and is not a subproject of this project" unless subproject_reference
            container_proxy.container_portal = subproject_reference.uuid

            container_proxy.proxy_type = Constants::PROXY_TYPES[:native_target]
            container_proxy.remote_global_id_string = metadata.native_target_uuid
            container_proxy.remote_info = metadata.target_label

            dependency = project.new(Xcodeproj::Project::PBXTargetDependency)
            dependency.name = metadata.target_label
            dependency.target_proxy = container_proxy

            dependencies << dependency
          #end
        end
      end
    end
  end
end
