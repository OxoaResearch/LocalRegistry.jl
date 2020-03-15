using LocalRegistry
using Test
using Random
using Pkg

include("utils.jl")

# The following tests are primarily regression tests - checking that
# the results are the same as when the tests were written, regardless
# of correctness.
#
# The general strategy is that a number of project files have been
# stored. These are read and expanded to minimal stub packages, which
# are then registered in a newly created registry. The resulting
# registries after some selections of packages have been added have
# also been stored and are compared against.
#
# The project files have been extracted from the git history of the
# Flux and Images packages. The patch numbers have been faked to get
# more version samples out of their git histories. The FirstTest1
# project file is derived from this package.

# Set up packages and registry directories in a temporary location.
if VERSION >= v"1.2"
    testdir = mktempdir(prefix = "LocalRegistryTests")
else
    testdir = mktempdir()
end
packages_dir = joinpath(testdir, "packages")
if packages_dir ∉ LOAD_PATH
    push!(LOAD_PATH, packages_dir)
end
registry_dir = joinpath(testdir, "TestRegistry")

# Create a new registry.
create_registry(registry_dir, "git@example.com:Julia/TestRegistry.git",
                description = "For testing purposes only.",
                uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369")

# Add the FirstTest1 package and check against the stored `registry1`.
prepare_package(packages_dir, "FirstTest1.toml")
using FirstTest
register(FirstTest, registry_dir)
@test check_result(registry_dir, "registry1")

# Reregister the same version of FirstTest to verify that nothing
# happens,
@test_logs (:info, "This version has already been registered and is unchanged.") register(FirstTest, registry_dir)
@test check_result(registry_dir, "registry1")

# Add 29 versions of the Flux project files and check against `registry2`.
for n = 1:29
    prepare_package(packages_dir, "Flux$(n).toml")
    using Flux
    register(Flux, registry_dir)
end
@test check_result(registry_dir, "registry2")

# Add 15 versions of the Images project files and check against `registry3`.
for n = 1:15
    prepare_package(packages_dir, "Images$(n).toml")
    using Images
    register(Images, registry_dir)
end
@test check_result(registry_dir, "registry3")

# Start over with a fresh registry and add all 46 project files but in
# shuffled order. Check that this also matches `registry3`.
registry_dir = joinpath(testdir, "test2", "TestRegistry")
create_registry(registry_dir, "git@example.com:Julia/TestRegistry.git",
                description = "For testing purposes only.",
                uuid = "ed6ca2f6-392d-11ea-3224-d3daf7fee369")
project_files = vcat("FirstTest1.toml",
                     ["Flux$(n).toml" for n = 1:29],
                     ["Images$(n).toml" for n = 1:15])
Random.seed!(13)
shuffle!(project_files)
for project_file in project_files
    prepare_package(packages_dir, project_file)
    package = match(r"[a-zA-Z]+", project_file).match
    # Register by path instead of module in this test.
    register(joinpath(packages_dir, package), registry_dir)
end
@test check_result(registry_dir, "registry3")

# Trying to register an already existing version with different content.
prepare_package(packages_dir, "Flux30.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                     registry_dir)

# Parse error in compat section.
prepare_package(packages_dir, "Broken1.toml")
@test_throws Pkg.Types.PkgError register(joinpath(packages_dir, "Broken"),
                                         registry_dir)

# Trying to change name (UUID remains).
prepare_package(packages_dir, "Fluxx1.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Fluxx"),
                                     registry_dir)

# Trying to change UUID.
prepare_package(packages_dir, "Flux31.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Flux"),
                                     registry_dir)

# Depends on itself.
prepare_package(packages_dir, "Broken2.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry_dir)

# Incorrect name of dependency.
prepare_package(packages_dir, "Broken3.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry_dir)

# TODO: This should really be an error but RegistryTools 1.3.0 doesn't catch it.
# Incorrect UUID of dependency.
prepare_package(packages_dir, "Broken4.toml")
register(joinpath(packages_dir, "Broken"), registry_dir)

# Incorrect UUID of stdlib.
prepare_package(packages_dir, "Broken5.toml")
@test_throws ErrorException register(joinpath(packages_dir, "Broken"),
                                     registry_dir)

pop!(LOAD_PATH)
