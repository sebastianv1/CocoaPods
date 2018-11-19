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
Enabling incremental pod installation will be gated by the installation option `incremental_installation` that depends on `generate_multiple_pod_projects` also being enabled. Installation will raise an exception in the `PodfileValidator` class if this condition isn't met.

In addition to the installation option, we will add a new installation flag `--force-full-install` that can be used to ignore the contents of the cache and force a complete installation.

### Project Caching
In order to enable *only* regenerating pod targets that have changed since the previous installation, we will create a cache inside the sandbox directory storing:
1. A target cache key used to determine if a particular target is dirty.
2. Target metadata used to recreate itself as a target dependency for parent targets.

The cache will exist under the `Pods/.project_cache` dir and store files for the two cases listed above: `installation_cache` and `metadata_cache` in addition to a `cache_version` file that is stored for backwards compatibility if changes are made in the future to the structure of the cache that would require flushing its contents. *Note*: We will update the documentation for projects that check the `Pods/` directory into source control that the `Pods/.project_cache` path should be ignored.


#### Key Cache: `Pods/.project_cache/installation_cache`
##### `TargetCacheKey`
The `TargetCacheKey` is responsible for uniquely identifying a target and determining if a target has changed. Since CocoaPods hands off the compilation of targets to Xcode, we can determine if a target is dirty based on a difference the following criteria:

- Podspec checksum values.
- Build settings.
- Set of specs to integrate.
- Set of files tracked (exclusive to local pods).
- Checkout options (if they exist for the pod).

For each `TargetCacheKey`, we will store in the `installation_cache` cache:
- Podspec checksum
- List of specification names
- All xcconfig file paths (contains the build settings)
- List of all tracked files (exclusive to local pods)
- SHA (if exists one exists from the checkout options)

_Note on storing the list of files:_ There are a couple ways we could go about storing the set of files: create a unique checksum from the list of files, or directly store them as an array. Storing the list of files as an array seems better since it allows us to output the files causing a project to be regenerated to be used by the `--verbose` flag and local testing. In addition, we will be comparing `TargetCacheKey` objects constructed from a `PodTarget` object against the equivalent target parsed from the cache; thus, we will already have to perform a linear operation to compute the checksum from the list of files on the `PodTarget` object to compare against the cached checksum. For these reasons, storing the set of files as an array seems to be the better option with only one extra iteration incurred for performance.

The `TargetCacheKey` public interface will be:

```ruby
class TargetCacheKey
	# @param [Symbol] type
	# The type of target (i.e. local, external, or aggregate)
	
	# @param [Hash] hash
	# Hash contents of the cache.
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
```

##### `ProjectInstallationCache`
The `ProjectInstallationCache` is responsible for creating an in-memory representation of the cache stored in `installation_cache`. In addition to storing the properties of each `TargetCacheKey` per target, this will also store the hash of user build configurations since the user build configurations are applied to all projects and any changes would require a full installation.
The `ProjectInstallationCache` public interface will be:
```ruby
class ProjectInstallationCache
	# @return [Hash<String, TargetCacheKey>
	attr_reader :target_by_cache_key
	
	# @return [Hash{String=>Symbol}]
	attr_reader :build_configurations
	
	def initialize(target_by_cache_key, build_configurations)

	# Saves cache to given path.
	def save_as(path)

	# Hashed representation of cache.
	def to_hash
	
	# Updates internal #target_by_cache_key
	def update_target_keys!(pod_targets, aggregate_targets)
		
	# Updates internal #build_configurations
	def update_build_configurations!(build_configurations)

	# @return [ProjectInstallationCache]
	def self.from_file(path)
```

#### Metadata Cache: `Pods/.project_cache/metadata_cache`
When a pod target has changed, we only want to regenerate the specific project it belongs to without having to also regenerate its dependencies. The metadata cache is responsible for storing the necessary metadata such that when a pod target is regenerated, we can construct and wire up its target dependencies again. 

_Note_: A future optimization could involve only opening up the project and selectively updating the properties that have changed instead of regenerating it from scratch. This would go along with updating the `TargetCacheKey` `key_difference` method to return more specific symbols (i.e. `:build_settings` or `:target_dependencies`)_

##### `TargetMetadata`
The `TargetMetadata` contains the properties needed to recreate a target dependency for a parent target. This includes:
- The native target UUID.
- Container project path.
- Target label

It's public interface will be:
```ruby
class TargetMetadata
	# @return [String] 
	attr_reader :native_target_uuid
	
	# @return [Path]
	attr_reader :container_project_path

	def initialize(native_target_uuid, container_project_path)

	def to_hash
	
	# @return [TargetMetadata]
	def self.cache_metadata_from_hash(hash)
	
	# @return [TargetMetadata]
	def self.cache_metadata_from_native_target(native_target)
```

##### `ProjectMetadataCache`
Similar to `ProjectInstallationCache`, this object is responsible for creating an in-memory representation of the cache stored in `metadata_cache`.

It's public interface will be:
```ruby
class ProjectMetadataCache
	# @return [Hash<String, TargetMetadata>]
	attr_reader :target_by_metadata

	def initialize(target_by_metadata)
	
	def save_as(path)
	
	def to_hash
	
	# Updates internal metadata from installation results
	def update_metadata!(aggregate_target_installation_results, pod_target_installation_results)
	
	# @return [ProjectMetadataCache]
	def self.from_file(path)
```


#### `ProjectCacheAnalyzer`
We can utilize the cache models we created to analyze which targets need to be regenerated. The `ProjectCacheAnalyzer` takes in an instance of `ProjectInstallationCache` and outputs a `ProjectCacheAnalysisResult` object that contains the list of targets that have been added, removed, and changed.

```ruby
class ProjectCacheAnalyzer
	def initialize(project_key_cache, pod_targets, aggregate_targets)

	# @return [ProjectCacheAnalysisResult] Analysis result.
	def analyze
```

```ruby
class ProjectCacheAnalysisResult
  	attr_reader :added_pod_targets
 	attr_reader :added_aggregate_targets
  
 	attr_reader :removed_pod_targets
 	attr_reader :removed_aggregate_targets
  
 	attr_reader :changed_pod_targets
  	attr_reader :changed_aggregate_targets
end
```



In the pipeline of installation steps, the `ProjectCacheAnalyzer` will run right before project generation and utilize its result to inject the list of targets that have changed into our project generator.


#### Wiring up cached target dependencies
Since we will not be creating `PBXNativeTarget` objects for targets that have not changed, we need to add two new methods that will allow us to recreate these target dependencies from the `TargetMetadata` object for parent targets that were regenerated.

`def add_cached_subproject(metadata, group)` will be added to `Pod::Project`.

`def add_cached_dependency(metadata)` will be added to the `Xcodeproj::Project::Object::AbstractTarget` and extended only inside of CocoaPods.

##### Alternative Options
Instead of caching the necessary information to recreate a `PBXTargetDependency` object, another option would be just opening the project on disk that contains the correct target dependency. The concern for this approach is the performance cost of opening a `Pod::Project` object, especially for changes to aggregate targets since that could involve opening 300+ projects for larger apps.

## Backwards Compatibility
Using incremental installation means that only a subset of the projects that need to be regenerated will be created by the project generator. This means that the properties `pods_project` and `pod_target_subprojects` on `Pod::Installer` won't necessarily exist since they may not be created. As a result, we will add a new property `generated_projects` that will hold a list of all the projects that were generated, and post-install hooks should start using this new property to map over the pods projects.

## Other Pod Commands that use `installer.rb`
`pod update` and `pod analyze` will receive the performance improvement of incremental installation, but should not require any changes because all of the changes will happen in the installer, rather than in the install command.

    







