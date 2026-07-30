set_languages("c++20")
set_rundir(".")
set_version("0.1.0")
set_toolchains("clang", "gcc")
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build"})
add_requires("doctest 2.4.12")

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
        if os.isdir(".githooks") and (os.isdir(".git") or os.isfile(".git")) then
            local configured = try { function() os.execv("git", {"config", "core.hooksPath"}); return true end }
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
    end)
    set_menu {
        usage = "xmake test",
        description = "Run unit tests",
        options = {}
    }

task("check")
    set_category("plugin")
    on_run(function ()
        local fmt_cmd = "find include src tests -type f \\( -name '*.h' -o -name '*.hpp' -o -name '*.c' -o -name '*.cpp' \\) -print0 2>/dev/null | xargs -0 clang-format -i"
        local tidy_cmd = "find src tests -type f \\( -name '*.c' -o -name '*.cpp' \\) -print0 2>/dev/null | xargs -0 clang-tidy -p=build"
        local ver_cmd = "hpp=$(awk '/^#define PROJECT_VERSION_MAJOR/{m=$3} /^#define PROJECT_VERSION_MINOR/{n=$3} /^#define PROJECT_VERSION_PATCH/{p=$3} END{print m\".\"n\".\"p}' include/version.hpp) && xmake_ver=$(xmake show --json | python3 -c \"import sys,json; print(json.load(sys.stdin)['project']['version'])\") && test \"$hpp\" = \"$xmake_ver\" || { echo \"version mismatch: version.hpp=$hpp xmake.lua=$xmake_ver\" >&2; exit 1; }"

        print("[1/5] version consistency...")
        os.execv("bash", {"-c", ver_cmd})

        print("[2/5] clang-format...")
        os.execv("bash", {"-c", fmt_cmd})

        print("[3/5] clang-tidy...")
        os.execv("xmake", {"project", "-k", "compile_commands", "build"})
        os.execv("bash", {"-c", tidy_cmd})

        print("[4/5] rebuild...")
        os.execv("xmake", {"-r"})

        print("[5/5] test...")
        os.execv("xmake", {"test"})

        print("\nAll checks passed.")
    end)
    set_menu {
        usage = "xmake check",
        description = "Full quality check: version + format + tidy + rebuild + test",
        options = {}
    }
