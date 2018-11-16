# Incremental Pod Installation (Phase 2)
**author:** [sebastianv1](https://github.com/sebastianv1).  
**date:** 11/16/2018

## Pre-Reads:
[Phase 1 Doc](https://github.com/CocoaPods/CocoaPods/issues/8253)

## Summary
[Summary](https://github.com/CocoaPods/CocoaPods/issues/8253) from Phase 1 Doc.

## Motivation
[Motivation](https://github.com/CocoaPods/CocoaPods/issues/8253) from Phase 1 Doc.

## Design (Incremental Pod Installation)

### Installation Option and Flags
Enabling incremental pod installation will be gated by the installation option `use_incremental_installation` that depends on `generate_multiple_pod_projects` also being enabled. Installation will raise an exception early on if this condition isn't met.

In addition to the installation option, we will add a new installation flag `--force-full-install` that can be used to ignore the contents of the cache and force a complete installation.

### Project Caching
In order to enable *only* regenerating projects that have changed since the previous installation, we will be creating a cache inside the sandbox directory storing:
1. A target cache key used to determine if a particular target is dirty.
2. Target metadata used to recreate itself as a target dependency for parent targets.

The cache will exist under the `.project_cache` dir and store two files for the cases listed above: `installation_cache` and `metadata_cache`

#### Key Cache: `./project_cache/installation_cache`
##### `TargetCacheKey`
The `TargetCacheKey` is responsible for uniquely identifying a target and determining if a target has changed. Since CocoaPods hands off the compilation of targets to Xcode, we can determine if a target is dirty based on the following criteria:

- Difference in podspec CHECKSUM values.
- Difference in build settings.
- SHA (if one exists from the checkout options).
- Difference in the set of files tracked (exclusive to local pods).

For each `TargetCacheKey`, we will store in the `./project_cache/installation_cache` cache:
- CHECKSUM
- Path to target's xcconfig file (containing the build settings)
- SHA (if exists)
- List of all tracked files (exclusive to local pods)

*(Maybe include?)Note on storing sets of files:* There are a couple ways we could go about storing the set of files: create a unique checksum from the list of files, or directly store the set of files as an array. Storing the list of files as an array directly seems better since it allows us to output the list of files causing a project to be regenerated that can be used by the `--verbose` flag and local testing. In addition, we will mostly be checking `TargetCacheKey` objects constructed from a `PodTarget` object against the equivalent target parsed from the cache; thus, we will already have to perform a linear operation (as opposed to a constant) in order to compute the checksum from the list of files on the `PodTarget` object to compare against the cached checksum. As a result, storing the set of files as an array seems to be the better option with only one extra iteration incurred for performance.

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
The `ProjectInstallationCache` is responsible for creating an in-memory representation of the cache stored in `.project_cache/installation_cache`. In addition to storing the properties of each `TargetCacheKey` per target, this will also store the hash of user build configurations and a cache version. Since the user build configurations are applied to all projects, any changes to that hash would require a full installation. The cache version is stored for backwards compatibility if changes are made in the future to the structure of the cache that would require flushing its contents.

The `ProjectInstallationCache` public interface will be:
```ruby
class ProjectInstallationCache
	# @return [Hash<String, TargetCacheKey>
	attr_reader :target_by_cache_key
	
	# @return [Hash{String=>Symbol}]
	attr_reader :build_configurations
	
	# @return [String]
	attr_reader :cache_version
	
	def initialize(target_by_cache_key, build_configurations, cache_version)

	# Saves cache to given path.
	def save(path)

	# Hashed representation of cache.
	def to_hash
	
	# Updates internal #target_by_cache_key
	def update_target_keys!(pod_targets, aggregate_targets)
		
	# Updates internal #build_configurations
	def update_build_configurations!(build_configurations)
	
	# Updates internal #cache_version
	def update_cache_version!(cache_version)

	# @return [ProjectInstallationCache]
	def self.from_file(path)
```

#### Metadata Cache: `.project_cache/metadata_cache`
When a pod target has changed, we only want to regenerate the specific project it belongs to without having to also regenerate its dependencies. The metadata cache is responsible for storing the necessary metadata such that when a pod target is regenerated, we can construct and wire up its target dependencies again. 

_Note: A future optimization could involve only opening up the project and selectively updating the properties that have changed instead of regenerating it from scratch. This would go along with updating the `TargetCacheKey` `key_difference` method to return more specific symbols (i.e. `:build_settings` or `:target_dependencies`)_

##### `TargetMetadata`
The `TargetMetadata` contains the properties needed to recreate a target dependency for a parent target. This includes:
- The native target UUID.
- Container project path.

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
Similar to `ProjectInstallationCache`, this object is responsible for creating an in-memory representation of the cache stored in `.project_cache/metadata_cache`.

It's public interface will be:
```ruby
class ProjectMetadataCache
	# @return [Hash<String, TargetMetadata>]
	attr_reader :target_by_metadata

	def initialize(target_by_metadata)
	
	def save(path)
	
	def to_hash
	
	# Updates internal metadata from installation results
	def update_metadata!(aggregate_target_installation_results, pod_target_installation_results)
	
	# @return [ProjectMetadataCache]
	def self.from_file(path)
```


#### `ProjectCacheAnalyzer`
We can utilize the cache models we created to analyze which targets need to be regenerated. The `ProjectCacheAnalyzer`'s responsbility is to output the list of `pod_targets` and `aggregate_targets` that have changed since the previous installation.

```ruby
class ProjectCacheAnalyzer
	def initialize(project_key_cache, all_pod_targets, all_aggregate_targets)

	# @return Struct(:changed_pod_targets, :changed_aggregate_targets)
	def analyze
```

In the pipeline of installation steps, the `ProjectCacheAnalyzer` will run right before project generation and utilizie its result to inject the list of targets that have changed into our project generator.


#### Wiring up cached target dependencies
Since we will not be creating `PBXNativeTarget` objects for targets that have not changed, we need to add two new methods that will allow us to recreate these target dependencies from the `TargetMetadata` object for parent targets that were regenerated.

`def add_cached_subproject(metadata, project)` will be added to `Pod::Project`.

`def add_cached_dependency` will be added to the `Xcodeproj::Project::Object::AbstractTarget` object reopened and extended inside of CocoaPods. This will use the metadata `native_target_uuid` and `container_project_uuid` in order to recreate a target dependency.

##### Alternative Options
Instead of caching the necessary information to recreate a `PBXTargetDependency` object, another option would be just opening the project on disk that contains the correct target dependency. The concern for this approach is the performance cost of opening a `Pod::Project` object, especially for changes to aggregate targets since that could involve opening 300+ projects for larger apps.

## Backwards Compatibility

The existing API on the `Installer` object includes two properties:`pods_project` and `pod_target_subprojects`. With incremental installation, these projects may not be generated. As a result, we should add to the documentation that these values _may_ not exist. Instead of using those properties, post-install hooks should use a new property called `changed_projects` which is just a list of the projects that were generated as a result of the incremental installation.

## Other Pod Commands that use `installer.rb`
`pod update` and `pod analyze` will receive the performance improvement of incremental installation, but should not require any changes.

    



