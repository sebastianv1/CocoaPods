require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      describe PodsProjectGenerator do
        describe 'Generating Multi Pods Project' do
          before do
            @ios_platform = Platform.new(:ios, '6.0')
            @osx_platform = Platform.new(:osx, '10.8')

            @ios_target_definition = fixture_target_definition('SampleApp-iOS', @ios_platform)
            @osx_target_definition = fixture_target_definition('SampleApp-macOS', @osx_platform)

            user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'App Store' => :release, 'Test' => :debug }

            @monkey_spec = fixture_spec('monkey/monkey.podspec')
            @monkey_ios_pod_target = fixture_pod_target(@monkey_spec, false,
                                                        user_build_configurations, [], @ios_platform,
                                                        [@ios_target_definition], 'iOS')
            @monkey_osx_pod_target = fixture_pod_target(@monkey_spec, false,
                                                        user_build_configurations, [], @osx_platform,
                                                        [@osx_target_definition], 'macOS')

            @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
            @banana_ios_pod_target = fixture_pod_target(@banana_spec, false,
                                                        user_build_configurations, [], @ios_platform,
                                                        [@ios_target_definition], 'iOS')
            @banana_osx_pod_target = fixture_pod_target(@banana_spec, false,
                                                        user_build_configurations, [], @osx_platform,
                                                        [@osx_target_definition], 'macOS')

            @orangeframework_spec = fixture_spec('orange-framework/OrangeFramework.podspec')
            @orangeframework_pod_target = fixture_pod_target_with_specs([@orangeframework_spec], false,
                                                                        user_build_configurations, [], @ios_platform,
                                                                        [@ios_target_definition])

            @coconut_spec = fixture_spec('coconut-lib/CoconutLib.podspec')
            @coconut_test_spec = @coconut_spec.test_specs.first
            @coconut_ios_pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec],
                                                                    false,
                                                                    user_build_configurations, [], @ios_platform,
                                                                    [@ios_target_definition],
                                                                    'iOS')
            @coconut_ios_pod_target.dependent_targets = [@orangeframework_pod_target]
            @coconut_osx_pod_target = fixture_pod_target_with_specs([@coconut_spec, @coconut_test_spec],
                                                                    false,
                                                                    user_build_configurations, [], @osx_platform,
                                                                    [@osx_target_definition],
                                                                    'macOS')

            @watermelon_spec = fixture_spec('watermelon-lib/WatermelonLib.podspec')
            @watermelon_ios_pod_target = fixture_pod_target_with_specs([@watermelon_spec,
                                                                        *@watermelon_spec.recursive_subspecs], false,
                                                                       user_build_configurations, [], Platform.new(:ios, '9.0'),
                                                                       [@ios_target_definition], 'iOS')
            @watermelon_osx_pod_target = fixture_pod_target_with_specs([@watermelon_spec,
                                                                        *@watermelon_spec.recursive_subspecs], false,
                                                                       user_build_configurations, [], @osx_platform,
                                                                       [@osx_target_definition], 'macOS')

            ios_pod_targets = [@banana_ios_pod_target, @monkey_ios_pod_target, @coconut_ios_pod_target,
                               @orangeframework_pod_target, @watermelon_ios_pod_target]
            osx_pod_targets = [@banana_osx_pod_target, @monkey_osx_pod_target, @coconut_osx_pod_target, @watermelon_osx_pod_target]
            pod_targets = ios_pod_targets + osx_pod_targets

            @ios_target = fixture_aggregate_target(ios_pod_targets, false,
                                                   user_build_configurations, [], @ios_platform,
                                                   @ios_target_definition)
            @osx_target = fixture_aggregate_target(osx_pod_targets, false,
                                                   user_build_configurations, [], @osx_platform,
                                                   @osx_target_definition)

            aggregate_targets = [@ios_target, @osx_target]

            @analysis_result = Pod::Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new,
                                                                            {}, {}, [],
                                                                            Pod::Installer::Analyzer::SpecsState.new,
                                                                            aggregate_targets, pod_targets, nil)

            @installation_options = Pod::Installer::InstallationOptions.new

            @multi_project_generator = MultiPodsProjectGenerator.new(config.sandbox, aggregate_targets, pod_targets, @analysis_result,
                                                  @installation_options, config)
          end

          it "creates build configurations for all projects of the user's targets" do
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.pod_target_by_project_map.values
            pods_project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
            pod_target_projects.each do |target_project|
              target_project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
            end
          end

          it 'sets STRIP_INSTALLED_PRODUCT to NO for all configurations for all projects' do
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.pod_target_by_project_map.values
            pods_project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pods_project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pods_project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pods_project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            pod_target_projects.each do |target_project|
              target_project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              target_project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              target_project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
              target_project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
            end
          end

          it 'sets the SYMROOT to the default value for all configurations for the whole project' do
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.pod_target_by_project_map.values
            pods_project.build_settings('Debug')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pods_project.build_settings('Test')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pods_project.build_settings('Release')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pods_project.build_settings('App Store')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            pod_target_projects.each do |target_project|
              target_project.build_settings('Debug')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              target_project.build_settings('Test')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              target_project.build_settings('Release')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
              target_project.build_settings('App Store')['SYMROOT'].should == Pod::Project::LEGACY_BUILD_ROOT
            end
          end

          it 'creates the correct Pods projects' do
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.pod_target_by_project_map.values
            pods_project.class.should == Pod::Project
            pod_target_projects.each do |target_project|
              target_project.class.should == Pod::Project
            end
          end

          it 'adds the Podfile to the Pods project and not pod target subprojects' do
            config.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.pod_target_by_project_map.values
            pods_project['Podfile'].should.be.not.nil
            pod_target_projects.each do |target_project|
              target_project['Podfile'].should.be.nil
            end
          end

          it 'sets the deployment target for the all projects' do
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_projects = pod_generator_result.pod_target_by_project_map.values
            build_settings = pods_project.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
              build_setting['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
            end
            pod_target_projects.each do |target_project|
              target_project_build_settings = target_project.build_configurations.map(&:build_settings)
              target_project_build_settings.each do |build_setting|
                build_setting['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
                build_setting['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
              end
            end
          end

          it 'adds subproject pods into main group' do
            pod_generator_result = @multi_project_generator.generate!
            banana_project = pod_generator_result.pod_target_by_project_map[@banana_ios_pod_target]
            banana_project.main_group["BananaLib"].should.not.be.nil
          end

          it 'installs file references' do
            pod_generator_result = @multi_project_generator.generate!
            pod_target_by_project_map = pod_generator_result.pod_target_by_project_map
            pods_project = pod_generator_result.project
            banana_project = pod_target_by_project_map[@banana_ios_pod_target]
            banana_project.should.be.not.nil
            banana_group = banana_project.group_for_spec('BananaLib')
            banana_group.files.map(&:name).sort.should == [
              'Banana.h',
              'Banana.m',
              'BananaPrivate.h',
              'BananaTrace.d',
              'MoreBanana.h',
            ]

            monkey_project = pod_target_by_project_map[@monkey_ios_pod_target]
            monkey_project.should.not.be.nil
            monkey_group = monkey_project.group_for_spec('monkey')
            monkey_group.files.map(&:name).sort.should.be.empty # pre-built pod

            orange_project = pod_target_by_project_map[@orangeframework_pod_target]
            orange_project.should.not.be.nil
            organge_framework_group = orange_project.group_for_spec('OrangeFramework')
            organge_framework_group.files.map(&:name).sort.should. == [
              'Juicer.swift',
            ]

            coconut_project = pod_target_by_project_map[@coconut_ios_pod_target]
            coconut_project.should.not.be.nil
            coconut_group = coconut_project.group_for_spec('CoconutLib')
            coconut_group.files.map(&:name).sort.should == [
              'Coconut.h',
              'Coconut.m',
            ]

            # Verify all projects exist under Pods.xcodeproj
            pods_project.reference_for_path(banana_project.path).should.not.be.nil
            pods_project.reference_for_path(monkey_project.path).should.not.be.nil
            pods_project.reference_for_path(orange_project.path).should.not.be.nil
            pods_project.reference_for_path(coconut_project.path).should.not.be.nil
          end

          it 'installs the correct targets per project' do
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_by_project_map = pod_generator_result.pod_target_by_project_map

            pods_project.targets.map(&:name).sort.should == [
                'Pods-SampleApp-iOS',
                'Pods-SampleApp-macOS',
            ]

            pod_target_by_project_map[@watermelon_ios_pod_target].targets.map(&:name).sort.should == [
                'AppHost-WatermelonLib-iOS-Unit-Tests',
                'WatermelonLib-iOS',
                'WatermelonLib-iOS-Unit-SnapshotTests',
                'WatermelonLib-iOS-Unit-Tests',
                'WatermelonLib-iOS-WatermelonLibTestResources',
            ]

            pod_target_by_project_map[@watermelon_osx_pod_target].targets.map(&:name).sort.should == [
                'AppHost-WatermelonLib-macOS-Unit-Tests',
                'WatermelonLib-macOS',
                'WatermelonLib-macOS-Unit-SnapshotTests',
                'WatermelonLib-macOS-Unit-Tests',
                'WatermelonLib-macOS-WatermelonLibTestResources',
            ]

            pod_target_by_project_map[@banana_ios_pod_target].targets.map(&:name).sort.should == [
                'BananaLib-iOS',
            ]

            pod_target_by_project_map[@banana_osx_pod_target].targets.map(&:name).sort.should == [
                'BananaLib-macOS',
            ]

            pod_target_by_project_map[@coconut_ios_pod_target].targets.map(&:name).sort.should == [
                'CoconutLib-iOS',
                'CoconutLib-iOS-Unit-Tests',
            ]

            pod_target_by_project_map[@coconut_osx_pod_target].targets.map(&:name).sort.should == [
                'CoconutLib-macOS',
                'CoconutLib-macOS-Unit-Tests',
            ]

            pod_target_by_project_map[@orangeframework_pod_target].targets.map(&:name).sort.should == [
                'OrangeFramework',
            ]

            pod_target_by_project_map[@monkey_ios_pod_target].targets.map(&:name).sort.should == [
                'monkey-iOS',
            ]

            pod_target_by_project_map[@monkey_osx_pod_target].targets.map(&:name).sort.should == [
                'monkey-macOS',
            ]
          end

          it 'sets the pod and aggregate target dependencies' do
            pod_generator_result = @multi_project_generator.generate!
            pods_project = pod_generator_result.project
            pod_target_by_project_map = pod_generator_result.pod_target_by_project_map

            pod_target_by_project_map[@banana_ios_pod_target].targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.map(&:name).should.be.empty
            pod_target_by_project_map[@banana_osx_pod_target].targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.map(&:name).should.be.empty
            pod_target_by_project_map[@coconut_osx_pod_target].targets.find { |t| t.name == 'CoconutLib-macOS' }.dependencies.map(&:name).should.be.empty
            pod_target_by_project_map[@monkey_ios_pod_target].targets.find { |t| t.name == 'monkey-iOS' }.dependencies.map(&:name).should.be.empty
            pod_target_by_project_map[@monkey_osx_pod_target].targets.find { |t| t.name == 'monkey-macOS' }.dependencies.map(&:name).should.be.empty
            pod_target_by_project_map[@coconut_ios_pod_target].targets.find { |t| t.name == 'CoconutLib-iOS' }.dependencies.map(&:name).sort.should == [
              'OrangeFramework',
            ]
            pods_project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.dependencies.map(&:name).sort.should == [
              'BananaLib-iOS',
              'CoconutLib-iOS',
              'OrangeFramework',
              'WatermelonLib-iOS',
              'monkey-iOS',
            ]
            pods_project.targets.find { |t| t.name == 'Pods-SampleApp-macOS' }.dependencies.map(&:name).sort.should == [
              'BananaLib-macOS',
              'CoconutLib-macOS',
              'WatermelonLib-macOS',
              'monkey-macOS',
            ]
          end

          it 'adds no system frameworks to static targets' do
            pod_generator_result = @multi_project_generator.generate!
            pod_target_by_project_map = pod_generator_result.pod_target_by_project_map
            pod_target_by_project_map[@orangeframework_pod_target].targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == []
          end

          it 'adds system frameworks to dynamic targets' do
            @orangeframework_pod_target.stubs(:requires_frameworks? => true)
            pod_generator_result = @multi_project_generator.generate!
            pod_generator_result.pod_target_by_project_map[@orangeframework_pod_target].targets.find { |t| t.name == 'OrangeFramework' }.frameworks_build_phase.file_display_names.should == %w(
              Foundation.framework
              UIKit.framework
            )
          end

          it 'adds target dependencies when inheriting search paths' do
            inherited_target_definition = fixture_target_definition('SampleApp-iOS-Tests', @ios_platform)
            inherited_target = fixture_aggregate_target([], false,
                                                        @ios_target.user_build_configurations, [],
                                                        @ios_target.platform, inherited_target_definition)
            inherited_target.search_paths_aggregate_targets << @ios_target
            @multi_project_generator.aggregate_targets << inherited_target
            pod_generator_result = @multi_project_generator.generate!
            pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS-Tests' }.dependencies.map(&:name).sort.should == [
              'Pods-SampleApp-iOS',
            ]
          end

          it 'sets resource bundle target dependencies' do
            @banana_spec.resource_bundles = { 'BananaLibResourcesBundle' => '**/*' }
            pod_generator_result = @multi_project_generator.generate!
            banana_ios_project = pod_generator_result.pod_target_by_project_map[@banana_ios_pod_target]
            banana_osx_project = pod_generator_result.pod_target_by_project_map[@banana_osx_pod_target]
            banana_ios_project.targets.find { |t| t.name == 'BananaLib-iOS-BananaLibResourcesBundle' }.should.not.be.nil
            banana_osx_project.targets.find { |t| t.name == 'BananaLib-macOS-BananaLibResourcesBundle' }.should.not.be.nil
            banana_ios_project.targets.find { |t| t.name == 'BananaLib-iOS' }.dependencies.map(&:name).should == [
              'BananaLib-iOS-BananaLibResourcesBundle',
            ]
            banana_osx_project.targets.find { |t| t.name == 'BananaLib-macOS' }.dependencies.map(&:name).should == [
              'BananaLib-macOS-BananaLibResourcesBundle',
            ]
          end

          it 'sets test resource bundle dependencies' do
            @coconut_test_spec.resource_bundles = { 'CoconutLibTestResourcesBundle' => '**/*' }
            pod_generator_result = @multi_project_generator.generate!
            coconut_ios_project = pod_generator_result.pod_target_by_project_map[@coconut_ios_pod_target]
            coconut_osx_project = pod_generator_result.pod_target_by_project_map[@coconut_osx_pod_target]
            coconut_ios_project.targets.find { |t| t.name == 'CoconutLib-iOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            coconut_osx_project.targets.find { |t| t.name == 'CoconutLib-macOS-CoconutLibTestResourcesBundle' }.should.not.be.nil
            coconut_ios_project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-iOS',
              'CoconutLib-iOS-CoconutLibTestResourcesBundle',
            ]
            coconut_osx_project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'CoconutLib-macOS',
              'CoconutLib-macOS-CoconutLibTestResourcesBundle',
            ]
          end

          it 'sets the app host dependency for the tests that need it' do
            @coconut_test_spec.ios.requires_app_host = true
            pod_generator_result = @multi_project_generator.generate!
            coconut_ios_project = pod_generator_result.pod_target_by_project_map[@coconut_ios_pod_target]
            coconut_osx_project = pod_generator_result.pod_target_by_project_map[@coconut_osx_pod_target]
            coconut_ios_project.targets.find { |t| t.name == 'AppHost-CoconutLib-iOS-Unit-Tests' }.should.not.be.nil
            coconut_ios_project.targets.find { |t| t.name == 'CoconutLib-iOS-Unit-Tests' }.dependencies.map(&:name).sort.should == [
              'AppHost-CoconutLib-iOS-Unit-Tests',
              'CoconutLib-iOS',
            ]
            coconut_osx_project.targets.find { |t| t.name == 'AppHost-CoconutLib-macOS-Unit-Tests' }.should.be.nil
            coconut_osx_project.targets.find { |t| t.name == 'CoconutLib-macOS-Unit-Tests' }.dependencies.map(&:name).should == [
              'CoconutLib-macOS',
            ]
          end

          it 'adds framework file references for framework pod targets that require building' do
            @orangeframework_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:should_build?).returns(true)
            pod_generator_result = @multi_project_generator.generate!
            coconut_ios_project = pod_generator_result.pod_target_by_project_map[@coconut_ios_pod_target]
            native_target = coconut_ios_project.targets.find { |t| t.name == 'CoconutLib-iOS' }
            native_target.isa.should == 'PBXNativeTarget'
            native_target.frameworks_build_phase.file_display_names.sort.should == [
              'Foundation.framework',
              'OrangeFramework.framework',
            ]
          end

          it 'does not add framework references for framework pod targets that do not require building' do
            @orangeframework_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:requires_frameworks?).returns(true)
            @coconut_ios_pod_target.stubs(:should_build?).returns(false)
            pod_generator_result = @multi_project_generator.generate!
            coconut_ios_project = pod_generator_result.pod_target_by_project_map[@coconut_ios_pod_target]
            coconut_ios_project.targets.find { |t| t.name == 'CoconutLib-iOS' }.isa.should == 'PBXAggregateTarget'
          end

          it 'creates and links app host with an iOS test native target' do
            pod_generator_result = @multi_project_generator.generate!
            watermelon_ios_project = pod_generator_result.pod_target_by_project_map[@watermelon_ios_pod_target]
            app_host_target = watermelon_ios_project.targets.find { |t| t.name == 'AppHost-WatermelonLib-iOS-Unit-Tests' }
            app_host_target.name.should.not.be.nil
            app_host_target.symbol_type.should == :application
            test_native_target = watermelon_ios_project.targets.find { |t| t.name == 'WatermelonLib-iOS-Unit-SnapshotTests' }
            test_native_target.should.not.be.nil
            test_native_target.build_configurations.each do |bc|
              bc.build_settings['TEST_HOST'].should == '$(BUILT_PRODUCTS_DIR)/AppHost-WatermelonLib-iOS-Unit-Tests.app/AppHost-WatermelonLib-iOS-Unit-Tests'
            end
            watermelon_ios_project.root_object.attributes['TargetAttributes'][test_native_target.uuid.to_s].should == {
              'TestTargetID' => app_host_target.uuid.to_s,
            }
          end

          it 'creates and links app host with an OSX test native target' do
            pod_generator_result = @multi_project_generator.generate!
            watermelon_osx_project = pod_generator_result.pod_target_by_project_map[@watermelon_osx_pod_target]
            app_host_target = watermelon_osx_project.targets.find { |t| t.name == 'AppHost-WatermelonLib-macOS-Unit-Tests' }
            app_host_target.name.should.not.be.nil
            app_host_target.symbol_type.should == :application
            test_native_target = watermelon_osx_project.targets.find { |t| t.name == 'WatermelonLib-macOS-Unit-SnapshotTests' }
            test_native_target.should.not.be.nil
            test_native_target.build_configurations.each do |bc|
              bc.build_settings['TEST_HOST'].should == '$(BUILT_PRODUCTS_DIR)/AppHost-WatermelonLib-macOS-Unit-Tests.app/Contents/MacOS/AppHost-WatermelonLib-macOS-Unit-Tests'
            end
            watermelon_osx_project.root_object.attributes['TargetAttributes'][test_native_target.uuid.to_s].should == {
              'TestTargetID' => app_host_target.uuid.to_s,
            }
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for pod targets of an aggregate target' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :app_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            pod_generator_result = @multi_project_generator.generate!
            pod_target_by_project_map = pod_generator_result.pod_target_by_project_map
            pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.dependencies.each do |dependency|
              project_dependency_key = pod_target_by_project_map.keys.select { |target| target.label == dependency.name }.first
              build_settings = pod_target_by_project_map[project_dependency_key].targets.find { |t| t.name == dependency.name }.build_configurations.map(&:build_settings)
              build_settings.each do |build_setting|
                build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
              end
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for app extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :app_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            pod_generator_result = @multi_project_generator.generate!
            build_settings = pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for watch2 extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :watch2_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            pod_generator_result = @multi_project_generator.generate!
            build_settings = pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for tvOS extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :tv_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            pod_generator_result = @multi_project_generator.generate!
            build_settings = pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for Messages extension targets' do
            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :messages_extension)
            @ios_target.stubs(:user_targets).returns([user_target])
            pod_generator_result = @multi_project_generator.generate!
            build_settings = pod_generator_result.project.targets.find { |t| t.name == 'Pods-SampleApp-iOS' }.build_configurations.map(&:build_settings)
            build_settings.each do |build_setting|
              build_setting['APPLICATION_EXTENSION_API_ONLY'].should == 'YES'
            end
          end

          it "uses the user project's object version for the all projects" do
            tmp_directory = Pathname(Dir.tmpdir) + 'CocoaPods'
            FileUtils.mkdir_p(tmp_directory)
            proj = Xcodeproj::Project.new(tmp_directory + 'Yolo.xcodeproj', false, 1)
            proj.save

            user_target = stub('SampleApp-iOS-User-Target', :symbol_type => :application)
            user_target.expects(:common_resolved_build_setting).with('APPLICATION_EXTENSION_API_ONLY').returns('NO')

            target = AggregateTarget.new(config.sandbox, false,
                                         { 'App Store' => :release, 'Debug' => :debug, 'Release' => :release, 'Test' => :debug },
                                         [], Platform.new(:ios, '6.0'), fixture_target_definition,
                                         config.sandbox.root.dirname, proj, nil, {})

            target.stubs(:user_targets).returns([user_target])

            @multi_project_generator = SinglePodsProjectGenerator.new(config.sandbox, [target], [],
                                                  @analysis_result, @installation_options, config)
            pod_generator_result = @multi_project_generator.generate!
            pod_generator_result.project.object_version.should == '1'
            pod_generator_result.pod_target_by_project_map.values.each do |target_project|
              target_project.object_version.should == '1'
            end

            FileUtils.rm_rf(tmp_directory)
          end

          describe '#write' do
            it 'recursively sorts the project' do
              pod_generator_result = @multi_project_generator.generate!
              pods_project = pod_generator_result.project
              pods_project.main_group.expects(:sort)
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              Xcode::PodsProjectWriter.new(@multi_project_generator.sandbox, pods_project,
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @multi_project_generator.installation_options).write!
              pod_generator_result.pod_target_by_project_map.values.each do |target_project|
                target_project.main_group.expects(:sort)
                Xcode::PodsProjectWriter.new(@multi_project_generator.sandbox, target_project,
                                             pod_generator_result.target_installation_results.pod_target_installation_results,
                                             @multi_project_generator.installation_options).write!
              end
            end

            it 'saves the project' do
              pod_generator_result = @multi_project_generator.generate!
              Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
              pod_generator_result.project.expects(:save)
              Xcode::PodsProjectWriter.new(@multi_project_generator.sandbox, pod_generator_result.project,
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @multi_project_generator.installation_options).write!
              pod_generator_result.pod_target_by_project_map.values.each do |target_project|
                target_project.expects(:sort)
                Xcode::PodsProjectWriter.new(@multi_project_generator.sandbox, target_project,
                                             pod_generator_result.target_installation_results.pod_target_installation_results,
                                             @multi_project_generator.installation_options).write!
              end
            end

            it 'project cleans up empty groups' do
              pod_generator_result = @multi_project_generator.generate!
              pods_project = pod_generator_result.project
              pod_target_by_project_map = pod_generator_result.pod_target_by_project_map
              Xcode::PodsProjectWriter.new(@multi_project_generator.sandbox, pods_project,
                                           pod_generator_result.target_installation_results.pod_target_installation_results,
                                           @multi_project_generator.installation_options).write!
              pods_project.main_group['Pods'].should.be.nil
              pods_project.main_group['Development Pods'].should.be.nil
              pods_project.main_group['Dependencies'].should.be.nil

              pod_target_by_project_map.values.each do |target_project|
                Xcode::PodsProjectWriter.new(@multi_project_generator.sandbox, pods_project,
                                             pod_generator_result.target_installation_results.pod_target_installation_results,
                                             @multi_project_generator.installation_options).write!
                pods_project.main_group['Pods'].should.be.nil
                pods_project.main_group['Development Pods'].should.be.nil
                pods_project.main_group['Dependencies'].should.be.nil
              end


            end
          end

          describe '#share_development_pod_schemes' do
            it 'does not share by default' do
              Xcodeproj::XCScheme.expects(:share_scheme).never
              @multi_project_generator.share_development_pod_schemes(nil, [])
            end

            it 'can share all schemes' do
              @multi_project_generator.installation_options.
                  stubs(:share_schemes_for_development_pods).
                  returns(true)

              pod_generator_result = @multi_project_generator.generate!
              @multi_project_generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

              banana_ios_project = pod_generator_result.pod_target_by_project_map[@banana_ios_pod_target]
              banana_osx_project = pod_generator_result.pod_target_by_project_map[@banana_osx_pod_target]

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                  banana_ios_project.path,
                  'BananaLib-iOS')

              Xcodeproj::XCScheme.expects(:share_scheme).with(
                  banana_osx_project.path,
                  'BananaLib-macOS')


              banana_ios_development_pods = [@banana_ios_pod_target].select { |pod_target| @multi_project_generator.sandbox.local?(pod_target.pod_name) }
              banana_osx_development_pods = [@banana_osx_pod_target].select { |pod_target| @multi_project_generator.sandbox.local?(pod_target.pod_name) }
              @multi_project_generator.share_development_pod_schemes(banana_ios_project, banana_ios_development_pods)
              @multi_project_generator.share_development_pod_schemes(banana_osx_project, banana_osx_development_pods)

            end
          end

          it 'shares test schemes' do
            @multi_project_generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(true)
            @multi_project_generator.sandbox.stubs(:development_pods).returns('CoconutLib' => fixture('CoconutLib'))

            pod_generator_result = @multi_project_generator.generate!
            coconut_ios_project = pod_generator_result.pod_target_by_project_map[@coconut_ios_pod_target]
            coconut_osx_project = pod_generator_result.pod_target_by_project_map[@coconut_osx_pod_target]

            Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_ios_project.path,
                'CoconutLib-iOS')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_ios_project.path,
                'CoconutLib-iOS-Unit-Tests')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_osx_project.path,
                'CoconutLib-macOS')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
                coconut_osx_project.path,
                'CoconutLib-macOS-Unit-Tests')

            coconut_ios_development_pod_targets = [@coconut_ios_pod_target].select { |pod_target| @multi_project_generator.sandbox.local?(pod_target.pod_name) }
            coconut_osx_development_pod_targets = [@coconut_osx_pod_target].select { |pod_target| @multi_project_generator.sandbox.local?(pod_target.pod_name) }

            @multi_project_generator.share_development_pod_schemes(coconut_ios_project, coconut_ios_development_pod_targets)
            @multi_project_generator.share_development_pod_schemes(coconut_osx_project, coconut_osx_development_pod_targets)

          end

          it 'allows opting out' do
            @multi_project_generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(false)

            Xcodeproj::XCScheme.expects(:share_scheme).never
            @multi_project_generator.share_development_pod_schemes(nil, [])

            @multi_project_generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(nil)

            Xcodeproj::XCScheme.expects(:share_scheme).never
            @multi_project_generator.share_development_pod_schemes(nil, [])
          end

          it 'allows specifying strings of pods to share' do
            @multi_project_generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(%w(BananaLib))

            pod_generator_result = @multi_project_generator.generate!
            @multi_project_generator.sandbox.stubs(:development_pods).returns('BananaLib' => fixture('BananaLib'))

            banana_ios_project = pod_generator_result.pod_target_by_project_map[@banana_ios_pod_target]
            banana_osx_project = pod_generator_result.pod_target_by_project_map[@banana_ios_pod_target]

            Xcodeproj::XCScheme.expects(:share_scheme).with(
                banana_ios_project.path,
                'BananaLib-iOS')

            Xcodeproj::XCScheme.expects(:share_scheme).with(
                banana_osx_project.path,
                'BananaLib-macOS')

            banana_ios_development_pod_targets = [@banana_ios_pod_target].select { |pod_target| @multi_project_generator.sandbox.local?(pod_target.pod_name) }
            @multi_project_generator.share_development_pod_schemes(banana_ios_project, banana_ios_development_pod_targets)
            banana_osx_development_pod_targets = [@banana_osx_pod_target].select { |pod_target| @multi_project_generator.sandbox.local?(pod_target.pod_name) }
            @multi_project_generator.share_development_pod_schemes(banana_osx_project, banana_osx_development_pod_targets)

            @multi_project_generator.installation_options.
                stubs(:share_schemes_for_development_pods).
                returns(%w(orange-framework))

            orange_project = pod_generator_result.pod_target_by_project_map[@orangeframework_pod_target]
            orange_development_pod_targets = [@orangeframework_pod_target].select { |pod_target| @multi_project_generator.sandbox.local?(pod_target.pod_name) }
            Xcodeproj::XCScheme.expects(:share_scheme).never
            @multi_project_generator.share_development_pod_schemes(orange_project, orange_development_pod_targets)
          end
        end
      end
    end
  end
end
