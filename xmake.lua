set_project("base-cpp")
set_version("0.1.0")
set_languages("c++23")
set_rundir(".")
if not get_config("toolchain") then
    set_toolchains("clang")
end
add_rules("plugin.compile_commands.autoupdate", {outputdir = "build"})
add_requires("doctest 2.4.12")

local function cpp_files()
    local files = {}
    local patterns = {
        "include/**.h",
        "include/**.hpp",
        "include/**.cpp",
        "src/**.h",
        "src/**.hpp",
        "src/**.cpp",
        "tests/**.h",
        "tests/**.hpp",
        "tests/**.cpp"
    }
    for _, pattern in ipairs(patterns) do
        for _, file in ipairs(os.files(pattern)) do
            table.insert(files, file)
        end
    end
    table.sort(files)
    return files
end

local function translation_units()
    local files = {}
    for _, pattern in ipairs({"src/**.cpp", "tests/**.cpp"}) do
        for _, file in ipairs(os.files(pattern)) do
            table.insert(files, file)
        end
    end
    table.sort(files)
    return files
end

target("app")
    set_kind("binary")
    add_files("src/**.cpp")
    add_includedirs("include")
    add_cxxflags("-Wall", "-Wextra", "-Werror", "-Wpedantic", {force = true})

target("unit_tests")
    set_kind("binary")
    set_default(false)
    add_files("tests/test_main.cpp", "tests/unit/**.cpp")
    add_includedirs("include")
    add_packages("doctest")
    add_cxxflags("-Wall", "-Wextra", "-Werror", "-Wpedantic", "-UNDEBUG", {force = true})

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

task("format")
    set_category("plugin")
    on_run(function ()
        for _, file in ipairs(cpp_files()) do
            os.execv("clang-format", {"-i", file})
        end
    end)
    set_menu {
        usage = "xmake format",
        description = "Format managed C/C++ files in place",
        options = {}
    }

task("check")
    set_category("plugin")
    on_run(function ()
        print("[1/5] clang-format check...")
        for _, file in ipairs(cpp_files()) do
            os.execv("clang-format", {"--dry-run", "--Werror", file})
        end

        print("[2/5] compilation database...")
        os.execv("xmake", {"project", "-k", "compile_commands", "build"})

        print("[3/5] clang-tidy...")
        for _, file in ipairs(translation_units()) do
            os.execv("clang-tidy", {"-p=build", file})
        end

        print("[4/5] rebuild...")
        os.execv("xmake", {"-r"})

        print("[5/5] test...")
        os.execv("xmake", {"test"})

        print("\nAll checks passed.")
    end)
    set_menu {
        usage = "xmake check",
        description = "Validate format, tidy, rebuild, and tests without modifying tracked files",
        options = {}
    }
