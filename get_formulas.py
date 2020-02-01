#!/usr/bin/env python
from contrib import dag
import sys, os, re, argparse, subprocess, platform

# Remove what has not been updated
def getModified(args):
    git_process = subprocess.Popen(['git', 'diff', '--name-only', 'master'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    file_list = git_process.communicate()[0].decode('utf-8').split()
    formula_files = set([])
    for f_file in file_list:
        if f_file.split(os.path.sep)[0] == 'recipes' and os.path.exists(f_file):
            formula_files.add(os.path.join(*f_file.split(os.path.sep)[:2], 'recipe'))
    return formula_files

# Search for and add a node for every formula found in formula_dir that works with bottles
def buildDAG(args, modified_files, formula_dir):
    formula_dag = dag.DAG()
    for directory, d_list, f_list in os.walk(formula_dir):
        if 'meta.yaml' in f_list:
            formula_dag.add_node(os.path.join(directory))
    return buildEdges(args, modified_files, formula_dir, formula_dag)

# Figure out what package depends on what other package
def buildEdges(args, modified_files, formula_dir, dag_object):
    dependency_set = re.compile(r'-\s((?!\S*\.)\S*)')
    skip_set = re.compile(r'^\s+skip:\s+(\w+).*\[(.*)\]', re.MULTILINE)
    recipe_dict = {}
    recipe_map = {}
    skip_map = {}
    for node in dag_object.topological_sort():
        with open(os.path.join(node, 'meta.yaml'), 'r') as f:
            content = f.read()
            logic = skip_set.findall(content)[0]
            if 'not' in logic[1].lower():
                if logic[0].lower() == 'true' and args.arch not in logic[1]:
                    skip_map[node.split(os.path.sep)[1]] = node
            else:
                if logic[0].lower() == 'true' and args.arch in logic[1]:
                    skip_map[node.split(os.path.sep)[1]] = node

        recipe_dict[node.split(os.path.sep)[1]] = set(dependency_set.findall(content))
        recipe_map[node.split(os.path.sep)[1]] = node

    # Delete the recipes which will be skipped
    for skip, v in skip_map.items():
        del recipe_dict[skip]
        dag_object.delete_node_if_exists(recipe_map[skip])

    # Build edges (dependencies)
    for key, deps in recipe_dict.items():
        for dep in deps:
            if dep in recipe_dict.keys():
                dag_object.add_edge(recipe_map[dep], recipe_map[key])

    # Populate build_set with recipes that have changed in the repository
    build_set = set([])
    for modified_file in modified_files:
        build_set.add(modified_file)
        # Add recipes this recipe depends on, if requested (--dependencies)
        if args.dependencies:
            build_set = build_set.union(set(dag_object.all_downstreams(modified_file)))

    # Remove any recipes not in build_set
    cloned = dag_object.clone()
    for node in cloned.topological_sort():
        if node not in build_set:
            dag_object.delete_node(node)

    return dag_object

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
    if my_arch == 'darwin':
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
