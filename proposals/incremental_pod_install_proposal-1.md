# Incremental Pod Installation (Phase 1)
**author:** sebastianv1

**date:** 10/31/2018

## Summary
A growing pain for developers using CocoaPods in a large codebase (>300 dependencies) is the wall clock time from invoking `pod install` to coding inside Xcode. A large portion of this time is spent generating the `Pods.xcodeproj` for every pod installation and waiting for Xcode to parse the contents of the `Pods.xcodeproj/project.pbxproj` file before a developer can begin interacting with his or her workspace.

Instead of generating and integrating all targets for every pod installation, we can optimize this with an incremental pod installation that would only generate and integrate pod targets that have changed since the previous installation. Implementing incremental pod installation necessitates two changes: The first is breaking up the monolithic `Pods.xcodeproj` into subprojects for each pod target (and its test targets) as a prerequisite for the second change, implementing the incremental logic to only regenerate the subprojects that have changed.

## Motivation
Productivity slows down significantly in large CocoaPods environments with many active contributors because invoking `pod install` is often required for every merge, rebase, or branch switch (in addition to the required installation for every new file, module, header etc.). This means that CocoaPods will regenerate the entire `Pods.xcodeproj` (most time consuming pipeline step) and Xcode has to reparse the entire `Pods.xcodeproj/project.pbxproj` contents before a developer can start coding again. For example, working in a monorepo with ~400 pods requires around 90 seconds to complete a `pod install` and at least 30 seconds for Xcode to become responsive again. The `Pods.xcodeproj` in this example monorepo contains `65,000` objects and `300,000` lines for Xcode to parse through. Requiring developers to wait 2 minutes (and longer as these projects grow) obviates the need to optimize larger Pod projects by only regenerating the minimum subset of dependencies that have changed in a project.


## Design (Splitting up `Pods.xcodeproj`)
### Overview
##### Installation Option
The option to generate Xcode projects per pod target will be gated by the installation option `generate_multiple_pod_projects` set to `false` by default.

##### Pod Target Projects 
When `generate_multiple_pod_projects` is flipped on, all pod targets will receive their own `.xcodeproj` file containing the target and test targets. For example, the pod `PonyDebugger` would now generate a `PonyDebugger.xcodeproj` containing `PonyDebugger` and `PonyDebugger-Unit-Tests` targets. The `Pods.xcodeproj` will transform into a container project that only holds the aggregate targets and nests each of the pod target projects. It makes sense to keep aggregate targets inside `Pods.xcodeproj` instead of breaking them out into their own projects since they already act as a container target that holds all target dependencies per user target and would only produce unnecessary nesting. Also, many aggregate targets often share the same pod target dependencies, and the likelihood that most (if not all) aggregate targets get updated on the addition or removal of a new dependency warrants keeping them in `Pods.xcodeproj`.


Putting each of the pod targets into their own projects allows us to also flatten the group hierarchy to something like:
```
PonyDebugger.xcodeproj
	-> PonyDebugger
	-> Dependencies
	-----> SocketRocket.xcodeproj
	-> Frameworks
	-> Support Files
```
Instead of nesting `PonyDebugger` under either `Development Pods` or `Pods` previously done in `Pods.xcodeproj`, we can move it up into the project's main group. In order to wire up the project's target dependencies correctly, we also need to create a new group `Dependencies` that contains a reference to its dependent xcode projects since the Xcodeproj gem (and Xcode in general) only allows targets to add other target dependencies that either exist in the same project or in a nested subproject.

##### Performance Concerns
By breaking up the monolithic `Pods.xcodeproj` into individual projects, we are creating more objects in general that Xcode needs to load into memory. For example, on the same sample project described in the Summary section, the total object count from just `Pods.xcodeproj` was 65,425,  and splitting up the projects created 74,676 objects. This could result in some Xcode performance issues by holding onto more objects in memory and a longer first time or clean `pod install` time (about 7 seconds in the aforementioned large sample project). However, the latter is dramatically improved by the overall goal of this project to only generate Xcode projects for the pod targets that have changed since the previous installation. 

Anecdotally, Apple recommends wiring up projects in this format by nesting dependent projects, and Xcode performance seems better as source files appear to load faster when they are broken up into subprojects instead of all living inside the one `Pods.xcodeproj`.


### Implementation Details
##### Single and Multi Pods Project Generator
To support the variant behavior between generating a single project vs multiple, we will create two new objects called `SinglePodsProjectGenerator` and `MultiPodsProjectGenerator` that inherit from the existing `PodsProjectGenerator`. Both objects use the inherited initializer and implement the same public API `generate!`.

By splitting up `PodsProjectGenerator` into `SinglePodsProjectGenerator` and `MultiPodsProjectGenerator`, we can also extract some shared logic out of `PodsProjectGenerator` that the two subclasses can reuse and not rely so heavily on inheritance. These two new objects are `ProjectGenerator` and `PodsProjectWriter`.

##### ProjectGenerator
This object is responsible for creating and preparing a project that can be used in CocoaPods. It's responsibilities include:
- Adding build configurations
- Resetting the symroot
- Add pod groups and the Podfile
- Settings project deployment targets for each platform.

```ruby
def initialize(sandbox, 
               path, 
	       pod_targets, 
	       build_configurations, 
	       platforms, 
	       pod_target_subproject, 
	       object_version=nil, 
	       podfile_path=nil)

# @returns [Pod::Project] The generated and prepared project.
def generate!
```

##### PodsProjectWriter
This object is responsible for taking a project generated by `ProjectGenerator` and cleaning up empty groups, generating deterministic UUID's if permitted by the installation options, adding test schemes, and saving to disk.

```ruby
def initialize(sandbox, 
               project, 
	       pod_target_installation_results, 
	       installation_options)
	       
# Cleans up and writes @project to disk.
def write!
```

##### Project
###### pod_target_subproject

By breaking out pod targets into their own projects, we will add a new parameter to the `Pod::Project` initializer `pod_target_subproject` that defaults to false.
The `pod_target_subproject` ivar is used to switch on behavior in the method `add_pod_group` since we want to put pod groups in the main group instead of `Development Pods` or `Pods` group for subprojects. It is also used in `pod_groups` in order to return the main group for subprojects.

###### dependencies

`Pod::Project` will also include a new ivar `dependencies` to represent the `Dependencies` group used by pod target subprojects. If this group is empty, it will also be cleaned up by the `PodsProjectWriter`.

##### Sandbox
The generated pod target projects will be written into the sandbox directory, so a new helper method will be added to `Pod::Sandbox` for determining the paths to these projects.
```ruby
def target_project_path(target)
  root.join(‘Projects’, “#{target.label}.xcodeproj”)
end
```

## Backwards Compatibility
The `pods_project` property on `Pod:Installer` now points to the container project, so any assumptions made about the state of the generated project may break. For instance, `pods_project.targets` will now only returns a list of aggregate targets instead of aggregate and pod targets. We can add certain helper methods like `all_targets` to `Pod::Project` in order to stay backwards compatible with post install hooks. Certain projects may have to fix their assumptions before turning on this installation option.

# Phase 2: Incremental Pod Installation
**Coming soon**

Phase 2 of this design doc will incorporate the changes required for making the `pod install` command incremental by only regenerating the individual subprojects that have changed since the previous installation. This will be published soon and referenced here.



