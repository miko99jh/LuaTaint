"""Contains a class that finds all names.
Used to find all variables on a right hand side(RHS) of assignment.
"""
from lua_parser import ast


class RHSVisitor(ast.NodeVisitor):
    """Visitor collecting all names."""

    def __init__(self):
        """Initialize result as list."""
        self.result = list()

    def visit_Name(self, node):
        self.result.append(node.id)

    def visit_Call(self, node):
        if node.args:
            for arg in node.args:
                self.visit(arg)
        '''if node.keywords:
            for keyword in node.keywords:
                self.visit(keyword)'''

    def visit_Invoke(self, node):
        if node.args:
            for arg in node.args:
                self.visit(arg)

    def visit_If(self, node):
        # The test doesn't taint the assignment
        self.visit(node.body)
        if node.orelse:
            self.visit(node.orelse)

    @classmethod
    def result_for_node(cls, node):
        visitor = cls()
        visitor.visit(node)
        return visitor.result
