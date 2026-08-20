#!/usr/bin/env python3
"""Migrate hggc-samples CMakeLists.txt from add_custom_command to cmake-hgcc.

Reads each leaf CMakeLists.txt, extracts the compilation pattern, and generates
a new cmake-hgcc-based version. Backs up originals to .bak files.

Usage:
    python3 migrate_cmake.py /path/to/hggc-samples [--dry-run]
"""

import os
import re
import sys
import shutil

def parse_cmake(filepath):
    """Extract key info from an old-style CMakeLists.txt."""
    with open(filepath) as f:
        content = f.read()

    info = {
        'project_name': '',
        'sources_hg': [],
        'sources_cpp': [],
        'libs': [],
        'include_dirs': [],
        'is_foreach': False,
        'foreach_tests': [],
        'foreach_libs': [],
        'fatbin_sources': [],
        'fatbin_names': [],
        'has_copy': False,
        'copy_files': [],
        'has_mpi': False,
    }

    m = re.search(r'project\((\S+)', content)
    if m:
        info['project_name'] = m.group(1)

    for m in re.finditer(r'(\S+\.hg)', content):
        fn = m.group(1)
        fn = re.sub(r'\$\{CMAKE_CURRENT_SOURCE_DIR\}/', '', fn)
        if fn not in info['sources_hg'] and 'fatbin' not in content.split(fn)[0][-200:].lower():
            info['sources_hg'].append(fn)

    for m in re.finditer(r'(\S+\.cpp)', content):
        fn = m.group(1)
        fn = re.sub(r'\$\{CMAKE_CURRENT_SOURCE_DIR\}/', '', fn)
        if fn not in info['sources_cpp']:
            info['sources_cpp'].append(fn)

    for m in re.finditer(r'-l\s+(\S+)', content):
        lib = m.group(1)
        if lib not in info['libs']:
            info['libs'].append(lib)
    for m in re.finditer(r'-l(\S+)', content):
        lib = m.group(1)
        if lib not in info['libs'] and lib not in ('hgrtc',):
            pass
    # re-extract -l<lib> (no space) from COMMAND lines
    for m in re.finditer(r'COMMAND.*?-l\s*(\w+)', content):
        lib = m.group(1)
        if lib not in info['libs']:
            info['libs'].append(lib)

    if 'foreach' in content:
        info['is_foreach'] = True
        m = re.search(r'foreach\(\S+\s+(.*?)\)', content, re.DOTALL)
        if m:
            tests = m.group(1).strip().split()
            info['foreach_tests'] = tests
        # extract libs from the foreach body
        for m2 in re.finditer(r'-l\s+(\w+)', content):
            lib = m2.group(1)
            if lib not in info['foreach_libs']:
                info['foreach_libs'].append(lib)

    if '-fatbin' in content or '--fatbin' in content:
        for m in re.finditer(r'COMMAND.*?-fatbin.*?(\S+\.hg)', content):
            fn = m.group(1)
            fn = re.sub(r'\$\{.*?\}/', '', fn)
            info['fatbin_sources'].append(fn)
        for m in re.finditer(r'OUTPUT\s+\$\{CMAKE_CURRENT_BINARY_DIR\}/(\S+\.fatbin)', content):
            info['fatbin_names'].append(m.group(1))

    if 'copy_if_different' in content:
        info['has_copy'] = True
        for m in re.finditer(r'copy_if_different\s+\$\{CMAKE_CURRENT_SOURCE_DIR\}/(\S+)', content):
            info['copy_files'].append(m.group(1))

    if 'MPI' in content:
        info['has_mpi'] = True

    return info

def lib_to_target(lib):
    """Map a library name to HGGC:: target or raw name."""
    mapping = {
        'hgrtc': 'HGGC::hgrtc',
        'hgvm': 'HGGC::hgvm',
        'hgJitLink': 'HGGC::hgJitLink',
        'acblas': 'HGGC::acblas',
        'acfft': 'HGGC::acfft',
        'acrand': 'HGGC::acrand',
        'acdnn': 'HGGC::acdnn',
        'acsparse': 'HGGC::acsparse',
        'acsolver': 'HGGC::acsolver',
        'pccl': 'HGGC::pccl',
    }
    return mapping.get(lib, lib)

def generate_cmake(info, dirpath, samples_root):
    """Generate new CMakeLists.txt content."""
    lines = []
    name = os.path.basename(dirpath)

    # Determine relative path to Common
    rel = os.path.relpath(os.path.join(samples_root, 'Common'), dirpath)
    common_var = '${CMAKE_CURRENT_SOURCE_DIR}/' + rel

    # Check if conformance test
    is_conformance = 'conformance_tests' in dirpath
    if is_conformance:
        test_common = '${CMAKE_CURRENT_SOURCE_DIR}/../common'

    if info['is_foreach']:
        tests = info['foreach_tests']
        libs_targets = [lib_to_target(l) for l in info['foreach_libs']]

        lines.append(f'foreach(_test {" ".join(tests)})')
        lines.append(f'  add_executable(${{_test}} ${{_test}}.hg)')
        inc_dirs = [common_var]
        if is_conformance:
            inc_dirs.append(test_common)
        lines.append(f'  target_include_directories(${{_test}} PRIVATE {" ".join(inc_dirs)})')
        if libs_targets:
            lines.append(f'  target_link_libraries(${{_test}} PRIVATE {" ".join(libs_targets)})')
        lines.append('endforeach()')
        return '\n'.join(lines) + '\n'

    # Collect all sources
    all_src = info['sources_hg'] + info['sources_cpp']
    # Remove fatbin sources from main sources
    for fs in info['fatbin_sources']:
        if fs in all_src:
            all_src.remove(fs)

    has_cpp = len(info['sources_cpp']) > 0
    needs_toolkit = has_cpp  # .cpp files need SDK includes

    # Map libraries
    libs_targets = [lib_to_target(l) for l in info['libs']]
    if needs_toolkit and 'HGGC::toolkit' not in libs_targets:
        libs_targets.insert(0, 'HGGC::toolkit')

    # Handle MPI
    if info['has_mpi']:
        lines.append('find_package(MPI)')
        lines.append('if(MPI_FOUND)')
        lines.append(f'  add_executable({name}')
        for s in all_src:
            lines.append(f'    {s}')
        lines.append('  )')
        inc = [common_var]
        if is_conformance:
            inc.append(test_common)
        inc.append('${MPI_C_INCLUDE_DIRS}')
        lines.append(f'  target_include_directories({name} PRIVATE {" ".join(inc)})')
        link_libs = libs_targets + ['${MPI_C_LIBRARIES}']
        lines.append(f'  target_link_libraries({name} PRIVATE {" ".join(link_libs)})')
        lines.append(f'else()')
        lines.append(f'  message(STATUS "MPI not found - skipping {name}")')
        lines.append(f'endif()')
        return '\n'.join(lines) + '\n'

    # Fatbin
    if info['fatbin_sources']:
        for i, fs in enumerate(info['fatbin_sources']):
            fb_name = info['fatbin_names'][i] if i < len(info['fatbin_names']) else f'{name}_fatbin'
            fb_name = fb_name.replace('.fatbin', '')
            lines.append(f'hgcc_add_fatbin({fb_name} {fs}')
            lines.append(f'  INCLUDE_DIRECTORIES {common_var})')
            lines.append('')

    # Main executable
    if all_src:
        if len(all_src) == 1:
            lines.append(f'add_executable({name} {all_src[0]})')
        else:
            lines.append(f'add_executable({name}')
            for s in all_src:
                lines.append(f'  {s}')
            lines.append(')')

        inc_dirs = [common_var]
        if is_conformance:
            inc_dirs.append(test_common)
        # Check for sub-dir includes
        for m in re.finditer(r'-I\s+\$\{CMAKE_CURRENT_SOURCE_DIR\}/(\S+)', open(os.path.join(dirpath, 'CMakeLists.txt')).read()):
            d = m.group(1)
            if d not in ('../../Common', '../../../Common', '../common'):
                inc_dirs.append('${CMAKE_CURRENT_SOURCE_DIR}/' + d)
        lines.append(f'target_include_directories({name} PRIVATE {" ".join(inc_dirs)})')

        if libs_targets:
            lines.append(f'target_link_libraries({name} PRIVATE {" ".join(libs_targets)})')

        # Fatbin dependency
        for i, fs in enumerate(info['fatbin_sources']):
            fb_name = info['fatbin_names'][i].replace('.fatbin', '') if i < len(info['fatbin_names']) else f'{name}_fatbin'
            lines.append(f'add_dependencies({name} {fb_name})')

    # Copy files
    if info['has_copy']:
        for cf in info['copy_files']:
            lines.append(f'configure_file({cf} ${{CMAKE_CURRENT_BINARY_DIR}}/{cf} COPYONLY)')

    return '\n'.join(lines) + '\n'


def migrate_file(filepath, samples_root, dry_run=False):
    """Migrate a single CMakeLists.txt."""
    dirpath = os.path.dirname(filepath)
    info = parse_cmake(filepath)

    # Skip intermediate files (only add_subdirectory)
    with open(filepath) as f:
        content = f.read()
    if 'add_custom_command' not in content and 'add_custom_target' not in content:
        return False

    new_content = generate_cmake(info, dirpath, samples_root)
    name = os.path.basename(dirpath)

    if dry_run:
        print(f"[DRY] {os.path.relpath(filepath, samples_root)}")
        print(new_content)
        print()
        return True

    # Backup
    backup = filepath + '.bak'
    if not os.path.exists(backup):
        shutil.copy2(filepath, backup)

    with open(filepath, 'w') as f:
        f.write(new_content)

    print(f"Migrated: {os.path.relpath(filepath, samples_root)}")
    return True


def migrate_toplevel(samples_root, cmake_hgcc_dir, dry_run=False):
    """Rewrite the top-level CMakeLists.txt."""
    filepath = os.path.join(samples_root, 'CMakeLists.txt')
    project_name = os.path.basename(samples_root)

    # Detect existing add_subdirectory calls to preserve them
    subdirs = []
    if os.path.exists(filepath):
        with open(filepath) as f:
            for line in f:
                m = re.match(r'\s*add_subdirectory\((\S+)\)', line)
                if m:
                    subdirs.append(m.group(1))

    if not subdirs:
        for d in sorted(os.listdir(samples_root)):
            if os.path.isdir(os.path.join(samples_root, d)) and \
               os.path.exists(os.path.join(samples_root, d, 'CMakeLists.txt')):
                subdirs.append(d)

    subdir_lines = '\n'.join(f'add_subdirectory({d})' for d in subdirs)

    new_content = f"""cmake_minimum_required(VERSION 3.20)

# Pick up cmake-hgcc modules from environment (source cmake-hgcc/envsetup.sh)
# or pass -DCMAKE_MODULE_PATH=/path/to/cmake-hgcc/cmake/Modules
if(DEFINED ENV{{CMAKE_MODULE_PATH}})
  list(APPEND CMAKE_MODULE_PATH "$ENV{{CMAKE_MODULE_PATH}}")
endif()

project({project_name} LANGUAGES CXX HG)

find_package(HGGCToolkit REQUIRED)
include(HGGCUtilities)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

{subdir_lines}
"""

    if dry_run:
        print(f"[DRY] Top-level CMakeLists.txt")
        print(new_content)
        return

    backup = filepath + '.bak'
    if not os.path.exists(backup):
        shutil.copy2(filepath, backup)

    with open(filepath, 'w') as f:
        f.write(new_content)
    print(f"Migrated: CMakeLists.txt (top-level)")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <hggc-samples-dir> [--dry-run]")
        sys.exit(1)

    samples_root = os.path.abspath(sys.argv[1])
    dry_run = '--dry-run' in sys.argv

    cmake_hgcc_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

    if not os.path.exists(os.path.join(samples_root, 'Common')):
        print(f"Error: {samples_root} does not look like hggc-samples")
        sys.exit(1)

    # Migrate top-level
    migrate_toplevel(samples_root, cmake_hgcc_dir, dry_run)

    # Migrate all leaf files
    count = 0
    for root, dirs, files in os.walk(samples_root):
        if 'build' in root:
            continue
        if 'CMakeLists.txt' in files:
            fp = os.path.join(root, 'CMakeLists.txt')
            if migrate_file(fp, samples_root, dry_run):
                count += 1

    print(f"\nMigrated {count} files {'(dry run)' if dry_run else ''}")


if __name__ == '__main__':
    main()
