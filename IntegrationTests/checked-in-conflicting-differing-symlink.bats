#!/usr/bin/env bats

load "Utilities/git-commit"
load "Utilities/TestFramework"

extracted_directory="${BATS_TMPDIR}/DependencyTest"

project_directory() {
	if [[ -z ${CI+x} ]]; then
		echo -n "${BATS_TMPDIR:?}"
	else
		echo -n "${HOME:?}/Library/Caches/org.carthage.CarthageIntegration"
	fi

	echo -n "/IntegrationTestProject"
}

setup() {
	extract-test-frameworks-one-and-two

	export GITCONFIG='/dev/null'
	branch-test-frameworks-one-and-two 'checked-in-conflicting-differing-symlink'

	cd ${extracted_directory}/SourceRepos/TestFramework1

	mkdir -p ${PWD}/'Carthage/Checkouts'
	ln -s 'TestFramework1.xcodeproj/project.xcworkspace/' 'Carthage/Checkouts/TestFramework2'
	git-commit 'Add (for nonsensical reasons) conflicting symlink at «Carthage/Checkouts/TestFramework2».'

	mkdir -p "$(project_directory)" && cd "$(project_directory)"

	cat > Cartfile <<-EOF
		git "file://${extracted_directory}/SourceRepos/TestFramework1" "checked-in-conflicting-differing-symlink"
	EOF

	# Optionally, only if environment variable `CARTHAGE_INTEGRATION_CLEAN_DEPENDENCIES_CACHE` is manually set:
	[[ -n ${CARTHAGE_INTEGRATION_CLEAN_DEPENDENCIES_CACHE+x} ]] || rm -rf ~/Library/Caches/org.carthage.CarthageKit/dependencies/
}

teardown() {
	[[ ! -d "$(project_directory)" ]] || rm -rf "$(project_directory)"
	[[ ! -d ${extracted_directory} ]] || rm -rf ${extracted_directory}
	cd $BATS_TEST_DIRNAME
}

check-symlink() {
	if [[ -L "${1:?}" ]]; then
		readlink "${1:?}"
	else
		echo "No symlink at path «${1:?}»."
		return 1
	fi
}

carthage-and-check-project-symlink() {
	utica $@
	check-symlink "$(project_directory)/Carthage/Checkouts/TestFramework1/Carthage/Checkouts/TestFramework2"
}

@test "with conflicting checked-in symlink in «Carthage/Checkouts» of dependency, utica bootstrap should avoid writing there" {
	carthage-and-check-project-symlink bootstrap --no-build --no-use-binaries
}

@test "with conflicting checked-in symlink in «Carthage/Checkouts» of dependency, utica «bootstrap, update, update» should avoid writing there" {
	carthage-and-check-project-symlink bootstrap --no-build --no-use-binaries

	carthage-and-check-project-symlink update --no-build --no-use-binaries

	carthage-and-check-project-symlink update --no-build --no-use-binaries
}

@test "with conflicting checked-in symlink in «Carthage/Checkouts» of dependency of git-controlled project, utica bootstrap should avoid writing there" {
	echo 'Carthage/Build' > .gitignore
	git init && git-commit 'Initialize project.'

	carthage-and-check-project-symlink bootstrap --no-build --no-use-binaries
}
