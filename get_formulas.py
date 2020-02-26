#!/usr/bin/env python
from contrib import dag
import sys, os, re, argparse, subprocess, platform
from conda_build.metadata import MetaData

def getModified(args):
    """
    return a path to meta.yaml for anything in that recipe directory as being modified.
    """
    git_process = subprocess.Popen(['git', 'diff', '--name-only', 'master'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    file_list = git_process.communicate()[0].decode('utf-8').split()
    formula_files = set([])
    for f_file in file_list:
        if f_file.split(os.path.sep)[0] == 'recipes' and os.path.exists(f_file):
            formula_files.add(os.path.join(*f_file.split(os.path.sep)[:2], 'recipe', 'meta.yaml'))
    return formula_files

def buildDAG(args, modified_files, formula_dir):
    oDag = dag.DAG()
    dMap = {}
    common_names = set([])
    for directory, d_list, f_list in os.walk(formula_dir):
        if 'meta.yaml' in f_list:
            meta = MetaData(os.path.join(directory, 'meta.yaml'))
            reqs = meta.meta['requirements']
            combined_deps = set(reqs.get('build', '')).union(reqs.get('run', ''))
            common_names.add(meta.name())
            dMap[meta.meta_path] = (meta.name(), combined_deps, meta)

    # Populate DAG
    [oDag.add_node(x) for x in dMap.keys()]

    # Create edges
    for ind_node, name, dependencies, meta, dag_node in _walkMapAndDag(dMap, oDag):
        controlled_dependencies = set(dependencies).intersection(common_names)
        if dMap[dag_node][0] in controlled_dependencies:
            oDag.add_edge(dag_node, ind_node)

    # Remove edges (skips, unmodified recipes, etc)
    for ind_node, name, dependencies, meta, dag_node in _walkMapAndDag(dMap, oDag):
        controlled_dependencies = set(dependencies).intersection(common_names)
        if ind_node not in modified_files and controlled_dependencies and args.dependencies:
            continue
        elif ind_node not in modified_files:
            oDag.delete_node_if_exists(ind_node)

    return oDag

def _walkMapAndDag(dict, dag):
    cloned = dag.clone()
    for key, values in dict.items():
        (common_name, dependencies, meta) = values
        for node in cloned.topological_sort():
            yield (key, common_name, dependencies, meta, node)

def verifyArgs(args):
    return args

def parseArguments(args=None):
    parser = argparse.ArgumentParser(description='Conda Recipe Dependency Generator',
                                     epilog='Prints recipes with changes, in the order that they need to be built, in relation to the master branch.')
    parser.add_argument('-d', '--dependencies', action='store_const', const=True, default=False, help='Prints all recipes requiring review, or modification for a proper dependency chain build. This should be used to give the user an idea on what recipes they should, at the very least, look over and identify if that dependency needs modification.')
    parser.add_argument('-r', '--reverse', action='store_const', const=True, default=False, help='Reverse dependency order')
    return verifyArgs(parser.parse_args(args))

if __name__ == '__main__':
    args = parseArguments()
    my_arch = re.findall(r'\w+', platform.platform())[0].lower()
    if my_arch in ['darwin', 'macos']:
        args.arch = 'osx'
    else:
        args.arch = my_arch
    modified_files = getModified(args)
    job_order = buildDAG(args, modified_files, 'recipes')
    if job_order.topological_sort():
        if args.reverse:
            job_order = job_order.reverse_clone()
        if args.dependencies:
            print(' '.join(['recipes/' + x.split(os.path.sep)[1] for x in job_order.topological_sort()]))
            sys.exit(0)
        if modified_files:
            print(' '.join(['recipes/' + x.split(os.path.sep)[1] for x in job_order.topological_sort()]))
