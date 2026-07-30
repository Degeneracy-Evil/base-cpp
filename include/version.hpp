#pragma once

#define PROJECT_VERSION_MAJOR 0
#define PROJECT_VERSION_MINOR 1
#define PROJECT_VERSION_PATCH 0

// Stringified version — computed from components, change only the three numbers above
#define PROJECT_VERSION_STRING_IMPL(major, minor, patch) #major "." #minor "." #patch
#define PROJECT_VERSION_STRING(major, minor, patch) PROJECT_VERSION_STRING_IMPL(major, minor, patch)
#define PROJECT_VERSION                                                                            \
    PROJECT_VERSION_STRING(PROJECT_VERSION_MAJOR, PROJECT_VERSION_MINOR, PROJECT_VERSION_PATCH)
