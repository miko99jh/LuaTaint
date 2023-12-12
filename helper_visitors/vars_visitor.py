from lua_parser import ast
import itertools

from core.ast_helper import get_call_names


class VarsVisitor(ast.NodeVisitor):
    def __init__(self):
        self.result = list()

    def visit_Name(self, node):
        self.result.append(node.id)

    def visit_BoolOp(self, node):
        for v in node.values:
            self.visit(v)

    def visit_BinOp(self, node):
        self.visit(node.left)
        self.visit(node.right)

    def visit_UnaryOp(self, node):
        self.visit(node.operand)

    def visit_Lambda(self, node):
        self.visit(node.body)

    def visit_IfExp(self, node):
        self.visit(node.test)
        self.visit(node.body)
        self.visit(node.orelse)

    def visit_Set(self, node):
        for e in node.elts:
            self.visit(e)

    def comprehension(self, node):
        self.visit(node.target)
        self.visit(node.iter)
        for c in node.ifs:
            self.visit(c)

    def visit_ListComp(self, node):
        self.visit(node.elt)
        for gen in node.generators:
            self.comprehension(gen)

    def visit_SetComp(self, node):
        self.visit(node.elt)
        for gen in node.generators:
            self.comprehension(gen)

    def visit_GeneratorComp(self, node):
        self.visit(node.elt)
        for gen in node.generators:
            self.comprehension(gen)

    def visit_Compare(self, node):
        self.visit(node.left)
        for c in node.comparators:
            self.visit(c)

    def visit_Call(self, node):
        # This will not visit Flask in Flask(__name__) but it will visit request in `request.args.get()
        if not isinstance(node.func, ast.Name):
            self.visit(node.func)
        for arg_node in itertools.chain(node.args):
            arg = arg_node
            if isinstance(arg, (ast.Call, ast.Invoke)):
                if isinstance(arg.func, ast.Name):
                    # We can't just visit because we need to add 'ret_'
                    self.result.append('ret_' + arg.func.id)
                elif isinstance(arg.func, (ast.Call, ast.Invoke)):
                    self.visit_curried_call_inside_call_args(arg)
                elif isinstance(arg.func, ast.Index):
                    self.visit(arg)
                else:
                    raise Exception('Cannot visit vars of ' + ast.to_pretty_str(arg))
            else:
                self.visit(arg)

    def visit_Invoke(self, node):
        # This will not visit Flask in Flask(__name__) but it will visit request in `request.args.get()
        if not isinstance(node.func, ast.Name):
            self.visit(node.func)
        for arg_node in itertools.chain(node.args):
            arg = arg_node
            if isinstance(arg, (ast.Call, ast.Invoke)):
                if isinstance(arg.func, ast.Name):
                    # We can't just visit because we need to add 'ret_'
                    self.result.append('ret_' + arg.func.id)
                elif isinstance(arg.func, (ast.Call, ast.Invoke)):
                    self.visit_curried_call_inside_call_args(arg)
                elif isinstance(arg.func, ast.Index):
                    self.visit(arg)
                else:
                    raise Exception('Cannot visit vars of ' + ast.to_pretty_str(arg))
            else:
                self.visit(arg)

    def visit_curried_call_inside_call_args(self, inner_call):
        # Curried functions aren't supported really, but we now at least have a defined behaviour.
        # In f(g(a)(b)(c)), inner_call is the Call node with argument c
        # Try to get the name of curried function g
        curried_func = inner_call.func.func
        while isinstance(curried_func, ast.Call):
            curried_func = curried_func.func
        if isinstance(curried_func, ast.Name):
            self.result.append('ret_' + curried_func.id)

        # Visit all arguments except a (ignore the curried function g)
        not_curried = inner_call
        while not_curried.func is not curried_func:
            for arg in itertools.chain(not_curried.args, not_curried.keywords):
                self.visit(arg.value if isinstance(arg, ast.keyword) else arg)
            not_curried = not_curried.func
    
    def visit_Table(self, node):
        for el in node.fields:
            self.visit(el)
