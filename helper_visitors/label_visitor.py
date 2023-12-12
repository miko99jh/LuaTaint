from lua_parser import ast

class LabelVisitor(ast.NodeVisitor):
    def __init__(self):
        self.result = ''

    def handle_comma_separated(self, comma_separated_list):
        if comma_separated_list:
            for element in range(len(comma_separated_list)-1):
                self.visit(comma_separated_list[element])
                self.result += ', '

            self.visit(comma_separated_list[-1])

    def visit_Table(self, node):
        self.result += '{'

        self.handle_comma_separated(node.fields)

        self.result += '}'

    def visit_Return(self, node):
        if node.values and len(node.values)>0:
            for node_values in node.values:
                self.visit(node_values)

    def visit_FalseExpr(self, node):
        self.result += 'false'

    def visit_TrueExpr(self, node):
        self.result += 'true'

    def visit_Assign(self, node):
        for target in node.targets:
            self.visit(target)
        self.result = ' '.join((self.result, '='))
        self.insert_space()

        self.visit(node.values[0])

    def visit_LocalAssign(self, node):
        for target in node.targets:
            self.visit(target)
        if len(node.values)>0:
            self.result = ' '.join((self.result, '='))
            self.insert_space()
            self.visit(node.values[0])
    
    def visit_Index(self, node): #修改
        if isinstance(node.value, ast.Index):
            self.visit_Index(node.value)
        else:
            self.visit(node.value)
        self.result += '.'
        self.visit(node.idx)
            
    def visit_Call(self, node):
        self.visit(node.func)
        self.result += '('

        if node.args:
            self.handle_comma_separated(node.args)
        self.result += ')'
            
    def visit_Invoke(self, node):
        self.visit(node.source)
        self.result += ':'
        self.visit(node.func)
        self.result += '('

        if node.args:
            self.handle_comma_separated(node.args)
        self.result += ')'

    def insert_space(self):
        self.result += ' '

    #  operator = Add | Sub | Mult | MatMult | Div | Mod | Pow | LShift | RShift | BitOr | BitXor | BitAnd | FloorDiv
    def visit_AddOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '+'
        self.insert_space()
        self.visit(node.right)

    def visit_SubOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '-'
        self.insert_space()
        self.visit(node.right)

    def visit_MultOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '*'
        self.insert_space()
        self.visit(node.right)

    def visit_FloatDivOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '/'
        self.insert_space()
        self.visit(node.right)

    def visit_ModOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '%'
        self.insert_space()
        self.visit(node.right)

    def visit_BShiftLOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '<<'
        self.insert_space()
        self.visit(node.right)

    def visit_BShiftROp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '>>'
        self.insert_space()
        self.visit(node.right)

    def visit_BOrOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '|'
        self.insert_space()
        self.visit(node.right)

    def visit_BXorOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '^'
        self.insert_space()
        self.visit(node.right)

    def visit_BAndOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '&'
        self.insert_space()
        self.visit(node.right)

    def visit_FloorDivOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '//'
        self.insert_space()
        self.visit(node.right)

    # cmpop = Eq | NotEq | Lt | LtE | Gt | GtE | Is | IsNot | In | NotIn
    def visit_EqToOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '=='
        self.insert_space()
        self.visit(node.right)
        self.insert_space()
        
        self.result = self.result.rstrip()

    def visit_GreaterThanOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '>'
        self.insert_space()
        self.visit(node.right)
        self.insert_space()
        
        self.result = self.result.rstrip()

    def visit_LessThanOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '<'
        self.insert_space()
        self.visit(node.right)
        self.insert_space()
        
        self.result = self.result.rstrip()

    def visit_NotEqToOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '~='
        self.insert_space()
        self.visit(node.right)
        self.insert_space()
        
        self.result = self.result.rstrip()

    def visit_GreaterOrEqThanOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '>='
        self.insert_space()
        self.visit(node.right)
        self.insert_space()
        
        self.result = self.result.rstrip()

    def visit_LessOrEqThanOp(self, node):
        self.visit(node.left)
        self.insert_space()
        self.result += '<='
        self.insert_space()
        self.visit(node.right)
        self.insert_space()
        
        self.result = self.result.rstrip()

    # unaryop = Invert | Not | UAdd | USub
    '''def visit_Invert(self, node):
        self.result += '~'
        '''

    def visit_UBNotOp(self, node):
        self.result += 'not '
        self.visit(node.operand)
    
    def visit_ULNotOp(self, node):
        self.result += 'not '
        self.visit(node.operand)

    '''def visit_UAdd(self, node):
        self.result += '+'
        '''

    def visit_UMinusOp(self, node):
        self.result += '-'
        self.visit(node.operand)

    # boolop = And | Or
    def visit_AndLoOp(self, node):
        self.visit(node.left)
        self.result += ' and '
        self.visit(node.right)

    def visit_OrLoOp(self, node):
        self.visit(node.left)
        self.result += ' or '
        self.visit(node.right)

    def visit_Concat(self, node):
        self.visit(node.left)
        self.result += '..'
        self.visit(node.right)

    def visit_ULengthOP(self, node):
        self.result += "#"
        self.visit(node.operand)

    def visit_Number(self, node):
        self.result += str(node.n)

    def visit_Name(self, node):
        self.result += node.id

    def visit_String(self, node):
        self.result += "'" + node.s + "'"

    def visit_Field(self, node):
        #self.visit(node.key)
        self.visit(node.value)
    
    def visit_joined_str(self, node, surround=True):#要改
        for val in node.values:
            if isinstance(val, ast.Str):
                self.result += val.s
            else:
                self.visit(val)

    '''
    def visit_FormattedValue(self, node):
        """
            FormattedValue(expr value, int? conversion, expr? format_spec)
        """
        self.result += '{'
        self.visit(node.value)
        self.result += {
            -1: '',     # no formatting
            97: '!a',   # ascii formatting
            114: '!r',  # repr formatting
            115: '!s',  # string formatting
        }[node.conversion]
        if node.format_spec:
            self.result += ':'
            self.visit_joined_str(node.format_spec)
        self.result += '}'

    def visit_IfExp(self, node):
        self.result += '('
        self.visit(node.test)
        self.result += ') ? ('
        self.visit(node.body)
        self.result += ') : ('
        self.visit(node.orelse)
        self.result += ')'
        '''
