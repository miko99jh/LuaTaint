"""A generic framework adaptor that leaves luci entry criteria to the caller."""

from lua_parser import ast
import logging

from cfg import make_cfg
from core.ast_helper import Arguments
from core.module_definitions import project_definitions
from core.node_types import (
    AssignmentNode,
    TaintedNode
)
from web_frameworks.framework_helper import (
    gen_entry_call_list
)

log = logging.getLogger(__name__)


class FrameworkAdaptor():
    """An engine that uses the template pattern to find all
    entry points in a framework and then taints their arguments.
    """

    def __init__(
        self,
        cfg_list,
        project_modules,
        local_modules,
        is_entry_call_function
    ):
        self.cfg_list = cfg_list
        self.project_modules = project_modules
        self.local_modules = local_modules
        self.is_entry_call_function = is_entry_call_function
        self.run()

    def get_func_cfg_with_tainted_args(self, definition):
        """Build a function cfg and return it, with all arguments tainted."""
        log.debug("Getting CFG for %s", definition.name)
        func_cfg = make_cfg(
            definition.node,
            self.project_modules,
            self.local_modules,
            definition.path,
            definition.module_definitions
        )

        args = Arguments(definition.node.args)
        if args:
            function_entry_node = func_cfg.nodes[0]
            function_entry_node.outgoing = list()
            first_node_after_args = func_cfg.nodes[1]
            first_node_after_args.ingoing = list()

            # We are just going to give all the tainted args the lineno of the def
            definition_line = definition.node.line

            # Taint all the arguments
            for i, arg in enumerate(args):
                node_type = TaintedNode
                '''if i == 0 and arg == 'self':
                    node_type = AssignmentNode'''

                arg_node = node_type(
                    label=arg,
                    left_hand_side=arg,
                    ast_node=None,
                    right_hand_side_variables=[],
                    line_number=definition_line,
                    path=definition.path
                )
                function_entry_node.connect(arg_node)
                # 1 and not 0 so that Entry Node remains first in the list
                func_cfg.nodes.insert(1, arg_node)
                arg_node.connect(first_node_after_args)

        return func_cfg

    def find_entry_functions_taint_args(self):
        """Find all entry functions and taint all of their arguments.

        Yields:
            CFG of each entry function, with args marked as tainted.
        """
        '''call_list1 = []
        for definition in _get_func_nodes():
            call_list = gen_entry_call_list(definition.node)
            if call_list != []:
                call_list1.extend(call_list)'''
        for definition in _get_func_nodes():
            if self.is_entry_call_function(definition.node):
                yield self.get_func_cfg_with_tainted_args(definition)

    def run(self):
        """Run find_route_functions_taint_args on each CFG."""
        function_cfgs = list()
        for _ in self.cfg_list:
            function_cfgs.extend(self.find_entry_functions_taint_args())
        self.cfg_list.extend(function_cfgs)


def _get_func_nodes():
    """Get all function nodes."""
    return [definition for definition in project_definitions.values()
            if isinstance(definition.node, (ast.Function,ast.LocalFunction))]
