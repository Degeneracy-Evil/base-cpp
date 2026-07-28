set_languages("c++20")
set_rundir(".")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build"})
add_requires("doctest")

local function configure_toolchain(target)
    local compiler = target:tool("cxx")
    if compiler and compiler:find("clang", 1, true) then
        target:add("cxxflags", "-stdlib=libc++", {force = true})
        target:add("ldflags", "-stdlib=libc++", "-fuse-ld=lld", "-rtlib=compiler-rt",
                   "-unwindlib=libunwind", {force = true})
    end
end

target("app")
    set_kind("binary")
    add_files("src/**.cpp")
    add_includedirs("include")
    add_cxxflags("-Wall", "-Wextra", "-Werror", {force = true})

    on_config(function (target)
        configure_toolchain(target)
    end)

    on_load(function (target)
        if os.isdir(".githooks") and os.isdir(".git") then
            local configured = try { function() os.runv("git", {"config", "core.hooksPath"}); return true end }
            if not configured then
                os.runv("git", {"config", "core.hooksPath", ".githooks"})
            end
        end
    end)

target("unit_tests")
    set_kind("binary")
    set_default(false)
    add_files("tests/test_main.cpp", "tests/unit/**.cpp")
    add_includedirs("include")
    add_packages("doctest")
    add_cxxflags("-Wall", "-Wextra", "-Werror", "-UNDEBUG", {force = true})

    on_config(function (target)
        configure_toolchain(target)
    end)

task("test")
    set_category("plugin")
    on_run(function ()
        os.execv("xmake", {"run", "unit_tests"})
        os.execv("bash", {"utils/tests/test_quality_scripts.sh"})
    end)
    set_menu {
        usage = "xmake test",
        description = "Run unit tests and quality script integration tests",
        options = {}
    }
