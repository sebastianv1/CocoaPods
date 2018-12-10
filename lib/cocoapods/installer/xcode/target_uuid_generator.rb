module Pod
  class Installer
    class TargetUUIDGenerator < Xcodeproj::Project::UUIDGenerator
      def generate_all_paths_by_objects(projects)
        @paths_by_object = {}
        all_objects = projects.flat_map(&:objects)
        all_objects.each do |object|
          @paths_by_object[object] = if object.is_a? Xcodeproj::Project::Object::AbstractTarget
                                       project_basename = object.project.path.basename.to_s
                                       Digest::MD5.hexdigest(project_basename + object.name).upcase
                                     else
                                       object.uuid
                                     end
        end
      end

      def uuid_for_path(path)
        path
      end
    end
  end
end
