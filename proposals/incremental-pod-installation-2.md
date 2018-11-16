# Incremental Pod Installation (Phase 2)
**author:** [sebastianv1](https://github.com/sebastianv1).  
**date:** 11/16/2018

## Pre-Reads:
[Phase 1 Doc](https://github.com/sebastianv1/CocoaPods/blob/sebastianv1/mutli-xcode-proposal/proposals/incremental-pod-install-1.md)

## Summary
[Summary](https://github.com/sebastianv1/CocoaPods/blob/sebastianv1/mutli-xcode-proposal/proposals/incremental-pod-install-1.md#Summary) from Phase 1 Doc.

## Motivation
[Motivation](https://github.com/sebastianv1/CocoaPods/blob/sebastianv1/mutli-xcode-proposal/proposals/incremental-pod-install-1.md#Motivation) from Phase 1 Doc.

## Design (Incremental Pod Installation)

### Installation Option and Flags
Enabling incremental pod installation will be gated by the installation option `use_incremental_installation` that depends on `generate_multiple_pod_projects` also being enabled. Installation will raise an exception early on if this condition isn't met.

In addition to the installation option, we will add a new installation flag `--force-full-install` that can be used to ignore the contents of the cache and force a complete installation.

### Project Caching
In order to enable *only* regenerating projects that have changed since the previous installation, we will be creating a cache inside the sandbox directory to store the information required to:
1. Determine if a particular target is dirty.
2. Recreate itself as a target dependency for parent targets that will be regenerated.

The cache will exist under the `.project_cache` dir and store two files for the cases listed above: `installation_cache` and `metadata_cache`

#### Key Cache: `./project_cache/installation_cache`
##### `TargetCacheKey`
The `TargetCacheKey` is responsible for uniquely identifying a target and used to determine if a target has changed. Since CocoaPods hands off the compilation of targets to Xcode, we can determine if a target is dirty based on the following criteria:

- Difference in podspec CHECKSUM values.
- Difference in build settings.

Local development targets:
- Difference in the set of files tracked.

External targets:
- SHA (if one exists from the checkout options)

*(Maybe include?)Note on storing sets of files:* There are a couple ways we could go about storing the set of files: create a unique checksum from the list of files, or directly store the set of files as an array. Storing the list of files as an array directly seems to be the better option since it allows us to output the list of files causing a project to be regenerated that can be used by the `--verbose` flag and local testing. In addition, we will mostly be checking `TargetCacheKey` objects generated from a `PodTarget` object against the equivalent target parsed from the cache; thus, we will already have to perform a linear operation (as opposed to a constant) in order to compute the checksum from the list of files on the `PodTarget` object to compare against the cached checksum. As a result, storing the set of files as an array seems to be the better option with only one extra iteration incurred for performance.

The `TargetCacheKey` object will be used to directly compare targets with each other in addition to targets stored in `.project_cache/target_key_cache`. It's public interface will be:

```ruby
class TargetCacheKey
	# @param [Symbol] type
	# The type of target (i.e. local, external, or aggregate)
	def initialize(type, hash)

	# @return [Symbol] difference
	# For now, returns :none if the keys are equal and :project if they are different.
	def key_difference(other)

	# Hash representation of TargetCacheKey. Used for cache storage.
	def to_hash

	# Converts hash to TargetCacheKey.
	def self.cache_key_from_hash(hash)

	# Converts #pod_target type to TargetCacheKey.
	def self.cache_key_from_pod_target(pod_target)

	# Converts #aggregate_target type to TargetCacheKey.
	def self.cache_key_from_aggregate_target(aggregate_target)
```

##### `ProjectInstallationCache`
The `ProjectInstallationCache` is responsible for creating an in-memory representation of the cache stored in `.project_cache/installation_cache`. In addition to storing the properties of each `TargetCacheKey` per target, this will also store the hash of user build configurations and a cache version. Since the user build configurations is applied to all projects, any changes to that hash would require a full installation. The cache version is stored for backwards compatibility if changes are made in the future to the structure of the cache that would require flushing its contents.

It's public interface will be:
```ruby
class ProjectInstallationCache

	attr_reader :target_by_cache_key
	attr_reader :build_configurations
	attr_reader :cache_version

	def initialize(target_by_cache_key, build_configurations, cache_version)

	# Saves cache to given path.
	def save(path)

	# Hashed representation of cache.
	def to_hash

	def update_target_keys!(pod_targets, aggregate_targets)

	def update_build_configurations!(build_configurations)

	def update_cache_version!(cache_version)

	# Parses contents of file and creates ProjectInstallationCache instance.
	def self.from_file(path)
```

#### Metadata Cache: `.project_cache/metadata_cache`
When a pod target has changed, we only want to regenerate that specific target without having to also regenerate its dependencies if they remain unchanged. The metadata cache is responsible for storing the necessary metadata such that when a pod target is regenerated, we can construct and wire up its target dependencies again since regenerating the project will create one from scratch. 

_Note: A future optimization could involve only opening up the project and selectively updating the properties that have changed. This would go along with updating the `TargetCacheKey` key_difference method to return more symbols (i.e. `:build_settings` or `:target_dependencies`)_

##### `TargetMetadata`
The `TargetMetadata` contains information needed to recreate itself as a target dependency for a parent target. This includes:
- The native target UUID.
- Container project path.
- Container project UUID.

It's public interface will be:
```ruby
class TargetMetadata

	attr_reader :native_target_uuid
	attr_reader :container_project_path
	attr_reader :container_project_uuid

	def initialize(native_target_uuid, container_project_path, container_project_uuid)

	def to_hash

	def self.cache_metadata_from_hash(hash)

	def self.cache_metadata_from_native_target(native_target)
```

##### `ProjectMetadataCache`
Similar to `ProjectInstallationCache`, this object is responsible for creating an in-memory representation of the cache stored in `.project_cache/metadata_cache`.

It's public interface will be:
```ruby
class ProjectMetadataCache

	attr_reader :target_by_metadata

	def initialize(target_by_metadata)

	def save(path)

	def to_hash

	def update_metadata!(aggregate_target_installation_results, pod_target_installation_results)

	def self.from_file(path)
```


#### `ProjectCacheAnalyzer`
With our cache models, now we can analyze which targets need to be regenerated. The main function of this object is to merely output the list of `pod_targets` and `aggregate_targets` that have changed since the last installation.

```ruby
class ProjectCacheAnalyzer
	def initialize(project_key_cache, all_pod_targets, all_aggregate_targets)

	# @return Struct(:changed_pod_targets, :changed_aggregate_targets)
	def analyze
```

In the pipeline of installation steps, the `ProjectCacheAnalyzer` will run right before project generation such that the project generator will only inject in the list of targets that the analyzer has determined needs to be generated.


#### Wiring up cached target dependencies
Since we will not be creating `PBXNativeTarget` objects for targets that have not changed, we need to add two new methods that will allow us to recreate the target dependencies for pod targets that have not changed with the properties stored in `TargetMetadata`.

`def add_cached_subproject` will belong as a part of `Pod::Project` and use the metadata `container_project_path` to recreate a file reference.

`def add_cached_dependency` will be added to the `Xcodeproj::Project::Object::AbstractTarget` object reopened and extended inside of CocoaPods. This will use the metadata `native_target_uuid` and `container_project_uuid` in order to recreate a target dependency.


## Backwards Compatibility

The existing API on the `Installer` includes two properties:`pods_project` and `pod_target_subprojects`. With incremental installation, these projects may not be generated. As a result, we should add to the documentation that these values _may_ not exist. Instead of using those properties, post-install hooks should use a new property called `changed_projects` which is just an array of the list of projects that were generated as a result of the incremental installation.

## Other Pod Commands that use `installer.rb`

`pod update` and `pod analyze` should remain unchanged as a result of the caching.


    



