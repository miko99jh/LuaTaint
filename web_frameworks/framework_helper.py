"""Provides helper functions that help with determining if a function is a route function."""
from lua_parser import ast

def is_django_view_function(ast_node):
    if len(ast_node.args.args):
        first_arg_name = ast_node.args.args[0].arg
        return first_arg_name == 'request'
    return False


def gen_entry_call_list(ast_node):
    call_list = []
    if isinstance(ast_node.name, ast.Name) and ast_node.name.id == 'index':
        for node in ast.walk(ast_node):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "entry":
                for n in ast.walk(node):
                    if isinstance(n, ast.Call) and n.func.id == "call":
                        call_list.append(n.args[0].s)
                    if isinstance(n, ast.Call) and n.func.id == "post":
                        call_list.append(n.args[0].s)
    return call_list

def is_luci_route_function(ast_node):
    return True
    """Check whether function uses a route function."""
    '''if call_list != None:
        if isinstance(ast_node.name, ast.Name) and ast_node.name.id in call_list:
            return True
    return False'''


def is_function(function):
    """Always returns true because arg is always a function."""
    return True


def is_function_without_leading_(ast_node):
    if ast_node.name.startswith('_'):
        return False
    return True

