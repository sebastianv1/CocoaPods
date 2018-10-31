# Incremental Pod Installation (Phase 1)
**author: **sebastianv1
**date: **10/31/2018

## Summary
A growing pain for developers using CocoaPods in a large codebase (>300 dependencies) is the wall clock time from invoking `pod install` to coding inside of Xcode. A large portion of this time is spent generating the `Pods.xcodeproj` for every `pod install` invocation and waiting for Xcode to parse the contents of the `Pods.xcodeproj/project.pbxproj` file before a developer can begin interacting with their workspace.

Instead of generating and integrating all targets for every pod installation, we can optimize this by implementing an incremental pod installation that would only generate and integrate pod targets that have changed since the initial setup. Implementing incremental pod installation necessitates two changes: The first is breaking up the monolithic `Pods.xcodeproj` into subprojects for each pod target (and its test targets) as a prerequesite for implementing the incremental portion that would regenerate the individual Xcode projects for only the pod targets that have changed.

## Motivation
Productivity slows singificantly in large CocoaPods environemnts with many active contributors since invoking `pod install` is often required for every merge, rebase, or branch switch (in addition to the required installation for every new file, module, header etc.). This means that CocoaPods will regenerate the entire `Pods.xcodeproj` (most time consuming pipeline step) and Xcode has to reparse the entire `Pods.xcodeproj/project.pbxproj` contents before a developer can start coding again. For example, working in monorepo with ~400 pods requires around 90 seconds to complete a `pod install` and another 30 seconds for Xcode to become responsive again. The `Pods.xcodeproj` contains `65,000` objects and `300,000` lines for Xcode to parse through. Requiring developers to wait 2 minutes (and longer as these projects grow) obviates the need for some optimization for larger Pod projects by only generating the minimum subset of dependencies that have changed in a project.


## Design
### Phase 1: Splitting up `Pods.xcodeproj`
#### Overview
###### Installation Option
The option to generate xcodeprojects per pod target will be gated by the installation option `:generate_pod_projects` set to `false` by default.

###### Pod Target Projects 
When `:generate_pod_projects` is flipped on, all pod targets will receive their own `.xcodeproj` file containing the target and test targets. For example, the pod `PonyDebugger` would now be generated a `PonyDebugger.xcodeproj` containing `PonyDebugger` and `PonyDebugger-Unit-Tests` targets. The `Pods.xcodeproj` will transform into a container project that only holds the aggregate targets and nests each of the pod target projects. It makes sense to keep aggregate targets inside `Pods.xcodeproj` instead of breaking them out into their own projects since they already act as a container target that holds all of a user's target dependencies and would only produce unnecessary nesting. Also, many aggregate targets often share the same pod target dependencies, and the likelihood that most (if not all) aggregate targets get updated on the addition or removal of a new dependency warrants keeping in `Pods.xcodeproj`.


Putting each of the pod targets into their own projects allows us to also flatten the group hierarchy to something like:
```
PonyDebugger.xcodeproj
	-> PonyDebugger
	-> Dependencies
	-----> SocketRocket.xcodeproj
	-> Frameworks
	-> Support Files
```
Instead of nesting `PonyDebugger` under either `Development Pods` or `Pods` previously done in `Pods.xcodeproj`, we can move it up into the project's main group. In order to wire up the project's target dependencies correctly, we also need to create a new group `Dependencies` that contains a reference to its dependencies' xcode projects since the Xcodeproj gem (and Xcode in general) only allows targets to add other target dependencies that either exist in the same project or in a nested subproject.

###### Performance Concerns
By breaking up the monolothic `Pods.xcodeproj` into individual projects, we are creating more objects in general that Xcode needs to know about. For example, on the same sample project described in the #Summary section, the total objects count from just `Pods.xcodeproj` was 65,425  and splitting up the projects created 74,676 objects. This could result in some Xcode performance issues by holding onto more objects in memory and a longer `pod install` time (about 7 seconds in the aforemetioned large sample project). However, the latter is dramatically improved by the overall goal of this project to only generate Xcode projects for the pod targets that have changed since the initial installation.


#### Implementation Details
###### Single and Multi Pods Project Generator
To support the variant behavior between generating a single `Pods.xcodeproj` with all targets and projects per pod target, we will create two new objects called `SinglePodsProjectGenerator` and `MultiPodsProjectGenerator` that inherit from the existing `PodsProjectGenerator`. Both objects use the inherited initializer and implement the same public API `generate!`.

By splitting up `PodsProjectGenerator` into `SinglePodsProjectGenerator` and `MultiPodsProjectGenerator`, we can also extract some shared logic out of `PodsProjectGenerator` that the two subclasses can reuse and not rely so much on inheritence. These two new objects are `ProjectGenerator` and `PodsProjectWriter`.

###### ProjectGenerator
This object is responsible for creating and preparing a project that can be used in CocoaPods. It's responsibilites include:
- Adding build configurations
- Resetting the symroot
- Add pod groups and the Podfile
- Settings project deployment targets for each platform.

```
def initialize(sandbox, path, pod_targets, build_configurations, platforms, pod_target_subproject, object_version=nil, podfile_path=nil)

# @returns [Pod::Project] This generated and prepared project.
def generate!
```

###### PodsProjectWriter
This object is responsbile for taking a project generated by `ProjectGenerator` and cleaning up empty groups, generating deterministic UUID's if permitted by the installation options, adding test schemes, and saving to disk.

```
def initialize(sandbox, project, pod_target_installation_results, installation_options)

def write!
```

###### Project
** pod_target_subproject **
By breaking out pod targets into their projects, we will add a new parameter to the `Pod::Project` initializer `pod_target_subproject` that defaults to false.
The `pod_target_subproject` ivar is used to switch on behavior in the method `add_pod_group` since we want to put pod groups in the main group instead of `Development Pods` or `Pods` group for subprojects. It is also used in `pod_groups` in order to return the parent group (main group) used to find pod groups.

**dependencies**
`Pod::Project` will also include a new ivar `dependencies` to represent the `Dependencies` group used by pod target subprojects. If this group is empty, it will also be a group cleaned up by the `PodsProjectWriter`.

###### Sandbox
The generated pod target projects will also go into the sandbox directory, so a new helper method will be added to `Pod::Sandbox` for the paths to these pod target projects.
```
def target_project_path(target)
      root + "#{target.label}.xcodeproj"
end
```


- Primilary changes to pods_project_generator.rb
	- Creating two new project generators
	 	- Multi and Single that inherit from Pods Project Generator that have variant generate! behavior, but return the same `PodsProjectGenerationResult`.
	 		- Expand the Pods Project Generation Result to include a `project_target_hash` with a mappings of pod targets to projects. This will be empty for SinglePodsProjectGeneration.
	 		- `project_target_hash` is a new hash map that will be empty for the `SinglePodsProjectGenerator` and populated with mapping from `pod_targets` to `Project` objects for `MultiXcodeProjectGenerator` to be used for installing and wiring targets correctly.
	 		- We can also extract logic out of `PodsProjectGenerator` into their own objects so that the two different generators and rely less on inheritence to share similar behavior.
	 			- write! goes into a new object `PodsProjectWriter`
	 			- project generation can go into a new `ProjectGenerator` object.
	- `Project` changes:
		- Add a new group called `Dependencies` that will be removed in cleanup if empty.
		- New property `pod_target_subproject` boolean to indicate whether this project is a pod target subproject.
			- For subprojects, we don't want to put nest them inside the `Pods` or `Development Pods` group, we can simply put it inside the `main_group` since each of the projects will uniquely identify itself. `pod_target_subproject` is used by `add_pod_group` and the sister function `pod_groups` in order to help find a group by pod.
		- New array `subproject_references`. 
			- The @pods_project.targets installer API breaks with nested subprojects since it would only return the Aggregate Targets. Adding a new public property `all_targets` that will take the nested subprojects and map over their targets such that `all_targets` on the container project will return all targets for the installer.


### Backwards Compatibility
The `pods_project` property on `Pod:Installer` now points to the container project, so any assumptions made about the state of the generated project may break. For instance, `pods_project.targets` will now only returns a list of aggregate targets instead of aggregate and pod targets. We can add certain helper methods like `all_targets` to `Pod::Project` in order to stay backwards compatible with post install hooks. Certain projects may have to fix their assumptions before turning on this installation option.

### Phase 2: Incremental Pod Installation
**Coming soon**
Design doc for phase 2 of this project will be published soon.

