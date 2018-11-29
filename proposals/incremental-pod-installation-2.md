# Incremental Pod Installation (Phase 2)
**author:** [sebastianv1](https://github.com/sebastianv1)  
**date:** 11/16/2018

## Pre-Reads:
[Phase 1 Doc](https://github.com/CocoaPods/CocoaPods/issues/8253)

## Summary
[Summary](https://github.com/CocoaPods/CocoaPods/issues/8253) from Phase 1 Doc.

## Motivation
[Motivation](https://github.com/CocoaPods/CocoaPods/issues/8253) from Phase 1 Doc.

## Design (Incremental Pod Installation)

### Installation Option and Flags
Enabling incremental pod installation will be gated by the installation option `incremental_installation` that depends on `generate_multiple_pod_projects` also being enabled. This is necessary because there is no performance improvement without `generate_multiple_pod_projects` enabled since the single pods project will regenerate itself entirely for every installation. We will raise an exception in the `PodfileValidator` class if this condition isn't met.

In addition to the installation option, we will add a new installation flag `--clean-install` that can be used to ignore the contents of the cache and force a complete installation.

### Project Caching
In order to enable _only_ regenerating the Xcode project files for pod targets that have changed since the previous installation, we will create a cache inside the sandbox directory storing:
1. A target cache key per target used to determine if it is dirty.
2. Target metadata used to recreate itself as a target dependency for parent targets.

The cache will exist under the `Pods/.project_cache` dir and store files for the two cases listed above (`installation_cache` and `metadata_cache`) in addition to a `cache_version` file that is stored for backwards compatibility if changes are made in the future to the structure of the cache that would require flushing its contents.


#### Key Cache: `Pods/.project_cache/installation_cache`
##### `TargetCacheKey`
The `TargetCacheKey` is responsible for uniquely identifying a `Target` and determining if it has changed.

For each `PodTarget`, we can mark it as dirty based on a difference in the following criteria:
- Podspec checksum values.
- Build settings
- Set of specs to integrate.
- Set of files tracked (exclusive to local pods).
- Checkout options (if they exist for the pod).

Each `PodTarget` will store in the `installation_cache` file:
- Podspec checksum.
- List of specification names.
- Checksum of build settings.
- List of all files tracked (exclusive to local pods).
- Checkout options (if they exist for the pod).

For each `AggregateTarget`, we can mark it as dirty based on a difference in the following criteria:
- Build settings.

Each `AggregateTarget` will store in the `installation_cache` file:
- Checksum of build settings.

___Note on storing the list of files__: There are a couple ways we could go about storing the set of files: create a unique checksum from the list of files, or directly store them as an array. Storing the list of files as an array seems better since it allows us to output the files causing a project to be regenerated to be used by the `--verbose` flag and local testing. In addition, we will be comparing `TargetCacheKey` objects constructed from a `PodTarget` object against the equivalent target parsed from the cache; thus, we will already have to perform a linear operation to compute the checksum from the list of files on the `PodTarget` object to compare against the cached checksum. For these reasons, storing the set of files as an array seems to be the better option with only one extra iteration incurred for performance._

The `TargetCacheKey` public interface will be:

```ruby
class TargetCacheKey
	# @return [Symbol] The type of target. (:aggregate or :pod_target)
	attr_reader :type
	
	# @param [Symbol] type
	# @param [Hash] hash
	def initialize(type, hash)

	# @return [Symbol] difference
	# For now, returns :none if the keys are equal and :project if they are different.
	def key_difference(other)

	# Hash representation of TargetCacheKey. Used for cache storage.
	def to_hash

	# @return [TargetCacheKey]
	def self.cache_key_from_hash(hash)

	# @return [TargetCacheKey]
	def self.cache_key_from_pod_target(pod_target)

	# @return [TargetCacheKey]
	def self.cache_key_from_aggregate_target(aggregate_target)
end
```

##### `ProjectInstallationCache`
The `ProjectInstallationCache` is responsible for creating an in-memory representation of the cache stored in the `installation_cache` file. In addition to storing the properties of each `TargetCacheKey` per target, the `installation_cache` file will also store the hash of user build configurations and project object version. These properties are applied to all projects and any changes to their values would require a full installation.
The `ProjectInstallationCache` public interface will be:
```ruby
class ProjectInstallationCache
	# @return [Hash<String, TargetCacheKey> Mapping from #Target to #TargetCacheKey. 
	attr_reader :cache_key_by_target
	
	# @return [Hash{String=>Symbol}]
	attr_reader :build_configurations
	
	# @return [String]
	attr_reader :project_object_version

	# @param [Hash<Target, TargetCacheKey>] cache_key_by_target @see #cache_key_by_target
	# @param [Hash] hash The contents of the cache.
	def initialize(type, hash)

	# @return [Symbol] difference
	# For now, returns :none if the keys are equal and :project if they are different.
	def initialize(cache_key_by_target, build_configurations)

	# Saves cache to given path.
	def save_as(path)

	# Hashed representation of cache.
	def to_hash
	
	# Updates internal #cache_key_by_target
	def cache_key_by_target=(cache_key_by_target)
		
	# Updates internal #build_configurations
	def build_configurations=(build_configurations)
	
	# Updates internal project object version
	def project_object_version=(project_object_version)

	# @return [ProjectInstallationCache]
	def self.from_file(path)
end
```

#### Metadata Cache: `Pods/.project_cache/metadata_cache`
When a pod target has changed, we only want to regenerate the specific project it belongs to without having to also regenerate its dependencies or parents. The metadata cache is responsible for storing the necessary metadata such that when a pod target is regenerated, we can construct and wire up its target dependencies again. 

_Note: A future optimization could involve only opening up the project and selectively updating the properties that have changed instead of regenerating it from scratch. This would go along with updating the `TargetCacheKey` `key_difference` method to return more specific symbols (i.e. `:build_settings` or `:target_dependencies`)_

##### `TargetMetadata`
The `TargetMetadata` contains the properties needed to recreate a target dependency for a parent target. This includes:
- Target label
- The native target UUID.
- Container project path.

It's public interface will be:
```ruby
class TargetMetadata
	# @return [String]
	# The label (or name) of the target
	attr_reader :target_label

	# @return [String] 
	# The UUID of the native target stored in its project.
	attr_reader :native_target_uuid
	
	# @return [Path]
	# Project path
	attr_reader :container_project_path
	
	# @param [String] target_label @see #target_label
	# @param [String] native_target_uuid @see #native_target_uuid
	# @param [String] container_project_path @see #container_project_path
	def initialize(target_label, native_target_uuid, container_project_path)
	
	def to_hash
	
	# @return [TargetMetadata]
	def self.cache_metadata_from_hash(hash)
	
	# @return [TargetMetadata]
	def self.cache_metadata_from_native_target(native_target)
end
```

##### `ProjectMetadataCache`
Similar to `ProjectInstallationCache`, the `ProjectMetadataCache` object is responsible for creating an in-memory representation of the cache stored in `metadata_cache`.

It's public interface will be:
```ruby
class ProjectMetadataCache
	# @return [Hash<String, TargetMetadata>]
	attr_reader :target_by_metadata
	
	# @param [Hash<String, TargetMetadata>] @see #target_by_metadata
	def initialize(target_by_metadata)
	
	def save_as(path)
	
	def to_hash
	
	# Updates internal metadata from installation results
	def update_metadata!(aggregate_target_installation_results, pod_target_installation_results)
	
	# @return [ProjectMetadataCache]
	def self.from_file(path)
end
```


#### `ProjectCacheAnalyzer`
We can utilize the cache models we created to analyze which targets and their associate projects need to be regenerated. The `ProjectCacheAnalyzer` takes an instance of a `ProjectInstallationCache` and outputs a `ProjectCacheAnalysisResult` object that will be used by the project generation step.

```ruby
class ProjectCacheAnalyzer
	# @return [Array<PodTarget>] List of all pod targets
	attr_reader :pod_targets
	
	# @return [Array<AggregateTarget>] List of all aggregate targets
      	attr_reader :aggregate_targets
	
	# @return [ProjectInstallationCache] cache used for analysis.
     	attr_reader :cache
	
	# @return [Sandbox] Project sandbox.
      	attr_reader :sandbox
	
	# @return [Hash{String=>Symbol}] project build configurations
      	attr_reader :build_configurations
	
	# @return [String] object version of user project.
      	attr_reader :project_object_version

	# @param [Sandbox] sandbox @see #sandbox
	# @param [ProjectInstallationCache] cache @see #cache
	# @param [Hash{String=>Symbol}] build_configurations @see #build_configurations
	# @param [String] project_object_version @see #project_object_version
	# @param [Array<PodTarget>] pod_targets @see #pod_targets
	# @param [Array<AggregateTarget>] aggregate_targets @see #aggregate_targets
	def initialize(sandbox, cache, build_configurations, project_object_version, pod_targets, aggregate_targets)

	# @return [ProjectCacheAnalysisResult] Analysis result.
	def analyze
end
```

```ruby
class ProjectCacheAnalysisResult
	# @return [Array<PodTarget>] List of pod targets that needs generation.
	attr_reader :pod_targets_to_generate
	
	# @return [Array<AggregateTarget>] List of aggregate targets that needs generation.
 	attr_reader :aggregate_targets_to_generate
	
	# @return [Hash<Target, TargetCacheKey>] The generated hash of targets cache key.
	attr_reader :cache_key_by_target
	
	# @return [Hash{String=>Symbol}] Build configurations to integrate.
	attr_reader :build_configurations
	
	# @return [String] project_object_version
	attr_reader :project_object_version
end
  ```


The `ProjectCacheAnalyzer` will be created by the `Pod::Installer` class and run right before project generation. The project generation step is where we will see a huge performance improvement from our caching since it will only be given the subset of pod targets that need to be generated, instead of generating all targets for every installation.

#### Wiring up cached target dependencies
Since we will not be creating `PBXNativeTarget` objects for targets that have not changed, we need to add two new methods that will allow us to recreate these target dependencies from the `TargetMetadata` object for parent targets that were regenerated.

`def add_cached_subproject(metadata, group)` will be added to `Pod::Project`.

`def add_cached_dependency(metadata)` will be added to the `Xcodeproj::Project::Object::AbstractTarget` and extended only inside of CocoaPods.

##### Alternative Options
Instead of caching the necessary information to recreate a `PBXTargetDependency` object, another option would be just opening the project on disk that contains the correct target dependency. The concern for this approach is the performance cost of opening a `Pod::Project` object, especially for changes to aggregate targets since that could involve opening 300+ projects for larger apps.

## Backwards Compatibility
Using incremental installation means that only a subset of the projects that need to be regenerated will be created by the project generator. This means that the properties `pods_project` and `pod_target_subprojects` on `Pod::Installer` won't necessarily exist since they may not be created. As a result, we will add a new property `generated_projects` that will hold a list of all the projects that were generated, and post-install hooks should start using this new property to map over properties they care about in the projects.

## Other Pod Commands that use `installer.rb`
`pod update` and `pod analyze` will receive the performance improvement of incremental installation, but should not require any changes because all of the changes will happen in the installer, rather than in the install command.

    







